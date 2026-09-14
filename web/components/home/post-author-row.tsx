import { MoreHorizontal } from "lucide-react";
import Link from "next/link";

import pc from "@/components/design-system/post-card.module.css";
import { WynosPillButton } from "@/components/design-system/WynosPillButton";

/**
 * WynosPostHeader (post author row) — name/timestamp/Follow/More
 * (WYN-159 design system, `.post-head` in the reference). The avatar
 * itself is a separate flex column owned by `HomePostCard`.
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
    <header className={pc.postAuthorRow}>
      <Link className={pc.postAuthorLink} href={profileHref}>
        <strong className={pc.postAuthorName}>{name}</strong>
        {verified ? <span className={`route-verified ${pc.postVerified}`}>✓</span> : null}
        <small className={pc.postTimestamp}>· {timeLabel}</small>
      </Link>
      <div className={pc.postHeadActions}>
        {showFollow ? (
          <WynosPillButton muted={followRequested} onClick={onFollow}>
            {followRequested ? "ขอติดตามแล้ว" : "ติดตาม"}
          </WynosPillButton>
        ) : null}
        <button className={pc.postMore} type="button" aria-label="เพิ่มเติม" onClick={onMore}>
          <MoreHorizontal size={22} />
        </button>
      </div>
    </header>
  );
}
