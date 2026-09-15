import type { CSSProperties } from "react";

export type AvatarVariant = "person" | "club" | "clubBanner";
export type AvatarElement = "span" | "div";

export type AvatarProps = {
  src?: string | null;
  alt: string;
  fallback?: string;
  size?: number;
  variant?: AvatarVariant;
  className?: string;
  as?: AvatarElement;
};

export function Avatar({
  src,
  alt,
  fallback,
  size = 44,
  variant = "person",
  className,
  as = "span",
}: AvatarProps) {
  const style = {
    "--wyn-avatar-size": `${size}px`,
    ...(src ? { backgroundImage: `url(${src})` } : {}),
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

  const Element = as;

  return (
    <Element aria-label={alt} className={classes} role="img" style={style}>
      {src ? null : fallback?.slice(0, 2).toUpperCase()}
    </Element>
  );
}
