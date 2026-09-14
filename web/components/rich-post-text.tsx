import Link from "next/link";

const tokenPattern = /((?:https?:\/\/[^\s]+)|(?:#[\p{L}\p{N}_]+))/gu;
const hashtagOnlyLine = /^\s*(?:#[\p{L}\p{N}_]+(?:\s+|$))+\s*$/u;

function renderTokens(value: string, keyPrefix: string) {
  return value.split(tokenPattern).map((part, index) => {
    if (!part) return null;
    if (/^https?:\/\//i.test(part)) {
      return (
        <a
          className="rich-post-link linkish"
          href={part}
          target="_blank"
          rel="noreferrer"
          key={`${keyPrefix}:url:${index}`}
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
          key={`${keyPrefix}:tag:${index}`}
        >
          {part}
        </Link>
      );
    }
    return part;
  });
}

function splitTrailingHashtags(value: string) {
  const lines = value.split("\n");
  let firstHashtagLine = lines.length;
  while (firstHashtagLine > 0 && hashtagOnlyLine.test(lines[firstHashtagLine - 1] ?? "")) {
    firstHashtagLine -= 1;
  }
  if (firstHashtagLine === lines.length || firstHashtagLine === 0) {
    return { body: value, hashtags: "" };
  }
  return {
    body: lines.slice(0, firstHashtagLine).join("\n").replace(/\s+$/u, ""),
    hashtags: lines.slice(firstHashtagLine).join("\n").trim(),
  };
}

export function RichPostText({ value, className = "" }: { value: string; className?: string }) {
  const { body, hashtags } = splitTrailingHashtags(value);
  return (
    <p className={`rich-post-text ${className}`.trim()}>
      {body ? <span className="rich-post-body">{renderTokens(body, "body")}</span> : null}
      {hashtags ? (
        <span className="rich-post-hashtag-block">
          {renderTokens(hashtags, "hashtags")}
        </span>
      ) : null}
    </p>
  );
}
