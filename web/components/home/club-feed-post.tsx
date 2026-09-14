import { Heart, MessageSquare } from "lucide-react";
import Link from "next/link";

import { Avatar } from "@/components/phase3-ui";
import { RichPostText } from "@/components/rich-post-text";
import { relativeTimeTh } from "@/lib/feed";
import type { ClubHomePost } from "@/lib/home-parity-data";

/** Home's "คลับของฉัน" tab card — same card geometry as HomePostCard,
 * minus ReDrop/Share/Follow, which the club feed doesn't have. */
export function ClubFeedPost({ post, onLike }: { post: ClubHomePost; onLike: () => void }) {
  const profileHref = `/profile/${post.author_id}`;
  const name = post.author_display_name?.trim() || post.author_username || "WYNOS";

  return (
    <article className="wyn-post">
      <Link className="wyn-post-avatar" href={profileHref}>
        <Avatar src={post.author_avatar_url} label={post.author_username || "WYNOS"} size={44} />
      </Link>
      <div className="wyn-post-body">
        <header className="wyn-post-author-row">
          <Link className="wyn-post-author-link" href={profileHref}>
            <strong className="wyn-post-author-name">{name}</strong>
            <small className="wyn-post-timestamp">{relativeTimeTh(post.created_at)}</small>
          </Link>
        </header>
        {post.content ? (
          <RichPostText className="wyn-post-caption" value={post.content} postHref={`/club-post/${post.id}`} compact />
        ) : null}
        {post.image_urls.length ? (
          <div className={`wyn-post-media-track ${post.image_urls.length === 1 ? "is-single" : ""}`}>
            {post.image_urls.map((url, index) => (
              // eslint-disable-next-line @next/next/no-img-element
              <img className="wyn-post-media-item" src={url} alt="" loading="lazy" decoding="async" key={`${post.id}:${index}`} />
            ))}
          </div>
        ) : null}
        <div className="wyn-post-actions">
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
