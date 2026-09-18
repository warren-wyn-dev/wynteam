"use client";

import { useState } from "react";

import { BottomNavigation } from "@/components/bottom-navigation";
import { HomeHeader } from "@/components/home/home-header";
import { HomePostCard } from "@/components/home/home-post-card";
import { HomeTabs, type HomeFeedMode } from "@/components/home/home-tabs";
import type { HomeFeedRow } from "@/lib/feed";
import type { HomeViewerState } from "@/lib/home-actions";

/**
 * Deterministic Home fixture for Playwright visual-regression screenshots
 * (see tests/browser/home-visual-parity.spec.ts). Renders the same
 * presentational components HomeScreen uses, with static data instead of
 * a live Supabase feed — test-only, not linked from anywhere in the app.
 */

const VIEWER_ID = "11111111-1111-4111-8111-111111111111";

// Inline SVG, not a remote CDN image: the fixture must render fully
// offline so screenshots stay deterministic in any CI environment.
const FIXTURE_IMAGE =
  "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='1200' height='900'%3E%3Crect width='100%25' height='100%25' fill='%23e8e6e0'/%3E%3Ctext x='50%25' y='50%25' font-family='sans-serif' font-size='48' fill='%238a8880' text-anchor='middle' dominant-baseline='middle'%3EFixture Photo%3C/text%3E%3C/svg%3E";

const rows: HomeFeedRow[] = [
  {
    id: "drop-1",
    content_type: "drop",
    author_id: "author-verified",
    author_username: "sirikanya.wongchaisuwan.official",
    author_display_name: "ศิริกัญญา วงศ์ไชยสุวรรณ",
    author_avatar_url: null,
    author_is_verified: true,
    // Hour-granularity (not minutes): relativeTimeTh's "N นาที" bucket
    // ticks over every 60s, which can flip between server render and
    // client hydration and make the screenshot non-deterministic.
    created_at: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(),
    caption:
      "เช้านี้อากาศดีมาก ออกไปเดินเล่นริมแม่น้ำแล้วเจอร้านกาแฟใหม่ บรรยากาศดีสุด ๆ ต้องกลับมาอีกแน่นอน\n\n#เชียงใหม่ #กาแฟ #วันหยุด",
    image_url: FIXTURE_IMAGE,
    image_width: 1200,
    image_height: 900,
    image_count: 1,
    like_count: 128,
    comment_count: 12,
    redrop_count: 4,
    redrop_id: "redrop-fixture-1",
    redropper_username: "wynos_online",
    audience: "everyone",
  },
  {
    id: "drop-2",
    content_type: "drop",
    author_id: "author-long-caption",
    author_username: "wynos_fan_2026",
    author_display_name: "คนรัก WYNOS",
    author_avatar_url: null,
    author_is_verified: false,
    created_at: new Date(Date.now() - 3 * 60 * 60 * 1000).toISOString(),
    caption:
      "วันนี้อยากเล่าเรื่องยาว ๆ ให้ฟังหน่อย ตั้งแต่เช้าจนถึงตอนนี้มีเรื่องเกิดขึ้นเยอะมาก ทั้งเรื่องงาน เรื่องเพื่อน แล้วก็เรื่องครอบครัว รู้สึกเหนื่อยแต่ก็มีความสุขไปพร้อม ๆ กัน อยากขอบคุณทุกคนที่อยู่เคียงข้างกันมาตลอด\nพรุ่งนี้จะพยายามทำให้ดีขึ้นกว่าเดิม ขอบคุณที่อ่านมาถึงตรงนี้นะคะ",
    image_url: null,
    image_count: 0,
    like_count: 0,
    comment_count: 0,
    redrop_count: 0,
    audience: "everyone",
  },
];

const viewer: HomeViewerState = {
  likedDropIds: new Set(["drop-1"]),
  savedDropIds: new Set(),
  redroppedDropIds: new Set(),
  followedAuthorIds: new Set(),
  pendingFollowAuthorIds: new Set(["author-long-caption"]),
  privateAuthorIds: new Set(),
};

const images = new Map<string, string[]>([["drop-1", [rows[0].image_url as string]]]);

export function HomeFixture() {
  const [mode, setMode] = useState<HomeFeedMode>("for-you");
  const [savedDropIds, setSavedDropIds] = useState<Set<string>>(new Set());
  const fixtureViewer = { ...viewer, savedDropIds };

  return (
    <div className="route-app route-with-bottom-nav">
      <main className="route-main">
        <div className="wyn-home">
          <HomeHeader
            notificationBadgeCount={3}
            onOpenMenu={() => {}}
            onOpenSearch={() => {}}
            onOpenNotifications={() => {}}
          />
          <HomeTabs mode={mode} onSelect={setMode} />
        </div>
        <div className="wyn-home-feed">
          {rows.map((row) => (
            <HomePostCard
              row={row}
              viewer={fixtureViewer}
              images={images.get(row.id) ?? []}
              userId={VIEWER_ID}
              onLike={() => {}}
              onMore={() => {}}
              onRedrop={() => {}}
              onFollow={() => {}}
              onShare={() => {}}
              onSave={() => setSavedDropIds((current) => {
                const next = new Set(current);
                if (next.has(row.id)) next.delete(row.id);
                else next.add(row.id);
                return next;
              })}
              key={row.id}
            />
          ))}
        </div>
      </main>
      <BottomNavigation
        profileHref={`/profile/${VIEWER_ID}`}
        isActive={(href) => href === "/"}
        notificationLabel="การแจ้งเตือน มี 2 รายการที่ยังไม่อ่าน"
        notificationBadge="2"
      />
    </div>
  );
}
