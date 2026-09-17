import { MoreHorizontal } from "lucide-react";
import Link from "next/link";

/**
 * Compact Threads-inspired author row for Home posts.
 * The Home feed intentionally shows display name + time only (no @handle).
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
  const followLabel = following ? "กำลังติดตาม" : followRequested ? "ขอติดตามแล้ว" : "ติดตาม";
  const followClass = following ? "is-following" : followRequested ? "is-requested" : "";

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
          style={{ flex: "0 1 auto", fontSize: 16, lineHeight: 1.25, fontWeight: 700 }}
        >
          {name}
        </strong>
        {verified ? <span className="route-verified wyn-post-verified">✓</span> : null}
        <small
          className="wyn-post-timestamp"
          style={{ maxWidth: 104, fontSize: 14, lineHeight: 1.2, flex: "0 0 auto" }}
        >
          · {timeLabel}
        </small>
      </Link>
      {showFollow ? (
        <button
          className={`wyn-post-follow-pill ${followClass}`.trim()}
          type="button"
          aria-label={followLabel}
          aria-pressed={following}
          onClick={onFollow}
        >
          {followLabel}
        </button>
      ) : null}
      <button
        className="wyn-post-more"
        style={{ flex: "0 0 32px", width: 32, minWidth: 32, margin: "0 -4px 0 0" }}
        type="button"
        aria-label="เพิ่มเติม"
        onClick={onMore}
      >
        <MoreHorizontal size={21} />
      </button>
    </header>
  );
}
