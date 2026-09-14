"use client";

import { Repeat } from "lucide-react";
import Link from "next/link";
import { useState } from "react";

import pc from "@/components/design-system/post-card.module.css";
import { WynosAvatar } from "@/components/design-system/WynosAvatar";
import { WynosPostCard } from "@/components/design-system/WynosPostCard";
import { PostActions } from "@/components/home/post-actions";
import { PostAuthorRow } from "@/components/home/post-author-row";
import { PostMediaCarousel } from "@/components/home/post-media-carousel";
import { RichPostText } from "@/components/rich-post-text";
import { authorLabel, postMediaAspectRatio, relativeTimeTh, type HomeFeedRow } from "@/lib/feed";
import type { HomeViewerState } from "@/lib/home-actions";

/**
 * WynosPostCard (Home variant) — one Home feed card (WYN-159 design system,
 * `.post-block` in the reference). Business logic (data, optimistic
 * like/redrop/follow state) is owned by HomeScreen; this component maps
 * Home's domain data onto the shared `WynosPostCard` skeleton and is
 * otherwise presentation only.
 *
 * `sendStatus`/`onRetry` are presentational-only additions for the
 * "failed to send" variant added in the 2026-09-14 `wynos-home.html`
 * correction: nothing in the product today models a locally-queued/failed
 * post in the feed (the composer surfaces publish errors inline in its own
 * modal instead — see `beta4-composer.tsx`), so no caller passes
 * `sendStatus="failed"` yet outside `home-fixture.tsx`. Wiring this up to a
 * real optimistic-send-failure flow is a future, separate piece of work.
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
  sendStatus = "sent",
  onRetry,
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
  sendStatus?: "sent" | "failed";
  onRetry?: () => void;
}) {
  const failed = sendStatus === "failed";
  const liked = viewer.likedDropIds.has(row.id);
  const redropped = viewer.redroppedDropIds.has(row.id);
  const following = viewer.followedAuthorIds.has(row.author_id);
  const requested = viewer.pendingFollowAuthorIds.has(row.author_id);
  const canRedrop = row.audience == null || row.audience === "everyone";
  const time = relativeTimeTh(row.created_at);
  const timeAndLocation = row.location ? `${time} · 📍 ${row.location}` : time;
  const profileHref = `/profile/${row.author_id}`;
  const [mediaIndex, setMediaIndex] = useState(0);

  const topContent = !failed && (row.redrop_id || row.quote_text) ? (
    <>
      {row.redrop_id ? (
        <div className={pc.postRedropLine}>
          <Repeat size={14} />
          รีโพสต์โดย @{row.redropper_username || "wynos"} · {time}
        </div>
      ) : null}
      {row.quote_text ? <RichPostText className={pc.postQuote} value={row.quote_text} /> : null}
    </>
  ) : null;

  const avatar = (
    <Link
      className={`${pc.postAvatar} ${failed ? pc.postAvatarMuted : ""}`.trim()}
      href={profileHref}
    >
      <WynosAvatar src={row.author_avatar_url} label={row.author_username || "WYNOS"} size="feed" />
    </Link>
  );

  const header = failed ? (
    <div className={pc.postMetaFailed}>
      <strong className={pc.postAuthorName}>คุณ</strong>
    </div>
  ) : (
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
  );

  const caption = row.caption ? (
    <RichPostText
      className={`${pc.postCaption} ${failed ? pc.postCaptionMuted : ""}`.trim()}
      value={row.caption}
      postHref={failed ? undefined : `/drop/${row.id}`}
      compact
    />
  ) : null;

  const actions = failed ? null : (
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
  );

  const media = !failed && images.length ? (
    <PostMediaCarousel
      urls={images}
      aspectRatio={postMediaAspectRatio(row, images.length > 1)}
      liked={liked}
      onDoubleLike={onLike}
      postKey={row.id}
      onIndexChange={setMediaIndex}
    />
  ) : null;

  return (
    <WynosPostCard
      topContent={topContent}
      avatar={avatar}
      header={header}
      caption={caption}
      media={media}
      mediaCount={failed ? 0 : images.length}
      activeIndex={mediaIndex}
      actions={actions}
      sendStatus={sendStatus}
      onRetry={onRetry}
    />
  );
}
