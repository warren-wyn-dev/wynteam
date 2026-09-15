import { Heart, MessageCircle, Repeat2, Send } from "lucide-react";
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
  const modernActionBase = modernFeed
    ? {
        minWidth: 38,
        height: 38,
        padding: 0,
        margin: 0,
        border: 0,
        borderRadius: 999,
        background: "transparent",
        justifyContent: "center",
        gap: 4,
        color: "var(--wyn-text)",
        transition: "color 160ms ease, transform 120ms ease",
      }
    : undefined;

  const count = (value: number) => (
    value > 0 ? <span className="wyn-action-button-count">{value}</span> : null
  );

  return (
    <div
      className="wyn-post-actions"
      style={modernFeed ? {
        margin: "8px 0 12px",
        width: "100%",
        paddingRight: 4,
        gap: 0,
        justifyContent: "space-between",
      } : undefined}
    >
      <button
        className={`wyn-action-button ${liked ? "is-liked" : ""}`}
        style={modernFeed ? {
          ...modernActionBase,
          color: liked ? "#ff2d55" : "var(--wyn-text)",
        } : undefined}
        type="button"
        aria-label={liked ? "เลิกถูกใจ" : "ถูกใจ"}
        onClick={onLike}
      >
        <Heart size={28} strokeWidth={2.05} fill={liked ? "currentColor" : "none"} />
        {count(likeCount)}
      </button>
      <Link
        className="wyn-action-button"
        style={modernActionBase}
        href={commentHref}
        aria-label="ความคิดเห็น"
      >
        <MessageCircle size={28} strokeWidth={2.05} />
        {count(commentCount)}
      </Link>
      {canRedrop ? (
        <button
          className={`wyn-action-button ${redropped ? "is-active" : ""}`}
          style={modernFeed ? {
            ...modernActionBase,
            color: redropped ? "#0a84ff" : "var(--wyn-text)",
          } : undefined}
          type="button"
          aria-label="รีโพสต์"
          onClick={onRedrop}
        >
          <Repeat2 size={28} strokeWidth={2.05} />
          {count(redropCount)}
        </button>
      ) : null}
      <button
        className="wyn-action-button wyn-action-share"
        style={modernFeed ? {
          ...modernActionBase,
          minWidth: 38,
        } : undefined}
        type="button"
        aria-label="แชร์"
        onClick={onShare}
      >
        <Send size={24} />
      </button>
    </div>
  );
}
