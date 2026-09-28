/**
 * WYNOS post actions — Circular Minimal Social preview.
 *
 * Visual language: social-first, rounded and compact. Every icon uses
 * round caps/joins and similar optical weight so the row reads as one family.
 * Kept local to the post row so unrelated app icons are unaffected.
 */
type PostActionIconProps = {
  size?: number;
  strokeWidth?: number;
  className?: string;
};

export function CommentIcon({ size = 24, strokeWidth = 1.9, className }: PostActionIconProps) {
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
      <path d="M12 3.5c5.05 0 9 3.45 9 7.75S17.05 19 12 19c-.9 0-1.77-.11-2.59-.32-1.14.79-2.5 1.31-4.01 1.5.65-.75 1.12-1.63 1.4-2.58C4.46 16.17 3 13.86 3 11.25 3 6.95 6.95 3.5 12 3.5Z" />
    </svg>
  );
}

export function RepostIcon({ size = 24, strokeWidth = 1.9, className }: PostActionIconProps) {
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
      <path d="M4.5 9V7.9A2.9 2.9 0 0 1 7.4 5h10.1" />
      <path d="m15.15 2.85 2.9 2.15-2.9 2.15" />
      <path d="M19.5 15v1.1A2.9 2.9 0 0 1 16.6 19H6.5" />
      <path d="m8.85 21.15-2.9-2.15 2.9-2.15" />
    </svg>
  );
}

export function ShareIcon({ size = 24, strokeWidth = 1.9, className }: PostActionIconProps) {
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
      <path d="M20.6 3.6 3.8 10.8c-.58.25-.55 1.08.05 1.28l6.55 2.2 2.2 6.05c.21.58 1.03.61 1.29.05L20.6 3.6Z" />
      <path d="m10.4 14.28 4.1-4.1" />
    </svg>
  );
}

export function SaveIcon({
  size = 24,
  strokeWidth = 1.9,
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
      <path d="M8.4 3.25h7.2c1.05 0 1.9.85 1.9 1.9v14.6L12 16.45l-5.5 3.3V5.15c0-1.05.85-1.9 1.9-1.9Z" />
    </svg>
  );
}
