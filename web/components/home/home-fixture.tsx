"use client";

import { useState } from "react";

import { BottomNavigation } from "@/components/bottom-navigation";
import { HomeHeader } from "@/components/home/home-header";
import { HomePostCard } from "@/components/home/home-post-card";
import { HomeTabs, type HomeFeedMode } from "@/components/home/home-tabs";
import { WynosIcon } from "@/components/ui/wynos-icon";
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
    author_id: "warren",
    author_username: "warren",
    author_display_name: "WARREN",
    author_avatar_url: null,
    author_is_verified: false,
    created_at: "2026-09-04T10:00:00.000Z",
    caption:
      "WYNOS เริ่มจากคำถามง่าย ๆ ว่า...\n“ทำไม Social Media กับการซื้อของ ต้องแยกกัน?”\n\nเราเห็นของที่ชอบจากโซเชียล แต่พออยากซื้อ\nกลับต้องไปหาในอีกแอป 😅\n\nเราเลยอยากลองสร้างพื้นที่ที่รวมทั้ง Social + E-commerce ไว้ด้วยกัน...\n\n#WYNOS #SocialCommerce #Ecommerce\n#Startup #WYNOSThailand",
    image_url: null,
    image_count: 0,
    like_count: 6,
    comment_count: 2,
    redrop_count: 2,
    redrop_id: "redrop-fixture-1",
    redropper_username: "WYNOS",
    audience: "everyone",
  },
  {
    id: "drop-2",
    content_type: "drop",
    author_id: "warren-followed",
    author_username: "warren",
    author_display_name: "WARREN",
    author_avatar_url: null,
    author_is_verified: false,
    created_at: "2026-08-25T10:00:00.000Z",
    caption:
      "WYNOS เริ่มจากคำถามง่าย ๆ ว่า...\n“ทำไม Social Media กับการซื้อของ ต้องแยกกัน?”\n\nเราเห็นของที่ชอบจากโซเชียล แต่พออยากซื้อกลับต้องไปหาในอีกแอป 😅",
    image_url: null,
    image_count: 0,
    like_count: 12,
    comment_count: 3,
    redrop_count: 4,
    redrop_id: "redrop-fixture-2",
    redropper_username: "sky_blue",
    audience: "everyone",
  },
  {
    id: "drop-3",
    content_type: "drop",
    author_id: "mint",
    author_username: "mint",
    author_display_name: "mint",
    author_avatar_url: null,
    author_is_verified: false,
    created_at: new Date(Date.now() - 60 * 60 * 1000).toISOString(),
    caption: "เช้านี้กาแฟดีมาก ☕\nพร้อมลุยงานต่อแล้ว 💪",
    image_url: null,
    image_count: 0,
    like_count: 28,
    comment_count: 5,
    redrop_count: 0,
    audience: "everyone",
  },
  {
    id: "drop-4",
    content_type: "drop",
    author_id: "techdaily",
    author_username: "techdaily",
    author_display_name: "TechDaily",
    author_avatar_url: null,
    author_is_verified: false,
    created_at: new Date(Date.now() - 3 * 60 * 60 * 1000).toISOString(),
    caption: "Apple เปิดตัวชิปใหม่ที่เน้นประสิทธิภาพด้าน AI มากขึ้น คาดว่าจะใช้ใน Mac รุ่นถัดไปเร็ว ๆ นี้",
    image_url: FIXTURE_IMAGE,
    image_width: 1200,
    image_height: 900,
    image_count: 1,
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
  followedAuthorIds: new Set(["warren-followed", "techdaily"]),
  pendingFollowAuthorIds: new Set(),
  privateAuthorIds: new Set(),
};

const images = new Map<string, string[]>([["drop-4", [rows[3].image_url as string]]]);

export function HomeFixture() {
  const [mode, setMode] = useState<HomeFeedMode>("for-you");
  const [savedDropIds, setSavedDropIds] = useState<Set<string>>(new Set());
  const fixtureViewer = { ...viewer, savedDropIds };

  return (
    <>
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
      </div>
      <button className="wyn-home-post-fab" type="button" aria-label="สร้างโพสต์">
        <WynosIcon name="post" size={30} strokeWidth={2} />
      </button>
      {/* Sibling of .route-with-bottom-nav, matching AppBottomNavHost's
          placement in app/layout.tsx — not nested inside it, so this
          fixture actually exercises the same custom-property scoping the
          real app depends on instead of masking a cross-subtree bug. */}
      <BottomNavigation
        profileHref={`/profile/${VIEWER_ID}`}
        isActive={(href) => href === "/"}
      />
    </>
  );
}
