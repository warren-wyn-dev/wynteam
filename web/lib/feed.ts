export type HomeFeedRow = {
  id: string;
  content_type: string;
  author_id: string;
  author_username?: string | null;
  author_display_name?: string | null;
  author_avatar_url?: string | null;
  author_is_verified?: boolean | null;
  created_at: string;
  caption?: string | null;
  image_url?: string | null;
  image_width?: number | null;
  image_height?: number | null;
  image_count?: number | null;
  like_count?: number | null;
  comment_count?: number | null;
  redrop_count?: number | null;
  redrop_id?: string | null;
  redropper_username?: string | null;
  quote_text?: string | null;
  location?: string | null;
};

type RankedCandidate = {
  row_data?: HomeFeedRow | null;
};

export function rankedDropRows(value: unknown, limit = 20): HomeFeedRow[] {
  if (!Array.isArray(value)) return [];

  const rows: HomeFeedRow[] = [];
  for (const candidate of value) {
    if (!candidate || typeof candidate !== "object") continue;
    const ranked = candidate as RankedCandidate;
    const row = ranked.row_data ?? (candidate as HomeFeedRow);
    if (!row || typeof row !== "object") continue;
    if (row.content_type !== "drop") continue;
    if (typeof row.id !== "string" || typeof row.created_at !== "string") continue;
    rows.push(row);
    if (rows.length >= limit) break;
  }
  return rows;
}

export function authorLabel(row: HomeFeedRow): string {
  const displayName = row.author_display_name?.trim();
  return displayName || row.author_username?.trim() || "WYNOS";
}

export function relativeTimeTh(iso: string): string {
  const then = new Date(iso).getTime();
  if (!Number.isFinite(then)) return "";
  const seconds = Math.max(0, Math.floor((Date.now() - then) / 1000));
  if (seconds < 60) return "เมื่อสักครู่";
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes} นาที`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} ชม.`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `${days} วัน`;
  return new Intl.DateTimeFormat("th-TH", {
    day: "numeric",
    month: "short",
  }).format(new Date(iso));
}
