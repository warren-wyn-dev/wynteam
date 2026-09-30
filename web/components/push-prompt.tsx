"use client";

import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";

import { WynosIcon } from "@/components/ui/wynos-icon";
import {
  getPushAvailability,
  isPushPromptPath,
  PUSH_PROMPT_DISMISS_KEY,
  pushPromptKind,
  pushReasonDescription,
  subscribeToPushNotifications,
} from "@/lib/push-notifications";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

const SHOW_DELAY_MS = 4000;
const HIGH_INTENT_SHOW_DELAY_MS = 1200;
// Same event the Settings install row uses to open the install instructions.
const OPEN_INSTALL_EVENT = "wynos:open-install";

function readDismissedAt(): number | null {
  try {
    const raw = window.localStorage.getItem(PUSH_PROMPT_DISMISS_KEY);
    const value = raw ? Number(raw) : NaN;
    return Number.isFinite(value) ? value : null;
  } catch {
    return null;
  }
}

function writeDismissedAt() {
  try {
    window.localStorage.setItem(PUSH_PROMPT_DISMISS_KEY, String(Date.now()));
  } catch {
    // Blocked storage: the card just may come back on the next visit.
  }
}

/**
 * Asks signed-in people who have not answered the notification question yet
 * to turn on Push (Founder decision 2026-09-27, all accounts). The OS
 * permission popup opens only from the Allow button's tap.
 */
export function PushPrompt() {
  const pathname = usePathname() ?? "";
  const [userId, setUserId] = useState<string | null>(null);
  // Tied to the account it was worked out for, so it never shows for the next account.
  const [prompt, setPrompt] = useState<{ userId: string; kind: "ask" | "install" | "settings" } | null>(null);
  const kind = prompt && prompt.userId === userId && isPushPromptPath(pathname) ? prompt.kind : null;
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    const client = getSupabaseBrowserClient();
    if (!client) return;
    const { data } = client.auth.onAuthStateChange((_event, session) => {
      setUserId(session?.user?.id ?? null);
    });
    return () => data.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (!userId) return;
    let cancelled = false;
    const delay = /^\/(chat|notifications)(\/|$)/.test(pathname)
      ? HIGH_INTENT_SHOW_DELAY_MS
      : SHOW_DELAY_MS;
    const timer = window.setTimeout(async () => {
      const permission = typeof Notification === "undefined" ? "unsupported" : Notification.permission;
      // Granted needs no prompt. Denied skips Firebase loading but can still
      // show a recovery card on Chat/Notifications.
      if (permission === "granted") return;
      const availability = permission === "denied"
        ? ({ available: false, reason: "denied" } as const)
        : await getPushAvailability();
      if (cancelled) return;
      const next = pushPromptKind({ path: pathname, permission, availability, dismissedAt: readDismissedAt(), now: Date.now() });
      setPrompt(next ? { userId, kind: next } : null);
    }, delay);
    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [userId, pathname]);

  // While the card is open, the install banner waits behind it (install-prompt.css).
  useEffect(() => {
    if (!kind) return;
    document.documentElement.dataset.wynosPushPrompt = "open";
    return () => {
      delete document.documentElement.dataset.wynosPushPrompt;
    };
  }, [kind]);

  if (!kind || !userId) return null;

  const dismiss = () => {
    writeDismissedAt();
    setPrompt(null);
  };

  const allow = async () => {
    const client = getSupabaseBrowserClient();
    if (busy || !client) return;
    setBusy(true);
    setError("");
    // First awaited browser call is the permission request (tap required on iOS).
    const result = await subscribeToPushNotifications(client, userId);
    setBusy(false);
    if (result.ok) {
      setPrompt(null);
      return;
    }
    // Not now in the OS popup: ask again in a week, not on every page.
    if (result.reason === "dismissed") writeDismissedAt();
    setError(pushReasonDescription(result.reason));
  };

  const showInstall = () => {
    // This is forward progress, not a dismissal. Do not start the seven-day
    // Push cooldown: after the user installs/opens the iOS Home Screen app,
    // WYNOS should be able to ask for notification permission right away.
    setPrompt(null);
    window.dispatchEvent(new Event(OPEN_INSTALL_EVENT));
  };

  const showPermissionHelp = () => {
    writeDismissedAt();
    window.location.assign("/settings");
  };

  return (
    <div className="install-prompt-banner push-prompt-banner" role="dialog" aria-label="เปิดการแจ้งเตือน">
      <div className="install-prompt-row">
        <span className="push-prompt-icon" aria-hidden="true"><WynosIcon name="notifications" size={22} strokeWidth={2} /></span>
        <div className="install-prompt-copy">
          <strong>{kind === "settings" ? "เปิดการแจ้งเตือนอีกครั้ง" : "เปิดการแจ้งเตือน"}</strong>
          <small>{kind === "install" ?
            "บน iPhone/iPad ต้องเพิ่ม WYNOS ไปยังหน้าจอโฮมก่อน จึงจะรับการแจ้งเตือนได้" :
            kind === "settings" ?
              "เบราว์เซอร์ปิดสิทธิ์แจ้งเตือนอยู่ เปิดสิทธิ์ให้ WYNOS เพื่อไม่พลาดข้อความและการตอบกลับ" :
              "รู้ทันทีเมื่อมีข้อความ การตอบกลับ และกิจกรรมสำคัญใน WYNOS"}</small>
        </div>
        <button type="button" className="install-prompt-close" aria-label="ปิด" onClick={dismiss}>
          <WynosIcon name="close" size={16} strokeWidth={2} />
        </button>
      </div>
      {error ? <p className="route-error push-prompt-error" role="alert">{error}</p> : null}
      <div className="install-prompt-actions">
        <button type="button" className="install-prompt-ghost" onClick={dismiss}>ไม่ใช่ตอนนี้</button>
        {kind === "install" ?
          <button type="button" className="install-prompt-primary" onClick={showInstall}>วิธีเพิ่มไปยังหน้าจอโฮม</button> :
          kind === "settings" ?
            <button type="button" className="install-prompt-primary" onClick={showPermissionHelp}>ดูวิธีเปิด</button> :
            <button type="button" className="install-prompt-primary" disabled={busy} onClick={() => void allow()}>{busy ? "กำลังเปิด…" : "เปิดการแจ้งเตือน"}</button>}
      </div>
    </div>
  );
}
