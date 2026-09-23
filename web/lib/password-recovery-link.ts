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
  if (query.get("type") === "recovery" && query.get("token_hash")) {
    return { kind: "token_hash", tokenHash: query.get("token_hash")! };
  }
  if (hash.get("type") === "recovery" && hash.get("access_token") && hash.get("refresh_token")) {
    return { kind: "implicit", accessToken: hash.get("access_token")!, refreshToken: hash.get("refresh_token")! };
  }
  if (query.get("code")) return { kind: "code", code: query.get("code")! };
  return { kind: "invalid" };
}
