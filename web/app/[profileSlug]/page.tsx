import type { Metadata } from "next";
import { notFound } from "next/navigation";

import { ProfileSlugResolver } from "@/components/profile-slug-resolver";
import { shareMetadata } from "@/lib/share-metadata";

// Next passes the segment still URL-encoded ("%40name" for "/@name"), so it
// must be decoded before checking for "@" -- checking the raw value 404'd
// every shared profile link.
function usernameFromSlug(profileSlug: string): string | null {
  let slug: string;
  try { slug = decodeURIComponent(profileSlug); } catch { return null; }
  return slug.startsWith("@") && slug.length > 1 ? slug.slice(1) : null;
}

export async function generateMetadata({ params }: { params: Promise<{ profileSlug: string }> }): Promise<Metadata> {
  const username = usernameFromSlug((await params).profileSlug);
  if (!username) return {};
  return shareMetadata(`@${username} บน WYNOS`, `ดูโปรไฟล์ @${username} บน WYNOS`, `/@${encodeURIComponent(username)}`);
}

export default async function Page({ params }: { params: Promise<{ profileSlug: string }> }) {
  const username = usernameFromSlug((await params).profileSlug);
  if (!username) notFound();
  return <ProfileSlugResolver username={username} />;
}
