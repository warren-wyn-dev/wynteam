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

export function createClockSkewRetryFetch(baseFetch: typeof fetch = (...args) => fetch(...args)): typeof fetch {
  return async (input, init) => {
    const resendable = canResend(input, init);
    for (let attempt = 0; ; attempt += 1) {
      const response = await baseFetch(input, init);
      if (!resendable || attempt >= RETRY_DELAYS_MS.length || !(await isSessionClockSkewResponse(response))) return response;
      await new Promise((resolve) => setTimeout(resolve, RETRY_DELAYS_MS[attempt]));
    }
  };
}

// Last-resort Thai copy for session errors that outlived the retries above, so
// the raw English PostgREST message never reaches customers or merchants.
export function sessionErrorCopy(message: string): string | null {
  if (message.includes("JWT issued at future")) return "กำลังยืนยันการเข้าสู่ระบบ กรุณาลองอีกครั้งในอีกสักครู่";
  if (message.includes("JWT expired")) return "เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่แล้วลองอีกครั้ง";
  return null;
}
