/**
 * Same-tab notification invalidation only. Never carry message previews,
 * actor names, Push tokens, or another account's rows in global events.
 */
const listeners = new Map<string, Set<() => void>>();

export function subscribeNotificationChanges(userId: string, listener: () => void): () => void {
  let userListeners = listeners.get(userId);
  if (!userListeners) {
    userListeners = new Set();
    listeners.set(userId, userListeners);
  }
  userListeners.add(listener);
  return () => {
    userListeners?.delete(listener);
    if (userListeners?.size === 0) listeners.delete(userId);
  };
}

export function emitNotificationChanges(userId: string): void {
  listeners.get(userId)?.forEach((listener) => listener());
}
