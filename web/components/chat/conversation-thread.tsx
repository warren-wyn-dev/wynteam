"use client";

import { useRef, useState, type PointerEvent, type ReactNode } from "react";

import { Avatar } from "@/components/phase3-ui";
import { WynosIcon } from "@/components/ui/wynos-icon";
import { MESSAGE_REACTIONS, type MessageReaction, type MessageRow, type ProfileRow } from "@/lib/phase3-data";

const CHAT_TIME_ZONE = "Asia/Bangkok";

export function chatDayKey(value: string): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: CHAT_TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date(value));
  const year = parts.find((part) => part.type === "year")?.value ?? "";
  const month = parts.find((part) => part.type === "month")?.value ?? "";
  const day = parts.find((part) => part.type === "day")?.value ?? "";
  return `${year}-${month}-${day}`;
}

function chatDateLabel(value: string): string {
  return new Intl.DateTimeFormat("th-TH-u-ca-gregory", {
    timeZone: CHAT_TIME_ZONE,
    day: "numeric",
    month: "long",
    year: "numeric",
  }).format(new Date(value));
}

function chatTimeLabel(value: string): string {
  return new Intl.DateTimeFormat("th-TH", {
    timeZone: CHAT_TIME_ZONE,
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(new Date(value));
}

/** Messages from one sender at most this far apart, on the same day, form one group (WYN-031 spec §2). */
export const GROUP_WINDOW_MS = 60_000;

/** Own plain-text messages can be edited for this long after sending (Founder, 2026-09-27). */
export const EDIT_WINDOW_MS = 30 * 60_000;
const LONG_PRESS_MS = 450;

export type MessageAction = "reply" | "edit" | "forward" | "copy" | "hide" | "unsend" | "pin" | "unpin" | "report";

/** The hold menu for this message: the main list and the "เพิ่มเติม" list. */
export function messageMenu(message: MessageRow, userId: string, options: { pinned?: boolean; now?: number } = {}): { main: MessageAction[]; more: MessageAction[] } {
  if (message.deleted_at || message.pending) return { main: [], more: [] };
  const now = options.now ?? Date.now();
  const mine = message.sender_id === userId;
  const hasText = Boolean(message.text?.trim());
  const plainText = hasText && !message.image_url && !message.shared_content_id;
  const main: MessageAction[] = ["reply"];
  if (mine && plainText && now - new Date(message.created_at).getTime() <= EDIT_WINDOW_MS) main.push("edit");
  // Only text is forwarded: a chat image lives in this conversation's private storage folder.
  if (plainText) main.push("forward");
  if (hasText) main.push("copy");
  main.push("hide");
  if (mine) main.push("unsend");
  const more: MessageAction[] = [options.pinned ? "unpin" : "pin"];
  if (!mine) more.push("report");
  return { main, more };
}

export type GroupPosition = "single" | "first" | "middle" | "last";

function sameGroup(a: MessageRow, b: MessageRow): boolean {
  return a.sender_id === b.sender_id
    && chatDayKey(a.created_at) === chatDayKey(b.created_at)
    && Math.abs(new Date(b.created_at).getTime() - new Date(a.created_at).getTime()) <= GROUP_WINDOW_MS;
}

/** Where each message (oldest first) sits in its sender group. */
export function groupPositions(ordered: MessageRow[]): GroupPosition[] {
  return ordered.map((message, index) => {
    const joinsPrevious = index > 0 && sameGroup(ordered[index - 1], message);
    const joinsNext = index < ordered.length - 1 && sameGroup(message, ordered[index + 1]);
    if (joinsPrevious && joinsNext) return "middle";
    if (joinsPrevious) return "last";
    if (joinsNext) return "first";
    return "single";
  });
}

type Props = {
  /** Oldest first. */
  messages: MessageRow[];
  userId: string;
  other: ProfileRow | null;
  otherLastReadAt?: string | null;
  /** WYN-159 (Beta2, developer-only until released): grouped, Threads-style thread. */
  threads: boolean;
  revealedMessageId: string | null;
  onToggleReveal: (messageId: string) => void;
  onDelete: (message: MessageRow) => void;
  /** Threads mode: long-press (or right-click) a bubble to open its actions. */
  onOpenActions?: (message: MessageRow, bubble: DOMRect) => void;
  pinnedIds?: ReadonlySet<string>;
  reactions?: MessageReaction[];
  renderImage: (path: string) => ReactNode;
};

/** Tap = one handler, hold 450 ms = another; a hold never also counts as a tap. */
function useLongPress(onLongPress: (target: Element) => void) {
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const start = useRef<{ x: number; y: number } | null>(null);
  const fired = useRef(false);
  const target = useRef<Element | null>(null);
  const clear = () => {
    if (timer.current) clearTimeout(timer.current);
    timer.current = null;
  };
  return {
    /** True once if the last press was a hold (so the click that follows is not a tap). */
    consumeHold: () => {
      const held = fired.current;
      fired.current = false;
      return held;
    },
    handlers: {
      onPointerDown: (event: PointerEvent) => {
        fired.current = false;
        start.current = { x: event.clientX, y: event.clientY };
        target.current = event.currentTarget;
        clear();
        timer.current = setTimeout(() => {
          fired.current = true;
          if (target.current) onLongPress(target.current);
        }, LONG_PRESS_MS);
      },
      onPointerMove: (event: PointerEvent) => {
        if (start.current && Math.hypot(event.clientX - start.current.x, event.clientY - start.current.y) > 10) clear();
      },
      onPointerUp: clear,
      onPointerCancel: clear,
      onPointerLeave: clear,
      onContextMenu: (event: { preventDefault: () => void; currentTarget: Element }) => {
        event.preventDefault();
        clear();
        fired.current = true;
        onLongPress(event.currentTarget);
      },
    },
  };
}

function Bubble({ tappable, onTap, onLongPress, children, ...rest }: { tappable: boolean; onTap?: () => void; onLongPress?: (bubble: DOMRect) => void; children: ReactNode; "aria-label"?: string; "aria-expanded"?: boolean }) {
  const press = useLongPress((target) => onLongPress?.(target.getBoundingClientRect()));
  return (
    <div
      className="message-bubble"
      role={tappable ? "button" : undefined}
      tabIndex={tappable ? 0 : undefined}
      {...rest}
      {...(onLongPress ? press.handlers : {})}
      onClick={tappable ? () => {
        if (!press.consumeHold()) onTap?.();
      } : undefined}
    >
      {children}
    </div>
  );
}

/**
 * The message list of a 1:1 conversation. Without `threads` it renders
 * exactly the Web Beta1 layout. With `threads`:
 * - consecutive messages from one sender within 60 s are grouped (4 px
 *   apart, rounded inner corners, one tail, one avatar on the last bubble);
 * - time is hidden until a bubble is tapped (own bubble: time + delete);
 * - the sent/read receipt shows once, under the latest outgoing message.
 */
export function ConversationThread({ messages, userId, other, otherLastReadAt, threads, revealedMessageId, onToggleReveal, onDelete, onOpenActions, pinnedIds, reactions, renderImage }: Props) {
  const positions = threads ? groupPositions(messages) : null;
  const lastMineId = threads ? [...messages].reverse().find((message) => message.sender_id === userId && !message.pending)?.id : undefined;
  return (
    <>
      {messages.map((message, index) => {
        const mine = message.sender_id === userId;
        const canDelete = mine && !message.deleted_at && !message.pending;
        const tapped = revealedMessageId === message.id;
        // Beta1: tapping your own bubble shows delete. Threads: tap only shows the time; actions are on long-press.
        const revealed = !threads && canDelete && tapped;
        const previous = index > 0 ? messages[index - 1] : null;
        const showDate = !previous || chatDayKey(previous.created_at) !== chatDayKey(message.created_at);
        const read = mine && Boolean(otherLastReadAt && new Date(message.created_at) <= new Date(otherLastReadAt));
        const position = positions?.[index];
        const showAvatar = !mine && other && (!threads || position === "last" || position === "single");
        const showTime = !threads || tapped || message.pending;
        const showReceipt = mine && !message.pending && (!threads || message.id === lastMineId);
        const tappable = threads ? !message.deleted_at && !message.pending : canDelete;
        const bubbleLabel = threads ? `${mine ? "คุณ" : (other?.display_name?.trim() || other?.username || "")} ${chatTimeLabel(message.created_at)}` : undefined;
        return <div className="message-entry" key={message.id} data-message-id={threads ? message.id : undefined}>
          {showDate ? <div className="conversation-date-separator"><span>{chatDateLabel(message.created_at)}</span></div> : null}
          <div className={`message-row ${mine ? "mine" : "theirs"} ${message.pending ? "is-pending" : ""}${position ? ` group-${position}` : ""}`}>
            {showAvatar && other ? <Avatar src={other.avatar_url} label={other.username} size={34} /> : threads && !mine ? <span className="message-avatar-space" aria-hidden="true" /> : null}
            <div className="message-stack">
              <Bubble
                tappable={tappable}
                aria-label={bubbleLabel}
                aria-expanded={threads && tappable ? tapped : undefined}
                onTap={() => onToggleReveal(message.id)}
                onLongPress={threads && onOpenActions && !message.deleted_at && !message.pending ? (bubble) => onOpenActions(message, bubble) : undefined}
              >
                {message.deleted_at ? <i>ลบข้อความแล้ว</i> : <>
                  {message.reply_to_message_id && message.reply_to ? <div className="reply-preview">{message.reply_to.deleted_at ? "ข้อความถูกลบ" : message.reply_to.text || (message.reply_to.image_url ? "รูปภาพ" : "ข้อความ")}</div> : null}
                  {threads && pinnedIds?.has(message.id) ? <span className="message-pinned-mark" aria-label="ปักหมุด"><WynosIcon name="pin" size={12} strokeWidth={2.2} /></span> : null}
                  {message.text ? <p data-i18n-skip="">{message.text}</p> : null}
                  {/* eslint-disable-next-line @next/next/no-img-element -- a local object URL for an image still uploading */}
                  {message.localPreviewUrl ? <img className="message-image" src={message.localPreviewUrl} alt="" /> : message.image_url ? renderImage(message.image_url) : null}
                </>}
              </Bubble>
              {threads ? <ReactionChips reactions={reactions?.filter((reaction) => reaction.message_id === message.id)} userId={userId} /> : null}
              {showTime || showReceipt ? <div className="message-meta">
                {showTime ? <time>{message.pending ? "กำลังส่ง…" : chatTimeLabel(message.created_at)}{message.edited_at ? " · แก้ไขแล้ว" : ""}</time> : null}
                {showReceipt ? (
                  // WhatsApp/LINE-style receipt: single check = sent,
                  // double check in the accent color = read.
                  <span className={`message-read-status ${read ? "read" : ""}`} aria-label={read ? "อ่านแล้ว" : "ส่งแล้ว"}>
                    <WynosIcon name={read ? "checkCheck" : "check"} size={14} strokeWidth={2.4} />
                  </span>
                ) : null}
              </div> : null}
            </div>
            {revealed ? <button className="message-delete" type="button" aria-label="ลบข้อความ" onClick={() => onDelete(message)}><WynosIcon name="trash" size={13} strokeWidth={2} /></button> : null}
          </div>
        </div>;
      })}
    </>
  );
}

/** Reactions under a bubble: each emoji once, with a count when more than one person used it. */
function ReactionChips({ reactions, userId }: { reactions?: MessageReaction[]; userId: string }) {
  if (!reactions?.length) return null;
  const counts = new Map<string, number>();
  for (const reaction of reactions) counts.set(reaction.emoji, (counts.get(reaction.emoji) ?? 0) + 1);
  const mine = reactions.some((reaction) => reaction.user_id === userId);
  return (
    <span className={`message-reactions${mine ? " mine" : ""}`} aria-label={[...counts].map(([emoji, count]) => `${emoji} ${count}`).join(", ")}>
      {[...counts].map(([emoji]) => <span key={emoji}>{emoji}</span>)}
      {reactions.length > 1 ? <small>{reactions.length}</small> : null}
    </span>
  );
}

const ACTION_LABELS: Record<MessageAction, { label: string; icon: "reply" | "pencil" | "send" | "copy" | "trash" | "undo" | "pin" | "flag" }> = {
  reply: { label: "ตอบกลับ", icon: "reply" },
  edit: { label: "แก้ไข", icon: "pencil" },
  forward: { label: "ส่งต่อ", icon: "send" },
  copy: { label: "คัดลอก", icon: "copy" },
  hide: { label: "ลบสำหรับคุณ", icon: "trash" },
  unsend: { label: "ยกเลิกการส่ง", icon: "undo" },
  pin: { label: "ปักหมุด", icon: "pin" },
  unpin: { label: "เลิกปักหมุด", icon: "pin" },
  report: { label: "รายงาน", icon: "flag" },
};

const MENU_ROW = 52;
const MENU_HEAD = 40;
const GAP = 8;

/**
 * Hold menu for one message (WYN-159 Beta2): the page dims and blurs, the
 * held bubble stays where it was, and the menu opens next to it (below, or
 * above when there is no room), headed by the message time. "เพิ่มเติม"
 * swaps in the secondary actions (pin, report).
 */
const REACTION_BAR = 64;
const REACTION_BAR_WIDTH = 6 * 50 + 18;

export function MessageActionMenu({ message, userId, bubble, pinned, myReaction, onReact, onChoose, onClose }: { message: MessageRow; userId: string; bubble: DOMRect; pinned?: boolean; myReaction?: string | null; onReact?: (emoji: string | null) => void; onChoose: (action: MessageAction) => void; onClose: () => void }) {
  const [view, setView] = useState<"main" | "more">("main");
  const menu = messageMenu(message, userId, { pinned });
  const rows = view === "main" ? menu.main.length + (menu.more.length ? 1 : 0) : menu.more.length + 1;
  const mine = message.sender_id === userId;
  const viewportHeight = typeof window === "undefined" ? 800 : window.innerHeight;
  const menuHeight = MENU_HEAD + Math.max(rows, menu.main.length + 1) * MENU_ROW + 8;
  // Like iOS: the reaction bar sits above the bubble and the menu below it;
  // when that does not fit, the bubble moves up (never under the bar).
  const minTop = onReact ? 16 + REACTION_BAR + GAP : 16;
  const bubbleTop = Math.max(minTop, Math.min(bubble.top, viewportHeight - 16 - menuHeight - GAP - bubble.height));
  const below = !!onReact || bubbleTop + bubble.height + GAP + menuHeight <= viewportHeight - 16;
  const menuTop = below ? bubbleTop + bubble.height + GAP : Math.max(16, bubbleTop - GAP - menuHeight);
  const reactionTop = bubbleTop - GAP - REACTION_BAR;
  const side = mine ? { right: Math.max(12, (typeof window === "undefined" ? 0 : window.innerWidth) - bubble.right) } : { left: Math.max(12, bubble.left) };
  const row = (action: MessageAction) => (
    <button key={action} role="menuitem" className={action === "unsend" || action === "report" ? "danger" : undefined} type="button" onClick={() => onChoose(action)}>
      <WynosIcon name={ACTION_LABELS[action].icon} size={22} strokeWidth={1.9} />{ACTION_LABELS[action].label}
    </button>
  );
  return (
    <div className="message-action-overlay" role="presentation" onClick={onClose}>
      <div className={`message-action-lifted ${mine ? "mine" : "theirs"}`} style={{ top: bubbleTop, left: bubble.left, width: bubble.width }} aria-hidden="true">
        <div className="message-action-bubble">
          {message.text ? <p data-i18n-skip="">{message.text}</p> : <i>{message.image_url ? "รูปภาพ" : "ข้อความ"}</i>}
        </div>
      </div>
      {onReact ? <div className="message-reaction-bar" role="toolbar" aria-label="ส่งความรู้สึก" style={{ top: reactionTop, ...(mine ? side : { left: Math.max(12, Math.min(bubble.left, (typeof window === "undefined" ? 390 : window.innerWidth) - REACTION_BAR_WIDTH - 12)) }) }} onClick={(event) => event.stopPropagation()}>
        {MESSAGE_REACTIONS.map((emoji) => (
          <button key={emoji} type="button" aria-pressed={myReaction === emoji} className={myReaction === emoji ? "chosen" : undefined} onClick={() => onReact(myReaction === emoji ? null : emoji)}>{emoji}</button>
        ))}
      </div> : null}
      <section className="message-action-menu" role="menu" aria-label="ตัวเลือกข้อความ" style={{ top: menuTop, ...side }} onClick={(event) => event.stopPropagation()}>
        <time>{chatTimeLabel(message.created_at)}</time>
        {view === "main" ? <>
          {menu.main.map(row)}
          {menu.more.length ? <button role="menuitem" type="button" className="more" onClick={() => setView("more")}>
            <WynosIcon name="more" size={22} strokeWidth={1.9} />เพิ่มเติม<WynosIcon name="chevronRight" size={20} strokeWidth={1.9} />
          </button> : null}
        </> : <>
          <button role="menuitem" type="button" onClick={() => setView("main")}>
            <WynosIcon name="back" size={22} strokeWidth={1.9} />กลับ
          </button>
          {menu.more.map(row)}
        </>}
      </section>
    </div>
  );
}
