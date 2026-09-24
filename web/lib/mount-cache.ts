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
const store = new Map<string, unknown>();

export function getMountCache<T>(key: string): T | undefined {
  return store.has(key) ? (store.get(key) as T) : undefined;
}

export function setMountCache<T>(key: string, value: T): void {
  store.set(key, value);
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
