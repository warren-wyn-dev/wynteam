// Supabase Auth can sign a fresh session ahead of the database clock. Until
// the clocks agree PostgREST rejects that token with 401 PGRST303 "JWT issued
// at future", which customers saw as a raw error right after signing in.
// The token becomes valid on its own once the database catches up, so wait and
// resend instead of failing. Only that exact error is retried, and only for
// requests whose body can be sent again.
const RETRY_DELAYS_MS = [1000, 2000, 3000, 5000, 8000, 13000, 13000];

function canResend(input: RequestInfo | URL, init?: RequestInit) {
  if (typeof Request !== "undefined" && input instanceof Request) return input.body === null;
  const body = init?.body;
  return body == null
    || typeof body === "string"
    || (typeof Blob !== "undefined" && body instanceof Blob)
    || (typeof FormData !== "undefined" && body instanceof FormData)
    || (typeof URLSearchParams !== "undefined" && body instanceof URLSearchParams)
    || body instanceof ArrayBuffer
    || ArrayBuffer.isView(body);
}

export async function isSessionClockSkewResponse(response: Response) {
  if (response.status !== 401) return false;
  const text = await response.clone().text().catch(() => "");
  return text.includes("JWT issued at future");
}

/** Retries after which a still-rejected token is replaced by a fresh one. */
const REFRESH_AFTER_ATTEMPTS = 2;

function withBearer(init: RequestInit | undefined, token: string): RequestInit {
  const headers = new Headers(init?.headers);
  if (!/^Bearer /i.test(headers.get("Authorization") ?? "")) return init ?? {};
  headers.set("Authorization", `Bearer ${token}`);
  return { ...init, headers };
}

/**
 * refreshAccessToken (optional) gets a newly issued session token. A stored
 * token minted while Auth was ahead of the database stays "from the future"
 * until its own iat, which can outlive every retry (Founder 2026-11-01: the
 * Merchant stayed unusable for 15+ minutes). After a couple of rejections the
 * request is resent once with a fresh token. Only the bearer header changes.
 */
export function createClockSkewRetryFetch(
  baseFetch: typeof fetch = (...args) => fetch(...args),
  refreshAccessToken?: () => Promise<string | null>,
): typeof fetch {
  return async (input, init) => {
    const resendable = canResend(input, init);
    // A Request carries its own headers; only init headers can take a new token.
    const swappable = !(typeof Request !== "undefined" && input instanceof Request);
    let request = init;
    let refreshed = false;
    for (let attempt = 0; ; attempt += 1) {
      const response = await baseFetch(input, request);
      if (!resendable || attempt >= RETRY_DELAYS_MS.length || !(await isSessionClockSkewResponse(response))) return response;
      if (refreshAccessToken && swappable && !refreshed && attempt + 1 >= REFRESH_AFTER_ATTEMPTS) {
        refreshed = true;
        const token = await refreshAccessToken().catch(() => null);
        if (token) { request = withBearer(init, token); continue; }
      }
      await new Promise((resolve) => setTimeout(resolve, RETRY_DELAYS_MS[attempt]));
    }
  };
}

/**
 * One shared refresh at a time, at most once per cooldown, so a burst of
 * rejected reads cannot become a burst of token refreshes.
 */
export function createSharedTokenRefresher(refresh: () => Promise<string | null>, cooldownMs = 30_000, now: () => number = Date.now) {
  let pending: Promise<string | null> | null = null;
  let last: { at: number; token: string | null } | null = null;
  return () => {
    if (pending) return pending;
    if (last && now() - last.at < cooldownMs) return Promise.resolve(last.token);
    pending = refresh().catch(() => null).then((token) => { last = { at: now(), token }; pending = null; return token; });
    return pending;
  };
}

// Last-resort Thai copy for session errors that outlived the retries above, so
// the raw English PostgREST message never reaches customers or merchants.
export function sessionErrorCopy(message: string): string | null {
  if (message.includes("JWT issued at future")) return "กำลังยืนยันการเข้าสู่ระบบ กรุณาลองอีกครั้งในอีกสักครู่";
  if (message.includes("JWT expired")) return "เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่แล้วลองอีกครั้ง";
  return null;
}
