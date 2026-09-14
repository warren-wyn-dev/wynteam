"use client";

import { BarChart3, Bookmark, ChevronLeft, ChevronRight, Heart, MessageSquare, MoreHorizontal, Repeat2, Send } from "lucide-react";
import Link from "next/link";
import { useState } from "react";

import pc from "@/components/design-system/post-card.module.css";
import { WynosAvatar } from "@/components/design-system/WynosAvatar";
import { WynosHeader } from "@/components/design-system/WynosHeader";
import { WynosIconButton } from "@/components/design-system/WynosIconButton";
import { WynosPillButton } from "@/components/design-system/WynosPillButton";
import { Caption, CommentRow, MediaGallery } from "@/components/post-detail-route";
import pdStyles from "@/components/post-detail/post-detail.module.css";
import type { DropCommentRow } from "@/lib/home-actions";

/**
 * Deterministic Post Detail fixture for Playwright visual-regression
 * screenshots and manual Founder review (WYN-159 Batch 3, mirrors the
 * pattern established by `components/home/home-fixture.tsx` /
 * `/dev/home-fixture`). Reuses the same presentational pieces
 * (`Caption`/`MediaGallery`/`CommentRow`, exported from
 * `post-detail-route.tsx`) with static data instead of a live Supabase
 * fetch — test-only, not linked from anywhere in the app. Includes a
 * comment thread with a reply so the threaded-comment visual is covered.
 */

const AUTHOR_ID = "33333333-3333-4333-8333-333333333333";

const TOP_COMMENT: DropCommentRow = {
  id: "comment-1",
  drop_id: "post-fixture-1",
  author_id: "44444444-4444-4444-8444-444444444444",
  text_content: "ภาพสวยมากเลยค่ะ ชอบโทนสีตอนเช้ามาก",
  // Hour-granularity (not minutes): relativeTimeTh's "N นาที" bucket ticks
  // over every 60s, which can flip between server render and client
  // hydration and make the fixture non-deterministic (see home-fixture.tsx).
  created_at: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(),
  parent_comment_id: null,
  author_username: "fah.readpost",
  author_display_name: "ฟ้า อ่านโพสต์",
  author_avatar_url: null,
  like_count: 12,
  liked_by_me: true,
};

const REPLY_COMMENT: DropCommentRow = {
  id: "comment-2",
  drop_id: "post-fixture-1",
  author_id: AUTHOR_ID,
  text_content: "ขอบคุณค่ะ ถ่ายตอนตีห้าเลย",
  created_at: new Date(Date.now() - 1 * 60 * 60 * 1000).toISOString(),
  parent_comment_id: "comment-1",
  author_username: "chompoo.wandee",
  author_display_name: "ชมพู่ วันดี",
  author_avatar_url: null,
  like_count: 3,
  liked_by_me: false,
};

const SECOND_COMMENT: DropCommentRow = {
  id: "comment-3",
  drop_id: "post-fixture-1",
  author_id: "55555555-5555-4555-8555-555555555555",
  text_content: "อยากไปเที่ยวที่นี้บ้างจัง แนะนำหน่อยได้ไหมคะ",
  created_at: new Date(Date.now() - 3 * 60 * 60 * 1000).toISOString(),
  parent_comment_id: null,
  author_username: "nan.travels",
  author_display_name: "น่าน เที่ยวไป",
  author_avatar_url: null,
  like_count: 0,
  liked_by_me: false,
};

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

export function PostDetailFixture() {
  const [liked, setLiked] = useState(true);
  const [saved, setSaved] = useState(false);
  const [redropped, setRedropped] = useState(false);
  const [draft, setDraft] = useState("");

  return (
    <div className="route-app route-without-bottom-nav">
      <main className="route-main">
        <div className="detail-floating-header">
          <WynosHeader
            leading={<WynosIconButton icon={<ChevronLeft size={24} />} aria-label="ย้อนกลับ" onClick={() => {}} />}
            center={<strong>โพสต์</strong>}
            trailing={<span className={pdStyles.headerTrailingSpacer} />}
          />
        </div>
        <article className="detail-post flutter-detail-post">
          <div className="detail-post-copy">
            <div className="detail-author-row">
              <Link className="route-drop-author detail-author-link" href={`/profile/${AUTHOR_ID}`}>
                <WynosAvatar src={null} label="chompoo.wandee" size={44} />
                <span className="detail-author-copy">
                  <span className="detail-author-primary">
                    <strong>
                      ชมพู่ วันดี<b className="route-verified">✓</b>
                    </strong>
                    <small>3 ชั่วโมงที่แล้ว</small>
                  </span>
                  <small className="detail-author-username">@chompoo.wandee</small>
                </span>
              </Link>
              <WynosPillButton className={pdStyles.followButton}>ติดตาม</WynosPillButton>
              <WynosIconButton tone="secondary" icon={<MoreHorizontal size={20} />} aria-label="เพิ่มเติม" onClick={() => {}} />
            </div>
            <Caption value="แสงเช้าของวันนี้สวยมากเลย ออกไปถ่ายรูปตั้งแต่ตีห้า #เชียงใหม่ #ภาพถ่าย" />
          </div>
          <MediaGallery urls={[fixtureImage("#dcd8cf", "Fixture Photo 1"), fixtureImage("#cfc9bc", "Fixture Photo 2")]} />
          <div className={`detail-post-actions ${pc.postActions}`}>
            <button className={`${pc.actionButton} ${liked ? pc.actionButtonLiked : ""}`} type="button" aria-label={liked ? "เลิกถูกใจ" : "ถูกใจ"} onClick={() => setLiked((value) => !value)}>
              <Heart size={24} fill={liked ? "currentColor" : "none"} />
              <span className={pc.actionButtonCount}>342</span>
            </button>
            <button className={pc.actionButton} type="button" aria-label="ความคิดเห็น">
              <MessageSquare size={24} />
              <span className={pc.actionButtonCount}>3</span>
            </button>
            <button className={`${pc.actionButton} ${redropped ? pc.actionButtonActive : ""}`} type="button" aria-label={redropped ? "ยกเลิกรีโพสต์" : "รีโพสต์"} onClick={() => setRedropped((value) => !value)}>
              <Repeat2 size={24} />
              <span className={pc.actionButtonCount}>6</span>
            </button>
            <button className={`${pc.actionButton} ${pc.actionShare}`} type="button" aria-label="แชร์โพสต์">
              <Send size={24} />
            </button>
            <button className={`${pc.actionButton} ${pc.actionShare} ${saved ? pc.actionButtonActive : ""}`} type="button" aria-label={saved ? "นำออกจากที่บันทึก" : "บันทึกโพสต์"} onClick={() => setSaved((value) => !value)}>
              <Bookmark size={24} fill={saved ? "currentColor" : "none"} />
            </button>
          </div>
          <button className="detail-activity-row" type="button">
            <span className="detail-activity-icon">
              <BarChart3 size={22} />
            </span>
            <strong>ดูกิจกรรม</strong>
            <ChevronRight size={27} />
          </button>
        </article>

        <section className="detail-comments flutter-detail-comments" aria-label="ความคิดเห็น">
          <div className="detail-thread">
            <CommentRow comment={TOP_COMMENT} isReply={false} currentUserId={AUTHOR_ID} onLike={() => {}} onReply={() => {}} onDelete={() => {}} />
            <CommentRow comment={REPLY_COMMENT} isReply currentUserId={AUTHOR_ID} onLike={() => {}} onReply={() => {}} onDelete={() => {}} />
          </div>
          <div className="detail-thread">
            <CommentRow comment={SECOND_COMMENT} isReply={false} currentUserId={AUTHOR_ID} onLike={() => {}} onReply={() => {}} onDelete={() => {}} />
          </div>
        </section>

        <div className="detail-composer-shell">
          <form className="detail-comment-form flutter-detail-composer" onSubmit={(event) => event.preventDefault()}>
            <WynosAvatar src={null} label="me" size={36} />
            <div className="flutter-detail-composer-field">
              <input value={draft} onChange={(event) => setDraft(event.target.value)} maxLength={500} placeholder="แสดงความคิดเห็น..." />
              <button type="submit" aria-label="ส่งความคิดเห็น" disabled={!draft.trim()}>
                <Send size={25} />
              </button>
            </div>
          </form>
        </div>
      </main>
    </div>
  );
}
