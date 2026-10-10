/**
 * Presentation gate only. Never treat this as proof of RPC/RLS authorization:
 * the target page and Supabase backend must enforce all access independently.
 * Keeping this pure makes it testable without any hosted Supabase account.
 */
export function canOpenAdminControl(role, capability) {
  if (role !== "admin" && role !== "moderator") return false;
  if (capability?.stage !== "existing-route") return false;
  // Never turn catalog metadata into an arbitrary external redirect, fragment,
  // protocol-relative URL or URL with query string/user-supplied parameters.
  const href = capability.href;
  if (typeof href !== "string" || !/^\/(?!\/)(?:[a-z0-9-]+(?:\/[a-z0-9-]+)*)?$/.test(href)) {
    return false;
  }
  const allowedRoles = capability.roles;
  if (allowedRoles !== undefined &&
    (!Array.isArray(allowedRoles) || allowedRoles.length === 0 ||
     !allowedRoles.every((candidate) => candidate === "admin" || candidate === "moderator") ||
     !allowedRoles.includes(role))) {
    return false;
  }
  return true;
}
