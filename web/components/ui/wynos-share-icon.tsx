import type { SVGProps } from "react";

// Approved Beta1 reference: a separate up-arrow rising from an OPEN, rounded
// U-shaped tray. The previous square outline had shoulders connected to the
// arrow, creating the house-like shape seen in the live iPhone screenshot.
// Shared by profile actions, post rows, sheets and install instructions.
type WynosShareIconProps = SVGProps<SVGSVGElement> & {
  size?: number | string;
};

export function WynosShareIcon({
  size = 24,
  strokeWidth = 2,
  className,
  ...props
}: WynosShareIconProps) {
  return (
    <svg
      className={["wyn-share-icon", className].filter(Boolean).join(" ")}
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      aria-hidden="true"
      {...props}
    >
      <path
        d="M12 15.5V3.5m0 0L7.75 7.75M12 3.5l4.25 4.25M4.75 11.75v7.1a2.4 2.4 0 0 0 2.4 2.4h9.7a2.4 2.4 0 0 0 2.4-2.4v-7.1"
        stroke="currentColor"
        strokeWidth={strokeWidth}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
