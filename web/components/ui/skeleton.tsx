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
