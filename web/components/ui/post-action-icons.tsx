/**
 * Founder-supplied icon set (wynos-post-icons.zip, 2026-09-22) for the
 * primary post action row (like/comment/repost/share/save). Kept as
 * standalone components -- not folded into WynosIcon's shared iconMap --
 * because "comment"/"repost"/"bookmark" there are also used by unrelated
 * UI (notification badges, the home drawer menu, redrop sheets) that this
 * change isn't meant to touch. AnimatedHeart and WynosShareIcon carry the
 * like/share shapes from the same set.
 */
type PostActionIconProps = {
  size?: number;
  strokeWidth?: number;
  className?: string;
};

export function CommentIcon({ size = 24, strokeWidth = 1.8, className }: PostActionIconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" className={className}>
      <path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5Z" />
    </svg>
  );
}

export function RepostIcon({ size = 24, strokeWidth = 1.8, className }: PostActionIconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" className={className}>
      <path d="M3 12a9 9 0 0 1 15.4-6.36L21 8" />
      <path d="M21 3v5h-5" />
      <path d="M21 12a9 9 0 0 1-15.4 6.36L3 16" />
      <path d="M8 16H3v5" />
    </svg>
  );
}

export function SaveIcon({ size = 24, strokeWidth = 1.8, saved = false, className }: PostActionIconProps & { saved?: boolean }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={saved ? "currentColor" : "none"} stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" className={className}>
      <path d="M19 21 12 16l-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z" />
    </svg>
  );
}
