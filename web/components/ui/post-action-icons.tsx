/**
 * WYNOS Beta 2 preview post actions.
 *
 * Like / Comment / Repost follow a familiar Threads-style social language.
 * Share uses a familiar Facebook-style curved forward arrow.
 * The shapes are redrawn for WYNOS and preserve the existing action-row geometry.
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
      <path d="M12 3.7c5.02 0 8.95 3.36 8.95 7.62S17.02 18.94 12 18.94c-1.16 0-2.27-.18-3.3-.52L4.9 20.15l1.18-3.42C4.15 15.33 3.05 13.4 3.05 11.32 3.05 7.06 6.98 3.7 12 3.7Z" />
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
      <path d="M6.4 7.1h9.95a2.85 2.85 0 0 1 2.85 2.85v.9" />
      <path d="m16.65 8.55 2.55 2.3 2.55-2.3" />
      <path d="M17.6 16.9H7.65a2.85 2.85 0 0 1-2.85-2.85v-.9" />
      <path d="m7.35 15.45-2.55-2.3-2.55 2.3" />
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
      <path d="M14.05 5.1 20.5 10l-6.45 4.9v-3.25c-4.62.08-7.95 1.66-10.55 5.25.78-5.48 4.2-8.57 10.55-9.03V5.1Z" />
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
      <path d="M7.5 3.25h9c1.1 0 2 .9 2 2v14.9L12 16.1l-6.5 4.05V5.25c0-1.1.9-2 2-2Z" />
    </svg>
  );
}
