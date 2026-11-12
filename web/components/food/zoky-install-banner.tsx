"use client";

import { useEffect, useState } from "react";

import { WynosIcon } from "@/components/ui/wynos-icon";
import { isFoodAppHost } from "@/lib/food-origin";
import {
  isEmbeddedFrame,
  isIosDevice,
  readZokyDismissedAt,
  writeZokyDismissedAt,
  ZOKY_INSTALL_SHOW_DELAY_MS,
  ZOKY_OPEN_URL,
  zokyInstallMode,
  type ZokyInstallMode,
} from "@/lib/zoky-pwa";

type BeforeInstallPromptEvent = Event & {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: "accepted" | "dismissed" }>;
};

function isStandalone() {
  try {
    return window.matchMedia("(display-mode: standalone)").matches ||
      (window.navigator as Navigator & { standalone?: boolean }).standalone === true;
  } catch {
    return false;
  }
}

function safeStorage(): Storage | null {
  try {
    return window.localStorage;
  } catch {
    return null;
  }
}

/** "Add ZOKY to the Home Screen" card. Only on ZOKY hosts (the WYNOS card stays excluded there). */
export function ZokyInstallBanner() {
  const [event, setEvent] = useState<BeforeInstallPromptEvent | null>(null);
  const [mode, setMode] = useState<ZokyInstallMode | null>(null);

  useEffect(() => {
    if (!isFoodAppHost(window.location.hostname)) return;
    const embedded = isEmbeddedFrame(window);
    const ios = isIosDevice(navigator.userAgent, navigator.platform, navigator.maxTouchPoints ?? 0);
    let saved: BeforeInstallPromptEvent | null = null;

    const evaluate = () => {
      setMode(zokyInstallMode({
        standalone: isStandalone(),
        embedded,
        ios,
        hasInstallEvent: saved !== null,
        dismissedAt: readZokyDismissedAt(safeStorage()),
        now: Date.now(),
      }));
    };
    const onBeforeInstall = (e: Event) => {
      e.preventDefault();
      saved = e as BeforeInstallPromptEvent;
      setEvent(saved);
      evaluate();
    };
    const onInstalled = () => {
      saved = null;
      setEvent(null);
      writeZokyDismissedAt(safeStorage(), Date.now());
      setMode(null);
    };

    // The Push card's "how to add to Home Screen" button asks for this card
    // explicitly, so it ignores the dismissal cooldown.
    const onOpenRequested = () => {
      setMode(zokyInstallMode({
        standalone: isStandalone(),
        embedded,
        ios,
        hasInstallEvent: saved !== null,
        dismissedAt: null,
        now: Date.now(),
      }));
    };

    window.addEventListener("beforeinstallprompt", onBeforeInstall);
    window.addEventListener("appinstalled", onInstalled);
    window.addEventListener("wynos:open-install", onOpenRequested);
    // Wait a moment so the card never covers the first screen.
    const timer = window.setTimeout(evaluate, ZOKY_INSTALL_SHOW_DELAY_MS);
    return () => {
      window.removeEventListener("beforeinstallprompt", onBeforeInstall);
      window.removeEventListener("appinstalled", onInstalled);
      window.removeEventListener("wynos:open-install", onOpenRequested);
      window.clearTimeout(timer);
    };
  }, []);

  if (!mode) return null;

  const dismiss = () => {
    writeZokyDismissedAt(safeStorage(), Date.now());
    setMode(null);
  };
  const install = async () => {
    if (!event) return;
    try {
      await event.prompt();
      await event.userChoice;
    } catch {
      // Chrome may invalidate a saved event; just close the card.
    }
    setEvent(null);
    dismiss();
  };

  const title = mode === "open-browser" ? "เปิด ZOKY ในเบราว์เซอร์" : "เพิ่ม ZOKY ไว้ที่หน้าจอหลัก";
  const hint = mode === "open-browser"
    ? "หน้าต่างนี้ติดตั้งแอปและรับแจ้งเตือนไม่ได้ เปิดในเบราว์เซอร์เพื่อติดตั้งและรับแจ้งสถานะออเดอร์"
    : mode === "ios"
      ? "บน iPhone ต้องเพิ่มไปยังหน้าจอโฮมก่อน จึงจะรับแจ้งเตือนออเดอร์ได้"
      : "เปิดเร็วขึ้น เต็มจอเหมือนแอป และรับแจ้งเตือนสถานะออเดอร์";

  return (
    <div className="install-prompt-banner zoky-install-banner" role="dialog" aria-label={title}>
      <div className="install-prompt-row">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img className="install-prompt-icon" src="/icons/zoky/icon-192-v1.png" alt="" width={44} height={44} />
        <div className="install-prompt-copy">
          <strong>{title}</strong>
          <small>{hint}</small>
        </div>
        <button type="button" className="install-prompt-close" aria-label="ปิด" onClick={dismiss}>
          <WynosIcon name="close" size={16} strokeWidth={2} />
        </button>
      </div>
      {mode === "ios" ? (
        <ol className="install-prompt-steps">
          <li><span className="install-prompt-step-index">1</span>กดปุ่มแชร์ <WynosIcon name="share" size={14} strokeWidth={2} /> ใน Safari</li>
          <li><span className="install-prompt-step-index">2</span>เลือก &quot;เพิ่มไปยังหน้าจอโฮม&quot;</li>
        </ol>
      ) : (
        <div className="install-prompt-actions">
          <button type="button" className="install-prompt-ghost" onClick={dismiss}>ไม่ใช่ตอนนี้</button>
          {mode === "open-browser" ? (
            <a className="install-prompt-primary" href={ZOKY_OPEN_URL} target="_blank" rel="noopener noreferrer" onClick={dismiss}>
              เปิด Zoky ในเบราว์เซอร์
            </a>
          ) : (
            <button type="button" className="install-prompt-primary" onClick={() => void install()}>ติดตั้ง</button>
          )}
        </div>
      )}
    </div>
  );
}
