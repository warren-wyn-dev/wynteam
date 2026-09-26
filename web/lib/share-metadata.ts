import type { Metadata } from "next";

// Link previews (LINE, Messenger, Facebook, X, iMessage) for shared URLs.
// Content is readable by signed-in users only (RLS), so previews stay generic
// and never include post text, images or who wrote them; the path itself
// (e.g. /@username) is the only per-link detail, and it is already public.
export const SITE_URL = "https://wynos.online";
const PREVIEW_IMAGE = { url: "/icons/icon-512.png", width: 512, height: 512, alt: "WYNOS" };

/** `path` sets canonical/og:url for that route only. The root layout omits
 * it: a URL set there is inherited by every route without its own metadata,
 * which would make all of those links preview as the home page. */
export function shareMetadata(title: string, description: string, path?: string): Metadata {
  return {
    title,
    description,
    ...(path ? { alternates: { canonical: path } } : {}),
    openGraph: {
      type: "website",
      siteName: "WYNOS",
      locale: "th_TH",
      ...(path ? { url: path } : {}),
      title,
      description,
      images: [PREVIEW_IMAGE],
    },
    twitter: { card: "summary", title, description, images: [PREVIEW_IMAGE.url] },
  };
}
