"use client";

import type { ReactNode } from "react";

import { Avatar } from "@/components/ui/avatar";
import { WynosIcon } from "@/components/ui/wynos-icon";

export type PostCardProps = {
  authorName: string;
  timeLabel: string;
  text?: string;
  avatarSrc?: string | null;
  avatarFallback?: string;
  media?: ReactNode;
  liked?: boolean;
  likeCount?: number | string;
  commentCount?: number | string;
  repostCount?: number | string;
  onLike?: () => void;
  onComment?: () => void;
  onRepost?: () => void;
  className?: string;
};

function actionText(label: string, count?: number | string) {
  return count === undefined || count === "" ? label : `${label} ${count}`;
}

export function PostCard({
  authorName,
  timeLabel,
  text,
  avatarSrc,
  avatarFallback,
  media,
  liked = false,
  likeCount,
  commentCount,
  repostCount,
  onLike,
  onComment,
  onRepost,
  className,
}: PostCardProps) {
  return (
    <article className={["wyn-post-card", className ?? ""].filter(Boolean).join(" ")}>
      <header className="wyn-post-card__header">
        <Avatar
          alt={`รูปโปรไฟล์ของ ${authorName}`}
          fallback={avatarFallback ?? authorName}
          size={42}
          src={avatarSrc}
          variant="person"
        />
        <div className="wyn-post-card__meta">
          <span className="wyn-post-card__author">{authorName}</span>
          <time className="wyn-post-card__time">{timeLabel}</time>
        </div>
      </header>

      {text ? <p className="wyn-post-card__text">{text}</p> : null}
      {media ? <div className="wyn-post-card__media">{media}</div> : null}

      <div className="wyn-post-card__actions" aria-label="การทำงานกับโพสต์">
        <button
          aria-label={liked ? "ยกเลิกถูกใจ" : "ถูกใจ"}
          aria-pressed={liked}
          className={`wyn-post-action${liked ? " wyn-post-action--liked" : ""}`}
          onClick={onLike}
          type="button"
        >
          <WynosIcon name="like" size={19} />
          <span>{actionText("ถูกใจ", likeCount)}</span>
        </button>
        <button aria-label="แสดงความคิดเห็น" className="wyn-post-action" onClick={onComment} type="button">
          <WynosIcon name="comment" size={19} />
          <span>{actionText("คอมเมนต์", commentCount)}</span>
        </button>
        <button aria-label="รีโพสต์" className="wyn-post-action" onClick={onRepost} type="button">
          <WynosIcon name="repost" size={19} />
          <span>{actionText("รีโพสต์", repostCount)}</span>
        </button>
      </div>
    </article>
  );
}
