import { hasSystemAccess } from "../admin-systems.ts";
import type { SecretaryAccess, ToolDefinition } from "./types.ts";

export type ToolDecision =
  | { allowed: true }
  | { allowed: false; reason: "no_permission" | "needs_approval" | "unknown_tool"; message: string };

/**
 * Checked before every tool call, in the server process. The AI never
 * decides this and cannot change it: the decision uses the signed-in
 * admin's own access (admin_my_access), and every tool's RPC re-checks
 * permission in the database anyway (defence in depth).
 *
 * Phase 1 runs Level 1 (read & analyze) tools only. Level 2 and 3 tools are
 * refused here until the approval workflow (Phase 3) exists, so a tool
 * registered by mistake still cannot act.
 */
export function authorizeTool(tool: ToolDefinition | undefined, access: SecretaryAccess): ToolDecision {
  if (!tool) {
    return { allowed: false, reason: "unknown_tool", message: "ไม่มีเครื่องมือนี้ในระบบ" };
  }
  if (tool.level !== 1) {
    return {
      allowed: false,
      reason: "needs_approval",
      message: "การดำเนินการนี้ต้องผ่านการอนุมัติ ซึ่งยังไม่เปิดใช้ใน Phase 1",
    };
  }
  if (tool.system !== null && hasSystemAccess(access, tool.system, tool.access) !== true) {
    // null (permissions not installed) is treated as no access: fail closed.
    return { allowed: false, reason: "no_permission", message: "บัญชีนี้ไม่มีสิทธิ์เข้าถึงข้อมูลของระบบนี้" };
  }
  return { allowed: true };
}
