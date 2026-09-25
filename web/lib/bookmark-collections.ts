import type { SupabaseClient } from "@supabase/supabase-js";
import { isQuotePost, type HomeFeedRow } from "@/lib/feed";
import { fetchVisibleQuoteRows } from "@/lib/quote-feed-data";

export type BookmarkCollection = {
  id: string;
  name: string;
  owner_id: string;
  created_at: string;
  updated_at: string;
};
export type BookmarkContent = { content_type: "drop" | "quote"; content_id: string };
type Membership = BookmarkContent & { created_at: string; collection_id: string };
type CollectionPage = { rows: (HomeFeedRow & { saved_at: string })[]; hasMore: boolean };

function fail(error: { message?: string } | null | undefined): void {
  if (error) throw new Error(error.message || "จัดการคอลเลกชันไม่สำเร็จ");
}

export function normalizeCollectionName(name: string): string {
  const trimmed = name.normalize("NFC").trim();
  if (!trimmed || trimmed.length > 48 || /[\u0000-\u001f\u007f]/u.test(trimmed)) {
    throw new Error("ชื่อคอลเลกชันต้องมี 1–48 ตัวอักษร");
  }
  return trimmed;
}

export function bookmarkContent(row: HomeFeedRow): BookmarkContent | null {
  if (isQuotePost(row) && row.redrop_id) return { content_type: "quote", content_id: row.redrop_id };
  if (row.content_type === "drop" && row.id) return { content_type: "drop", content_id: row.id };
  return null;
}

export async function listBookmarkCollections(
  client: SupabaseClient, userId: string,
): Promise<BookmarkCollection[]> {
  const result = await client.from("bookmark_collections")
    .select("id,name,owner_id,created_at,updated_at")
    .eq("owner_id", userId).order("created_at", { ascending: false });
  fail(result.error);
  return (result.data ?? []) as BookmarkCollection[];
}

export async function createBookmarkCollection(
  client: SupabaseClient, userId: string, name: string,
): Promise<BookmarkCollection> {
  const normalized = normalizeCollectionName(name);
  const result = await client.from("bookmark_collections")
    .insert({ owner_id: userId, name: normalized })
    .select("id,name,owner_id,created_at,updated_at").single();
  fail(result.error);
  if (!result.data) throw new Error("สร้างคอลเลกชันไม่สำเร็จ");
  return result.data as BookmarkCollection;
}

export async function renameBookmarkCollection(
  client: SupabaseClient, userId: string, collectionId: string, name: string,
): Promise<void> {
  const result = await client.from("bookmark_collections")
    .update({ name: normalizeCollectionName(name), updated_at: new Date().toISOString() })
    .eq("id", collectionId).eq("owner_id", userId);
  fail(result.error);
}

export async function deleteBookmarkCollection(
  client: SupabaseClient, userId: string, collectionId: string,
): Promise<void> {
  const result = await client.from("bookmark_collections").delete()
    .eq("id", collectionId).eq("owner_id", userId);
  fail(result.error);
}

export async function collectionMembershipsForContent(
  client: SupabaseClient, userId: string, content: BookmarkContent,
): Promise<string[]> {
  const result = await client.from("bookmark_collection_items")
    .select("collection_id").eq("owner_id", userId)
    .eq("content_type", content.content_type).eq("content_id", content.content_id);
  fail(result.error);
  return (result.data ?? []).map((item) => String(item.collection_id));
}

export async function addToBookmarkCollection(
  client: SupabaseClient, userId: string, collectionId: string, content: BookmarkContent,
): Promise<void> {
  const result = await client.from("bookmark_collection_items")
    .insert({ collection_id: collectionId, owner_id: userId, ...content });
  fail(result.error);
}

export async function removeFromBookmarkCollection(
  client: SupabaseClient, userId: string, collectionId: string, content: BookmarkContent,
): Promise<void> {
  const result = await client.from("bookmark_collection_items").delete()
    .eq("owner_id", userId).eq("collection_id", collectionId)
    .eq("content_type", content.content_type).eq("content_id", content.content_id);
  fail(result.error);
}

/** RLS on saves/quote_saves and home_feed rechecks every returned item:
 * membership rows alone must never cause an unsaved or blocked post to render. */
export async function fetchBookmarkCollectionPage(
  client: SupabaseClient, userId: string, collectionId: string, page: number,
): Promise<CollectionPage> {
  const result = await client.from("bookmark_collection_items")
    .select("collection_id,content_type,content_id,created_at")
    .eq("owner_id", userId).eq("collection_id", collectionId)
    .order("created_at", { ascending: false }).range(page * 21, page * 21 + 20);
  fail(result.error);
  const items = (result.data ?? []) as Membership[];
  const dropIds = items.filter((item) => item.content_type === "drop").map((item) => item.content_id);
  const quoteIds = items.filter((item) => item.content_type === "quote").map((item) => item.content_id);
  const [drops, quotes] = await Promise.all([
    dropIds.length
      ? client.from("saved_feed").select("*").eq("user_id", userId)
          .eq("content_type", "drop").in("id", dropIds)
          .then(({ data, error }) => { fail(error); return (data ?? []) as HomeFeedRow[]; })
      : Promise.resolve([] as HomeFeedRow[]),
    quoteIds.length
      ? client.from("quote_saves").select("quote_id")
          .eq("user_id", userId).in("quote_id", quoteIds)
          .then(async ({ data, error }) => {
            fail(error);
            return fetchVisibleQuoteRows(client, (data ?? []).map((item) => String(item.quote_id)));
          })
      : Promise.resolve(new Map<string, HomeFeedRow>()),
  ]);
  const byDropId = new Map(drops.map((row) => [row.id, row]));
  const byQuoteId = quotes;
  return {
    rows: items.flatMap((item) => {
      const row = item.content_type === "drop"
        ? byDropId.get(item.content_id) : byQuoteId.get(item.content_id);
      return row ? [{ ...row, saved_at: item.created_at }] : [];
    }),
    hasMore: items.length === 21,
  };
}
