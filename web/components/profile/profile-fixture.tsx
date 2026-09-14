"use client";

import { useState } from "react";

import { WynosTabs } from "@/components/design-system/WynosTabs";
import { BottomNavigation } from "@/components/bottom-navigation";
import { DropPreviewCard } from "@/components/phase3-ui";
import { ProfileHeader } from "@/components/profile/profile-header";
import type { HomeFeedRow } from "@/lib/feed";
import type { ProfileRow, ProfileSummary } from "@/lib/phase3-data";

/**
 * Deterministic Profile fixture for Playwright visual-regression screenshots
 * and manual Founder review (WYN-159 Batch 3, mirrors the pattern
 * established by `components/home/home-fixture.tsx` / `/dev/home-fixture`).
 * Renders the same presentational `ProfileHeader` + `WynosTabs` + post grid
 * ProfileInner uses, with static data instead of a live Supabase profile —
 * test-only, not linked from anywhere in the app.
 *
 * `variant="own"` shows the current user's own profile (Edit Profile pill,
 * no Follow button). `variant="other"` shows another user's profile with a
 * visible Follow button, matching the two required screenshot states.
 */

const VIEWER_ID = "11111111-1111-4111-8111-111111111111";
const OTHER_ID = "22222222-2222-4222-8222-222222222222";

function fixtureImage(fill: string, label: string) {
  return (
    "data:image/svg+xml," +
    encodeURIComponent(
      `<svg xmlns='http://www.w3.org/2000/svg' width='1200' height='900'>` +
        `<rect width='100%' height='100%' fill='${fill}'/>` +
        `<text x='50%' y='50%' font-family='sans-serif' font-size='48' fill='#8a8880' ` +
        `text-anchor='middle' dominant-baseline='middle'>${label}</text></svg>`,
    )
  );
}

const COVER_IMAGE = fixtureImage("#2b2a26", "Fixture Cover");

function fixtureProfile(overrides: Partial<ProfileRow>): ProfileRow {
  return {
    id: OTHER_ID,
    username: "chompoo.wandee",
    display_name: "ชมพู่ วันดี",
    bio: "ช่างภาพอิสระ 📷 เล่าเรื่องผ่านภาพถ่ายทุกวัน",
    avatar_url: null,
    cover_url: COVER_IMAGE,
    is_private: false,
    is_verified: true,
    dm_permission: "everyone",
    mention_permission: "everyone",
    comment_permission: "everyone",
    likes_visibility: "everyone",
    ...overrides,
  };
}

const ownSummary: ProfileSummary = {
  profile: fixtureProfile({
    id: VIEWER_ID,
    username: "me.wynos",
    display_name: "คุณ",
    bio: "บัญชีของฉันเอง — ทดสอบหน้าโปรไฟล์",
    is_verified: false,
  }),
  followerCount: 1280,
  followingCount: 312,
  following: false,
  requested: false,
  blocked: false,
  blockedBy: false,
  muted: false,
};

const otherSummary: ProfileSummary = {
  profile: fixtureProfile({}),
  followerCount: 48200,
  followingCount: 189,
  following: false,
  requested: false,
  blocked: false,
  blockedBy: false,
  muted: false,
};

const FIXTURE_ROWS: HomeFeedRow[] = [
  {
    id: "profile-drop-1",
    content_type: "drop",
    author_id: OTHER_ID,
    author_username: "chompoo.wandee",
    author_display_name: "ชมพู่ วันดี",
    author_avatar_url: null,
    author_is_verified: true,
    created_at: new Date(Date.now() - 3 * 60 * 60 * 1000).toISOString(),
    caption: "แสงเช้าของวันนี้สวยมากเลย ออกไปถ่ายรูปตั้งแต่ตีห้า",
    image_url: fixtureImage("#dcd8cf", "Fixture Photo"),
    image_count: 1,
    like_count: 342,
    comment_count: 28,
    redrop_count: 6,
    audience: "everyone",
  },
  {
    id: "profile-drop-2",
    content_type: "drop",
    author_id: OTHER_ID,
    author_username: "chompoo.wandee",
    author_display_name: "ชมพู่ วันดี",
    author_avatar_url: null,
    author_is_verified: true,
    created_at: new Date(Date.now() - 26 * 60 * 60 * 1000).toISOString(),
    caption: "งานอดิเรกใหม่ของเดือนนี้คือถ่ายภาพฟิล์ม",
    image_url: null,
    image_count: 0,
    like_count: 96,
    comment_count: 5,
    redrop_count: 1,
    audience: "everyone",
  },
];

function ProfileTabsAndFeed() {
  const [tab, setTab] = useState<"posts" | "redrops" | "likes">("posts");
  return (
    <>
      <WynosTabs
        items={[
          { key: "posts", label: "สื่อ" },
          { key: "redrops", label: "รีโพสต์" },
          { key: "likes", label: "ถูกใจ" },
        ]}
        activeKey={tab}
        onSelect={setTab}
        ariaLabel="แท็บโปรไฟล์"
      />
      {tab === "posts" ? (
        <div className="profile-feed-list">
          {FIXTURE_ROWS.map((row) => (
            <DropPreviewCard row={row} key={row.id} />
          ))}
        </div>
      ) : (
        <div className="route-empty">
          <p>{tab === "redrops" ? "ยังไม่มีรีโพสต์" : "ยังไม่มีสิ่งที่ถูกใจ"}</p>
        </div>
      )}
    </>
  );
}

export function ProfileFixture({ variant }: { variant: "own" | "other" }) {
  const own = variant === "own";
  const summary = own ? ownSummary : otherSummary;
  const profile = summary.profile;

  return (
    <div className="route-app route-with-bottom-nav">
      <main className="route-main">
        <section className="profile-route flutter-profile-route">
          <ProfileHeader
            profile={profile}
            summary={summary}
            own={own}
            name={profile.display_name?.trim() || profile.username}
            action={false}
            error=""
            onBack={() => {}}
            onShare={() => {}}
            onSettings={() => {}}
            onSearch={() => {}}
            onMore={() => {}}
            onEdit={() => {}}
            onSuggested={() => {}}
            onBookmarks={() => {}}
            onFollow={() => {}}
            onUnblock={() => {}}
            onStartChat={() => {}}
          />
        </section>
        <ProfileTabsAndFeed />
      </main>
      <BottomNavigation
        profileHref={`/profile/${VIEWER_ID}`}
        isActive={(href) => href === `/profile/${VIEWER_ID}`}
        notificationLabel="การแจ้งเตือน"
        notificationBadge={null}
      />
    </div>
  );
}
