"use client";

// ZOKY-LINE-002 F: tell users inside the LINE in-app browser that Google
// sign-in is blocked there. Informational only: no redirect, the Google
// button stays, the guest basket is never touched.
import { Info } from "lucide-react";
import { useEffect, useState } from "react";

import { configuredLiffIds, foodLoginExternalUrl, isLineUserAgent, liffIdFor } from "@/lib/line-liff";

const LINE_GOOGLE_HINT = "ถ้าเห็นหน้าปฏิเสธจาก Google ให้ใช้อีเมลและรหัสผ่าน หรือเปิดในเบราว์เซอร์";

export function withLineGoogleHint(message: string): string {
  if (typeof navigator === "undefined" || !isLineUserAgent(navigator.userAgent)) return message;
  return `${message} ${LINE_GOOGLE_HINT}`;
}

type Liff = typeof import("@line/liff").default;
type Slot = "pending" | "ready" | "unavailable";

async function loadLiff(liffId: string): Promise<Liff> {
  const { default: liff } = await import("@line/liff");
  await liff.init({ liffId });
  return liff;
}

export function LineLoginGuidance() {
  const [inLine, setInLine] = useState(false);
  const [slot, setSlot] = useState<Slot>("pending");
  const [opening, setOpening] = useState(false);
  const [openError, setOpenError] = useState(false);

  useEffect(() => {
    if (!isLineUserAgent(navigator.userAgent)) return;
    let live = true;
    // Same async-after-mount pattern as food-auth: state is set from a promise.
    void (async () => {
      setInLine(true);
      const liffId = liffIdFor("food", configuredLiffIds());
      if (!liffId) { setSlot("unavailable"); return; }
      try {
        const liff = await loadLiff(liffId);
        if (live) setSlot(liff.isInClient() ? "ready" : "unavailable");
      } catch {
        if (live) setSlot("unavailable");
      }
    })();
    return () => { live = false; };
  }, []);

  async function openExternal() {
    if (opening) return;
    setOpening(true);
    setOpenError(false);
    // Re-enable after at most 3 seconds, whatever LINE does with the window.
    window.setTimeout(() => setOpening(false), 3000);
    try {
      const liffId = liffIdFor("food", configuredLiffIds());
      if (!liffId) throw new Error("liff_not_configured");
      const liff = await loadLiff(liffId);
      liff.openWindow({ url: foodLoginExternalUrl(window.location.origin), external: true });
    } catch {
      setOpenError(true);
      setOpening(false);
    }
  }

  if (!inLine) return null;
  return (
    <div className="wf-auth-note wf-auth-note--line" role="note">
      <Info size={17} aria-hidden="true" />
      <p>
        <strong>เปิดใน LINE อยู่</strong>
        <span>Google ไม่อนุญาตให้เข้าสู่ระบบในแอป LINE ใช้อีเมลและรหัสผ่านต่อได้เลย ตะกร้าของคุณยังอยู่ หรือเปิดในเบราว์เซอร์ของเครื่องเพื่อเข้าสู่ระบบด้วย Google</span>
      </p>
      {slot === "unavailable" ? (
        <p className="wf-auth-line-slot">
          <span>เปิดเบราว์เซอร์จากที่นี่ไม่ได้ เปิดหน้านี้ในเบราว์เซอร์ของเครื่อง หรือใช้อีเมลและรหัสผ่านต่อได้เลย</span>
        </p>
      ) : (
        <div className="wf-auth-line-slot">
          {slot === "ready" ? (
            <>
              <span className="wf-auth-line-warning">ถ้าเปิดในเบราว์เซอร์ ตะกร้าจะไม่ถูกย้ายไปด้วย ต้องเลือกเมนูใหม่อีกครั้ง</span>
              <button
                className="wf-auth-line-open"
                type="button"
                disabled={opening}
                aria-busy={opening}
                aria-label="เปิดหน้าเข้าสู่ระบบในเบราว์เซอร์ของเครื่อง ตะกร้าจะไม่ถูกย้ายไปด้วย"
                onClick={() => void openExternal()}
              >{opening ? "กำลังเปิด…" : "เปิดในเบราว์เซอร์"}</button>
            </>
          ) : null}
        </div>
      )}
      {openError ? <p className="wf-auth-error" role="alert">เปิดเบราว์เซอร์ไม่สำเร็จ ลองกดอีกครั้ง หรือใช้อีเมลและรหัสผ่านต่อได้เลย ตะกร้ายังอยู่</p> : null}
    </div>
  );
}
