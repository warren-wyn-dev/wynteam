/* eslint-disable @next/next/no-img-element */
"use client";

import type { SupabaseClient } from "@supabase/supabase-js";
import {
  Bookmark,
  CheckCircle2,
  Flag,
  Heart,
  Link as LinkIcon,
  MessageCircle,
  MoreVertical,
  Pin,
  Share2,
  Trash2,
} from "lucide-react";
import Link from "next/link";
import { useRef, useState, type PointerEvent } from "react";

import { Avatar } from "@/components/phase3-ui";
import { relativeTimeTh } from "@/lib/feed";
import {
  deleteClubPost,
  toggleClubPostLike,
  toggleClubPostPin,
  toggleClubPostSave,
  voteClubPostPoll,
  type ClubHomePost,
} from "@/lib/home-parity-data";

function DoubleTapZone({
  liked,
  onLike,
  children,
}: {
  liked: boolean;
  onLike: () => void;
  children: React.ReactNode;
}) {
  const lastTap = useRef(0);
  const pointerUp = (event: PointerEvent<HTMLDivElement>) => {
    if (event.pointerType === "mouse") return;
    const now = Date.now();
    if (now - lastTap.current <= 300) {
      lastTap.current = 0;
      if (!liked) onLike();
    } else {
      lastTap.current = now;
    }
  };
  return <div onDoubleClick={() => { if (!liked) onLike(); }} onPointerUp={pointerUp}>{children}</div>;
}

function pollRemaining(expiresAt: string): { closed: boolean; label: string } {
  const end = new Date(expiresAt).getTime();
  const remaining = end - Date.now();
  if (!Number.isFinite(end) || remaining <= 0) return { closed: true, label: "โพลปิดแล้ว" };
  const days = Math.floor(remaining / 86_400_000);
  if (days >= 1) return { closed: false, label: `เหลืออีก ${days} วัน` };
  const hours = Math.floor(remaining / 3_600_000);
  if (hours >= 1) return { closed: false, label: `เหลืออีก ${hours} ชม.` };
  const minutes = Math.max(1, Math.min(59, Math.floor(remaining / 60_000)));
  return { closed: false, label: `เหลืออีก ${minutes} นาที` };
}

function optimisticVote(post: ClubHomePost, optionIndex: number): ClubHomePost {
  const options = post.poll_options ?? [];
  const previous = post.poll_my_vote_index ?? null;
  const counts = [...(post.poll_option_counts ?? Array.from({ length: options.length }, () => 0))];
  if (previous != null && previous < counts.length) counts[previous] = Math.max(0, counts[previous] - 1);
  if (optionIndex < counts.length) counts[optionIndex] = (counts[optionIndex] ?? 0) + 1;
  return {
    ...post,
    poll_my_vote_index: optionIndex,
    poll_total_votes: previous == null ? (post.poll_total_votes ?? 0) + 1 : post.poll_total_votes ?? 1,
    poll_option_counts: counts,
  };
}

function ClubPoll({ post, viewerUserId, onVote }: { post: ClubHomePost; viewerUserId: string; onVote: (index: number) => void }) {
  if (!post.poll_id || !post.poll_options || !post.poll_expires_at) return null;
  const timing = pollRemaining(post.poll_expires_at);
  const resultsVisible = post.poll_total_votes != null;
  const own = post.poll_my_vote_index;
  const total = post.poll_total_votes ?? 0;
  const canVote = post.author_id !== viewerUserId && !timing.closed;
  const status = resultsVisible
    ? `${total === 0 ? "ยังไม่มีใครโหวต" : `${total} โหวต`} · ${timing.label}`
    : timing.label;

  return (
    <div className="web-club-poll">
      {post.poll_options.map((option, index) => {
        const percent = resultsVisible && total > 0
          ? Math.round((((post.poll_option_counts ?? [])[index] ?? 0) / total) * 100)
          : resultsVisible ? 0 : null;
        const mine = own === index;
        return (
          <button
            className={`web-club-poll-option ${mine ? "mine" : ""}`}
            type="button"
            disabled={!canVote}
            onClick={() => onVote(index)}
            key={`${post.poll_id}:${index}`}
          >
            {percent != null ? <span className="web-club-poll-fill" style={{ width: `${percent}%` }} /> : null}
            <span className="web-club-poll-copy">
              {mine ? <CheckCircle2 size={16} /> : null}
              <span>{option}</span>
              {percent != null ? <b>{percent}%</b> : null}
            </span>
          </button>
        );
      })}
      <small>{status}</small>
    </div>
  );
}

type CardProps = {
  client: SupabaseClient;
  userId: string;
  post: ClubHomePost;
  onChange?: (post: ClubHomePost) => void;
  onDeleted?: (postId: string) => void;
};

export function ClubPostCardWeb({ client, userId, post: initialPost, onChange, onDeleted }: CardProps) {
  const [post, setPost] = useState(initialPost);
  const [menuOpen, setMenuOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const isOwn = post.author_id === userId;
  const canModerate = ["owner", "admin", "moderator"].includes(post.my_role ?? "");

  const commit = (next: ClubHomePost) => {
    setPost(next);
    onChange?.(next);
  };

  const like = async () => {
    if (busy) return;
    const before = post;
    const next = {
      ...post,
      liked_by_me: !post.liked_by_me,
      like_count: Math.max(0, post.like_count + (post.liked_by_me ? -1 : 1)),
    };
    commit(next);
    try {
      await toggleClubPostLike(client, userId, before.id, before.liked_by_me);
    } catch {
      commit(before);
    }
  };

  const save = async () => {
    if (busy) return;
    const before = post;
    const next = { ...post, saved_by_me: !post.saved_by_me };
    commit(next);
    setMenuOpen(false);
    try {
      await toggleClubPostSave(client, userId, before.id, before.saved_by_me);
    } catch {
      commit(before);
    }
  };

  const share = async () => {
    const url = `${window.location.origin}/club-post/${post.id}`;
    setMenuOpen(false);
    try {
      if (navigator.share) await navigator.share({ title: post.author_display_name?.trim() || post.author_username || "WYNOS", text: post.content || "WYNOS Club", url });
      else await navigator.clipboard.writeText(url);
    } catch {
      // Native share cancellation is not an application error.
    }
  };

  const remove = async () => {
    if (busy || !window.confirm("ลบโพสต์นี้?\nลบแล้วไม่สามารถกู้คืนได้")) return;
    setBusy(true); setError("");
    try {
      await deleteClubPost(client, post.id);
      setMenuOpen(false);
      onDeleted?.(post.id);
    } catch {
      setError("ลบโพสต์ไม่สำเร็จ ลองใหม่อีกครั้ง");
    } finally {
      setBusy(false);
    }
  };

  const pin = async () => {
    if (busy) return;
    const before = post;
    const next = { ...post, pinned: !post.pinned };
    commit(next);
    setMenuOpen(false);
    try {
      await toggleClubPostPin(client, post.id, before.pinned);
    } catch {
      commit(before);
    }
  };

  const report = async () => {
    if (busy) return;
    setBusy(true); setError("");
    const result = await client.rpc("submit_report", {
      p_target_type: "club_post",
      p_target_id: post.id,
      p_category: "other",
      p_detail: "รายงานจากเมนูโพสต์ Club",
    });
    if (result.error) setError(result.error.message || "ส่งรายงานไม่สำเร็จ");
    else setMenuOpen(false);
    setBusy(false);
  };

  const vote = async (index: number) => {
    if (!post.poll_id || busy) return;
    const before = post;
    commit(optimisticVote(post, index));
    try {
      await voteClubPostPoll(client, userId, post.poll_id, index);
    } catch {
      commit(before);
    }
  };

  const name = post.author_display_name?.trim() || post.author_username || "WYNOS";
  const hasImages = post.image_urls.length > 0;

  return (
    <article className="web-club-post-card">
      <Link className="web-club-post-avatar" href={`/profile/${post.author_id}`}>
        <Avatar src={post.author_avatar_url} label={post.author_username || name} size={42} />
      </Link>
      <div className="web-club-post-content">
        <header>
          <Link href={`/profile/${post.author_id}`} className="web-club-post-author">
            <strong>{name}</strong>
            <small>{relativeTimeTh(post.created_at)}</small>
          </Link>
          <button type="button" className="web-club-post-more" aria-label="เพิ่มเติม" onClick={() => setMenuOpen(true)}>
            <MoreVertical size={22} />
          </button>
        </header>

        {post.content ? (
          <DoubleTapZone liked={post.liked_by_me} onLike={() => void like()}>
            <Link href={`/club-post/${post.id}`} className="web-club-post-open"><p>{post.content}</p></Link>
          </DoubleTapZone>
        ) : null}

        {hasImages ? (
          <DoubleTapZone liked={post.liked_by_me} onLike={() => void like()}>
            <div className={`web-club-post-images ${post.image_urls.length === 1 ? "single" : ""}`}>
              {post.image_urls.map((url, index) => <img src={url} alt="" loading="lazy" decoding="async" key={`${post.id}:${index}`} />)}
            </div>
          </DoubleTapZone>
        ) : null}

        <ClubPoll post={post} viewerUserId={userId} onVote={(index) => void vote(index)} />

        {post.link_url ? (
          <a className="web-club-post-link" href={post.link_url} target="_blank" rel="noreferrer">
            <LinkIcon size={16} /><span>{post.link_url}</span>
          </a>
        ) : null}

        <div className="web-club-post-actions">
          <button className={post.liked_by_me ? "liked" : ""} type="button" aria-label={post.liked_by_me ? "เลิกถูกใจ" : "ถูกใจ"} onClick={() => void like()}>
            <Heart size={17} fill={post.liked_by_me ? "currentColor" : "none"} /><span>{post.like_count}</span>
          </button>
          <Link href={`/club-post/${post.id}`} aria-label="ดูคอมเมนต์">
            <MessageCircle size={17} /><span>{post.comment_count}</span>
          </Link>
        </div>
        {error ? <p className="route-error web-club-post-error">{error}</p> : null}
      </div>

      {menuOpen ? (
        <div className="route-modal-backdrop audit-sheet-backdrop" role="presentation" onClick={() => setMenuOpen(false)}>
          <section className="audit-action-sheet" role="dialog" aria-modal="true" aria-label="ตัวเลือกโพสต์ Club" onClick={(event) => event.stopPropagation()}>
            <div className="audit-sheet-grip" />
            <button className="audit-sheet-row" type="button" onClick={() => void share()}><Share2 size={20} />แชร์</button>
            <button className="audit-sheet-row" type="button" onClick={() => void save()}><Bookmark size={20} fill={post.saved_by_me ? "currentColor" : "none"} />{post.saved_by_me ? "เอาออกจากบันทึก" : "บันทึก"}</button>
            {isOwn || canModerate ? <button className="audit-sheet-row" type="button" disabled={busy} onClick={() => void remove()}><Trash2 size={20} />ลบโพสต์</button> : null}
            {!isOwn && canModerate ? <button className="audit-sheet-row" type="button" disabled={busy} onClick={() => void pin()}><Pin size={20} fill={post.pinned ? "currentColor" : "none"} />{post.pinned ? "เลิกปักหมุด" : "ปักหมุด"}</button> : null}
            {!isOwn ? <button className="audit-sheet-row" type="button" disabled={busy} onClick={() => void report()}><Flag size={20} />รายงานโพสต์</button> : null}
          </section>
        </div>
      ) : null}
    </article>
  );
}
