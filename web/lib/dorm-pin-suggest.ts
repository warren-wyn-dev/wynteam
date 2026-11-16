import type { SupabaseClient } from "@supabase/supabase-js";

import { dormPinNoticeComplete, type DormPinNotice } from "@/lib/dorm-pin-notice";

/**
 * Opt-in: a customer who saved a delivery address in a dorm can offer the dorm's name and the pin
 * of that address so the map can learn where the dorm is. Only the name and one position are sent
 * (never room, floor, name, phone or address). The offer never blocks saving the address and a
 * missing database function is not an error (see norswor-backend `dorm_pin_suggestions`).
 */
export const DORM_PIN_CONSENT_VERSION = "2026-11-16-th-1";

// The area the map is collecting dorms for (the database enforces the same box).
const LAT_MIN = 15.5, LAT_MAX = 16.8, LNG_MIN = 102.8, LNG_MAX = 103.6;

export type DormPinResult = "sent" | "skipped" | "unavailable" | "failed";

/** Where the delivery pin came from. Only a reading of the device GPS may be offered to the map. */
export type DeliveryPinSource = { kind: "gps"; accuracyM: number | null } | { kind: "search" };

// A reading worse than this cannot tell one dorm from the next, so the box is not offered.
export const DORM_PIN_MAX_GPS_ACCURACY_M = 50;

export function dormPinGpsUsable(source: DeliveryPinSource | null | undefined): source is { kind: "gps"; accuracyM: number } {
  return source?.kind === "gps" && typeof source.accuracyM === "number" && Number.isFinite(source.accuracyM)
    && source.accuracyM >= 0 && source.accuracyM <= DORM_PIN_MAX_GPS_ACCURACY_M;
}

export function dormPinName(raw: string | null | undefined): string | null {
  const text = (raw ?? "").replace(/[\u0000-\u001f\u007f]/g, "").replace(/\s+/g, " ").trim();
  return text.length >= 2 ? text.slice(0, 80) : null;
}

export function inDormPinArea(location: { latitude: number; longitude: number } | null | undefined): boolean {
  return Boolean(location)
    && Number.isFinite(location!.latitude) && Number.isFinite(location!.longitude)
    && location!.latitude >= LAT_MIN && location!.latitude <= LAT_MAX
    && location!.longitude >= LNG_MIN && location!.longitude <= LNG_MAX;
}

/** The checkbox is offered only with a building name, a pin inside the collecting area and a complete notice (controller and contact). */
export function dormPinOffered(
  buildingName: string | null | undefined,
  location: { latitude: number; longitude: number } | null | undefined,
  notice?: DormPinNotice,
): boolean {
  return dormPinName(buildingName) !== null && inDormPinArea(location) && dormPinNoticeComplete(notice);
}

function missingFunction(error: { code?: string; message?: string } | null): boolean {
  return error?.code === "PGRST202" || error?.code === "42883" || /could not find the function|does not exist/i.test(error?.message ?? "");
}

export async function suggestDormPin(
  client: Pick<SupabaseClient, "rpc">,
  input: { buildingName: string | null | undefined; location: { latitude: number; longitude: number } | null | undefined; accuracyM?: number | null },
): Promise<DormPinResult> {
  const name = dormPinName(input.buildingName);
  if (name === null || !input.location || !inDormPinArea(input.location)) return "skipped";
  // Only a usable GPS reading is sent, with its accuracy (the database keeps it for the reviewer).
  if (!dormPinGpsUsable({ kind: "gps", accuracyM: input.accuracyM ?? null })) return "skipped";
  try {
    const { error } = await client.rpc("dorm_pin_suggest", {
      p_name: name,
      p_latitude: input.location.latitude,
      p_longitude: input.location.longitude,
      p_accuracy_m: Math.round((input.accuracyM as number) * 10) / 10,
      p_consent_version: DORM_PIN_CONSENT_VERSION,
    });
    if (!error) return "sent";
    return missingFunction(error) ? "unavailable" : "failed";
  } catch {
    return "failed";
  }
}

/** Withdraws every offer of the signed-in customer. */
export async function withdrawDormPins(client: Pick<SupabaseClient, "rpc">): Promise<{ result: "done" | "unavailable" | "failed"; count: number }> {
  try {
    const { data, error } = await client.rpc("dorm_pin_withdraw_all");
    if (!error) return { result: "done", count: typeof data === "number" ? data : 0 };
    return { result: missingFunction(error) ? "unavailable" : "failed", count: 0 };
  } catch {
    return { result: "failed", count: 0 };
  }
}

// ---- the question after saving: asked once per dorm name, not again for 30 days ----
export const DORM_PIN_PROMPT_STORAGE_KEY = "zoky:dorm-pin-prompt";
export const DORM_PIN_PROMPT_COOLDOWN_MS = 30 * 24 * 60 * 60 * 1000;
const DORM_PIN_PROMPT_MAX_ENTRIES = 100;

type PromptStorage = Pick<Storage, "getItem" | "setItem">;

/** The same dorm under another spelling of spaces or punctuation is the same question. */
export function dormPinPromptKey(name: string | null | undefined): string | null {
  const clean = dormPinName(name);
  if (clean === null) return null;
  const key = clean.toLowerCase().replace(/[\s!-/:-@[-`{-~]/g, "");
  return key.length >= 2 ? key : null;
}

function readPromptLog(storage: PromptStorage | null): Record<string, number> {
  try {
    const parsed: unknown = JSON.parse(storage?.getItem(DORM_PIN_PROMPT_STORAGE_KEY) ?? "{}");
    if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) return {};
    return Object.fromEntries(Object.entries(parsed as Record<string, unknown>).filter(([, value]) => typeof value === "number" && Number.isFinite(value))) as Record<string, number>;
  } catch {
    return {};
  }
}

export function dormPinPromptAllowed(storage: PromptStorage | null, name: string | null | undefined, now: number = Date.now()): boolean {
  const key = dormPinPromptKey(name);
  if (key === null) return false;
  const asked = readPromptLog(storage)[key];
  return asked === undefined || now - asked >= DORM_PIN_PROMPT_COOLDOWN_MS;
}

export function rememberDormPinPrompt(storage: PromptStorage | null, name: string | null | undefined, now: number = Date.now()): void {
  const key = dormPinPromptKey(name);
  if (key === null || !storage) return;
  const log = { ...readPromptLog(storage), [key]: now };
  const newest = Object.entries(log).sort((a, b) => b[1] - a[1]).slice(0, DORM_PIN_PROMPT_MAX_ENTRIES);
  try { storage.setItem(DORM_PIN_PROMPT_STORAGE_KEY, JSON.stringify(Object.fromEntries(newest))); } catch { /* private mode: asked again next time */ }
}
