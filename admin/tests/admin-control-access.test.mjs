import assert from "node:assert/strict";
import { test } from "node:test";
import { readFileSync } from "node:fs";
import { canOpenAdminControl } from "../lib/admin-control-access.mjs";

const catalog = readFileSync(new URL("../lib/admin-control-catalog.ts", import.meta.url), "utf8");

test("catalog navigation allows only two authenticated staff roles", () => {
  const normal = { stage: "existing-route", href: "/social" };
  for (const role of ["admin", "moderator"]) assert.equal(canOpenAdminControl(role, normal), true);
  for (const role of [null, undefined, "", "user", "owner", "super_admin", {}, ["admin"]]) {
    assert.equal(canOpenAdminControl(role, normal), false, String(role));
  }
});

test("Admin-only Food and finance destinations never appear to a moderator", () => {
  for (const href of ["/food/orders", "/food/ads"]) {
    const restricted = { stage: "existing-route", href, roles: ["admin"] };
    assert.equal(canOpenAdminControl("admin", restricted), true);
    assert.equal(canOpenAdminControl("moderator", restricted), false);
  }
  assert.equal(canOpenAdminControl("moderator", {
    stage: "existing-route", href: "/audit-log", roles: ["admin", "moderator"],
  }), true);
  for (const roles of [[], ["super_admin"], ["admin", "super_admin"], "admin", null]) {
    assert.equal(canOpenAdminControl("admin", { stage: "existing-route", href: "/food/orders", roles }), false);
  }
});

test("planned and malformed catalog entries cannot become clickable", () => {
  for (const href of ["/", "/maps", "/finance", "https://evil.example", "//evil.example", "/users?q=1", "/reports#detail", "/a/../admin", "/%2fexternal", "/admin\\nheaders", "javascript:alert(1)", "", undefined]) {
    if (href === "/" || href === "/maps" || href === "/finance") {
      assert.equal(canOpenAdminControl("admin", { stage: "planned", href }), false);
    } else {
      assert.equal(canOpenAdminControl("admin", { stage: "existing-route", href }), false, String(href));
    }
  }
  assert.equal(canOpenAdminControl("admin", { stage: "existing-route", href: "/" }), true);
  assert.equal(canOpenAdminControl("admin", null), false);
  assert.equal(canOpenAdminControl("admin", {}), false);
});

test("all catalog planned entries are unlinked and existing entries have literal local routes", () => {
  const entries = [...catalog.matchAll(/^\s*\{ id: "[^"]+", label: "[^"]+", stage: "(existing-route|planned)"[^\n]*\},?$/gm)];
  assert.ok(entries.length >= 45, "all Control Map capabilities stay in inventory");
  for (const entry of entries) {
    const raw = entry[0];
    const href = raw.match(/\bhref: "([^"]+)"/)?.[1];
    if (entry[1] === "planned") {
      assert.equal(href, undefined, "planned entry must not declare a link");
    } else {
      assert.ok(href, "existing route must declare a destination");
      assert.equal(canOpenAdminControl("admin", { stage: "existing-route", href }), true, href);
    }
  }
});
