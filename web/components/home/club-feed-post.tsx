import { Heart, MessageCircle } from "lucide-react";
import Image from "next/image";
import Link from "next/link";

import { Avatar } from "@/components/phase3-ui";
import { AnimatedCount } from "@/components/ui/animated-count";
import { RichPostText } from "@/components/rich-post-text";
import { relativeTimeTh } from "@/lib/feed";
import type { ClubHomePost } from "@/lib/home-parity-data";

/** Home's "คลับของฉัน" tab card using the same X + Threads-inspired
 * composition as normal Home posts, while keeping Club-specific actions. */
export function ClubFeedPost({ post, onLike }: { post: ClubHomePost; onLike: () => void }) {
  const profileHref = `/profile/${post.author_id}`;
  const name = post.author_display_name?.trim() || post.author_username || "WYNOS";

  return (
    <article className="wyn-post" style={{ paddingTop: 9 }}>
      <Link className="wyn-post-avatar" href={profileHref}>
        <Avatar src={post.author_avatar_url} label={post.author_username || "WYNOS"} size={40} />
      </Link>
      <div className="wyn-post-body">
        <header
          className="wyn-post-author-row"
          style={{ minHeight: 24, marginRight: 0, gap: 4, alignItems: "center" }}
        >
          <Link
            className="wyn-post-author-link"
            href={profileHref}
            style={{ gap: 4, alignItems: "center", overflow: "hidden" }}
          >
            <strong
              className="wyn-post-author-name"
              style={{ flex: "0 1 auto", fontSize: 14, lineHeight: 1.3, fontWeight: 600 }}
            >
              {name}
            </strong>
            <small
              className="wyn-post-timestamp"
              style={{ maxWidth: 96, fontSize: 13.5, lineHeight: 1.2, flex: "0 0 auto" }}
            >
              · {relativeTimeTh(post.created_at)}
            </small>
          </Link>
        </header>
        {post.content ? (
          <RichPostText
            className="wyn-post-caption"
            value={post.content}
            postHref={`/club-post/${post.id}`}
            compact
            style={{
              margin: "6px 0 0",
              transform: "none",
              fontSize: 15,
              lineHeight: 1.5,
              fontWeight: 400,
            }}
          />
        ) : null}
        {post.image_urls.length ? (
          <div
            className={`wyn-post-media-track ${post.image_urls.length === 1 ? "is-single" : ""}`}
            style={{
              marginTop: 8,
              ...(post.image_urls.length === 1 ? { paddingRight: 0 } : {}),
            }}
          >
            {post.image_urls.map((url, index) => (
              <Image
                className="wyn-post-media-item"
                src={url}
                alt=""
                width={1200}
                height={1500}
                style={{ width: "100%", height: "auto" }}
                sizes="(max-width: 640px) 100vw, 640px"
                loading="lazy"
                key={`${post.id}:${index}`}
              />
            ))}
          </div>
        ) : null}
        <div className="wyn-post-actions wyn-threads-actions">
          <button
            className={`wyn-action-button ${post.liked_by_me ? "is-liked" : ""}`}
            type="button"
            aria-label={post.liked_by_me ? "เลิกถูกใจ" : "ถูกใจ"}
            onClick={onLike}
          >
            <Heart size={20} strokeWidth={2} fill={post.liked_by_me ? "currentColor" : "none"} />
            <AnimatedCount className="wyn-action-button-count" value={post.like_count} hideZero />
          </button>
          <Link className="wyn-action-button" href={`/club-post/${post.id}`} aria-label="ความคิดเห็น">
            <MessageCircle size={20} strokeWidth={2} />
            <AnimatedCount className="wyn-action-button-count" value={post.comment_count} hideZero />
          </Link>
        </div>
      </div>
    </article>
  );
}
