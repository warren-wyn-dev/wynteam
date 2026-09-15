/* eslint-disable @next/next/no-img-element */
"use client";

import { useEffect, useState } from "react";

import { Avatar } from "@/components/phase3-ui";
import { authorLabel, relativeTimeTh, type HomeFeedRow } from "@/lib/feed";

const QUOTE_REDROP_FORM_ID = "wyn-quote-redrop-submit";

export function QuoteRedropComposer({
  row,
  value,
  busy,
  error,
  onChange,
  onClose,
  onSubmit,
}: {
  row: HomeFeedRow;
  value: string;
  busy: boolean;
  error: string;
  onChange: (value: string) => void;
  onClose: () => void;
  onSubmit: () => void;
}) {
  const [closePrompt, setClosePrompt] = useState(false);

  useEffect(() => {
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = "";
    };
  }, []);

  const requestClose = () => {
    if (busy) return;
    if (!value.trim()) {
      onClose();
      return;
    }
    setClosePrompt(true);
  };

  const submit = () => {
    if (busy || !value.trim()) return;
    onSubmit();
  };

  return (
    <div className="route-modal-backdrop beta4-composer-backdrop" role="presentation">
      <section
        className="beta4-composer"
        role="dialog"
        aria-modal="true"
        aria-label="รีโพสต์พร้อมความคิดเห็น"
        style={{ maxWidth: 680 }}
      >
        <form
          id={QUOTE_REDROP_FORM_ID}
          onSubmit={(event) => {
            event.preventDefault();
            submit();
          }}
        />

        <header className="beta4-composer-header" style={{ position: "relative", zIndex: 20 }}>
          <button className="beta4-cancel" type="button" onClick={requestClose}>ยกเลิก</button>
          <strong style={{ fontSize: 17, fontWeight: 750 }}>สร้างโพสต์</strong>
          <button
            className="beta4-post"
            type="submit"
            form={QUOTE_REDROP_FORM_ID}
            disabled={busy || !value.trim()}
            aria-disabled={busy || !value.trim()}
            style={{ position: "relative", zIndex: 21, pointerEvents: "auto", touchAction: "manipulation" }}
          >
            {busy ? <span className="route-system-spinner tiny" /> : "โพสต์"}
          </button>
        </header>

        {error ? (
          <p
            className="route-error beta4-composer-error"
            role="alert"
            aria-live="polite"
            style={{ margin: "10px 16px 0", position: "relative", zIndex: 19 }}
          >
            {error}
          </p>
        ) : null}

        <div className="beta4-composer-scroll" style={{ paddingBottom: 32 }}>
          <div className="beta4-composer-identity">
            <Avatar src={null} label="WYNOS" size={44} />
          </div>

          <textarea
            autoFocus
            className="beta4-compose-text"
            maxLength={500}
            value={value}
            disabled={busy}
            onChange={(event) => onChange(event.target.value)}
            placeholder="เพิ่มความคิดเห็น..."
            style={{ minHeight: 120 }}
          />

          <article
            aria-label="โพสต์ต้นฉบับ"
            style={{
              margin: "8px 18px 0 72px",
              overflow: "hidden",
              border: "1px solid var(--hairline)",
              borderRadius: 18,
              background: "var(--paper)",
            }}
          >
            <div style={{ display: "flex", alignItems: "center", gap: 9, padding: "13px 14px 8px" }}>
              <Avatar src={row.author_avatar_url} label={authorLabel(row)} size={30} />
              <div style={{ minWidth: 0, display: "flex", alignItems: "baseline", gap: 6 }}>
                <strong style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", fontSize: 14.5 }}>
                  {authorLabel(row)}
                </strong>
                <span style={{ color: "var(--graphite)", fontSize: 12.5, whiteSpace: "nowrap" }}>
                  · {relativeTimeTh(row.created_at)}
                </span>
              </div>
            </div>

            {row.caption ? (
              <p style={{ margin: 0, padding: "0 14px 12px", fontSize: 14.5, lineHeight: 1.45, whiteSpace: "pre-wrap" }}>
                {row.caption}
              </p>
            ) : null}

            {row.image_url ? (
              <img
                src={row.image_url}
                alt=""
                style={{ width: "100%", maxHeight: 360, display: "block", objectFit: "cover", borderTop: "1px solid var(--hairline)" }}
              />
            ) : null}
          </article>

          {value.length > 400 ? (
            <div className="beta4-character-count">{500 - value.length}</div>
          ) : null}
        </div>

        {closePrompt ? (
          <div className="route-modal-backdrop detail-dialog-backdrop" role="presentation" onClick={() => setClosePrompt(false)}>
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
          </div>
        ) : null}
      </section>
    </div>
  );
}
