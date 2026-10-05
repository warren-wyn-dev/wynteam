"use client";

export type MerchantAlertPreferences = {
  sound_enabled: boolean;
  vibration_enabled: boolean;
  quiet_enabled: boolean;
  quiet_start: string;
  quiet_end: string;
};

export const MERCHANT_ALERT_PREFS_KEY = "wynos.merchant.alert-prefs.v1";
export const MERCHANT_ALERT_PREFS_EVENT = "wynos:merchant-alert-prefs";

export const DEFAULT_MERCHANT_ALERT_PREFS: MerchantAlertPreferences = {
  sound_enabled: true,
  vibration_enabled: true,
  quiet_enabled: false,
  quiet_start: "22:00",
  quiet_end: "08:00",
};

function validClock(value: unknown, fallback: string) {
  return typeof value === "string" && /^([01]\d|2[0-3]):[0-5]\d$/.test(value) ? value : fallback;
}

export function readMerchantAlertPreferences(): MerchantAlertPreferences {
  if (typeof window === "undefined") return DEFAULT_MERCHANT_ALERT_PREFS;
  try {
    const raw = JSON.parse(window.localStorage.getItem(MERCHANT_ALERT_PREFS_KEY) ?? "null") as Partial<MerchantAlertPreferences> | null;
    if (!raw) return DEFAULT_MERCHANT_ALERT_PREFS;
    return {
      sound_enabled: raw.sound_enabled !== false,
      vibration_enabled: raw.vibration_enabled !== false,
      quiet_enabled: raw.quiet_enabled === true,
      quiet_start: validClock(raw.quiet_start, DEFAULT_MERCHANT_ALERT_PREFS.quiet_start),
      quiet_end: validClock(raw.quiet_end, DEFAULT_MERCHANT_ALERT_PREFS.quiet_end),
    };
  } catch {
    return DEFAULT_MERCHANT_ALERT_PREFS;
  }
}

export function saveMerchantAlertPreferences(next: MerchantAlertPreferences) {
  try {
    window.localStorage.setItem(MERCHANT_ALERT_PREFS_KEY, JSON.stringify(next));
    window.dispatchEvent(new CustomEvent(MERCHANT_ALERT_PREFS_EVENT, { detail: next }));
  } catch {
    // Private browsing can disable localStorage; current UI state still works.
  }
}

function clockMinutes(value: string) {
  const [hour, minute] = value.split(":").map(Number);
  return hour * 60 + minute;
}

export function merchantAlertQuietNow(prefs: MerchantAlertPreferences, now = new Date()) {
  if (!prefs.quiet_enabled) return false;
  const start = clockMinutes(prefs.quiet_start);
  const end = clockMinutes(prefs.quiet_end);
  if (start === end) return false;
  const current = now.getHours() * 60 + now.getMinutes();
  return start < end ? current >= start && current < end : current >= start || current < end;
}
