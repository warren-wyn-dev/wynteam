/**
 * Shimmering placeholder blocks shown while feed/profile/chat data loads,
 * shaped like the content they stand in for so the layout doesn't jump once
 * real data arrives. See app/skeleton.css for the shimmer animation.
 */
export function SkeletonBlock({
  width,
  height,
  radius,
  className,
  style,
}: {
  width?: number | string;
  height?: number | string;
  radius?: number;
  className?: string;
  style?: React.CSSProperties;
}) {
  return (
    <div
      className={`wyn-skeleton ${className ?? ""}`}
      aria-hidden="true"
      style={{ width, height, borderRadius: radius, ...style }}
    />
  );
}

export function SkeletonCircle({ size }: { size: number }) {
  return <SkeletonBlock className="wyn-skeleton-circle" width={size} height={size} />;
}

function FeedItemSkeleton() {
  return (
    <div className="wyn-skeleton-feed-item">
      <SkeletonCircle size={44} />
      <div className="wyn-skeleton-feed-item-body">
        <SkeletonBlock width="40%" height={14} />
        <SkeletonBlock width="90%" height={14} />
        <SkeletonBlock width="70%" height={14} />
        <SkeletonBlock height={220} radius={16} />
      </div>
    </div>
  );
}

export function FeedSkeleton({ items = 3 }: { items?: number }) {
  return (
    <div aria-label="กำลังโหลดฟีด" aria-live="polite">
      {Array.from({ length: items }, (_, index) => (
        <FeedItemSkeleton key={index} />
      ))}
    </div>
  );
}

export function ProfileSkeleton() {
  return (
    <div aria-label="กำลังโหลดโปรไฟล์" aria-live="polite">
      <div className="wyn-skeleton-profile-header">
        <div className="wyn-skeleton-profile-intro">
          <SkeletonCircle size={64} />
          <div className="wyn-skeleton-profile-copy">
            <SkeletonBlock width="55%" height={16} />
            <SkeletonBlock width="80%" height={13} />
          </div>
        </div>
        <div className="wyn-skeleton-profile-stats">
          <SkeletonBlock width={72} height={14} />
          <SkeletonBlock width={72} height={14} />
        </div>
        <SkeletonBlock height={36} radius={10} />
      </div>
      <FeedSkeleton items={2} />
    </div>
  );
}

function ChatRowSkeleton() {
  return (
    <div className="wyn-skeleton-chat-row">
      <SkeletonCircle size={48} />
      <div className="wyn-skeleton-chat-row-copy">
        <SkeletonBlock width="45%" height={14} />
        <SkeletonBlock width="75%" height={12} />
      </div>
    </div>
  );
}

export function ChatListSkeleton({ items = 6 }: { items?: number }) {
  return (
    <div aria-label="กำลังโหลดข้อความ" aria-live="polite">
      {Array.from({ length: items }, (_, index) => (
        <ChatRowSkeleton key={index} />
      ))}
    </div>
  );
}

// WYN-175: Search and Notifications used a spinner instead of a
// content-shaped placeholder. Row dimensions below mirror the real
// .route-person-row/.route-club-row/.notification-row CSS (app/phase3.css)
// so nothing jumps once real rows replace these.
function SearchUserRowSkeleton() {
  return (
    <div className="wyn-skeleton-search-person-row">
      <SkeletonCircle size={42} />
      <div className="wyn-skeleton-search-person-copy">
        <SkeletonBlock width="42%" height={14} />
        <SkeletonBlock width="28%" height={12} />
      </div>
    </div>
  );
}

export function SearchUserSkeleton({ items = 6 }: { items?: number }) {
  return (
    <div aria-label="กำลังค้นหาผู้ใช้" aria-live="polite">
      {Array.from({ length: items }, (_, index) => (
        <SearchUserRowSkeleton key={index} />
      ))}
    </div>
  );
}

function SearchClubRowSkeleton() {
  return (
    <div className="wyn-skeleton-search-club-row">
      <SkeletonBlock width={46} height={46} radius={13} />
      <div className="wyn-skeleton-search-person-copy">
        <SkeletonBlock width="50%" height={14} />
        <SkeletonBlock width="34%" height={12} />
      </div>
    </div>
  );
}

export function SearchClubSkeleton({ items = 6 }: { items?: number }) {
  return (
    <div aria-label="กำลังค้นหา Club" aria-live="polite">
      {Array.from({ length: items }, (_, index) => (
        <SearchClubRowSkeleton key={index} />
      ))}
    </div>
  );
}

function HashtagRowSkeleton() {
  return (
    <div className="wyn-skeleton-hashtag-row">
      <SkeletonBlock width={16} height={12} />
      <SkeletonBlock width="55%" height={13} />
    </div>
  );
}

export function SearchDiscoverySkeleton() {
  return (
    <div aria-label="กำลังโหลดคำแนะนำ" aria-live="polite">
      {Array.from({ length: 3 }, (_, index) => <HashtagRowSkeleton key={index} />)}
      {Array.from({ length: 3 }, (_, index) => <SearchUserRowSkeleton key={index} />)}
    </div>
  );
}

function NotificationRowSkeleton() {
  return (
    <div className="wyn-skeleton-notification-row">
      <SkeletonCircle size={44} />
      <div className="wyn-skeleton-notification-copy">
        <SkeletonBlock width="80%" height={13} />
        <SkeletonBlock width="30%" height={11} />
      </div>
    </div>
  );
}

export function NotificationSkeleton({ items = 6 }: { items?: number }) {
  return (
    <div aria-label="กำลังโหลดการแจ้งเตือน" aria-live="polite">
      {Array.from({ length: items }, (_, index) => (
        <NotificationRowSkeleton key={index} />
      ))}
    </div>
  );
}

/** Content-shaped placeholder for the text-first Post Detail view. */
export function PostDetailSkeleton() {
  return (
    <section className="wyn-skeleton-detail" aria-label="กำลังโหลดโพสต์" role="status">
      <div className="wyn-skeleton-detail-author">
        <SkeletonCircle size={44} />
        <div className="wyn-skeleton-detail-author-copy">
          <SkeletonBlock width="55%" height={15} />
          <SkeletonBlock width="38%" height={12} />
        </div>
        <SkeletonBlock width={28} height={28} radius={14} />
      </div>
      <div className="wyn-skeleton-detail-caption">
        <SkeletonBlock width="64%" height={16} />
        <SkeletonBlock width="86%" height={16} />
      </div>
      <div className="wyn-skeleton-detail-actions">
        {Array.from({ length: 5 }, (_, index) => <SkeletonBlock key={index} width={27} height={27} radius={12} />)}
      </div>
      <div className="wyn-skeleton-detail-activity"><SkeletonBlock height={54} radius={18} /></div>
      <div className="wyn-skeleton-detail-comment"><SkeletonBlock width="52%" height={13} /></div>
    </section>
  );
}
