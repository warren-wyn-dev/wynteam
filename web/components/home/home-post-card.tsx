import { Repeat2 } from "lucide-react";
import Link from "next/link";

import pc from "@/components/design-system/post-card.module.css";
import { WynosAvatar } from "@/components/design-system/WynosAvatar";
import { PostActions } from "@/components/home/post-actions";
import { PostAuthorRow } from "@/components/home/post-author-row";
import { PostMediaCarousel } from "@/components/home/post-media-carousel";
import { RichPostText } from "@/components/rich-post-text";
import { authorLabel, postMediaAspectRatio, relativeTimeTh, type HomeFeedRow } from "@/lib/feed";
import type { HomeViewerState } from "@/lib/home-actions";

/**
 * WynosPostCard (Home variant) — one Home feed card (WYN-159 design system,
 * `.post` in the reference). Business logic (data, optimistic
 * like/redrop/follow state) is owned by HomeScreen; this component is
 * presentation only.
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
}) {
  const liked = viewer.likedDropIds.has(row.id);
  const redropped = viewer.redroppedDropIds.has(row.id);
  const following = viewer.followedAuthorIds.has(row.author_id);
  const requested = viewer.pendingFollowAuthorIds.has(row.author_id);
  const canRedrop = row.audience == null || row.audience === "everyone";
  const time = relativeTimeTh(row.created_at);
  const timeAndLocation = row.location ? `${time} · 📍 ${row.location}` : time;
  const profileHref = `/profile/${row.author_id}`;

  return (
    <article className={pc.post}>
      {row.redrop_id ? (
        <div className={pc.postRedropLine}>
          <Repeat2 size={14} />
          รีโพสต์โดย @{row.redropper_username || "wynos"} · {time}
        </div>
      ) : null}
      {row.quote_text ? <RichPostText className={pc.postQuote} value={row.quote_text} /> : null}
      <div className={pc.postRow}>
        <Link className={pc.postAvatar} href={profileHref}>
          <WynosAvatar src={row.author_avatar_url} label={row.author_username || "WYNOS"} size="feed" />
        </Link>
        <div className={pc.postBody}>
          <PostAuthorRow
            profileHref={profileHref}
            name={authorLabel(row)}
            verified={Boolean(row.author_is_verified)}
            timeLabel={timeAndLocation}
            showFollow={row.author_id !== userId && !following}
            followRequested={requested}
            onFollow={onFollow}
            onMore={onMore}
          />
          {row.caption ? (
            <RichPostText
              className={pc.postCaption}
              value={row.caption}
              postHref={`/drop/${row.id}`}
              compact
            />
          ) : null}
          <PostMediaCarousel
            urls={images}
            aspectRatio={postMediaAspectRatio(row, images.length > 1)}
            liked={liked}
            onDoubleLike={onLike}
            postKey={row.id}
          />
          <PostActions
            liked={liked}
            likeCount={row.like_count ?? 0}
            commentCount={row.comment_count ?? 0}
            canRedrop={canRedrop}
            redropped={redropped}
            redropCount={row.redrop_count ?? 0}
            onLike={onLike}
            commentHref={`/drop/${row.id}#comments`}
            onRedrop={onRedrop}
            onShare={onShare}
          />
        </div>
      </div>
    </article>
  );
}
