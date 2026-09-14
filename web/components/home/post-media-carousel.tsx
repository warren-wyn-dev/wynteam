/* eslint-disable @next/next/no-img-element */
"use client";

import { Heart } from "lucide-react";
import { useRef, useState, type CSSProperties, type PointerEvent } from "react";

/**
 * Home's post media: PostImageFrame (single image) / PostImageCarousel
 * (multi-image peek row) from post_media.dart, both using the same
 * clamped aspect ratio (lib/feed.ts's postMediaAspectRatio already
 * mirrors postImageAspectRatio/DropAspectRatio), 16px border radius and
 * 75dvh height cap. A double-tap (or double-click) likes the post, same
 * as Flutter's DoubleTapLike.
 */
export function PostMediaCarousel({
  urls,
  aspectRatio,
  liked,
  onDoubleLike,
  postKey,
}: {
  urls: string[];
  aspectRatio: number;
  liked: boolean;
  onDoubleLike: () => void;
  postKey: string;
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
    setIndex((current) => (current === next ? current : next));
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
    <div className="wyn-post-media" onDoubleClick={doubleLike} onPointerUp={onPointerUp}>
      <div
        ref={track}
        onScroll={updateIndex}
        className={`wyn-post-media-track ${urls.length === 1 ? "is-single" : ""}`}
        style={{ "--post-media-ratio": String(aspectRatio) } as CSSProperties}
      >
        {urls.map((url, i) => (
          <img
            className={`wyn-post-media-item ${urls.length > 1 ? (i === index ? "is-front" : i < index ? "is-before" : "is-after") : ""}`}
            src={url}
            alt=""
            loading={i === 0 ? "eager" : "lazy"}
            decoding="async"
            key={`${postKey}:${i}`}
          />
        ))}
      </div>
      {burst ? <Heart className="wyn-post-heart-burst" size={72} fill="currentColor" strokeWidth={0} /> : null}
    </div>
  );
}
