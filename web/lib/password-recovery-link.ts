/** Parse only the recovery credentials, never a normal auth/session navigation. */
export type PasswordRecoveryLink =
  | { kind: "code"; code: string }
  | { kind: "token_hash"; tokenHash: string }
  | { kind: "implicit"; accessToken: string; refreshToken: string }
  | { kind: "invalid" };

export function parsePasswordRecoveryLink(href: string): PasswordRecoveryLink {
  const url = new URL(href);
  const query = url.searchParams;
  const hash = new URLSearchParams(url.hash.replace(/^#/, ""));

  if (query.has("error") || hash.has("error")) return { kind: "invalid" };
  // New reset emails carry the token in the URL fragment so a mail scanner's
  // HTTP prefetch never sends the one-time credential to our web server.
  if (hash.get("type") === "recovery" && hash.get("token_hash")) {
    return { kind: "token_hash", tokenHash: hash.get("token_hash")! };
  }
  // Backward compatibility for previously issued custom recovery links.
  if (query.get("type") === "recovery" && query.get("token_hash")) {
    return { kind: "token_hash", tokenHash: query.get("token_hash")! };
  }
  if (hash.get("type") === "recovery" && hash.get("access_token") && hash.get("refresh_token")) {
    return { kind: "implicit", accessToken: hash.get("access_token")!, refreshToken: hash.get("refresh_token")! };
  }
  if (query.get("code")) return { kind: "code", code: query.get("code")! };
  return { kind: "invalid" };
}
