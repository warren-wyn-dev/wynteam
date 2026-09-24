import type { CSSProperties } from "react";

/**
 * One neutral fallback for every person who has not uploaded a profile photo.
 * Keep person avatars independent of usernames, including after image errors.
 * Club avatars intentionally retain their separate branding/fallback.
 */
export function DefaultProfileAvatar({
  size = 42,
  className,
  label = "รูปโปรไฟล์เริ่มต้น",
  as = "span",
}: {
  size?: number;
  className?: string;
  label?: string;
  as?: "span" | "div";
}) {
  const Element = as;
  const style: CSSProperties = {
    width: size,
    height: size,
    display: "inline-grid",
    placeItems: "center",
    flexShrink: 0,
    borderRadius: "50%",
    border: "1px solid #e7e7e7",
    backgroundColor: "#f2f2f2",
    color: "#9c9c9c",
    overflow: "hidden",
    userSelect: "none",
  };

  return (
    <Element className={["wyn-default-profile-avatar", className].filter(Boolean).join(" ")} role="img" aria-label={label} style={style}>
      <svg viewBox="0 0 40 40" width="65%" height="65%" fill="currentColor" aria-hidden="true" focusable="false">
        <circle cx="20" cy="12.5" r="7" />
        <path d="M4.8 34.8c0-8.7 6.8-13.7 15.2-13.7s15.2 5 15.2 13.7v.7H4.8z" />
      </svg>
    </Element>
  );
}
