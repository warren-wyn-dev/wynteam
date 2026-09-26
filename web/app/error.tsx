"use client";

import { useEffect } from "react";
import Link from "next/link";

import { reportClientFailure } from "@/lib/client-health";

/** A recoverable route failure should not leave the installed PWA blank. */
export default function ErrorPage({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    reportClientFailure("route_render");
  }, [error]);

  return (
    <main style={{ minHeight: "100dvh", display: "grid", placeItems: "center", padding: 24, background: "var(--wyn-bg, #fff)", color: "var(--wyn-text, #171717)" }}>
      <section role="alert" style={{ width: "100%", maxWidth: 420, textAlign: "center", display: "grid", gap: 16 }}>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>โหลดหน้านี้ไม่สำเร็จ</h1>
        <p style={{ lineHeight: 1.6 }}>ข้อมูลของคุณยังอยู่ในบัญชี กรุณาลองใหม่อีกครั้งเมื่อการเชื่อมต่อพร้อม</p>
        <button type="button" onClick={reset} style={{ minHeight: 48, borderRadius: 12, border: 0, background: "#171717", color: "white", fontWeight: 650, cursor: "pointer" }}>ลองอีกครั้ง</button>
        <Link href="/" style={{ minHeight: 44, display: "grid", placeItems: "center", textDecoration: "none" }}>กลับหน้าหลัก</Link>
      </section>
    </main>
  );
}
