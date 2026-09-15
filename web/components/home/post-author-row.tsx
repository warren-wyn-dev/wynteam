import { MoreHorizontal } from "lucide-react";
import Link from "next/link";

/**
 * Compact X/Threads-inspired author row for Home posts.
 * The avatar stays in HomePostCard's left column; metadata sits on one line.
 */
export function PostAuthorRow({
  profileHref,
  name,
  username,
  verified,
  timeLabel,
  showFollow,
  followRequested,
  onFollow,
  onMore,
}: {
  profileHref: string;
  name: string;
  username?: string | null;
  verified: boolean;
  timeLabel: string;
  showFollow: boolean;
  followRequested: boolean;
  onFollow: () => void;
  onMore: () => void;
}) {
  const handle = username?.trim().replace(/^@/, "");

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
        {handle ? (
          <span
            className="wyn-post-handle"
            style={{
              minWidth: 0,
              overflow: "hidden",
              textOverflow: "ellipsis",
              whiteSpace: "nowrap",
              color: "var(--wyn-text-muted)",
              fontSize: 14,
              lineHeight: 1.2,
              fontWeight: 400,
            }}
          >
            @{handle}
          </span>
        ) : null}
        <small
          className="wyn-post-timestamp"
          style={{ maxWidth: 104, fontSize: 14, lineHeight: 1.2, flex: "0 0 auto" }}
        >
          · {timeLabel}
        </small>
      </Link>
      {showFollow ? (
        <button
          className={`wyn-post-follow-pill ${followRequested ? "is-requested" : ""}`}
          style={{ minHeight: 26, height: 26, padding: "0 10px", fontSize: 12.5 }}
          type="button"
          onClick={onFollow}
        >
          {followRequested ? "ขอติดตามแล้ว" : "ติดตาม"}
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
