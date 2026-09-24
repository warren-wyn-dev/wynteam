"use client";

import { ViewportPortal } from "@/components/ui/viewport-portal";
import { PostDetailSkeleton } from "@/components/ui/skeleton";

/**
 * Keyboard-inset regression fixture (see
 * tests/browser/post-detail-keyboard.spec.ts). Renders the same composer
 * markup/classes as PostDetailRoute's `.detail-composer-shell` without a
 * Supabase-backed page, so the CSS contract that `useKeyboardInset` drives
 * (--wyn-kb-inset + [data-keyboard-open] on <html>) can be exercised
 * directly — real iOS keyboard show/hide can't be triggered in headless
 * Chromium, so this checks the contract's effect on layout instead of the
 * hook's event wiring. Test-only, not linked from anywhere in the app, same
 * pattern as home-fixture.tsx / wyn-175-skeleton-fixture.tsx.
 */
export function PostDetailKeyboardFixture({ loading = false }: { loading?: boolean }) {
  if (loading) return <><header className="detail-floating-header"><strong>โพสต์</strong></header><PostDetailSkeleton /></>;
  return (
    <div className="route-app route-app-header-hidden route-without-bottom-nav">
      <main className="route-main">
        <article className="detail-post flutter-detail-post" id="post-context">
          <div className="detail-post-copy">
            <p>เนื้อหาโพสต์ตัวอย่างสำหรับทดสอบ layout ตอนคีย์บอร์ดเปิด</p>
          </div>
        </article>
        <section className="detail-comments flutter-detail-comments" aria-label="ความคิดเห็น">
          {Array.from({ length: 20 }, (_, index) => (
            <div className="detail-comment" key={index}>
              <div className="detail-comment-copy"><p>คอมเมนต์ตัวอย่าง #{index + 1}</p></div>
            </div>
          ))}
        </section>
        <ViewportPortal><div className="detail-composer-shell" id="composer-shell">
          <form className="detail-comment-form flutter-detail-composer" onSubmit={(event) => event.preventDefault()}>
            <span className="route-avatar fallback" style={{ width: 36, height: 36 }}>W</span>
            <div className="flutter-detail-composer-field">
              <input id="composer-input" placeholder="แสดงความคิดเห็น..." />
              <button id="composer-send" type="submit" aria-label="ส่งความคิดเห็น">›</button>
            </div>
          </form>
        </div></ViewportPortal>
      </main>
    </div>
  );
}
