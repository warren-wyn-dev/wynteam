"use client";

import Image from "next/image";
import { useEffect, useState } from "react";

import { WynosIcon } from "@/components/ui/wynos-icon";

const DISMISS_KEY = "wyn-install-prompt-dismissed-at";
const DISMISS_COOLDOWN_MS = 7 * 24 * 60 * 60 * 1000;
const SHOW_DELAY_MS = 20000;
const OPEN_INSTALL_EVENT = "wynos:open-install";

type BeforeInstallPromptEvent = Event & {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: "accepted" | "dismissed" }>;
};

function isStandalone() {
  try {
    return window.matchMedia("(display-mode: standalone)").matches || (window.navigator as Navigator & { standalone?: boolean }).standalone === true;
  } catch {
    return false;
  }
}

function isIos() {
  if (/iphone|ipad|ipod/i.test(navigator.userAgent)) return true;
  // iPadOS 13+ Safari's default UA masquerades as desktop macOS Safari (no
  // "iPad" substring at all) — the standard sniff for it is a "Mac" UA that
  // also reports touch points, which no real Mac ever does.
  return navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1;
}

function readDismissedAt(): number | null {
  try {
    const raw = window.localStorage.getItem(DISMISS_KEY);
    return raw ? Number(raw) : null;
  } catch {
    return null;
  }
}

function writeDismissedAt() {
  try {
    window.localStorage.setItem(DISMISS_KEY, String(Date.now()));
  } catch {
    // Private-browsing/blocked storage: banner just won't remember the dismissal this time.
  }
}

export function InstallPromptBanner() {
  const [deferredEvent, setDeferredEvent] = useState<BeforeInstallPromptEvent | null>(null);
  const [platform, setPlatform] = useState<"android" | "ios" | null>(null);
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (isStandalone()) return;

    const dismissedAt = readDismissedAt();
    const mayAutoShow = !dismissedAt || Date.now() - dismissedAt >= DISMISS_COOLDOWN_MS;
    const ios = isIos();
    let showTimer: number | null = null;

    // The settings shortcut always works, even during the automatic
    // banner's seven-day dismissal cooldown.
    function openInstall() {
      if (isStandalone()) return;
      if (showTimer !== null) window.clearTimeout(showTimer);
      showTimer = null;
      setPlatform(ios ? "ios" : "android");
      setVisible(true);
    }

    function onAppInstalled() {
      if (showTimer !== null) window.clearTimeout(showTimer);
      showTimer = null;
      writeDismissedAt();
      setDeferredEvent(null);
      setVisible(false);
    }

    function onBeforeInstallPrompt(event: Event) {
      event.preventDefault();
      setDeferredEvent(event as BeforeInstallPromptEvent);
      if (mayAutoShow && showTimer === null) {
        showTimer = window.setTimeout(() => {
          setPlatform("android");
          setVisible(true);
        }, SHOW_DELAY_MS);
      }
    }

    window.addEventListener(OPEN_INSTALL_EVENT, openInstall);
    window.addEventListener("appinstalled", onAppInstalled);
    if (!ios) window.addEventListener("beforeinstallprompt", onBeforeInstallPrompt);
    if (ios && mayAutoShow) {
      showTimer = window.setTimeout(() => {
        setPlatform("ios");
        setVisible(true);
      }, SHOW_DELAY_MS);
    }

    return () => {
      window.removeEventListener(OPEN_INSTALL_EVENT, openInstall);
      window.removeEventListener("appinstalled", onAppInstalled);
      if (!ios) window.removeEventListener("beforeinstallprompt", onBeforeInstallPrompt);
      if (showTimer !== null) window.clearTimeout(showTimer);
    };
  }, []);

  const dismiss = () => {
    writeDismissedAt();
    setVisible(false);
  };

  const install = async () => {
    if (!deferredEvent) return;
    try {
      await deferredEvent.prompt();
      await deferredEvent.userChoice;
      setDeferredEvent(null);
      // Whether accepted or dismissed, avoid showing an automatic prompt again.
      dismiss();
    } catch {
      // Chrome may invalidate a saved prompt event. Keep the banner open
      // and show the manual install instructions instead of failing silently.
      setDeferredEvent(null);
    }
  };

  if (!visible || !platform) return null;

  return (
    <div className="install-prompt-banner" role="dialog" aria-label="เพิ่ม WYNOS ไว้ที่หน้าจอหลัก">
      <div className="install-prompt-row">
        <Image className="install-prompt-icon" src="/icons/icon-192.png" alt="" width={44} height={44} />
        <div className="install-prompt-copy">
          <strong>เพิ่ม WYNOS ไว้ที่หน้าจอหลัก</strong>
          <small>{platform === "ios" ? "เปิดเร็วขึ้น ไม่มีแถบเบราว์เซอร์ เหมือนแอปจริง" : "เปิดได้เร็วขึ้น ใช้งานแบบเต็มจอเหมือนแอป"}</small>
        </div>
        <button type="button" className="install-prompt-close" aria-label="ปิด" onClick={dismiss}>
          <WynosIcon name="close" size={16} strokeWidth={2} />
        </button>
      </div>
      {platform === "android" && deferredEvent ? (
        <div className="install-prompt-actions">
          <button type="button" className="install-prompt-ghost" onClick={dismiss}>ไม่ใช่ตอนนี้</button>
          <button type="button" className="install-prompt-primary" onClick={() => void install()}>ติดตั้ง</button>
        </div>
      ) : platform === "android" ? (
        <ol className="install-prompt-steps">
          <li><span className="install-prompt-step-index">1</span>เปิด WYNOS ใน Chrome แล้วแตะเมนู ⋮</li>
          <li><span className="install-prompt-step-index">2</span>เลือก &quot;ติดตั้งแอป&quot; หรือ &quot;เพิ่มลงในหน้าจอหลัก&quot;</li>
          <li><span className="install-prompt-step-index">3</span>ยืนยันการติดตั้ง WYNOS</li>
        </ol>
      ) : (
        <ol className="install-prompt-steps">
          <li><span className="install-prompt-step-index">1</span>เปิด WYNOS ใน Safari แล้วแตะปุ่ม <WynosIcon name="share" size={14} strokeWidth={2} /> แชร์</li>
          <li><span className="install-prompt-step-index">2</span>เลื่อนหาแล้วแตะ &quot;เพิ่มไปยังหน้าจอโฮม&quot;</li>
          <li><span className="install-prompt-step-index">3</span>แตะ &quot;เพิ่ม&quot; เพื่อยืนยัน</li>
        </ol>
      )}
    </div>
  );
}
