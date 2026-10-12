"use client";

import { MessageSquareText, RefreshCw, Star } from "lucide-react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { useCallback, useEffect, useMemo, useState } from "react";
import type { FoodStore } from "@/lib/food-merchant";
import {
  fetchMerchantStaff, fetchMerchantStoreReviews, replyMerchantStoreReview,
  type MerchantStoreReview, type MerchantStoreReviewFeed,
} from "@/lib/merchant-core";

function reviewDate(value: string) {
  return new Intl.DateTimeFormat("th-TH", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value));
}

function Stars({ rating }: { rating: number }) {
  return <span className="wm-review-stars" aria-label={`${rating} จาก 5 ดาว`}>
    {[1, 2, 3, 4, 5].map((star) => <Star key={star} size={16} strokeWidth={1.8} fill={star <= Math.round(rating) ? "currentColor" : "none"} />)}
  </span>;
}

/** Dedicated feedback screen; reads the same verified, access-controlled customer reviews as Store Tools. */
export function MerchantFeedbackPanel({ client, store, userId, onMessage }: {
  client: SupabaseClient;
  store: FoodStore;
  userId: string;
  onMessage: (message: string) => void;
}) {
  const [feed, setFeed] = useState<MerchantStoreReviewFeed | null>(null);
  const [canReply, setCanReply] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [onlyUnanswered, setOnlyUnanswered] = useState(false);
  const [replyId, setReplyId] = useState<string | null>(null);
  const [draft, setDraft] = useState("");
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const [reviews, members] = await Promise.all([
        fetchMerchantStoreReviews(client, store.id, 100),
        fetchMerchantStaff(client, store.id),
      ]);
      if (!reviews) {
        setFeed(null);
        setError("ระบบรีวิวของร้านยังไม่พร้อมใช้งาน");
        return;
      }
      setFeed(reviews);
      const member = members.find((row) => row.user_id === userId && row.active);
      setCanReply(member?.role === "owner" || member?.role === "admin" || member?.role === "manager");
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "โหลดฟีดแบ็กไม่สำเร็จ");
    } finally {
      setLoading(false);
    }
  }, [client, store.id, userId]);

  useEffect(() => {
    const id = window.setTimeout(() => void load(), 0);
    return () => window.clearTimeout(id);
  }, [load]);

  const reviews = useMemo(() => (feed?.reviews ?? []).filter((review) => !onlyUnanswered || !review.merchant_reply), [feed, onlyUnanswered]);
  const startReply = (review: MerchantStoreReview) => {
    setReplyId(review.id);
    setDraft(review.merchant_reply ?? "");
  };
  const saveReply = async (review: MerchantStoreReview) => {
    if (!canReply || saving || !draft.trim()) return;
    setSaving(true);
    try {
      await replyMerchantStoreReview(client, review.id, draft);
      onMessage(review.merchant_reply ? "แก้ไขคำตอบแล้ว" : "ตอบกลับลูกค้าแล้ว");
      setReplyId(null);
      setDraft("");
      await load();
    } catch (reason) {
      onMessage(reason instanceof Error ? reason.message : "ส่งคำตอบไม่สำเร็จ");
    } finally {
      setSaving(false);
    }
  };

  return (
    <>
      <div className="wm-page-heading"><div><small>ความคิดเห็นจากลูกค้า WYNOS Food ที่สั่งจริง</small><h1>ฟีดแบ็ก</h1></div></div>
      <section className="wm-feedback-summary">
        <div><MessageSquareText size={23} /><strong>{feed ? feed.count : "–"}</strong><small>รีวิวทั้งหมด</small></div>
        <div><Star size={23} /><strong>{feed?.count ? feed.average.toFixed(1) : "–"}</strong><small>คะแนนเฉลี่ย / 5</small></div>
        <div><MessageSquareText size={23} /><strong>{feed ? feed.unanswered : "–"}</strong><small>รอตอบกลับ</small></div>
      </section>
      <div className="wm-feedback-toolbar">
        <div role="group" aria-label="กรองรีวิว">
          <button className={!onlyUnanswered ? "is-active" : ""} type="button" aria-pressed={!onlyUnanswered} onClick={() => setOnlyUnanswered(false)}>ทั้งหมด</button>
          <button className={onlyUnanswered ? "is-active" : ""} type="button" aria-pressed={onlyUnanswered} onClick={() => setOnlyUnanswered(true)}>รอตอบ</button>
        </div>
        <button type="button" aria-label="โหลดรีวิวใหม่" disabled={loading} onClick={() => void load()}><RefreshCw size={17} /> รีเฟรช</button>
      </div>
      {error ? <div className="wm-history-error" role="alert">{error} <button type="button" onClick={() => void load()}>ลองอีกครั้ง</button></div> : null}
      {loading && !feed ? <div className="wm-history-state">กำลังโหลดฟีดแบ็ก…</div> : null}
      {!loading && !error && reviews.length === 0 ? (
        <div className="wm-empty"><MessageSquareText size={36} strokeWidth={1.5} /><strong>{onlyUnanswered ? "ไม่มีรีวิวรอตอบ" : "ยังไม่มีรีวิวจากลูกค้า"}</strong><p>รีวิวจากคำสั่งซื้อที่ส่งสำเร็จจะแสดงที่นี่</p></div>
      ) : null}
      {reviews.length ? (
        <div className="wm-review-list wm-feedback-list">
          {reviews.map((review) => (
            <article className="wm-review-card" key={review.id}>
              <div className="wm-review-card-head">
                <span><strong>{review.reviewer_label}</strong><small>สั่งจริงกับ WYNOS Food · {reviewDate(review.created_at)}</small></span>
                <Stars rating={review.rating} />
              </div>
              {review.review_text ? <p>{review.review_text}</p> : null}
              {review.tags.length ? <div className="wm-review-tags">{review.tags.map((tag) => <span key={tag}>{tag}</span>)}</div> : null}
              {review.merchant_reply ? <div className="wm-review-existing-reply"><strong>คำตอบของร้าน</strong><p>{review.merchant_reply}</p>{review.merchant_replied_at ? <small>{reviewDate(review.merchant_replied_at)}</small> : null}</div> : null}
              {canReply ? (replyId === review.id ? (
                <div className="wm-review-reply-form">
                  <label>คำตอบของร้าน
                    <textarea maxLength={500} value={draft} onChange={(event) => setDraft(event.target.value)} placeholder="ขอบคุณลูกค้า หรือชี้แจงอย่างสุภาพ" />
                  </label>
                  <div>
                    <button className="wm-text-button" type="button" disabled={saving} onClick={() => { setReplyId(null); setDraft(""); }}>ยกเลิก</button>
                    <button className="wm-small-primary" type="button" disabled={saving || !draft.trim()} onClick={() => void saveReply(review)}>{saving ? "กำลังส่ง…" : "บันทึกคำตอบ"}</button>
                  </div>
                </div>
              ) : <button className="wm-review-reply-button" type="button" onClick={() => startReply(review)}>{review.merchant_reply ? "แก้ไขคำตอบ" : "ตอบกลับรีวิว"}</button>) : null}
            </article>
          ))}
        </div>
      ) : null}
      {feed && feed.count > feed.reviews.length ? <p className="wm-history-count">กำลังแสดงรีวิวล่าสุด {feed.reviews.length} รายการ จากทั้งหมด {feed.count} รายการ</p> : null}
    </>
  );
}
