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
  const followLabel = following
    ? "กำลังติดตาม"
    : followRequested
      ? "ขอติดตามแล้ว"
      : "ติดตาม";

  return (
    <header
      className="wyn-post-author-row"
      style={{ minHeight: 24, marginRight: 0, gap: 4, alignItems: "center" }}
    >
      <Link
        className="wyn-post-author-link"
        href={profileHref}
        style={{ gap: 4, alignItems: "center", overflow: "hidden" }}
      >
        <strong
          className="wyn-post-author-name"
          style={{ flex: "0 1 auto", fontSize: 14, lineHeight: 1.3, fontWeight: 600 }}
        >
          {name}
        </strong>
        {verified ? <span className="route-verified wyn-post-verified">✓</span> : null}
        <small
          className="wyn-post-timestamp"
          style={{ maxWidth: 96, fontSize: 13.5, lineHeight: 1.2, flex: "0 0 auto" }}
        >
          · {timeLabel}
        </small>
      </Link>
      {showFollow ? (
        <button
          className={`wyn-post-follow-pill ${following ? "is-following" : ""} ${followRequested ? "is-requested" : ""}`}
          style={{ minHeight: 26, height: 26, padding: "0 12px", fontSize: 12 }}
          type="button"
          aria-pressed={following || followRequested}
          onClick={onFollow}
        >
          {followLabel}
        </button>
      ) : null}
      <button
        className="wyn-post-more"
        style={{ flex: "0 0 28px", width: 28, minWidth: 28, margin: "0 -2px 0 0" }}
        type="button"
        aria-label="เพิ่มเติม"
        onClick={onMore}
      >
        <MoreHorizontal size={18} />
      </button>
    </header>
  );
}
