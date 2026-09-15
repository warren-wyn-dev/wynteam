import { Heart, MessageSquare, Repeat2, Send } from "lucide-react";
import Link from "next/link";

/**
 * Home action row. modernFeed keeps the interaction strip compact while
 * aligning it with the post content column beside the avatar.
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
  modernFeed = false,
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
  modernFeed?: boolean;
}) {
  return (
    <div
      className="wyn-post-actions"
      style={modernFeed ? {
        margin: "8px 0 12px",
        width: "100%",
        gap: 22,
      } : undefined}
    >
      <button
        className={`wyn-action-button ${liked ? "is-liked" : ""}`}
        type="button"
        aria-label={liked ? "เลิกถูกใจ" : "ถูกใจ"}
        onClick={onLike}
      >
        <Heart size={24} fill={liked ? "currentColor" : "none"} />
        <span className="wyn-action-button-count">{likeCount}</span>
      </button>
      <Link className="wyn-action-button" href={commentHref} aria-label="ความคิดเห็น">
        <MessageSquare size={24} />
        <span className="wyn-action-button-count">{commentCount}</span>
      </Link>
      {canRedrop ? (
        <button
          className={`wyn-action-button ${redropped ? "is-active" : ""}`}
          type="button"
          aria-label="รีโพสต์"
          onClick={onRedrop}
        >
          <Repeat2 size={24} />
          <span className="wyn-action-button-count">{redropCount}</span>
        </button>
      ) : null}
      <button
        className="wyn-action-button wyn-action-share"
        type="button"
        aria-label="แชร์"
        onClick={onShare}
      >
        <Send size={24} />
      </button>
    </div>
  );
}
