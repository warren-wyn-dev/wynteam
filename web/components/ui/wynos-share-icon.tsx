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
        d="M4.5 18.25C6.1 13.3 9.45 10.8 14.85 10.8H19"
        stroke="currentColor"
        strokeWidth="2.15"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M15.25 6.75L19.5 10.8L15.25 14.85"
        stroke="currentColor"
        strokeWidth="2.15"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
