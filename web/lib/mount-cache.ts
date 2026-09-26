// The root `PageTransition` fully unmounts/remounts every page on route
// change (see components/ui/page-transition.tsx), so a plain useState/useRef
// loses a page's already-fetched data the instant the user taps to another
// tab. Every page that seeds `loading` to `true` and fetches in a mount
// effect then re-shows its skeleton and refetches on every single visit —
// which reads as the whole app "reloading" on every navigation, even though
// nothing actually reloaded.
//
// This is a plain module-level Map, not React state: it deliberately
// survives unmount/remount across the whole session, keyed by whatever the
// caller uses to identify "this page, for this user" (e.g. `${userId}` or
// `${userId}:${otherId}`). It is display cache only — every caller still
// re-fetches in the background after seeding from it, the same as before.
// Keep only recently visited routes. On long mobile sessions an unbounded
// Map can retain hundreds of heavy Feed/Profile/Chat snapshots. Every
// consumer already re-fetches when the display cache has been evicted.
export const MAX_MOUNT_CACHE_ENTRIES = 96;
const store = new Map<string, unknown>();

export function getMountCache<T>(key: string): T | undefined {
  if (!store.has(key)) return undefined;
  const value = store.get(key) as T;
  // Map iteration is insertion-ordered: touching a page makes it recent.
  store.delete(key);
  store.set(key, value);
  return value;
}

export function setMountCache<T>(key: string, value: T): void {
  if (store.has(key)) store.delete(key);
  store.set(key, value);
  while (store.size > MAX_MOUNT_CACHE_ENTRIES) {
    const oldest = store.keys().next().value;
    if (oldest === undefined) break;
    store.delete(oldest);
  }
}

// Mutations invalidate only the affected profile's repost list. Clearing this
// cache prevents a removed repost reappearing briefly after tab navigation.
export function deleteMountCache(key: string): void {
  store.delete(key);
}

export function deleteMountCacheByPrefix(prefix: string): void {
  for (const key of store.keys()) {
    if (key.startsWith(prefix)) store.delete(key);
  }
}
