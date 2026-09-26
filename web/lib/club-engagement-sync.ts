/** Session-local coordination between Home's Club tab and Club detail cards. */
export type ClubLikeChange = {
  userId: string;
  postId: string;
  liked: boolean;
  count: number;
  source: string;
};

const EVENT = "wynos:club-like";
const RECENT_MS = 60_000;
const latest = new Map<string, { change: ClubLikeChange; at: number }>();
const key = (userId: string, postId: string) => `${userId}:${postId}`;

export function publishClubLike(change: ClubLikeChange): void {
  latest.set(key(change.userId, change.postId), { change, at: Date.now() });
  if (typeof window !== "undefined") {
    window.dispatchEvent(new CustomEvent(EVENT, { detail: change }));
  }
}

export function getRecentClubLike(userId: string, postId: string): ClubLikeChange | null {
  const id = key(userId, postId);
  const entry = latest.get(id);
  if (!entry) return null;
  if (Date.now() - entry.at > RECENT_MS) { latest.delete(id); return null; }
  return entry.change;
}

export function listenClubLike(listener: (change: ClubLikeChange) => void): () => void {
  if (typeof window === "undefined") return () => undefined;
  const handler = (event: Event) => listener((event as CustomEvent<ClubLikeChange>).detail);
  window.addEventListener(EVENT, handler);
  return () => window.removeEventListener(EVENT, handler);
}
