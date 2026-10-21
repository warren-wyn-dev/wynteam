export function processorFee(balance: Record<string, unknown>): number | null {
  if (!Array.isArray(balance.fee_details)) return null;
  let total = 0, combined = 0;
  for (const raw of balance.fee_details) {
    const line = raw as Record<string, unknown>;
    if (!Number.isSafeInteger(line.amount) || Number(line.amount) < 0 || typeof line.type !== "string") return null;
    combined += Number(line.amount);
    if (line.type !== "application_fee") total += Number(line.amount);
  }
  return Number.isSafeInteger(total) && combined === balance.fee ? total : null;
}

export function bangkokPayoutWindow(now = new Date()) {
  const local = new Date(now.getTime() + 7 * 3600000);
  const day = local.toISOString().slice(0, 10);
  const cutoff = new Date(`${day}T00:00:00+07:00`);
  return { businessDay: new Date(cutoff.getTime() - 86400000 + 7 * 3600000).toISOString().slice(0, 10),
    cutoff: cutoff.toISOString(), mayInitiate: local.getUTCHours() >= 8 };
}

export async function stripeGet(path: string, secret: string, account?: string) {
  if (!path.startsWith("/v1/") || path.includes("..")) throw Error("invalid_provider_path");
  const response = await fetch("https://api.stripe.com" + path, {
    headers: { Authorization: `Basic ${btoa(secret + ":")}`, ...(account ? { "Stripe-Account": account } : {}) },
    redirect: "error", signal: AbortSignal.timeout(7500),
  });
  if (!response.ok) throw Error("provider_read_failed");
  return await response.json() as Record<string, unknown>;
}
