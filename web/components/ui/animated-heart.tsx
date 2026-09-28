"use client";

import { motion, useAnimationControls } from "framer-motion";
import { useEffect, useRef } from "react";

/**
 * WYNOS Circular Minimal Social like icon.
 *
 * Rounded, compact heart geometry inspired by familiar social interaction
 * patterns while keeping WYNOS' own proportions and existing tap behavior.
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
      void controls.start({
        scale: [1, 1.32, 0.96, 1.06, 1],
        transition: { duration: 0.38, ease: "easeOut" },
      });
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
        <path d="M12 20.4S3.8 15.6 3.8 9.7A4.7 4.7 0 0 1 12 6.6a4.7 4.7 0 0 1 8.2 3.1c0 5.9-8.2 10.7-8.2 10.7Z" />
      </svg>
    </motion.span>
  );
}
