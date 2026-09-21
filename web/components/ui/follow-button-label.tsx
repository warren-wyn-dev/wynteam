/**
 * WYN-185 item 9: shared follow-button label/state logic, used by every
 * follow/unfollow toggle (profile, post detail, chat, search, follower
 * lists, suggestions). Previously each call site inlined its own
 * `following ? "กำลังติดตาม" : requested ? "ขอติดตามแล้ว" : "ติดตาม"` ternary
 * with no pending-state feedback at all -- "กำลังติดตาม" ("currently
 * following") reads like an in-progress action on a *button* (the same verb
 * shape as "กำลังโหลด"/"กำลังส่ง"), and a tap just went straight from
 * "ติดตาม" to that ambiguous label with the button merely `disabled` in
 * between, no visible sign anything was happening.
 */
export function followButtonLabel(state: { busy: boolean; following: boolean; requested: boolean }): string {
  if (state.busy) return "กำลังดำเนินการ…";
  if (state.following) return "ติดตามแล้ว";
  if (state.requested) return "ขอติดตามแล้ว";
  return "ติดตาม";
}
