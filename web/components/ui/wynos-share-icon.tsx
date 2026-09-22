// Square-with-up-arrow share glyph; consistent across WYNOS profile and posts.
// Uses the same 24px viewBox as other post actions. Interaction stays in callers.
export function WynosShareIcon({ size = 24 }: { size?: number }) {
  return (
    <svg
      className="wyn-share-icon"
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      aria-hidden="true"
    >
      <path
        d="M12 15V3m0 0L8 7m4-4 4 4M8 8H5.75A2.75 2.75 0 0 0 3 10.75v8.5A2.75 2.75 0 0 0 5.75 22h12.5A2.75 2.75 0 0 0 21 19.25v-8.5A2.75 2.75 0 0 0 18.25 8H16"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
