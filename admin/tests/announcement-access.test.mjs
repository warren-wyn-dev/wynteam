import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const require = createRequire(import.meta.url);

function loadModule(path, dependencies = {}) {
  const source = readFileSync(new URL(path, import.meta.url), "utf8");
  const { outputText } = ts.transpileModule(source, {
    fileName: path,
    compilerOptions: {
      module: ts.ModuleKind.CommonJS,
      target: ts.ScriptTarget.ES2022,
      jsx: ts.JsxEmit.ReactJSX,
    },
  });
  const exports = {};
  runInNewContext(outputText, {
    exports,
    require: (name) => dependencies[name] ?? require(name),
  });
  return exports;
}

const systems = loadModule("../lib/admin-systems.ts");
const { adminCan } = loadModule("../lib/auth.ts", {
  "@/lib/admin-systems": systems,
  "@/lib/admin-permissions": { fetchAdminAccess: () => assert.fail("no backend access in fixtures") },
  "@/lib/supabase/server": { createClient: () => assert.fail("no backend access in fixtures") },
});

async function viewFor(access, role = "staff") {
  const { default: Page } = loadModule("../app/(admin)/announcements/page.tsx", {
    "@/lib/auth": { adminCan, requireAdminRole: async () => ({ role, access }) },
    "./compose-form": { ComposeForm: "compose-form" },
    "./history": { AnnouncementHistory: "announcement-history" },
    "./inactive-reminder-form": { InactiveReminderForm: "reminder-form" },
    "./inactive-reminder-history": { InactiveReminderHistory: "reminder-history" },
    "@/components/admin/no-access": { NoAccess: "no-access" },
  });
  return Page();
}

function flatten(element) {
  if (!element || typeof element !== "object") return [];
  return [element, ...[element.props?.children].flat(Infinity).flatMap(flatten)];
}

test("Social and Account staff see restricted history without mounting audit reads", async () => {
  for (const system of ["social", "account"]) {
    const elements = flatten(await viewFor({
      available: true, superAdmin: false, permissions: { [system]: "edit" },
    }));
    const types = elements.map((element) => element.type);
    assert.equal(types.includes("announcement-history"), false);
    assert.equal(types.includes("reminder-history"), false);
    assert.ok(elements.some((element) => element.props.children === "ประวัติการส่งประกาศดูได้เฉพาะ super admin"));
    assert.ok(elements.some((element) => element.props.children === "ประวัติการเตือนผู้ใช้ดูได้เฉพาะ super admin"));
    assert.equal(types.includes("compose-form"), system === "social");
    assert.equal(types.includes("reminder-form"), system === "account");
  }
});

test("Super admin and legacy admin retain history and both send forms", async () => {
  for (const access of [
    { available: true, superAdmin: true, permissions: {} },
    { available: false, superAdmin: false, permissions: {} },
  ]) {
    const types = flatten(await viewFor(access, "admin")).map((element) => element.type);
    for (const type of ["announcement-history", "reminder-history", "compose-form", "reminder-form"]) {
      assert.ok(types.includes(type), type);
    }
  }
});

test("View-only staff cannot send and other system staff cannot enter the page", async () => {
  const types = flatten(await viewFor({
    available: true, superAdmin: false, permissions: { social: "view" },
  })).map((element) => element.type);
  assert.equal(types.includes("compose-form"), false);
  assert.equal(types.includes("reminder-form"), false);
  assert.equal((await viewFor({
    available: true, superAdmin: false, permissions: { food: "edit" },
  })).type, "no-access");
});
