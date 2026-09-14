import { MoreHorizontal } from "lucide-react";
import Link from "next/link";

/**
 * The name/timestamp/Follow/More row from home_drop_card.dart's author
 * header (the avatar itself is a separate grid column owned by
 * HomePostCard, matching WYN-107's two-column card layout).
 */
export function PostAuthorRow({
  profileHref,
  name,
  verified,
  timeLabel,
  showFollow,
  followRequested,
  onFollow,
  onMore,
}: {
  profileHref: string;
  name: string;
  verified: boolean;
  timeLabel: string;
  showFollow: boolean;
  followRequested: boolean;
  onFollow: () => void;
  onMore: () => void;
}) {
  return (
    <header className="wyn-post-author-row">
      <Link className="wyn-post-author-link" href={profileHref}>
        <strong className="wyn-post-author-name">{name}</strong>
        {verified ? <span className="route-verified wyn-post-verified">✓</span> : null}
        <small className="wyn-post-timestamp">{timeLabel}</small>
      </Link>
      {showFollow ? (
        <button
          className={`wyn-post-follow-pill ${followRequested ? "is-requested" : ""}`}
          type="button"
          onClick={onFollow}
        >
          {followRequested ? "ขอติดตามแล้ว" : "ติดตาม"}
        </button>
      ) : null}
      <button className="wyn-post-more" type="button" aria-label="เพิ่มเติม" onClick={onMore}>
        <MoreHorizontal size={22} />
      </button>
    </header>
  );
}
