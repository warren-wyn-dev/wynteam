// Shared links (post, profile, club) must survive the login wall: a signed-out
// recipient is sent to /welcome, signs in or signs up, and should land on the
// page they were sent — not on Home. Only same-origin, in-app paths are ever
// stored or returned, so this can never become an open redirect.
const KEY = "wynos.return-to.v1";
const MAX_AGE_MS = 60 * 60 * 1000;
const AUTH_PREFIXES = ["/welcome", "/login", "/signup", "/onboarding", "/auth", "/forgot-password", "/reset-password", "/account"];

export function isSafeReturnPath(path: string): boolean {
  if (!path.startsWith("/") || path.startsWith("//") || path.startsWith("/\\") || path.length > 512) return false;
  if (/[\u0000-\u001f]/.test(path)) return false;
  const pathname = path.split(/[?#]/)[0];
  if (pathname === "/") return false;
  return !AUTH_PREFIXES.some((prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`));
}

export function rememberReturnPath(path: string): void {
  if (!isSafeReturnPath(path)) return;
  try { window.sessionStorage.setItem(KEY, JSON.stringify({ path, at: Date.now() })); } catch { /* storage unavailable */ }
}

export function clearReturnPath(): void {
  try { window.sessionStorage.removeItem(KEY); } catch { /* storage unavailable */ }
}

/** Returns the stored path once (then forgets it), or null. */
export function consumeReturnPath(): string | null {
  let raw: string | null = null;
  try { raw = window.sessionStorage.getItem(KEY); } catch { return null; }
  clearReturnPath();
  if (!raw) return null;
  try {
    const { path, at } = JSON.parse(raw) as { path?: unknown; at?: unknown };
    if (typeof path !== "string" || typeof at !== "number" || Date.now() - at > MAX_AGE_MS) return null;
    return isSafeReturnPath(path) ? path : null;
  } catch {
    return null;
  }
}
