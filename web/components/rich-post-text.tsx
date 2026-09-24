import Link from "next/link";
import type { CSSProperties } from "react";

const tokenPattern = /((?:https?:\/\/[^\s]+)|(?:#[\p{L}\p{M}\p{N}_]+)|(?:@[\p{L}\p{M}\p{N}_.]+))/gu;
const compactHashtagBlankLinePattern = /\r?\n(?:[ \t]*\r?\n)+(?=[ \t]*#)/g;

function renderTokens(value: string, postHref?: string) {
  return value.split(tokenPattern).map((part, index) => {
    if (!part) return null;
    if (/^https?:\/\//i.test(part)) {
      return (
        <a
          className="rich-post-link linkish"
          href={part}
          target="_blank"
          rel="noreferrer"
          key={`url:${index}`}
        >
          {part}
        </a>
      );
    }
    if (part.startsWith("#")) {
      return (
        <Link
          className="rich-post-link hashtag"
          href={`/search?q=${encodeURIComponent(part)}`}
          key={`tag:${index}`}
        >
          {part}
        </Link>
      );
    }
    if (part.startsWith("@")) {
      return (
        <Link
          className="rich-post-link mention"
          href={`/@${encodeURIComponent(part.slice(1))}`}
          key={`mention:${index}`}
        >
          {part}
        </Link>
      );
    }
    if (postHref) {
      return (
        <Link className="rich-post-body-link" href={postHref} key={`body:${index}`}>
          {part}
        </Link>
      );
    }
    return part;
  });
}

export function RichPostText({
  value,
  className = "",
  postHref,
  compact: compactProp,
  style,
}: {
  value: string;
  className?: string;
  postHref?: string;
  /** Threads-like dense caption rhythm: collapse a blank line before a
   * trailing hashtag block instead of leaving a gap. Defaults to
   * sniffing legacy class names so existing callers keep working. */
  compact?: boolean;
  style?: CSSProperties;
}) {
  const compact = compactProp ?? (className.includes("audit-caption") || className.includes("golden-drop") || className.includes("wyn-post-caption"));
  const displayValue = compact
    ? value.trimEnd().replace(compactHashtagBlankLinePattern, "\n")
    : value;

  return (
    <p className={`rich-post-text ${className}`.trim()} style={style}>
      {renderTokens(displayValue, postHref)}
    </p>
  );
}
