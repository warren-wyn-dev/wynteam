"use client";

import { motion } from "framer-motion";
import Image from "next/image";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";

import { Avatar } from "@/components/phase3-ui";
import { authorLabel, relativeTimeTh, type HomeFeedRow } from "@/lib/feed";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

const QUOTE_REDROP_FORM_ID = "wyn-quote-redrop-submit";

type QuoteActor = {
  username: string;
  display_name?: string | null;
  avatar_url?: string | null;
  is_verified?: boolean | null;
};

type VisualViewportBounds = { height: number; top: number };

/**
 * One X-inspired Quote composer shared by the Home feed and profile posts.
 * Its own body portal matters: the profile tab swipe wrapper (and the global
 * page transition) use transforms that otherwise displace position:fixed
 * overlays below the visible iPhone screen.
 */
export function QuoteRedropComposer({
  row,
  value,
  busy,
  error,
  viewerId,
  viewer,
  onChange,
  onClose,
  onSubmit,
}: {
  row: HomeFeedRow;
  value: string;
  busy: boolean;
  error: string;
  viewerId: string;
  viewer?: QuoteActor | null;
  onChange: (value: string) => void;
  onClose: () => void;
  onSubmit: () => void;
}) {
  const [closePrompt, setClosePrompt] = useState(false);
  const [resolvedViewer, setResolvedViewer] = useState<QuoteActor | null>(null);
  const [viewport, setViewport] = useState<VisualViewportBounds | null>(null);
  const textRef = useRef<HTMLTextAreaElement>(null);
  const actor = viewer?.username ? viewer : resolvedViewer;
  const actorName = actor?.display_name?.trim() || actor?.username || "บัญชีของคุณ";

  // Home already has an authenticated identity. Profile post cards only have
  // viewerId; read that user's real avatar/name/badge on demand instead of
  // rendering a hard-coded WYNOS placeholder for every person's quote.
  useEffect(() => {
    if (viewer?.username || !viewerId) return;
    const client = getSupabaseBrowserClient();
    if (!client) return;
    let active = true;
    void client.from("profiles")
      .select("username,display_name,avatar_url,is_verified")
      .eq("id", viewerId)
      .maybeSingle()
      .then(({ data, error: profileError }) => {
        if (!active || profileError || !data) return;
        setResolvedViewer({
          username: String(data.username ?? ""),
          display_name: data.display_name ? String(data.display_name) : null,
          avatar_url: data.avatar_url ? String(data.avatar_url) : null,
          is_verified: Boolean(data.is_verified),
        });
      });
    return () => { active = false; };
  }, [viewer, viewerId]);

  // On iOS, 100dvh can still extend behind the software keyboard in a PWA.
  // Track the actual *visual* viewport while the keyboard opens, closes or
  // pans the page, retaining a stationary header and a scrollable post body.
  useEffect(() => {
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const visual = window.visualViewport;
    const update = () => {
      const height = Math.round(visual?.height || window.innerHeight);
      const top = Math.round(visual?.offsetTop || 0);
      setViewport((current) =>
        current?.height === height && current.top === top ? current : { height, top },
      );
    };
    update();
    visual?.addEventListener("resize", update);
    visual?.addEventListener("scroll", update);
    window.addEventListener("resize", update);
    return () => {
      visual?.removeEventListener("resize", update);
      visual?.removeEventListener("scroll", update);
      window.removeEventListener("resize", update);
      document.body.style.overflow = previousOverflow;
    };
  }, []);

  // Grow only as text is entered; the quoted post should start immediately
  // underneath a short comment rather than below a fixed 120px empty field.
  useEffect(() => {
    const node = textRef.current;
    if (!node) return;
    node.style.height = "auto";
    node.style.height = Math.min(node.scrollHeight, 220) + "px";
    node.style.overflowY = node.scrollHeight > 220 ? "auto" : "hidden";
  }, [value]);

  const requestClose = () => {
    if (busy) return;
    if (!value.trim()) { onClose(); return; }
    setClosePrompt(true);
  };

  const submit = () => {
    if (busy || !value.trim()) return;
    onSubmit();
  };

  // Do not autofocus: opening iOS's keyboard during the entrance animation
  // was one cause of the quote card jumping offscreen before it was visible.
  if (typeof document === "undefined") return null;
  return createPortal(
    <>
      <motion.div
        className="route-modal-backdrop beta4-composer-backdrop wyn-quote-backdrop"
        role="presentation"
        style={viewport ? { top: viewport.top, height: viewport.height } : undefined}
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        transition={{ duration: 0.16 }}
        onTouchStart={(event) => event.stopPropagation()}
        onTouchMove={(event) => event.stopPropagation()}
        onTouchEnd={(event) => event.stopPropagation()}
      >
        <motion.section
          className="beta4-composer wyn-quote-composer"
          role="dialog"
          aria-modal="true"
          aria-label="อ้างอิง"
          style={{ maxWidth: 680, height: "100%", maxHeight: "100%" }}
          initial={{ y: "8%" }}
          animate={{ y: 0 }}
          exit={{ y: "8%" }}
          transition={{ duration: 0.2, ease: "easeOut" }}
        >
          <form
            id={QUOTE_REDROP_FORM_ID}
            onSubmit={(event) => { event.preventDefault(); submit(); }}
          />

          <header className="beta4-composer-header wyn-quote-header">
            <button className="beta4-cancel" type="button" disabled={busy} onClick={requestClose}>ยกเลิก</button>
            <strong className="beta4-composer-header-title">อ้างอิง</strong>
            <button
              className="beta4-post"
              type="submit"
              form={QUOTE_REDROP_FORM_ID}
              disabled={busy || !value.trim()}
            >
              {busy ? <span className="route-system-spinner tiny" /> : "โพสต์"}
            </button>
          </header>

          {error ? (
            <p className="route-error wyn-quote-error" role="alert" aria-live="polite">{error}</p>
          ) : null}

          <div className="beta4-composer-scroll wyn-quote-scroll">
            <div className="wyn-quote-row">
              <div className="wyn-quote-avatar">
                <Avatar src={actor?.avatar_url} label={actor?.username || "คุณ"} size={44} />
              </div>
              <div className="wyn-quote-body">
                <div className="wyn-quote-author">
                  <strong>{actorName}</strong>
                  {actor?.is_verified ? <span className="route-verified" aria-label="ยืนยันแล้ว">✓</span> : null}
                </div>
                <textarea
                  ref={textRef}
                  className="beta4-compose-text wyn-quote-text"
                  rows={2}
                  maxLength={500}
                  value={value}
                  disabled={busy}
                  onChange={(event) => onChange(event.target.value)}
                  placeholder="เพิ่มความคิดเห็นของคุณ..."
                  aria-label="ความคิดเห็นของคุณ"
                />

                <article className="wyn-quote-original" aria-label="โพสต์ต้นฉบับ">
                  <div className="wyn-quote-original-author">
                    <Avatar src={row.author_avatar_url} label={authorLabel(row)} size={32} />
                    <span className="wyn-quote-original-byline">
                      <span className="wyn-quote-original-name">
                        <strong>{authorLabel(row)}</strong>
                        {row.author_is_verified ? <span className="route-verified" aria-label="ยืนยันแล้ว">✓</span> : null}
                      </span>
                      <small>@{row.author_username || "wynos"} · {relativeTimeTh(row.created_at)}</small>
                    </span>
                  </div>
                  {row.caption ? <p className="wyn-quote-original-text">{row.caption}</p> : null}
                  {row.image_url ? (
                    <div className="wyn-quote-original-media">
                      <Image
                        src={row.image_url}
                        alt="ภาพประกอบโพสต์ต้นฉบับ"
                        width={640}
                        height={360}
                        sizes="(max-width: 680px) calc(100vw - 110px), 520px"
                      />
                    </div>
                  ) : null}
                  <Link
                    className="wyn-quote-original-link"
                    href={`/drop/${row.id}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    aria-label="เปิดโพสต์ต้นฉบับในหน้าใหม่"
                  >ดูโพสต์ต้นฉบับ ↗</Link>
                </article>
              </div>
            </div>
            {value.length > 400 ? <div className="beta4-character-count">{500 - value.length}</div> : null}
          </div>
        </motion.section>
      </motion.div>

      {closePrompt ? createPortal(
        <div className="route-modal-backdrop detail-dialog-backdrop wyn-quote-discard-backdrop" role="presentation" onClick={() => setClosePrompt(false)}>
          <section
            className="route-modal detail-confirm-dialog"
            role="alertdialog"
            aria-modal="true"
            aria-label="ทิ้งโพสต์นี้หรือไม่?"
            onClick={(event) => event.stopPropagation()}
          >
            <strong>ทิ้งโพสต์นี้หรือไม่?</strong>
            <footer>
              <button type="button" onClick={() => setClosePrompt(false)}>ยกเลิก</button>
              <button className="danger" type="button" onClick={onClose}>ทิ้ง</button>
            </footer>
          </section>
        </div>,
        document.body,
      ) : null}
    </>,
    document.body,
  );
}
