import { Heart, MessageSquare } from "lucide-react";
import Link from "next/link";

import pc from "@/components/design-system/post-card.module.css";
import { WynosAvatar } from "@/components/design-system/WynosAvatar";
import { RichPostText } from "@/components/rich-post-text";
import { relativeTimeTh } from "@/lib/feed";
import type { ClubHomePost } from "@/lib/home-parity-data";

/** Home's "คลับของฉัน" tab card — same card geometry as HomePostCard
 * (shares `post-card.module.css`), minus ReDrop/Share/Follow, which the
 * club feed doesn't have. */
export function ClubFeedPost({ post, onLike }: { post: ClubHomePost; onLike: () => void }) {
  const profileHref = `/profile/${post.author_id}`;
  const name = post.author_display_name?.trim() || post.author_username || "WYNOS";

  return (
    <article className={pc.post}>
      <div className={pc.postRow}>
        <Link className={pc.postAvatar} href={profileHref}>
          <WynosAvatar src={post.author_avatar_url} label={post.author_username || "WYNOS"} size="feed" />
        </Link>
        <div className={pc.postBody}>
          <header className={pc.postAuthorRow}>
            <Link className={pc.postAuthorLink} href={profileHref}>
              <strong className={pc.postAuthorName}>{name}</strong>
              <small className={pc.postTimestamp}>· {relativeTimeTh(post.created_at)}</small>
            </Link>
          </header>
          {post.content ? (
            <RichPostText className={pc.postCaption} value={post.content} postHref={`/club-post/${post.id}`} compact />
          ) : null}
          {post.image_urls.length ? (
            <div className={`${pc.mediaTrack} ${post.image_urls.length === 1 ? pc.mediaTrackSingle : ""}`}>
              {post.image_urls.map((url, index) => (
                // eslint-disable-next-line @next/next/no-img-element
                <img className={pc.mediaItem} src={url} alt="" loading="lazy" decoding="async" key={`${post.id}:${index}`} />
              ))}
            </div>
          ) : null}
          <div className={pc.postActions}>
            <button
              className={`${pc.actionButton} ${post.liked_by_me ? pc.actionButtonLiked : ""}`}
              type="button"
              aria-label={post.liked_by_me ? "เลิกถูกใจ" : "ถูกใจ"}
              onClick={onLike}
            >
              <Heart size={24} fill={post.liked_by_me ? "currentColor" : "none"} />
              <span className={pc.actionButtonCount}>{post.like_count}</span>
            </button>
            <Link className={pc.actionButton} href={`/club-post/${post.id}`} aria-label="ความคิดเห็น">
              <MessageSquare size={24} />
              <span className={pc.actionButtonCount}>{post.comment_count}</span>
            </Link>
          </div>
        </div>
      </div>
    </article>
  );
}
