import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import vm from "node:vm";
import { createRequire } from "node:module";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import ts from "typescript";
import { createClient } from "@supabase/supabase-js";

const output = ts.transpileModule(readFileSync(new URL("../lib/food-support.ts", import.meta.url), "utf8"), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const api = {};
vm.runInNewContext(output, { exports: api, AbortSignal });
const support = { id: "case-fixture", order_id: "order-fixture", order_number: "TEST-001", subject: "Synthetic case", status: "open", version: 1, appeal_count: 0, messages: [] };

function fixture(responder = () => support) {
  const requests = [];
  const client = createClient("https://synthetic.supabase.invalid", "synthetic-publishable-key", {
    auth: { persistSession: false, autoRefreshToken: false }, global: { fetch: async (url, options) => {
      requests.push({ name: new URL(url).pathname.split("/").at(-1), body: JSON.parse(options.body), signal: options.signal });
      return Response.json(responder(requests.at(-1)));
    } },
  });
  return { client, requests };
}

test("support writes pin order evidence and optimistic version without client user identifiers", async () => {
  const { client, requests } = fixture();
  await api.createFoodSupportCase(client, { orderId: "order-fixture", kind: "order", subject: "  Subject fixture  ", body: "  Body fixture  ", evidenceItemId: "item-fixture", compensationRequested: true });
  await api.replyFoodSupportCase(client, support, "  Additional detail  ", true);
  assert.deepEqual(requests[0].body, { p_order_id: "order-fixture", p_kind: "order", p_subject: "Subject fixture", p_body: "Body fixture", p_evidence_order_item_id: "item-fixture", p_compensation_requested: true });
  assert.deepEqual(requests[1].body, { p_case_id: "case-fixture", p_expected_version: 1, p_body: "Additional detail", p_appeal: true });
  assert.ok(requests.every(request => request.signal instanceof AbortSignal));
});

test("malformed support responses cannot become case success or an empty list", async () => {
  const { client } = fixture(() => null);
  await assert.rejects(api.loadFoodSupportCases(client), /Unexpected support response/);
  await assert.rejects(api.loadFoodSupportCase(client, "case-fixture"), /Unexpected support response/);
  await assert.rejects(api.replyFoodSupportCase(client, support, "Reply fixture", false), /Unexpected support response/);
  const broken = fixture(() => ({ ...support, messages: [{ id: "m", body: {}, actor_role: "support" }] }));
  await assert.rejects(api.loadFoodSupportCase(broken.client, "case-fixture"), /Unexpected support response/);
});

test("support errors instruct uncertain writes to refresh and never disclose raw failures", () => {
  assert.match(api.foodSupportErrorCopy({ message: "AbortError: timeout private-provider-detail" }), /ตรวจสอบก่อนส่งอีกครั้ง/);
  assert.match(api.foodSupportErrorCopy({ message: "Case changed; reload" }), /โหลดล่าสุด/);
  assert.doesNotMatch(api.foodSupportErrorCopy({ message: "private-provider-detail" }), /private-provider-detail/);
});

test("new customer support stays hidden until the account passes the existing rollout gate", () => {
  const require = createRequire(import.meta.url);
  const code = ts.transpileModule(readFileSync(new URL("../components/food/food-support-panel.tsx", import.meta.url), "utf8"), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022, jsx: ts.JsxEmit.ReactJSX },
  }).outputText;
  for (const allowed of [false, true]) {
    const mod = { exports: {} }, calls = [];
    vm.runInNewContext(code, { module: mod, exports: mod.exports, require(name) {
      if (name === "@/lib/use-is-developer-account") return { useIsDeveloperAccount(client, userId) { calls.push({ client, userId }); return allowed; } };
      if (name === "@/lib/food-support") return api;
      return require(name);
    } });
    const client = {};
    const html = renderToStaticMarkup(createElement(mod.exports.FoodSupportEntry, { client, userId: "account-fixture", orders: [] }));
    assert.equal(calls[0].client, client);
    assert.equal(calls[0].userId, "account-fixture");
    if (allowed) assert.match(html, /ช่วยเหลือและติดตามปัญหาออเดอร์/);
    else assert.equal(html, "");
  }
});
