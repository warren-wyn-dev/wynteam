import { Heart, MessageSquare } from "lucide-react";
import Link from "next/link";

import { Avatar } from "@/components/phase3-ui";
import { RichPostText } from "@/components/rich-post-text";
import { relativeTimeTh } from "@/lib/feed";
import type { ClubHomePost } from "@/lib/home-parity-data";

/** Home's "คลับของฉัน" tab card using the same X + Threads-inspired
 * composition as normal Home posts, while keeping Club-specific actions. */
export function ClubFeedPost({ post, onLike }: { post: ClubHomePost; onLike: () => void }) {
  const profileHref = `/profile/${post.author_id}`;
  const name = post.author_display_name?.trim() || post.author_username || "WYNOS";
  const handle = post.author_username?.trim().replace(/^@/, "");

  return (
    <article
      className="wyn-post"
      style={{
        padding: "12px 16px 0",
        gridTemplateColumns: "44px minmax(0, 1fr)",
        columnGap: 10,
      }}
    >
      <Link className="wyn-post-avatar" href={profileHref} style={{ marginTop: 0 }}>
        <Avatar src={post.author_avatar_url} label={post.author_username || "WYNOS"} size={44} />
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
              style={{ flex: "0 1 auto", fontSize: 16, lineHeight: 1.25, fontWeight: 700 }}
            >
              {name}
            </strong>
            {handle ? (
              <span
                style={{
                  minWidth: 0,
                  overflow: "hidden",
                  textOverflow: "ellipsis",
                  whiteSpace: "nowrap",
                  color: "var(--wyn-text-muted)",
                  fontSize: 14,
                  lineHeight: 1.2,
                }}
              >
                @{handle}
              </span>
            ) : null}
            <small
              className="wyn-post-timestamp"
              style={{ maxWidth: 104, fontSize: 14, lineHeight: 1.2, flex: "0 0 auto" }}
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
              margin: "3px 0 0",
              transform: "none",
              fontSize: 16,
              lineHeight: 1.4,
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
              // eslint-disable-next-line @next/next/no-img-element
              <img className="wyn-post-media-item" src={url} alt="" loading="lazy" decoding="async" key={`${post.id}:${index}`} />
            ))}
          </div>
        ) : null}
        <div
          className="wyn-post-actions"
          style={{
            margin: "8px 0 12px",
            width: "100%",
            gap: 22,
          }}
        >
          <button
            className={`wyn-action-button ${post.liked_by_me ? "is-liked" : ""}`}
            type="button"
            aria-label={post.liked_by_me ? "เลิกถูกใจ" : "ถูกใจ"}
            onClick={onLike}
          >
            <Heart size={24} fill={post.liked_by_me ? "currentColor" : "none"} />
            <span className="wyn-action-button-count">{post.like_count}</span>
          </button>
          <Link className="wyn-action-button" href={`/club-post/${post.id}`} aria-label="ความคิดเห็น">
            <MessageSquare size={24} />
            <span className="wyn-action-button-count">{post.comment_count}</span>
          </Link>
        </div>
      </div>
    </article>
  );
}
