/* eslint-disable @next/next/no-html-link-for-pages -- root-layout error fallback intentionally avoids Next router components */
"use client";

import { useEffect } from "react";

import { reportClientFailure } from "@/lib/client-health";

/**
 * Root layout failures are not caught by app/error.tsx. This last-resort
 * recovery screen is intentionally standalone, with no auth, fonts, fetched
 * assets or navigation components that could fail together with the layout.
 */
export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => { reportClientFailure("route_render"); }, [error]);

  return (
    <html lang="th">
      <body style={{ margin: 0, fontFamily: "system-ui, sans-serif", background: "#fff", color: "#171717" }}>
        <main style={{ minHeight: "100dvh", display: "grid", placeItems: "center", padding: 24 }}>
          <section role="alert" style={{ width: "100%", maxWidth: 420, textAlign: "center", display: "grid", gap: 16 }}>
            <h1 style={{ fontSize: 22, margin: 0 }}>WYNOS พบปัญหาระหว่างโหลด</h1>
            <p style={{ lineHeight: 1.6 }}>ลองโหลดใหม่อีกครั้งเมื่อการเชื่อมต่อพร้อม หากกำลังเขียนโพสต์อยู่ให้ตรวจสอบฉบับร่างก่อนส่งซ้ำ</p>
            <button type="button" onClick={reset} style={{ minHeight: 48, borderRadius: 12, border: 0, background: "#171717", color: "#fff", fontSize: 16, fontWeight: 650 }}>
              ลองอีกครั้ง
            </button>
            <a href="/" style={{ minHeight: 44, display: "grid", placeItems: "center", color: "#171717" }}>กลับหน้าหลัก</a>
          </section>
        </main>
      </body>
    </html>
  );
}
