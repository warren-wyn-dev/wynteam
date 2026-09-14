import { Heart, MessageCircle, Repeat, Send } from "lucide-react";
import Link from "next/link";

import pc from "@/components/design-system/post-card.module.css";

/**
 * Home's action row: Like / Comment / ReDrop / Share (WYN-159 design system,
 * `WynosPostActions` — `.post-actions`/`.action` in the reference, extended
 * with the existing WYN Share action per the app-shell/home doc). 24px
 * lucide icons (kept from the already-shipped sizing, see `tokens.ts`),
 * 28px gap between actions, 5px icon-to-count gap. ReDrop is omitted
 * entirely (not disabled) when the post's audience isn't "everyone", and
 * the view-count metric is never rendered on Home.
 */
export function PostActions({
  liked,
  likeCount,
  commentCount,
  canRedrop,
  redropped,
  redropCount,
  onLike,
  commentHref,
  onRedrop,
  onShare,
}: {
  liked: boolean;
  likeCount: number;
  commentCount: number;
  canRedrop: boolean;
  redropped: boolean;
  redropCount: number;
  onLike: () => void;
  commentHref: string;
  onRedrop: () => void;
  onShare: () => void;
}) {
  return (
    <div className={pc.postActions}>
      <button
        className={`${pc.actionButton} ${liked ? pc.actionButtonLiked : ""}`}
        type="button"
        aria-label={liked ? "เลิกถูกใจ" : "ถูกใจ"}
        onClick={onLike}
      >
        <Heart size={24} fill={liked ? "currentColor" : "none"} />
        <span className={pc.actionButtonCount}>{likeCount}</span>
      </button>
      <Link className={pc.actionButton} href={commentHref} aria-label="ความคิดเห็น">
        <MessageCircle size={24} />
        <span className={pc.actionButtonCount}>{commentCount}</span>
      </Link>
      {canRedrop ? (
        <button
          className={`${pc.actionButton} ${redropped ? pc.actionButtonActive : ""}`}
          type="button"
          aria-label="รีโพสต์"
          onClick={onRedrop}
        >
          <Repeat size={24} />
          <span className={pc.actionButtonCount}>{redropCount}</span>
        </button>
      ) : null}
      <button
        className={`${pc.actionButton} ${pc.actionShare}`}
        type="button"
        aria-label="แชร์"
        onClick={onShare}
      >
        <Send size={24} />
      </button>
    </div>
  );
}
