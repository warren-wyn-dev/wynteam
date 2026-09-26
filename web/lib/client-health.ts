"use client";

import { track } from "@vercel/analytics";

export type ClientFailureKind =
  | "uncaught"
  | "unhandled_rejection"
  | "route_render"
  | "social_write"
  | "composer_publish"
  | "composer_draft";

const emitted = new Map<string, number>();
let total = 0;

export function healthArea(pathname: string): string {
  if (pathname === "/") return "feed";
  if (/^\/drop\//.test(pathname)) return "post_detail";
  if (/^\/profile\//.test(pathname)) return "profile";
  if (/^\/clubs?(\/|$)/.test(pathname) || /^\/club-post\//.test(pathname)) return "club";
  if (/^\/chat(\/|$)/.test(pathname)) return "chat";
  if (/^\/(login|signup|auth)(\/|$)/.test(pathname)) return "auth";
  if (pathname === "/search" || pathname === "/notifications") return "discovery";
  return "other";
}

/**
 * Deliberately send no message, stack, query string, user id or post id.
 * Health events have a small fixed vocabulary and a capped session volume.
 * Existing Vercel Speed Insights measures LCP/INP/CLS separately.
 */
export function reportClientFailure(kind: ClientFailureKind): void {
  if (typeof window === "undefined" || total >= 8) return;
  const area = healthArea(window.location.pathname);
  const fingerprint = `${kind}:${area}`;
  const now = Date.now();
  if (now - (emitted.get(fingerprint) ?? 0) < 30_000) return;
  emitted.set(fingerprint, now);
  total += 1;
  try {
    void track("beta1_client_failure", { kind, area });
  } catch {
    // Observability must never break the primary user action.
  }
}
