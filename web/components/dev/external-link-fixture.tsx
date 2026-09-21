"use client";

import { normalizeExternalUrl } from "@/lib/external-link";

/**
 * WYNOS Web Beta1, item 11: exercises normalizeExternalUrl() (web/lib/
 * external-link.ts), the client-side safety check for Edit Profile's new
 * "เว็บไซต์ภายนอก" field. Pure function, no Supabase/session needed.
 * Test-only, not linked from anywhere in the app.
 */
const CASES: { id: string; input: string }[] = [
  { id: "case-plain-domain", input: "example.com" },
  { id: "case-https", input: "https://example.com/alice" },
  { id: "case-http", input: "http://example.com" },
  { id: "case-javascript", input: "javascript:alert(1)" },
  { id: "case-javascript-slashes", input: "javascript://alert(1)" },
  { id: "case-empty", input: "   " },
  { id: "case-bare-word", input: "hello" },
  { id: "case-whitespace-padding", input: "  example.com  " },
];

export function ExternalLinkFixture() {
  return (
    <ul>
      {CASES.map((item) => (
        <li id={item.id} key={item.id}>{normalizeExternalUrl(item.input) ?? "null"}</li>
      ))}
    </ul>
  );
}
