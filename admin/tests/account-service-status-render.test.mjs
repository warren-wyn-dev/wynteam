import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import vm from "node:vm";
import React from "react";
import { renderToStaticMarkup } from "react-dom/server";
import ts from "typescript";

const require = createRequire(import.meta.url);
const source = readFileSync(
  new URL("../components/admin/account-service-status.tsx", import.meta.url),
  "utf8",
);
const compiled = ts.transpileModule(source, {
  compilerOptions: {
    target: ts.ScriptTarget.ES2022,
    module: ts.ModuleKind.CommonJS,
    jsx: ts.JsxEmit.ReactJSX,
  },
});
const exported = { exports: {} };
const stubRequire = (name) =>
  name === "@/components/ui/badge"
    ? {
        Badge: ({ variant, children }) =>
          React.createElement("span", { "data-variant": variant }, children),
      }
    : require(name);

vm.runInNewContext(compiled.outputText, {
  module: exported,
  exports: exported.exports,
  require: stubRequire,
});
const { AccountServiceStatus } = exported.exports;
assert.equal(typeof AccountServiceStatus, "function");
const snapshot = {
  account_id: "00000000-0000-0000-0000-000000000123",
  created_at: "2026-10-09T00:00:00Z",
  signals: {
    social_profile: true,
    food_activity: false,
    merchant_record: false,
    maps_activity: false,
  },
};

function render(signals) {
  return renderToStaticMarkup(
    React.createElement(AccountServiceStatus, {
      snapshot: { ...snapshot, signals },
    }),
  );
}
const socialOnly = render(snapshot.signals);
for (const label of ["WYNOS Social", "WYNOS Food", "WYNOS Merchant", "WYNOS Maps"]) {
  assert.ok(socialOnly.includes(label), `missing service: ${label}`);
}
assert.ok(socialOnly.includes("00000000-0000-0000-0000-000000000123"));
assert.equal((socialOnly.match(/มีโปรไฟล์/g) ?? []).length, 1);
assert.equal((socialOnly.match(/ยังไม่พบข้อมูล/g) ?? []).length, 3);
assert.ok(socialOnly.includes("ไม่ได้แปลว่าผู้ใช้ไม่เคยเข้าใช้บริการนั้น"));

const allOn = render(Object.fromEntries(
  Object.keys(snapshot.signals).map((key) => [key, true]),
));
assert.ok(allOn.includes("พบกิจกรรม"));
assert.ok(allOn.includes("มีข้อมูล Merchant"));
assert.equal((allOn.match(/ยังไม่พบข้อมูล/g) ?? []).length, 0);

const allOff = render(Object.fromEntries(
  Object.keys(snapshot.signals).map((key) => [key, false]),
));
assert.equal((allOff.match(/ยังไม่พบข้อมูล/g) ?? []).length, 4);
assert.ok(!allOff.includes("มีโปรไฟล์"));

console.log("PASS: WYNOS Account four-service UI evidence and no-evidence states");
