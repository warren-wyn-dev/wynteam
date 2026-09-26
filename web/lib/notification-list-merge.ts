export const NOTIFICATION_PAGE_SIZE = 30;

type Row = { id: string; created_at: string };

/**
 * Merge a background re-read of the newest notification page into rows the
 * user already paged through. A short fresh page is the whole list, so
 * rows deleted since are dropped rather than kept from the stale copy.
 */
export function mergeNewestNotificationPage<T extends Row>(current: T[], next: T[]): T[] {
  if (next.length < NOTIFICATION_PAGE_SIZE) return next;
  const fresh = new Set(next.map((row) => row.id));
  const oldestFresh = next[next.length - 1].created_at;
  return [...next, ...current.filter((row) => !fresh.has(row.id) && row.created_at <= oldestFresh)];
}
