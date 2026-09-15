/* eslint-disable @next/next/no-img-element */
"use client";

import { Heart } from "lucide-react";
import { useRef, useState, type CSSProperties, type PointerEvent } from "react";

/**
 * Home's post media: PostImageFrame (single image) / PostImageCarousel
 * (multi-image peek row). modernFeed expands the media beneath the avatar
 * column, matching the cleaner X + Threads-inspired composition.
 */
export function PostMediaCarousel({
  urls,
  aspectRatio,
  liked,
  onDoubleLike,
  postKey,
  modernFeed = false,
}: {
  urls: string[];
  aspectRatio: number;
  liked: boolean;
  onDoubleLike: () => void;
  postKey: string;
  modernFeed?: boolean;
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

  const mediaStyle: CSSProperties | undefined = modernFeed
    ? { marginTop: 8, marginLeft: -54, width: "calc(100% + 54px)" }
    : undefined;

  const trackStyle = {
    "--post-media-ratio": String(aspectRatio),
    ...(modernFeed && urls.length === 1 ? { paddingRight: 0 } : {}),
  } as CSSProperties;

  return (
    <div
      className="wyn-post-media"
      style={mediaStyle}
      onDoubleClick={doubleLike}
      onPointerUp={onPointerUp}
    >
      <div
        ref={track}
        onScroll={updateIndex}
        className={`wyn-post-media-track ${urls.length === 1 ? "is-single" : ""}`}
        style={trackStyle}
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
