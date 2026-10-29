/** Use the Merchant origin's current root rollout after a direct sign-in. */
export function merchantDefaultReturnPath(hostname: string): string {
  return hostname === "merchant.wynos.online" ? "/" : "/merchant";
}
