/**
 * Synchronous, session-local in-flight guard for non-idempotent social actions.
 *
 * React state updates are asynchronous: two clicks or clicks from Home and
 * Detail can otherwise both send mutations based on the same old state.
 * The guard is acquired BEFORE optimistic state changes and released after
 * the server resolves (or fails). A later deliberate tap works normally.
 *
 * No user content or keys are persisted; unmounting a component must NOT
 * clear a still-running mutation from another route.
 */
const inFlight = new Map<string, symbol>();

export type InteractionKind = "like" | "save" | "redrop" | "quote";
export type InteractionScope = "drop" | "club" | "quote";

function interactionKey(scope: InteractionScope, userId: string, postId: string, kind: InteractionKind) {
  return JSON.stringify([scope, userId, postId, kind]);
}

export function beginSocialMutation(
  scope: InteractionScope,
  userId: string,
  postId: string,
  kind: InteractionKind,
): (() => void) | null {
  const key = interactionKey(scope, userId, postId, kind);
  if (inFlight.has(key)) return null;
  const token = Symbol("social-mutation");
  inFlight.set(key, token);
  let released = false;
  return () => {
    if (released) return;
    released = true;
    if (inFlight.get(key) === token) inFlight.delete(key);
  };
}

export function socialMutationPending(
  scope: InteractionScope,
  userId: string,
  postId: string,
  kind: InteractionKind,
): boolean {
  return inFlight.has(interactionKey(scope, userId, postId, kind));
}

/** navigator.onLine=false is a definite offline signal (true is not proof of connectivity). */
export function definitelyOffline(): boolean {
  return typeof navigator !== "undefined" && navigator.onLine === false;
}

export const OFFLINE_ACTION_MESSAGE = "ไม่มีอินเทอร์เน็ต กรุณาเชื่อมต่อแล้วลองอีกครั้ง";
