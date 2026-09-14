import { Heart, MessageSquare, Repeat2, Send } from "lucide-react";
import Link from "next/link";

/**
 * Home's action row: Like / Comment / ReDrop / Share, matching
 * ActionMetric's contract in home_drop_card.dart exactly (icon 24px,
 * 6px icon-count gap, 16px between metrics, zero counts always shown
 * here since Home passes hideZeroActionCounts: false). ReDrop is
 * omitted entirely (not disabled) when the post's audience isn't
 * "everyone", and the view-count metric is never rendered on Home.
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
    <div className="wyn-post-actions">
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
