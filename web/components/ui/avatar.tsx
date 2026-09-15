import type { CSSProperties } from "react";

export type AvatarVariant = "person" | "club" | "clubBanner";

export type AvatarProps = {
  src?: string | null;
  alt: string;
  fallback?: string;
  size?: number;
  variant?: AvatarVariant;
  className?: string;
};

export function Avatar({
  src,
  alt,
  fallback,
  size = 44,
  variant = "person",
  className,
}: AvatarProps) {
  const style = {
    "--wyn-avatar-size": `${size}px`,
    ...(src ? { backgroundImage: `url(${JSON.stringify(src)})` } : {}),
  } as CSSProperties;

  const classes = [
    "wyn-avatar",
    variant === "person" ? "wyn-avatar--person" : "",
    variant === "club" ? "wyn-avatar--club" : "",
    variant === "clubBanner" ? "wyn-avatar--club-banner" : "",
    className ?? "",
  ]
    .filter(Boolean)
    .join(" ");

  return (
    <span aria-label={alt} className={classes} role="img" style={style}>
      {src ? null : fallback?.slice(0, 2).toUpperCase()}
    </span>
  );
}
