import assert from "node:assert/strict";
import { test } from "node:test";

import { authorizeTool } from "../policy.ts";
import { NO_ACCESS, NOT_INSTALLED, SUPER_ADMIN, fakeTool } from "./helpers.ts";

test("super admin may run a level 1 tool", () => {
  assert.deepEqual(authorizeTool(fakeTool(), SUPER_ADMIN), { allowed: true });
});

test("unknown tools are refused", () => {
  const decision = authorizeTool(undefined, SUPER_ADMIN);
  assert.equal(decision.allowed, false);
  assert.equal(!decision.allowed && decision.reason, "unknown_tool");
});

test("level 2 and 3 tools need approval even for the super admin", () => {
  for (const level of [2, 3] as const) {
    const decision = authorizeTool(fakeTool({ level }), SUPER_ADMIN);
    assert.equal(!decision.allowed && decision.reason, "needs_approval");
  }
});

test("a system tool needs that system's permission", () => {
  const tool = fakeTool({ system: "food", access: "view" });
  assert.equal(authorizeTool(tool, NO_ACCESS).allowed, false);
  assert.equal(authorizeTool(tool, { available: true, superAdmin: false, permissions: { food: "view" } }).allowed, true);
  assert.equal(authorizeTool(tool, { available: true, superAdmin: false, permissions: { social: "edit" } }).allowed, false);
});

test("edit access is required for edit tools; view is not enough", () => {
  const tool = fakeTool({ system: "food", access: "edit" });
  assert.equal(authorizeTool(tool, { available: true, superAdmin: false, permissions: { food: "view" } }).allowed, false);
  assert.equal(authorizeTool(tool, { available: true, superAdmin: false, permissions: { food: "edit" } }).allowed, true);
});

test("fails closed before the permissions foundation is installed", () => {
  assert.equal(authorizeTool(fakeTool({ system: "social" }), NOT_INSTALLED).allowed, false);
});
