"use client";

import Image from "next/image";
import { useEffect, useState } from "react";

import { WynosIcon } from "@/components/ui/wynos-icon";

const DISMISS_KEY = "wyn-install-prompt-dismissed-at";
const DISMISS_COOLDOWN_MS = 7 * 24 * 60 * 60 * 1000;
const SHOW_DELAY_MS = 20000;

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
  return /iphone|ipad|ipod/i.test(navigator.userAgent);
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
    if (dismissedAt && Date.now() - dismissedAt < DISMISS_COOLDOWN_MS) return;

    if (isIos()) {
      const timer = window.setTimeout(() => {
        setPlatform("ios");
        setVisible(true);
      }, SHOW_DELAY_MS);
      return () => window.clearTimeout(timer);
    }

    let showTimer: number | null = null;
    function onBeforeInstallPrompt(event: Event) {
      event.preventDefault();
      setDeferredEvent(event as BeforeInstallPromptEvent);
      showTimer = window.setTimeout(() => {
        setPlatform("android");
        setVisible(true);
      }, SHOW_DELAY_MS);
    }

    window.addEventListener("beforeinstallprompt", onBeforeInstallPrompt);
    return () => {
      window.removeEventListener("beforeinstallprompt", onBeforeInstallPrompt);
      if (showTimer) window.clearTimeout(showTimer);
    };
  }, []);

  const dismiss = () => {
    writeDismissedAt();
    setVisible(false);
  };

  const install = async () => {
    if (!deferredEvent) return;
    await deferredEvent.prompt();
    const choice = await deferredEvent.userChoice;
    setDeferredEvent(null);
    if (choice.outcome === "accepted") setVisible(false);
    else dismiss();
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
      {platform === "android" ? (
        <div className="install-prompt-actions">
          <button type="button" className="install-prompt-ghost" onClick={dismiss}>ไม่ใช่ตอนนี้</button>
          <button type="button" className="install-prompt-primary" onClick={() => void install()}>ติดตั้ง</button>
        </div>
      ) : (
        <ol className="install-prompt-steps">
          <li><span className="install-prompt-step-index">1</span>แตะปุ่ม <WynosIcon name="share" size={14} strokeWidth={2} /> แชร์ ด้านล่าง</li>
          <li><span className="install-prompt-step-index">2</span>เลื่อนหาแล้วแตะ &quot;เพิ่มไปยังหน้าจอโฮม&quot;</li>
          <li><span className="install-prompt-step-index">3</span>แตะ &quot;เพิ่ม&quot; มุมขวาบน</li>
        </ol>
      )}
    </div>
  );
}
