import type { HomeFeedRow } from "@/lib/feed";
import type { HomeViewerState } from "@/lib/home-actions";
import { deleteMountCache } from "@/lib/mount-cache";

export type DropEngagementChange = {
  userId: string;
  dropId: string;
  kind: "like" | "save" | "redrop";
  active: boolean;
  count?: number;
  source: string;
};

const EVENT = "wynos:drop-engagement";
const RECENT_MS = 60_000;
const recent = new Map<string, { change: DropEngagementChange; at: number }>();
const key = (change: Pick<DropEngagementChange, "userId" | "dropId" | "kind">) =>
  `${change.userId}:${change.dropId}:${change.kind}`;

/**
 * Session-local propagation, not an authority for server mutations.
 * Each mutation still uses Supabase and publishes a rollback on failure.
 */
export function publishDropEngagement(change: DropEngagementChange): void {
  recent.set(key(change), { change, at: Date.now() });
  // Do not replay a stale detail/bookmark mount cache after navigating back.
  deleteMountCache(`post-detail:${change.userId}:${change.dropId}`);
  if (change.kind === "save") deleteMountCache(`bookmarks:${change.userId}`);
  if (typeof window !== "undefined") {
    window.dispatchEvent(new CustomEvent(EVENT, { detail: change }));
  }
}

export function listenDropEngagement(listener: (change: DropEngagementChange) => void): () => void {
  if (typeof window === "undefined") return () => undefined;
  const handler = (event: Event) => listener((event as CustomEvent<DropEngagementChange>).detail);
  window.addEventListener(EVENT, handler);
  return () => window.removeEventListener(EVENT, handler);
}

export function getRecentDropEngagement(userId: string, dropId: string): DropEngagementChange[] {
  const now = Date.now();
  const events: DropEngagementChange[] = [];
  for (const kind of ["like", "save", "redrop"] as const) {
    const id = key({ userId, dropId, kind });
    const entry = recent.get(id);
    if (!entry) continue;
    if (now - entry.at > RECENT_MS) { recent.delete(id); continue; }
    events.push(entry.change);
  }
  return events;
}

export function patchDropViewer(viewer: HomeViewerState, change: DropEngagementChange): HomeViewerState {
  const field = change.kind === "like" ? "likedDropIds"
    : change.kind === "save" ? "savedDropIds" : "redroppedDropIds";
  const values = new Set(viewer[field]);
  if (change.active) values.add(change.dropId);
  else values.delete(change.dropId);
  return { ...viewer, [field]: values };
}

export function patchDropRow(row: HomeFeedRow, change: DropEngagementChange): HomeFeedRow {
  if (row.id !== change.dropId || change.count === undefined) return row;
  if (change.kind === "like") return { ...row, like_count: change.count };
  if (change.kind === "redrop") return { ...row, redrop_count: change.count };
  return row;
}

/** Apply short-lived in-tab edits to cached feeds when coming back from Detail. */
export function reconcileRecentDropEngagement(
  userId: string,
  rows: HomeFeedRow[],
  viewer: HomeViewerState,
): { rows: HomeFeedRow[]; viewer: HomeViewerState } {
  let nextViewer = viewer;
  const nextRows = rows.map((row) => {
    let nextRow = row;
    for (const change of getRecentDropEngagement(userId, row.id)) {
      nextViewer = patchDropViewer(nextViewer, change);
      nextRow = patchDropRow(nextRow, change);
    }
    return nextRow;
  });
  return { rows: nextRows, viewer: nextViewer };
}
