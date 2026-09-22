"use client";

import { motion, useAnimationControls } from "framer-motion";
import { useEffect, useRef } from "react";

/**
 * Like-button heart: scales up and settles back down the moment `liked`
 * flips from false to true, on top of whatever press feedback the
 * surrounding button already has. Distinct from the existing double-tap
 * "burst" heart overlay (CSS keyframe in golden-drop-card.css/home.css) —
 * this animates the small in-button icon itself, which had no motion at all
 * before. Driven imperatively off a liked-transition effect (rather than a
 * keyframe array in `animate`) so unrelated re-renders while liked stays
 * true never replay the bounce.
 */
export function AnimatedHeart({
  size = 24,
  strokeWidth = 2,
  liked,
}: {
  size?: number;
  strokeWidth?: number;
  liked: boolean;
}) {
  const controls = useAnimationControls();
  const wasLiked = useRef(liked);

  useEffect(() => {
    if (liked && !wasLiked.current) {
      void controls.start({ scale: [1, 1.35, 0.95, 1.08, 1], transition: { duration: 0.42, ease: "easeOut" } });
    }
    wasLiked.current = liked;
  }, [liked, controls]);

  return (
    <motion.span style={{ display: "inline-flex" }} animate={controls}>
      {/* Founder-supplied icon set (wynos-post-icons.zip, 2026-09-22) --
          swapped from lucide-react's Heart to this exact path. */}
      <svg width={size} height={size} viewBox="0 0 24 24" fill={liked ? "currentColor" : "none"} stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.6l-1-1a5.5 5.5 0 0 0-7.8 7.8l1 1L12 21l7.8-7.6 1-1a5.5 5.5 0 0 0 0-7.8Z" />
      </svg>
    </motion.span>
  );
}
