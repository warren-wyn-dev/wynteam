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
  const pillBase = modernFeed
    ? {
        flex: "1 1 0",
        minWidth: 0,
        height: 40,
        padding: "0 10px",
        margin: 0,
        border: "1px solid var(--wyn-border)",
        borderRadius: 999,
        background: "var(--wyn-bg)",
        justifyContent: "center",
        gap: 7,
        transition: "background 160ms ease, color 160ms ease, border-color 160ms ease",
      }
    : undefined;

  return (
    <div
      className="wyn-post-actions"
      style={modernFeed ? {
        margin: "8px 0 12px",
        width: "100%",
        gap: 10,
      } : undefined}
    >
      <button
        className={`wyn-action-button ${liked ? "is-liked" : ""}`}
        style={modernFeed ? {
          ...pillBase,
          color: liked ? "#ff2d55" : "var(--wyn-text-secondary)",
          background: liked ? "rgb(255 45 85 / 6%)" : "var(--wyn-bg)",
          borderColor: liked ? "rgb(255 45 85 / 18%)" : "var(--wyn-border)",
        } : undefined}
        type="button"
        aria-label={liked ? "เลิกถูกใจ" : "ถูกใจ"}
        onClick={onLike}
      >
        <Heart size={24} fill={liked ? "currentColor" : "none"} />
        <span className="wyn-action-button-count">{likeCount}</span>
      </button>
      <Link
        className="wyn-action-button"
        style={pillBase}
        href={commentHref}
        aria-label="ความคิดเห็น"
      >
        <MessageSquare size={24} />
        <span className="wyn-action-button-count">{commentCount}</span>
      </Link>
      {canRedrop ? (
        <button
          className={`wyn-action-button ${redropped ? "is-active" : ""}`}
          style={modernFeed ? {
            ...pillBase,
            color: redropped ? "#0a84ff" : "var(--wyn-text-secondary)",
            background: redropped ? "rgb(10 132 255 / 6%)" : "var(--wyn-bg)",
            borderColor: redropped ? "rgb(10 132 255 / 18%)" : "var(--wyn-border)",
          } : undefined}
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
        style={pillBase}
        type="button"
        aria-label="แชร์"
        onClick={onShare}
      >
        <Send size={24} />
      </button>
    </div>
  );
}
