"use client";

import { AlertCircle } from "lucide-react";
import type { ReactNode } from "react";

import pc from "@/components/design-system/post-card.module.css";

/**
 * WynosPostCard — the single, prop-driven feed post skeleton (WYN-159
 * design system, `article.post-block` in `wynos-home.html`, the 2026-09-14
 * "exact source of truth" correction). One component renders all three
 * variants from the reference — text-only, image-carousel, failed-to-send —
 * distinguished by **where the action row and closing spacer land**, not by
 * different markup per case:
 *
 *   article.post-block
 *     div.post-head-row               (padding: 14px 16px 0)
 *       [topContent]                  (redrop line / quote — existing WYN
 *                                       convention, not in the reference)
 *       div.post                      (avatar + post-body row)
 *         [avatar]
 *         div.post-body
 *           [header]                  -- omitted (caller passes null) on
 *                                         the failed variant
 *           [caption]
 *           sendStatus="failed"  -> .error-box
 *           mediaCount === 0     -> [actions] + 14px spacer (text-only)
 *           mediaCount > 0       -> nothing here (actions move to the
 *                                    footer below, next to the media)
 *     mediaCount > 0:
 *       div.post-media-wrap            (sibling of post-head-row, NOT
 *                                        nested in post-body, so it can
 *                                        bleed to full card width)
 *       div.dots                       (only when mediaCount > 1)
 *       div.post-footer                ([actions] again, below the media)
 *
 * Callers (`home-post-card.tsx`, `club-feed-post.tsx`) own all business
 * logic/data; this component is presentation only.
 */
export function WynosPostCard({
  topContent = null,
  avatar,
  header,
  caption,
  media = null,
  mediaCount = 0,
  activeIndex = 0,
  showDots = mediaCount > 1,
  actions,
  sendStatus = "sent",
  errorMessage = "โพสต์ไม่สำเร็จ ตรวจสอบอินเทอร์เน็ต",
  retryLabel = "ลองอีกครั้ง",
  onRetry,
}: {
  /** Rendered above the avatar row, still inside .post-head-row (e.g. the
   * existing "รีโพสต์โดย ..." line / quote text — not part of the
   * reference, an existing WYN convention preserved from before this
   * redesign). */
  topContent?: ReactNode;
  /** The avatar element itself (e.g. `<Link><WynosAvatar/></Link>`) —
   * caller applies the 50%-opacity muted style for the failed variant. */
  avatar: ReactNode;
  /** Full post-head (name/time/Follow/More) for sent posts, or a bare-name
   * node for the failed variant — `null` renders nothing (post-head is
   * omitted entirely on failed, per the reference). */
  header: ReactNode | null;
  /** The post text node (caller applies the 60%-opacity muted style for
   * the failed variant), or `null` when there is no caption. */
  caption: ReactNode | null;
  /** Pre-rendered carousel/media content, or `null` for a text-only post. */
  media?: ReactNode | null;
  /** Number of media items — drives which variant renders (0 = text-only)
   * and whether dots render (`showDots`, default: > 1 item). */
  mediaCount?: number;
  /** Which dot is active — controlled by the caller (e.g. synced to the
   * media carousel's scroll position via `onIndexChange`). */
  activeIndex?: number;
  showDots?: boolean;
  /** The post-actions row (Like/Comment/ReDrop/Share) — rendered inside
   * post-body for text-only, or in post-footer below the media otherwise.
   * Ignored when `sendStatus === "failed"` (error-box replaces it). */
  actions: ReactNode;
  sendStatus?: "sent" | "failed";
  errorMessage?: string;
  retryLabel?: string;
  onRetry?: () => void;
}) {
  const failed = sendStatus === "failed";
  const hasMedia = !failed && mediaCount > 0;

  return (
    <article className={pc.postBlock}>
      <div className={`${pc.postHeadRow} ${failed ? pc.postHeadRowFailed : ""}`.trim()}>
        {topContent}
        <div className={pc.postRow}>
          {avatar}
          <div className={pc.postBody}>
            {header}
            {caption}
            {failed ? (
              <div className={pc.errorBox}>
                <AlertCircle className={pc.errorBoxIcon} size={16} aria-hidden="true" />
                <span className={pc.errorBoxMessage}>{errorMessage}</span>
                <button type="button" className={pc.errorBoxRetry} onClick={onRetry}>
                  {retryLabel}
                </button>
              </div>
            ) : !hasMedia ? (
              <>
                {actions}
                <div style={{ height: 14 }} />
              </>
            ) : null}
          </div>
        </div>
      </div>

      {hasMedia ? (
        <>
          <div className={pc.postMediaWrap}>{media}</div>
          {showDots ? (
            <div className={pc.dots} aria-hidden="true">
              {Array.from({ length: mediaCount }).map((_, index) => (
                <span
                  className={`${pc.dot} ${index === activeIndex ? pc.dotActive : ""}`.trim()}
                  data-dot-index={index}
                  key={index}
                />
              ))}
            </div>
          ) : null}
          <div className={pc.postFooter}>{actions}</div>
        </>
      ) : null}
    </article>
  );
}
