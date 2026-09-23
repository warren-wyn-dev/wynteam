"use client";

import { RepostIcon } from "@/components/ui/post-action-icons";
import { WynosIcon } from "@/components/ui/wynos-icon";

/**
 * Approved WYNOS Repost action sheet for Home and Profile.
 *
 * Both entry points share exactly the same two uncluttered choices: Thai
 * labels, a circular-arrow repost icon, and a pencil for quote repost.
 * The caller still controls the existing repost / quote logic and owns the
 * bottom-sheet frame, so unrelated Report menus are unaffected.
 */
export function RepostSheetChoices({
  reposted,
  busy = false,
  error,
  onRepost,
  onQuote,
  quoteLabel = "อ้างอิง",
}: {
  reposted: boolean;
  busy?: boolean;
  error?: string;
  onRepost: () => void;
  onQuote: () => void;
  quoteLabel?: string;
}) {
  return (
    <div className="wyn-repost-sheet-options">
      <button
        className="wyn-repost-sheet-choice"
        type="button"
        disabled={busy}
        aria-label={reposted ? "ยกเลิกรีโพสต์" : "รีโพสต์"}
        onClick={onRepost}
      >
        <RepostIcon size={28} strokeWidth={2} />
        <span>{reposted ? "ยกเลิกรีโพสต์" : "รีโพสต์"}</span>
      </button>
      <button
        className="wyn-repost-sheet-choice"
        type="button"
        disabled={busy}
        onClick={onQuote}
      >
        <WynosIcon name="pencil" size={27} strokeWidth={2} />
        <span>{quoteLabel}</span>
      </button>
      {error ? <p className="route-error wyn-repost-sheet-error" role="alert">{error}</p> : null}
    </div>
  );
}
