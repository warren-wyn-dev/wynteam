/**
 * Trusted, public **reachability** checks, NOT end-to-end business health.
 * Hosts are fixed in code. Caller-controlled URLs are never fetched.
 */
export const ALLOWED_HEALTH_ENDPOINTS = Object.freeze({
  social: "https://wynos.online/",
  food: "https://food.wynos.online/",
  merchant: "https://merchant.wynos.online/",
  maps: "https://maps.wynos.online/",
});

export function classifyHttpStatus(code) {
  if (!Number.isInteger(code) || code < 100 || code > 599) return "unknown";
  if ((code >= 200 && code < 400)) return "reachable"; // includes login redirect, NOT a functional test
  if (code === 401 || code === 403 || code === 408 || code === 429) return "unknown";
  if (code >= 500 || code === 404 || code === 410) return "degraded";
  return "unknown";
}

export async function probePublicReachability(id, fetchImpl = fetch) {
  const url = ALLOWED_HEALTH_ENDPOINTS[id];
  if (typeof url !== "string") throw new Error("Untrusted health source");
  const checkedAt = new Date().toISOString();
  try {
    const response = await fetchImpl(url, {
      method: "HEAD",
      credentials: "omit",
      redirect: "manual",
      // Identical public URLs cache briefly and avoid multiplying checks
      // across authenticated staff page loads.
      next: { revalidate: 120 },
      signal: AbortSignal.timeout(2500),
    });
    const status = classifyHttpStatus(response.status);
    return {
      id,
      checkedAt,
      status,
      detail: status === "reachable"
        ? "ตอบสนอง HTTP ได้ ยังไม่ได้ยืนยันฟังก์ชันภายใน"
        : status === "degraded"
          ? "ปลายทางตอบสถานะ HTTP ผิดปกติ"
          : "ปลายทางอาจมีการป้องกันการเข้าถึงหรือจำกัดคำขอ",
    };
  } catch {
    // DNS/network/protection failures must never be mislabelled as a real
    // outage, or report internal stack traces to operators.
    return {
      id,
      checkedAt,
      status: "unknown",
      detail: "ยังไม่สามารถยืนยันการเข้าถึงจากระบบตรวจสอบได้",
    };
  }
}
