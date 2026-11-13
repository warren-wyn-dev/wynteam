// Founder 2026-11-13: a quick "test notifications" button for ZOKY customers.
// It shows a notification on THIS device through the service worker, so it
// checks the permission and that the phone can display ZOKY notifications.
// It does not go through the server, so it does not prove delivery from ZOKY.

/** Sent by the ZOKY notification card so the Account page refreshes its switch. */
export const ZOKY_PUSH_ENABLED_EVENT = "zoky:push-enabled";

export type ZokyNotificationTestResult =
  | { ok: true }
  | { ok: false; reason: "unsupported" | "not-granted" | "failed" };

export function zokyNotificationTestMessage(result: ZokyNotificationTestResult): string {
  if (result.ok) return "ส่งแจ้งเตือนทดสอบแล้ว ถ้าเห็นข้อความที่ด้านบนหน้าจอ แปลว่าเครื่องนี้แสดงการแจ้งเตือนได้ปกติ";
  if (result.reason === "unsupported") return "เครื่องหรือเบราว์เซอร์นี้ยังไม่รองรับการแจ้งเตือน บน iPhone ให้เพิ่ม ZOKY ไปยังหน้าจอโฮมก่อน";
  if (result.reason === "not-granted") return "ยังไม่ได้อนุญาตการแจ้งเตือน กรุณาเปิดการแจ้งเตือนก่อน แล้วลองทดสอบอีกครั้ง";
  return "ทดสอบการแจ้งเตือนไม่สำเร็จ กรุณาลองใหม่";
}

export async function showZokyTestNotification(): Promise<ZokyNotificationTestResult> {
  if (typeof window === "undefined" || typeof Notification === "undefined" || !("serviceWorker" in navigator)) {
    return { ok: false, reason: "unsupported" };
  }
  if (Notification.permission !== "granted") return { ok: false, reason: "not-granted" };
  try {
    const registration = (await navigator.serviceWorker.getRegistration("/")) ?? (await navigator.serviceWorker.ready);
    await registration.showNotification("ZOKY", {
      body: "ทดสอบการแจ้งเตือน: ถ้าเห็นข้อความนี้ แจ้งเตือนของ ZOKY ทำงานปกติ",
      icon: "/icons/food/icon-192.png",
      tag: "zoky-notification-test",
      data: { app: "food" },
    });
    return { ok: true };
  } catch {
    return { ok: false, reason: "failed" };
  }
}
