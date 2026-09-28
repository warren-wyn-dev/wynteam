/**
 * WYNOS Action Icons — Outline Clean.
 *
 * These shapes are intentionally related: round line caps, round joins,
 * matching optical weight and softened corners. They stay as dedicated post
 * action components so unrelated WYNOS icons are not restyled by accident.
 */
type PostActionIconProps = {
  size?: number;
  strokeWidth?: number;
  className?: string;
};

export function CommentIcon({ size = 24, strokeWidth = 1.8, className }: PostActionIconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      className={className}
    >
      {/* A round bubble plus a short curved tail avoids the old sharp pointer. */}
      <path d="M12 3.6c5.02 0 9 3.48 9 7.8s-3.98 7.8-9 7.8-9-3.48-9-7.8 3.98-7.8 9-7.8Z" />
      <path d="M7.8 18.15c-.42 1.08-1.18 1.85-2.3 2.3 1.6-.02 2.96-.4 4.08-1.08" />
    </svg>
  );
}

export function RepostIcon({ size = 24, strokeWidth = 1.8, className }: PostActionIconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      className={className}
    >
      {/* Two directional lanes read as repost, not a circular refresh icon. */}
      <path d="M4.4 9V7.9A2.9 2.9 0 0 1 7.3 5h10.4" />
      <path d="m15.2 2.8 2.8 2.2-2.8 2.2" />
      <path d="M19.6 15v1.1A2.9 2.9 0 0 1 16.7 19H6.3" />
      <path d="m8.8 21.2-2.8-2.2 2.8-2.2" />
    </svg>
  );
}

export function SaveIcon({
  size = 24,
  strokeWidth = 1.8,
  saved = false,
  className,
}: PostActionIconProps & { saved?: boolean }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill={saved ? "currentColor" : "none"}
      stroke="currentColor"
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      className={className}
    >
      {/* Rounded shoulders and a shallower notch keep Bookmark in the same family. */}
      <path d="M7.5 3.25h9c1.1 0 2 .9 2 2v14.9L12 16.1l-6.5 4.05V5.25c0-1.1.9-2 2-2Z" />
    </svg>
  );
}
