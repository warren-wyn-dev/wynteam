import Link from "next/link";

import { AnimatedHeart } from "@/components/ui/animated-heart";
import { WynosIcon } from "@/components/ui/wynos-icon";
import { WynosShareIcon } from "@/components/ui/wynos-share-icon";

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
  saved = false,
  onLike,
  commentHref,
  onRedrop,
  onShare,
  onSave,
  modernFeed = false,
}: {
  liked: boolean;
  likeCount: number;
  commentCount: number;
  canRedrop: boolean;
  redropped: boolean;
  redropCount: number;
  saved?: boolean;
  onLike: () => void;
  commentHref: string;
  onRedrop: () => void;
  onShare: () => void;
  onSave?: () => void;
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
        aria-pressed={liked}
        onClick={onLike}
      >
        <AnimatedHeart size={22} strokeWidth={2} liked={liked} />
        {count(likeCount)}
      </button>
      <Link
        className="wyn-action-button"
        href={commentHref}
        aria-label="ความคิดเห็น"
      >
        <WynosIcon name="comment" size={22} strokeWidth={2} />
        {count(commentCount)}
      </Link>
      {canRedrop ? (
        <button
          className={`wyn-action-button ${redropped ? "is-active" : ""}`}
          type="button"
          aria-label="รีโพสต์"
          aria-pressed={redropped}
          onClick={onRedrop}
        >
          {/* WYN-185 item 13: was 24 -- every other icon in this row is 22,
              so this stood out slightly larger for no reason. */}
          <WynosIcon name="repost" size={22} strokeWidth={2} />
          {count(redropCount)}
        </button>
      ) : null}
      <button
        className="wyn-action-button wyn-action-share"
        type="button"
        aria-label="แชร์"
        onClick={onShare}
      >
        <WynosShareIcon size={22} />
      </button>
      {onSave ? (
        <button
          className={`wyn-action-button wyn-action-save ${saved ? "is-active" : ""}`}
          type="button"
          aria-label={saved ? "ยกเลิกบันทึก" : "บันทึก"}
          aria-pressed={saved}
          onClick={onSave}
        >
          <WynosIcon name="bookmark" size={22} strokeWidth={2} fill={saved ? "currentColor" : "none"} />
        </button>
      ) : null}
    </div>
  );
}
