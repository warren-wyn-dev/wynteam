import { Bookmark, ChevronLeft, MoreVertical, Pencil, Search, Send, Settings, Share2, UserPlus } from "lucide-react";

import { WynosAvatar } from "@/components/design-system/WynosAvatar";
import { WynosIconButton } from "@/components/design-system/WynosIconButton";
import profileStyles from "@/components/profile/profile.module.css";
import type { ProfileSummary } from "@/lib/phase3-data";

/**
 * ProfileHeader — cover photo + avatar + identity + stats + primary actions
 * (WYN-159 design system, Profile screen: WynosHeader-equivalent toolbar +
 * WynosAvatar + stats block + primary action pills). Extracted from
 * `profile-route.tsx` so the same presentational block can be reused by the
 * `/dev/profile-fixture` route for deterministic screenshots.
 *
 * Preserves the exact WYN-141 Founder-approved cover/avatar/stats metrics
 * (170px cover, 92px avatar overlap at -23px, 44px action row, stats grid)
 * per the WYN-159 Profile spec — this component only re-skins colors onto
 * those already-approved proportions, it does not re-derive layout.
 *
 * IMPORTANT: `profile-parity-route.tsx` intercepts clicks on
 * `.flutter-profile-stats button` (routes to followers/following) and on
 * `button[aria-label="เพิ่มเติม"]` (opens its own report/mute/block sheet) via
 * a capture-phase listener on an ancestor element. Those class name / aria
 * label hooks are preserved exactly here — do not rename/remove them without
 * updating the capture() selectors in profile-parity-route.tsx to match.
 */
export function ProfileHeader({
  profile,
  summary,
  own,
  name,
  action,
  error,
  onBack,
  onShare,
  onSettings,
  onSearch,
  onMore,
  onEdit,
  onSuggested,
  onBookmarks,
  onFollow,
  onUnblock,
  onStartChat,
}: {
  profile: ProfileSummary["profile"];
  summary: ProfileSummary;
  own: boolean;
  name: string;
  action: boolean;
  error: string;
  onBack: () => void;
  onShare: () => void;
  onSettings: () => void;
  onSearch: () => void;
  onMore: () => void;
  onEdit: () => void;
  onSuggested: () => void;
  onBookmarks: () => void;
  onFollow: () => void;
  onUnblock: () => void;
  onStartChat: () => void;
}) {
  return (
    <>
      <div className={`flutter-profile-cover ${profileStyles.cover}`}>
        {profile.cover_url ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={profile.cover_url} alt="" />
        ) : (
          <span className="profile-cover-fallback" />
        )}
        <div className={`flutter-profile-cover-toolbar ${profileStyles.coverToolbar}`}>
          <WynosIconButton className={profileStyles.coverIcon} icon={<ChevronLeft size={24} />} aria-label="ย้อนกลับ" onClick={onBack} />
          <strong>โปรไฟล์</strong>
          <span className="profile-cover-toolbar-spacer" />
          {own ? (
            <>
              <WynosIconButton className={profileStyles.coverIcon} icon={<Share2 size={20} />} aria-label="แชร์โปรไฟล์" onClick={onShare} />
              <WynosIconButton className={profileStyles.coverIcon} icon={<Settings size={22} />} aria-label="ตั้งค่า" onClick={onSettings} />
            </>
          ) : (
            <>
              <WynosIconButton className={profileStyles.coverIcon} icon={<Search size={20} />} aria-label="ค้นหา" onClick={onSearch} />
              <WynosIconButton className={profileStyles.coverIcon} icon={<MoreVertical size={20} />} aria-label="เพิ่มเติม" onClick={onMore} />
            </>
          )}
        </div>
      </div>
      <div className={`flutter-profile-identity ${profileStyles.identity}`}>
        <div className="flutter-profile-avatar">
          <WynosAvatar src={profile.avatar_url} label={profile.username} size={92 - 8} />
        </div>
        <div className={`profile-copy flutter-profile-copy ${profileStyles.copy}`}>
          <h2>
            {name}
            {profile.is_verified ? <span className="route-verified">✓</span> : null}
          </h2>
          <p className="profile-username">@{profile.username}</p>
          {profile.bio ? <p>{profile.bio}</p> : null}
        </div>
        {!summary.blockedBy ? (
          <div className="profile-stats flutter-profile-stats">
            <button type="button">
              <b>{summary.followingCount.toLocaleString("th-TH")}</b> กำลังติดตาม
            </button>
            <button type="button">
              <b>{summary.followerCount.toLocaleString("th-TH")}</b> ผู้ติดตาม
            </button>
          </div>
        ) : null}
        {own ? (
          <div className="flutter-profile-actions own">
            <button className="profile-action-primary" type="button" onClick={onEdit}>
              <Pencil size={20} />
              แก้ไขโปรไฟล์
            </button>
            <button className="profile-action-icon" type="button" aria-label="แนะนำสำหรับคุณ" onClick={onSuggested}>
              <UserPlus size={20} />
            </button>
            <button className="profile-action-icon" type="button" aria-label="บันทึกไว้" onClick={onBookmarks}>
              <Bookmark size={20} />
            </button>
          </div>
        ) : summary.blocked ? (
          <div className="flutter-profile-actions">
            <button className="profile-action-primary soft" disabled={action} type="button" onClick={onUnblock}>
              ปลดบล็อก
            </button>
          </div>
        ) : (
          <div className="flutter-profile-actions">
            <button
              className={`profile-action-primary ${summary.following || summary.requested ? "soft" : ""}`}
              disabled={action || summary.blockedBy}
              type="button"
              onClick={onFollow}
            >
              {summary.following ? "กำลังติดตาม" : summary.requested ? "ขอติดตามแล้ว" : "ติดตาม"}
            </button>
            <button className="profile-action-secondary" disabled={action || summary.blockedBy} type="button" onClick={onStartChat}>
              <Send size={18} /> ส่งข้อความ
            </button>
          </div>
        )}
        {summary.blockedBy ? <p className="route-notice">ไม่สามารถดูเนื้อหาของผู้ใช้นี้ได้</p> : null}
        {!summary.blockedBy && profile.is_private && !own && !summary.following ? (
          <p className="route-notice">บัญชีนี้เป็นส่วนตัว — ติดตามเพื่อดู {name}</p>
        ) : null}
        {error ? <p className="route-error">{error}</p> : null}
      </div>
    </>
  );
}
