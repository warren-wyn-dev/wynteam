import { Avatar } from "@/components/phase3-ui";

/**
 * WynosAvatar — canonical circular avatar (WYN-159 design system, `.avatar`
 * in the reference), size variants per the design-system doc's Sizing Tokens
 * table (36px feed row, 72px profile header, or a custom size).
 *
 * Wraps the existing `Avatar` (`components/phase3-ui.tsx`) instead of
 * reimplementing fallback-letter logic — that component is shared by ~20
 * other routes today and already does exactly what this primitive needs;
 * duplicating it would violate "reuse before duplication".
 */
export function WynosAvatar({
  src,
  label,
  size = "feed",
}: {
  src?: string | null;
  label: string;
  size?: "feed" | "profile" | number;
}) {
  const px = size === "feed" ? 36 : size === "profile" ? 72 : size;
  return <Avatar src={src} label={label} size={px} />;
}
