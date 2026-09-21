"use client";

import { useSearchParams } from "next/navigation";
import { Suspense } from "react";

import { AppChrome, EmptyState, LoadingState } from "@/components/phase3-ui";

/**
 * WYNOS Web Beta1, item 3: Trending Top 100 fixture (see
 * tests/browser/trending-top100.spec.ts). Reproduces TrendingRoute's three
 * render branches (loading/error/empty/list) without a Supabase-backed
 * fetch, selected via ?state=loading|error|empty|list -- same
 * no-backend-fixture pattern as home-fixture.tsx / post-detail-keyboard-fixture.tsx.
 * Test-only, not linked from anywhere in the app.
 */
function TrendingFixtureInner() {
  const state = useSearchParams().get("state") ?? "list";
  return (
    <AppChrome title="อันดับแฮชแท็ก (Top 100)" userId="fixture-user" backHref="/search" showBottomNav={false}>
      <div className="trending-top100-page">
        {state === "error" ? (
          <div className="route-empty">
            <p>โหลดอันดับแฮชแท็กไม่สำเร็จ</p>
            <button className="route-secondary" type="button" id="retry-button">ลองใหม่</button>
          </div>
        ) : state === "loading" ? (
          <LoadingState />
        ) : state === "empty" ? (
          <EmptyState>ยังไม่มีแฮชแท็กกำลังนิยมตอนนี้</EmptyState>
        ) : (
          <div className="hashtag-list trending-top100-list">
            {[
              { tag: "wynos", postCount: 42 },
              { tag: "photography", postCount: 30 },
            ].map((item, index) => (
              <div className="hashtag-row flutter-rank-row" key={item.tag}>
                <b>{index + 1}</b>
                <span className="flutter-rank-copy">
                  <strong>#{item.tag}</strong>
                  <small>{item.postCount.toLocaleString("th-TH")} โพสต์ · กำลังนิยมใน ไทย</small>
                </span>
              </div>
            ))}
          </div>
        )}
      </div>
    </AppChrome>
  );
}

export function TrendingFixture() {
  return (
    <Suspense fallback={null}>
      <TrendingFixtureInner />
    </Suspense>
  );
}
