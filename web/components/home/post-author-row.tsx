import { MoreHorizontal } from "lucide-react";
import Link from "next/link";

/**
 * Compact Threads-inspired author row for Home posts.
 * The avatar stays in HomePostCard's left column; display name and time sit on one line.
 */
export function PostAuthorRow({
  profileHref,
  name,
  verified,
  timeLabel,
  showFollow,
  following,
  followRequested,
  onFollow,
  onMore,
}: {
  profileHref: string;
  name: string;
  verified: boolean;
  timeLabel: string;
  showFollow: boolean;
  following: boolean;
  followRequested: boolean;
  onFollow: () => void;
  onMore: () => void;
}) {
  const followLabel = followRequested ? "ขอติดตามแล้ว" : "ติดตาม";

  return (
    <header className="wyn-post-author-row">
      <Link className="wyn-post-author-link" href={profileHref}>
        <strong className="wyn-post-author-name">
          {name}
        </strong>
        {verified ? <span className="route-verified wyn-post-verified">✓</span> : null}
        <small className="wyn-post-timestamp">
          · {timeLabel}
        </small>
      </Link>
      {showFollow && !following ? (
        <button
          className={`wyn-post-follow-pill ${following ? "is-following" : ""} ${followRequested ? "is-requested" : ""}`}
          type="button"
          aria-pressed={following || followRequested}
          onClick={onFollow}
        >
          {followLabel}
        </button>
      ) : null}
      <button
        className="wyn-post-more"
        type="button"
        aria-label="เพิ่มเติม"
        onClick={onMore}
      >
        <MoreHorizontal size={16} />
      </button>
    </header>
  );
}
