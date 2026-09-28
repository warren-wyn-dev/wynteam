"use client";

import { motion, useAnimationControls } from "framer-motion";
import { useEffect, useRef } from "react";

/**
 * WYNOS Outline Clean like icon.
 *
 * The visible icon stays at the existing action-row size; only the artwork is
 * softened so Like, Comment, Repost, Share and Bookmark read as one family.
 * A real false -> true transition keeps the existing tactile bounce.
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
      <svg
        width={size}
        height={size}
        viewBox="0 0 24 24"
        fill={liked ? "currentColor" : "none"}
        stroke="currentColor"
        strokeWidth={strokeWidth}
        strokeLinecap="round"
        strokeLinejoin="round"
        aria-hidden="true"
      >
        <path d="M12 20.45c-.25 0-.5-.08-.7-.23C5.7 16.05 2.75 13.4 2.75 9.8c0-3.05 2.2-5.3 5.05-5.3 1.78 0 3.28.82 4.2 2.1.92-1.28 2.42-2.1 4.2-2.1 2.85 0 5.05 2.25 5.05 5.3 0 3.6-2.95 6.25-8.55 10.42-.2.15-.45.23-.7.23Z" />
      </svg>
    </motion.span>
  );
}
