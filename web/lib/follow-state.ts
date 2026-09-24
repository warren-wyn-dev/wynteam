import { deleteMountCacheByPrefix } from "@/lib/mount-cache";

export type FollowState = "following" | "requested" | "none";
export type FollowChange = { actorId: string; targetId: string; state: FollowState };

const listeners = new Set<(change: FollowChange) => void>();

export function subscribeFollowChange(listener: (change: FollowChange) => void): () => void {
  listeners.add(listener);
  return () => { listeners.delete(listener); };
}

export function publishFollowChange(change: FollowChange): void {
  // Search results, discovery and both follow tabs must never reuse a
  // relationship snapshot created before this server-confirmed change.
  deleteMountCacheByPrefix("search-users:" + change.actorId + ":");
  deleteMountCacheByPrefix("search-discovery:" + change.actorId);
  deleteMountCacheByPrefix("follow-list:" + change.actorId + ":");
  for (const listener of listeners) listener(change);
}
