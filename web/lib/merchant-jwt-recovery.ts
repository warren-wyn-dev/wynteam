/**
 * Read-only recovery for intermittent Supabase PostgREST PGRST303 responses.
 *
 * Supabase Auth may issue a valid JWT while PostgREST's JWT validator uses a
 * lagging clock. Retrying only a harmless Merchant read (not mutations or
 * authentication/session operations) may succeed after its clock catches up.
 * We do not alter tokens, loosen validation, or bypass auth/RLS.
 */
export function isMerchantJwtIssuedInFuture(error: unknown): boolean {
  if (typeof error === "string") return /jwt issued at future/i.test(error);
  if (!error || typeof error !== "object") return false;
  const value = error as { code?: unknown; message?: unknown };
  // Error codes alone are insufficient when reused for other JWT failures;
  // only the specific server diagnostic qualifies for this limited retry.
  return typeof value.message === "string" && /jwt issued at future/i.test(value.message);
}

const READ_RETRY_DELAYS_MS = [750, 2000, 4000] as const;

export async function retryMerchantJwtRead<T>(
  read: () => Promise<T>,
  wait: (ms: number) => Promise<void> = (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
): Promise<T> {
  for (let attempt = 0; ; attempt += 1) {
    try {
      return await read();
    } catch (error) {
      if (!isMerchantJwtIssuedInFuture(error) || attempt >= READ_RETRY_DELAYS_MS.length) throw error;
      await wait(READ_RETRY_DELAYS_MS[attempt]);
    }
  }
}
