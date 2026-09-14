"use client";

import { useState } from "react";

import { BottomNavigation } from "@/components/bottom-navigation";
import { WynosAppShell } from "@/components/design-system/WynosAppShell";
import homeShell from "@/components/home/home-shell.module.css";
import { HomeHeader } from "@/components/home/home-header";
import { HomePostCard } from "@/components/home/home-post-card";
import { HomeTabs, type HomeFeedMode } from "@/components/home/home-tabs";
import type { HomeFeedRow } from "@/lib/feed";
import type { HomeViewerState } from "@/lib/home-actions";

/**
 * Deterministic Home fixture for Playwright visual-regression screenshots
 * and manual Founder review (see tests/browser/home-visual-parity.spec.ts,
 * WYN-159's `/dev/home-fixture` correction pass). Renders the same
 * presentational components HomeScreen uses, with static data instead of
 * a live Supabase feed — test-only, not linked from anywhere in the app.
 *
 * Includes all three `WynosPostCard` variants from the 2026-09-14
 * `wynos-home.html` correction so a single screenshot of this route
 * demonstrates the full corrected spec: text-only, image-carousel, and
 * failed-to-send.
 */

const VIEWER_ID = "11111111-1111-4111-8111-111111111111";

// Inline SVGs, not remote CDN images: the fixture must render fully
// offline so screenshots stay deterministic in any CI environment.
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

const CAROUSEL_IMAGES = [
  fixtureImage("#e8e6e0", "Fixture Photo 1"),
  fixtureImage("#dcd8cf", "Fixture Photo 2"),
  fixtureImage("#cfc9bc", "Fixture Photo 3"),
];

const rows: HomeFeedRow[] = [
  // ---- Post 1: text only (matches wynos-home.html's "พลอย เดินทาง" post) ----
  {
    id: "drop-1",
    content_type: "drop",
    author_id: "author-long-caption",
    author_username: "wynos_fan_2026",
    author_display_name: "คนรัก WYNOS",
    author_avatar_url: null,
    author_is_verified: false,
    created_at: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(),
    caption:
      "วันนี้อยากเล่าเรื่องยาว ๆ ให้ฟังหน่อย ตั้งแต่เช้าจนถึงตอนนี้มีเรื่องเกิดขึ้นเยอะมาก ทั้งเรื่องงาน เรื่องเพื่อน แล้วก็เรื่องครอบครัว รู้สึกเหนื่อยแต่ก็มีความสุขไปพร้อม ๆ กัน อยากขอบคุณทุกคนที่อยู่เคียงข้างกันมาตลอด\nพรุ่งนี้จะพยายามทำให้ดีขึ้นกว่าเดิม ขอบคุณที่อ่านมาถึงตรงนี้นะคะ",
    image_url: null,
    image_count: 0,
    like_count: 0,
    comment_count: 0,
    redrop_count: 0,
    audience: "everyone",
  },
  // ---- Post 2: image carousel (matches wynos-home.html's "ต้น สายเทค" post) ----
  {
    id: "drop-2",
    content_type: "drop",
    author_id: "author-verified",
    author_username: "sirikanya.wongchaisuwan.official",
    author_display_name: "ศิริกัญญา วงศ์ไชยสุวรรณ",
    author_avatar_url: null,
    author_is_verified: true,
    // Hour-granularity (not minutes): relativeTimeTh's "N นาที" bucket
    // ticks over every 60s, which can flip between server render and
    // client hydration and make the screenshot non-deterministic.
    created_at: new Date(Date.now() - 5 * 60 * 60 * 1000).toISOString(),
    caption:
      "เช้านี้อากาศดีมาก ออกไปเดินเล่นริมแม่น้ำแล้วเจอร้านกาแฟใหม่ บรรยากาศดีสุด ๆ ต้องกลับมาอีกแน่นอน\n\n#เชียงใหม่ #กาแฟ #วันหยุด",
    image_url: CAROUSEL_IMAGES[0],
    image_width: 1200,
    image_height: 900,
    image_count: CAROUSEL_IMAGES.length,
    like_count: 128,
    comment_count: 12,
    redrop_count: 4,
    audience: "everyone",
  },
  // ---- Post 3: failed to send (matches wynos-home.html's "คุณ" post) ----
  // Presentational-only: nothing in the product today models a locally
  // queued/failed post in the feed (see home-post-card.tsx's doc comment),
  // so this fixture row exists purely to demonstrate the variant.
  {
    id: "drop-3-failed",
    content_type: "drop",
    author_id: VIEWER_ID,
    author_username: "me",
    author_display_name: "คุณ",
    author_avatar_url: null,
    author_is_verified: false,
    created_at: new Date().toISOString(),
    caption: "อยากกินอะไรมื้อเย็นดี",
    image_url: null,
    image_count: 0,
    like_count: 0,
    comment_count: 0,
    redrop_count: 0,
    audience: "everyone",
  },
];

const viewer: HomeViewerState = {
  likedDropIds: new Set(["drop-2"]),
  savedDropIds: new Set(),
  redroppedDropIds: new Set(),
  followedAuthorIds: new Set(),
  pendingFollowAuthorIds: new Set(["author-long-caption"]),
  privateAuthorIds: new Set(),
};

const images = new Map<string, string[]>([["drop-2", CAROUSEL_IMAGES]]);

export function HomeFixture() {
  const [mode, setMode] = useState<HomeFeedMode>("for-you");

  return (
    <div className="route-app route-with-bottom-nav">
      <main className="route-main">
        <WynosAppShell>
          <div className={homeShell.stickyWrap}>
            <div className={homeShell.headerGroup}>
              <HomeHeader chatBadgeCount={3} onOpenMenu={() => {}} onOpenChat={() => {}} />
              <HomeTabs mode={mode} onSelect={setMode} />
            </div>
          </div>
          <div className={homeShell.feed}>
            {rows.map((row) => (
              <HomePostCard
                row={row}
                viewer={viewer}
                images={images.get(row.id) ?? []}
                userId={VIEWER_ID}
                onLike={() => {}}
                onMore={() => {}}
                onRedrop={() => {}}
                onFollow={() => {}}
                onShare={() => {}}
                sendStatus={row.id === "drop-3-failed" ? "failed" : "sent"}
                onRetry={() => {}}
                key={row.id}
              />
            ))}
          </div>
        </WynosAppShell>
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
