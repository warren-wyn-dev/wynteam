"use client";

import type { ReactNode } from "react";

import { Avatar } from "@/components/phase3-ui";
import { WynosIcon } from "@/components/ui/wynos-icon";
import type { MessageRow, ProfileRow } from "@/lib/phase3-data";

export function chatDayKey(value: string): string {
  const date = new Date(value);
  return `${date.getFullYear()}-${date.getMonth()}-${date.getDate()}`;
}

function chatDateLabel(value: string): string {
  return new Intl.DateTimeFormat("th-TH-u-ca-gregory", { day: "numeric", month: "long", year: "numeric" }).format(new Date(value));
}

function chatTimeLabel(value: string): string {
  return new Intl.DateTimeFormat("th-TH", { hour: "2-digit", minute: "2-digit", hour12: false }).format(new Date(value));
}

/** Messages from one sender at most this far apart, on the same day, form one group (WYN-031 spec §2). */
export const GROUP_WINDOW_MS = 60_000;

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
  renderImage: (path: string) => ReactNode;
};

/**
 * The message list of a 1:1 conversation. Without `threads` it renders
 * exactly the Web Beta1 layout. With `threads`:
 * - consecutive messages from one sender within 60 s are grouped (4 px
 *   apart, rounded inner corners, one tail, one avatar on the last bubble);
 * - time is hidden until a bubble is tapped (own bubble: time + delete);
 * - the sent/read receipt shows once, under the latest outgoing message.
 */
export function ConversationThread({ messages, userId, other, otherLastReadAt, threads, revealedMessageId, onToggleReveal, onDelete, renderImage }: Props) {
  const positions = threads ? groupPositions(messages) : null;
  const lastMineId = threads ? [...messages].reverse().find((message) => message.sender_id === userId && !message.pending)?.id : undefined;
  return (
    <>
      {messages.map((message, index) => {
        const mine = message.sender_id === userId;
        const canDelete = mine && !message.deleted_at && !message.pending;
        const tapped = revealedMessageId === message.id;
        const revealed = canDelete && tapped;
        const previous = index > 0 ? messages[index - 1] : null;
        const showDate = !previous || chatDayKey(previous.created_at) !== chatDayKey(message.created_at);
        const read = mine && Boolean(otherLastReadAt && new Date(message.created_at) <= new Date(otherLastReadAt));
        const position = positions?.[index];
        const showAvatar = !mine && other && (!threads || position === "last" || position === "single");
        const showTime = !threads || tapped || message.pending;
        const showReceipt = mine && !message.pending && (!threads || message.id === lastMineId);
        const tappable = threads ? !message.deleted_at || canDelete : canDelete;
        const bubbleLabel = threads ? `${mine ? "คุณ" : (other?.display_name?.trim() || other?.username || "")} ${chatTimeLabel(message.created_at)}` : undefined;
        return <div className="message-entry" key={message.id}>
          {showDate ? <div className="conversation-date-separator"><span>{chatDateLabel(message.created_at)}</span></div> : null}
          <div className={`message-row ${mine ? "mine" : "theirs"} ${message.pending ? "is-pending" : ""}${position ? ` group-${position}` : ""}`}>
            {showAvatar && other ? <Avatar src={other.avatar_url} label={other.username} size={34} /> : threads && !mine ? <span className="message-avatar-space" aria-hidden="true" /> : null}
            <div className="message-stack">
              <div
                className="message-bubble"
                role={tappable ? "button" : undefined}
                tabIndex={tappable ? 0 : undefined}
                aria-label={bubbleLabel}
                aria-expanded={threads && tappable ? tapped : undefined}
                onClick={tappable ? () => onToggleReveal(message.id) : undefined}
              >
                {message.deleted_at ? <i>ลบข้อความแล้ว</i> : <>
                  {message.reply_to_message_id && message.reply_to ? <div className="reply-preview">{message.reply_to.deleted_at ? "ข้อความถูกลบ" : message.reply_to.text || (message.reply_to.image_url ? "รูปภาพ" : "ข้อความ")}</div> : null}
                  {message.text ? <p data-i18n-skip="">{message.text}</p> : null}
                  {/* eslint-disable-next-line @next/next/no-img-element -- a local object URL for an image still uploading */}
                  {message.localPreviewUrl ? <img className="message-image" src={message.localPreviewUrl} alt="" /> : message.image_url ? renderImage(message.image_url) : null}
                </>}
              </div>
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
