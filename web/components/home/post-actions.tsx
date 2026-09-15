import { Heart, MessageCircle, Repeat2, Send } from "lucide-react";
import Link from "next/link";

/**
 * Home action row. modernFeed uses the compact Threads-style interaction strip:
 * muted icons at rest, hidden zero counts, and intrinsic-width actions so a
 * count only pushes later actions when engagement actually exists.
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
  const count = (value: number) => (
    value > 0 ? <span className="wyn-action-button-count">{value}</span> : null
  );

  return (
    <div className={`wyn-post-actions ${modernFeed ? "wyn-threads-actions" : ""}`}>
      <button
        className={`wyn-action-button ${liked ? "is-liked" : ""}`}
        type="button"
        aria-label={liked ? "เลิกถูกใจ" : "ถูกใจ"}
        onClick={onLike}
      >
        <Heart size={24} strokeWidth={2} fill={liked ? "currentColor" : "none"} />
        {count(likeCount)}
      </button>
      <Link
        className="wyn-action-button"
        href={commentHref}
        aria-label="ความคิดเห็น"
      >
        <MessageCircle size={24} strokeWidth={2} />
        {count(commentCount)}
      </Link>
      {canRedrop ? (
        <button
          className={`wyn-action-button ${redropped ? "is-active" : ""}`}
          type="button"
          aria-label="รีโพสต์"
          onClick={onRedrop}
        >
          <Repeat2 size={24} strokeWidth={2} />
          {count(redropCount)}
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
