import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const compiled = ts.transpileModule(readFileSync(new URL("../lib/maps-saved-places.ts", import.meta.url), "utf8"), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const mod = { exports: {} };
runInNewContext(compiled, { module: mod, exports: mod.exports, Number, Array, Error });
const { loadSavedPlaces, saveMapPlace } = mod.exports;
const plain = (value) => JSON.parse(JSON.stringify(value));

function fakeClient({ session = { user: { id: "u1" } }, rpc = {} } = {}) {
  const calls = [];
  return {
    calls,
    auth: { getSession: async () => ({ data: { session } }) },
    rpc: async (name, args) => {
      calls.push([name, args]);
      return rpc[name] ?? { data: null, error: null };
    },
  };
}

test("signed-out visitors get a sign-in state without calling the RPC", async () => {
  const client = fakeClient({ session: null });
  assert.deepEqual(plain(await loadSavedPlaces(client)), { status: "signed-out" });
  assert.equal(client.calls.length, 0);
});

test("a missing migration hides saved places instead of erroring", async () => {
  const client = fakeClient({ rpc: { wynos_saved_places_list: { data: null, error: { code: "PGRST202" } } } });
  assert.deepEqual(plain(await loadSavedPlaces(client)), { status: "unavailable" });
});

test("rows are parsed and malformed ones dropped", async () => {
  const client = fakeClient({ rpc: { wynos_saved_places_list: { data: [
    { id: "a", kind: "home", label: "บ้าน", place_id: null, name: "หอพัก", address: null, latitude: 16.2, longitude: 103.2 },
    { id: "b", kind: "office", name: "x", latitude: 1, longitude: 1 },
    { id: "c", kind: "favorite", name: "ร้าน", latitude: "bad", longitude: 1 },
  ], error: null } } });
  const state = plain(await loadSavedPlaces(client));
  assert.equal(state.status, "ready");
  assert.deepEqual(state.places.map((p) => p.id), ["a"]);
  assert.equal(state.places[0].label, "บ้าน");
});

test("save sends trimmed fields and maps server errors to Thai messages", async () => {
  const ok = fakeClient();
  await saveMapPlace(ok, { kind: "favorite", name: "ร้านกาแฟ", latitude: 16.2, longitude: 103.2 });
  assert.equal(ok.calls[0][0], "wynos_save_place");
  assert.equal(ok.calls[0][1].p_kind, "favorite");
  const full = fakeClient({ rpc: { wynos_save_place: { error: { message: "saved place limit reached" } } } });
  await assert.rejects(saveMapPlace(full, { kind: "favorite", name: "x", latitude: 1, longitude: 1 }), /สูงสุด 50/);
  const anon = fakeClient({ rpc: { wynos_save_place: { error: { message: "authentication required" } } } });
  await assert.rejects(saveMapPlace(anon, { kind: "home", name: "x", latitude: 1, longitude: 1 }), /เข้าสู่ระบบ/);
});
