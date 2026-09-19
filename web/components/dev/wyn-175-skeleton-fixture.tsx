import {
  NotificationSkeleton,
  SearchClubSkeleton,
  SearchDiscoverySkeleton,
  SearchUserSkeleton,
} from "@/components/ui/skeleton";

/**
 * WYN-175 regression fixture (see tests/browser/wyn-175-skeleton-parity.spec.ts).
 * Renders each new skeleton component next to a minimal instance of the real
 * row markup it stands in for, so a Playwright test can assert their heights
 * stay within 1px of each other. Exists because the first version of these
 * skeletons was built from the first CSS rule found for a class name instead
 * of the one that actually wins this codebase's parity/pixel-parity override
 * cascade, causing a real layout shift once data replaced the skeleton
 * (`.wyn/tasks/bugs/WYN-175-skeleton-row-height-cascade-mismatch.md`) — test-only,
 * not linked from anywhere in the app, same pattern as home-fixture.tsx.
 */
export function Wyn175SkeletonFixture() {
  return (
    <div>
      <div id="skel-user"><SearchUserSkeleton items={1} /></div>
      <div className="route-list" id="real-user">
        <div className="route-person-row">
          <a className="route-person-main" href="#">
            <span className="route-avatar fallback" style={{ width: 42, height: 42 }}>W</span>
            <span className="route-person-copy"><strong>WYNOS</strong><small>@wynos</small></span>
          </a>
        </div>
      </div>

      <div id="skel-club"><SearchClubSkeleton items={1} /></div>
      <a className="route-club-row" href="#" id="real-club">
        <span className="route-club-image" style={{ width: 46, height: 46 }}>W</span>
        <span><strong>WYN Club</strong><small>100 สมาชิก</small></span>
      </a>

      <div id="skel-notification"><NotificationSkeleton items={1} /></div>
      <button className="notification-row" type="button" id="real-notification">
        <span className="notification-avatar-wrap">
          <span className="route-avatar fallback" style={{ width: 40, height: 40 }}>W</span>
        </span>
        <span className="notification-copy"><strong>ทดสอบ</strong><small>1 นาทีที่แล้ว</small></span>
      </button>

      <div id="skel-discovery"><SearchDiscoverySkeleton /></div>
      <div className="hashtag-list">
        <div className="hashtag-row flutter-rank-row" id="real-hashtag">
          <b>1</b>
          <span className="flutter-rank-copy"><strong>#test</strong><small>10 โพสต์</small></span>
        </div>
      </div>
    </div>
  );
}
