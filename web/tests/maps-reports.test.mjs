import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const compiled = ts.transpileModule(readFileSync(new URL("../lib/maps-reports.ts", import.meta.url), "utf8"), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const mod = { exports: {} };
runInNewContext(compiled, { module: mod, exports: mod.exports, require: () => ({}), AbortSignal, Error, Object });
const { canReportMapPlace, submitMapReport, searchReportableMapPlaces, loadMyMapReports, mapReportErrorCopy } = mod.exports;
const place = `wynos_place_${"a".repeat(32)}`;

function rpcClient(result) {
  const calls = [];
  return {
    calls,
    rpc: (name, input) => { calls.push({ name, input }); return { abortSignal: () => Promise.resolve(result) }; },
  };
}
test("reports accept only persistent WYNOS public-place identity syntax", () => {
  assert.equal(canReportMapPlace(place), true);
  for (const value of [null, "osm_123", "apple_place_x", "home", "wynos_place_" + "a".repeat(31), place + "extra"]) assert.equal(canReportMapPlace(value), false);
});
test("intake sends only the selected place, allowlisted kind and trimmed plain text", async () => {
  const client = rpcClient({ data: "report-uuid", error: null });
  assert.equal(await submitMapReport(client, place, "wrong_info", "  Entrance is on the north side  "), "report-uuid");
  assert.equal(JSON.stringify(client.calls), JSON.stringify([{ name: "submit_wynos_map_report", input: {
    p_place_id: place, p_kind: "wrong_info", p_note: "Entrance is on the north side",
  } }]));
});
test("invalid client intake fails before any request, including inherited object keys", async () => {
  const client = rpcClient({});
  for (const [id, kind, note] of [["osm_1", "closed", "This place has closed"], [place, "toString", "This place has closed"], [place, "other", "short"], [place, "other", "a".repeat(501)]]) {
    await assert.rejects(submitMapReport(client, id, kind, note), /Invalid report input/);
  }
  assert.equal(client.calls.length, 0);
});
test("server duplicate/rate/deployment errors remain actionable without losing intake", async () => {
  for (const [message, copy] of [["Active report already exists", "รอตรวจสอบ"], ["Report rate limit", "24 ชั่วโมง"], ["Public place not available", "ค้นหาใหม่"]]) {
    const client = rpcClient({ data: null, error: { message } });
    await assert.rejects(submitMapReport(client, place, "closed", "This place has closed"), error => mapReportErrorCopy(error).includes(copy));
  }
  assert.match(mapReportErrorCopy({ code: "PGRST202" }), /ยังไม่พร้อม/);
});
test("owner status requests have no caller-supplied user identity", async () => {
  const client = rpcClient({ data: [], error: null });
  assert.equal((await loadMyMapReports(client)).length, 0);
  assert.equal(JSON.stringify(client.calls), JSON.stringify([{ name: "wynos_my_map_reports", input: { p_limit: 50 } }]));
  await assert.rejects(loadMyMapReports(rpcClient({ data: null, error: null })), /Unexpected/);
});
test("place search selects only public labels and escapes LIKE wildcards", async () => {
  const calls = [];
  const query = {};
  for (const method of ["select", "eq", "ilike", "order", "limit"]) query[method] = (...args) => { calls.push([method, ...args]); return query; };
  query.abortSignal = () => Promise.resolve({ data: [{ id: place, name_th: "Sample", address: null }, { id: "osm_1" }], error: null });
  const client = { from: name => { calls.push(["from", name]); return query; } };
  assert.equal((await searchReportableMapPlaces(client, "Sample%_\\")).length, 1);
  assert.equal(JSON.stringify(calls), JSON.stringify([
    ["from", "wynos_places"], ["select", "id,name_th,address"], ["eq", "is_active", true],
    ["ilike", "name_th", "%Sample\\%\\_\\\\%"], ["order", "name_th"], ["limit", 10],
  ]));
  calls.length = 0;
  assert.equal((await searchReportableMapPlaces(client, "a")).length, 0);
  assert.equal(calls.length, 0);
});

test("account gate preserves same-user drafts, clears switches and ignores stale gate replies", async () => {
  const gateRequests = [];
  let onAuth;
  let effect;
  let state;
  let unsubscribed = false;
  const timers = new Map();
  let nextTimer = 0;
  const client = {
    auth: {
      getSession: async () => ({ data: { session: { user: { id: "developer-a" } } } }),
      onAuthStateChange: callback => { onAuth = callback; return { data: { subscription: { unsubscribe() { unsubscribed = true; } } } }; },
    },
    rpc: name => {
      assert.equal(name, "is_developer_account");
      return { abortSignal(signal) {
        assert.ok(signal instanceof AbortSignal);
        return new Promise(resolve => gateRequests.push(resolve));
      } };
    },
  };
  const react = {
    useMemo: factory => factory(),
    useState: initial => { state = initial; return [state, update => { state = typeof update === "function" ? update(state) : update; }]; },
    useEffect: callback => { effect = callback; },
  };
  const componentCode = ts.transpileModule(readFileSync(new URL("../components/maps/maps-reports-panel.tsx", import.meta.url), "utf8"), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022, jsx: ts.JsxEmit.ReactJSX },
  }).outputText + "\nexports.testAccountHook = useReportAccount;";
  const component = { exports: {} };
  runInNewContext(componentCode, { module: component, exports: component.exports, AbortSignal,
    require: name => name === "react" ? react : name === "@/lib/supabase/browser" ? { getSupabaseBrowserClient: () => client } : {},
    window: { setTimeout(callback) { timers.set(++nextTimer, callback); return nextTimer; }, clearTimeout(id) { timers.delete(id); } },
  });
  component.exports.testAccountHook();
  const cleanup = effect();
  const tick = async () => { await Promise.resolve(); await Promise.resolve(); };
  const flushTimers = () => { const pending = [...timers.values()]; timers.clear(); for (const callback of pending) callback(); };
  assert.equal(state.ready, false);
  await tick();
  gateRequests[0]({ data: true, error: null }); await tick();
  assert.equal(state.allowed, true);
  onAuth("TOKEN_REFRESHED", { user: { id: "developer-a" } });
  assert.equal(state.allowed, true, "same-user refresh keeps the mounted report draft");
  assert.equal(state.ready, true);
  flushTimers();
  assert.equal(state.allowed, true, "draft stays mounted during the bounded recheck");
  onAuth("SIGNED_IN", { user: { id: "developer-b" } });
  assert.equal(state.allowed, false, "identity switch clears prior account immediately");
  assert.equal(state.ready, false);
  flushTimers();
  gateRequests[1]({ data: true, error: null }); await tick();
  assert.equal(state.allowed, false, "stale A permission cannot open B reports");
  gateRequests[2]({ data: true, error: null }); await tick();
  assert.equal(state.userId, "developer-b"); assert.equal(state.allowed, true);
  onAuth("SIGNED_OUT", null);
  assert.equal(state.allowed, false); assert.equal(state.userId, undefined);
  flushTimers();
  cleanup();
  assert.equal(unsubscribed, true);
});
