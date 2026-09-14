/* eslint-disable @next/next/no-img-element */
"use client";

import { Heart } from "lucide-react";
import { useRef, useState, type CSSProperties, type PointerEvent } from "react";

import pc from "@/components/design-system/post-card.module.css";

/**
 * Home's post media (WYN-159 design system, Media/Image Posts — renders
 * inside `WynosPostCard`'s `media` slot, i.e. `.post-media-wrap`, a sibling
 * of `.post-head-row` rather than nested in `.post-body` — see the
 * 2026-09-14 correction to `wynos-home.html`): single-image frame /
 * multi-image peek carousel, both using the same clamped aspect ratio
 * (lib/feed.ts's postMediaAspectRatio), `--radius-card` (16px) corners and
 * 75dvh height cap. A double-tap (or double-click) likes the post. Media
 * math/behavior is unchanged from before this redesign — only the chrome
 * (colors, radius token) is restyled. `mediaTrackFeed` applies the
 * reference's `padding: 0 16px 10px 62px` so the first image's left edge
 * lines up with the post text above it (see post-card.module.css).
 * `onIndexChange` reports the active slide up to `WynosPostCard` so it can
 * render the `.dots` indicator, which is a sibling of this carousel, not
 * nested inside it.
 */
export function PostMediaCarousel({
  urls,
  aspectRatio,
  liked,
  onDoubleLike,
  postKey,
  onIndexChange,
}: {
  urls: string[];
  aspectRatio: number;
  liked: boolean;
  onDoubleLike: () => void;
  postKey: string;
  onIndexChange?: (index: number) => void;
}) {
  const lastTap = useRef(0);
  const [burst, setBurst] = useState(false);
  const [index, setIndex] = useState(0);
  const track = useRef<HTMLDivElement>(null);

  const updateIndex = () => {
    const node = track.current;
    const first = node?.querySelector<HTMLImageElement>("img");
    if (!node || !first || urls.length <= 1) return;
    const stride = first.getBoundingClientRect().width + 8;
    if (stride <= 0) return;
    const next = Math.max(0, Math.min(urls.length - 1, Math.round(node.scrollLeft / stride)));
    setIndex((current) => {
      if (current === next) return current;
      onIndexChange?.(next);
      return next;
    });
  };

  const doubleLike = () => {
    if (!liked) onDoubleLike();
    setBurst(false);
    requestAnimationFrame(() => setBurst(true));
    window.setTimeout(() => setBurst(false), 700);
  };

  const onPointerUp = (event: PointerEvent<HTMLDivElement>) => {
    if (event.pointerType === "mouse") return;
    const now = Date.now();
    if (now - lastTap.current <= 300) {
      lastTap.current = 0;
      doubleLike();
    } else {
      lastTap.current = now;
    }
  };

  if (!urls.length) return null;

  return (
    <div className={pc.media} onDoubleClick={doubleLike} onPointerUp={onPointerUp}>
      <div
        ref={track}
        onScroll={updateIndex}
        className={`${pc.mediaTrack} ${pc.mediaTrackFeed} ${urls.length === 1 ? pc.mediaTrackSingle : ""}`}
        style={{ "--post-media-ratio": String(aspectRatio) } as CSSProperties}
      >
        {urls.map((url, i) => (
          <img
            className={`${pc.mediaItem} ${urls.length > 1 ? (i === index ? "" : i < index ? pc.mediaItemBefore : pc.mediaItemAfter) : ""}`}
            src={url}
            alt=""
            loading={i === 0 ? "eager" : "lazy"}
            decoding="async"
            key={`${postKey}:${i}`}
          />
        ))}
      </div>
      {burst ? <Heart className={pc.heartBurst} size={72} fill="currentColor" strokeWidth={0} /> : null}
    </div>
  );
}
