/**
 * WYN-185 item 11: safe normalization for a user-entered external website
 * URL (Edit Profile's "เว็บไซต์ภายนอก" field). Client-side only -- the
 * server independently re-validates via `profiles_validate_social_links()`
 * (see the accompanying migration), since a raw REST call can always bypass
 * whatever the client does.
 *
 * Returns the canonical URL string, or null for an empty input (meaning
 * "remove the link") or an input that isn't a safe http(s) URL.
 */
export function normalizeExternalUrl(input: string): string | null {
  const trimmed = input.trim();
  if (!trimmed) return null;
  const withScheme = /^[a-z][a-z0-9+.-]*:\/\//i.test(trimmed) ? trimmed : `https://${trimmed}`;
  let url: URL;
  try {
    url = new URL(withScheme);
  } catch {
    return null;
  }
  // http(s) only -- rejects javascript:, data:, file:, etc.
  if (url.protocol !== "http:" && url.protocol !== "https:") return null;
  // A bare word like "hello" parses as a "valid" URL with an empty-looking
  // host once https:// is prepended, so require at least one dot to avoid
  // storing something that was never really meant as a domain.
  if (!url.hostname || !url.hostname.includes(".")) return null;
  if (url.toString().length > 300) return null;
  return url.toString();
}
