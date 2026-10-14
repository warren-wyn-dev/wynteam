import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import vm from "node:vm";
import ts from "typescript";
import { createClient } from "@supabase/supabase-js";

test("authenticated catalogue hides archived menus while retaining temporarily unavailable items", async () => {
  const output = ts.transpileModule(readFileSync(new URL("../lib/food-customer.ts", import.meta.url), "utf8"), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText;
  const api = {};
  vm.runInNewContext(output, { exports: api, require: () => ({}) });
  let menuRequest;
  const client = createClient("https://synthetic.supabase.invalid", "synthetic-publishable-key", {
    auth: { persistSession: false, autoRefreshToken: false }, global: { fetch: async url => {
      const request = new URL(url);
      if (request.pathname.endsWith("food_customer_access_enabled")) return Response.json(true);
      if (request.pathname.endsWith("is_developer_account")) return Response.json(false);
      if (request.pathname.endsWith("/food_stores")) return Response.json({ id: "fixture-store", name: "Synthetic store" });
      if (request.pathname.endsWith("/food_menu_items")) {
        menuRequest = request;
        return Response.json([
          { id: "active", is_available: true, archived_at: null },
          { id: "temporarily-closed", is_available: false, archived_at: null },
          ...(request.searchParams.get("archived_at") === "is.null" ? [] : [{ id: "archived", is_available: false, archived_at: "2026-10-14T00:00:00Z" }]),
        ]);
      }
      return Response.json([]);
    } },
  });
  const snapshot = await api.fetchFoodCustomerSnapshot(client, "fixture-user", "fixture-store");
  assert.equal(menuRequest.searchParams.get("store_id"), "eq.fixture-store");
  assert.equal(menuRequest.searchParams.get("archived_at"), "is.null");
  assert.deepEqual(Array.from(snapshot.menu, item => item.id), ["active", "temporarily-closed"]);
});
