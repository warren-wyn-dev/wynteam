import Link from "next/link";

import { PostActions } from "@/components/home/post-actions";
import { PostAuthorRow } from "@/components/home/post-author-row";
import { PostMediaCarousel } from "@/components/home/post-media-carousel";
import { Avatar } from "@/components/phase3-ui";
import { WynosIcon } from "@/components/ui/wynos-icon";
import { RichPostText } from "@/components/rich-post-text";
import { authorLabel, postMediaAspectRatio, relativeTimeTh, type HomeFeedRow } from "@/lib/feed";
import type { HomeViewerState } from "@/lib/home-actions";

function splitHomeCaption(value: string) {
  const lines = value.trim().split(/\r?\n/);
  let tagStart = lines.length;
  while (tagStart > 0) {
    const line = lines[tagStart - 1].trim();
    if (!line) {
      if (tagStart < lines.length) {
        tagStart -= 1;
        continue;
      }
      break;
    }
    if (line.startsWith("#")) {
      tagStart -= 1;
      continue;
    }
    break;
  }

  const prose = lines.slice(0, tagStart).join("\n").trimEnd().replace(/\n{3,}/g, "\n\n");
  const tags = lines.slice(tagStart).join("\n").trim();
  const chars = Array.from(prose);
  const truncated = chars.length > 190;
  const visibleProse = truncated ? chars.slice(0, 220).join("").trimEnd() : prose;
  return { visibleProse, tags, truncated };
}

/**
 * One Home feed card. Business logic stays in HomeScreen while the visual
 * composition follows the approved compact Threads-inspired WYNOS mockup.
 */
export function HomePostCard({
  row,
  viewer,
  images,
  userId,
  onLike,
  onMore,
  onRedrop,
  onFollow,
  onShare,
  onSave,
  priority = false,
}: {
  row: HomeFeedRow;
  viewer: HomeViewerState;
  images: string[];
  userId: string;
  onLike: () => void;
  onMore: () => void;
  onRedrop: () => void;
  onFollow: () => void;
  onShare: () => void;
  onSave: () => void;
  priority?: boolean;
}) {
  const liked = viewer.likedDropIds.has(row.id);
  const saved = viewer.savedDropIds.has(row.id);
  const redropped = viewer.redroppedDropIds.has(row.id);
  const following = viewer.followedAuthorIds.has(row.author_id);
  const requested = viewer.pendingFollowAuthorIds.has(row.author_id);
  const canRedrop = row.audience == null || row.audience === "everyone";
  const time = relativeTimeTh(row.created_at);
  const timeAndLocation = row.location ? `${time} · 📍 ${row.location}` : time;
  const profileHref = `/profile/${row.author_id}`;
  const caption = row.caption ? splitHomeCaption(row.caption) : null;

  return (
    <article
      className={`wyn-post ${row.redrop_id ? "has-redrop" : ""}`}
      style={{ paddingTop: row.redrop_id ? 10 : 8 }}
    >
      {row.redrop_id ? (
        <div className="wyn-post-redrop-line">
          <WynosIcon name="repost" size={16} strokeWidth={2} />
          รีโพสต์โดย {row.redropper_username || "WYNOS"} · {time}
        </div>
      ) : null}
      {row.quote_text ? <RichPostText className="wyn-post-quote" value={row.quote_text} /> : null}
      <Link className="wyn-post-avatar" href={profileHref}>
        <Avatar src={row.author_avatar_url} label={row.author_username || "WYNOS"} size={40} />
      </Link>
      <div className="wyn-post-body">
        <PostAuthorRow
          profileHref={profileHref}
          name={authorLabel(row)}
          verified={Boolean(row.author_is_verified)}
          timeLabel={timeAndLocation}
          showFollow={row.author_id !== userId}
          following={following}
          followRequested={requested}
          onFollow={onFollow}
          onMore={onMore}
        />
        {caption ? (
          <div className="wyn-post-caption-wrap">
            {caption.visibleProse ? (
              <RichPostText
                className="wyn-post-caption"
                value={caption.visibleProse}
                postHref={`/drop/${row.id}`}
                compact
              />
            ) : null}
            {caption.truncated ? (
              <>
                {caption.tags ? (
                  <RichPostText
                    className="wyn-post-caption wyn-post-caption-tags is-inline"
                    value={caption.tags}
                    postHref={`/drop/${row.id}`}
                    compact
                  />
                ) : null}
                <Link className="wyn-post-more-text" href={`/drop/${row.id}`}>… ดูเพิ่มเติม</Link>
              </>
            ) : caption.tags ? (
              <RichPostText
                className="wyn-post-caption wyn-post-caption-tags"
                value={caption.tags}
                postHref={`/drop/${row.id}`}
                compact
              />
            ) : null}
          </div>
        ) : null}
        <PostMediaCarousel
          urls={images}
          aspectRatio={postMediaAspectRatio(row, images.length > 1)}
          liked={liked}
          onDoubleLike={onLike}
          postKey={row.id}
          modernFeed
          priority={priority}
        />
        <PostActions
          liked={liked}
          likeCount={row.like_count ?? 0}
          commentCount={row.comment_count ?? 0}
          canRedrop={canRedrop}
          redropped={redropped}
          redropCount={row.redrop_count ?? 0}
          saved={saved}
          onLike={onLike}
          commentHref={`/drop/${row.id}#comments`}
          onRedrop={onRedrop}
          onShare={onShare}
          onSave={onSave}
          modernFeed
        />
      </div>
    </article>
  );
}
