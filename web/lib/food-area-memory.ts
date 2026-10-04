"use client";

import type { SupabaseClient } from "@supabase/supabase-js";
import { useCallback, useEffect, useState } from "react";

/**
 * WYN-212: the Home "WYNOS Food" banner only shows to people we already know
 * are in Maha Sarakham, so it does not bother everyone else. Food is still in
 * the drawer for all. Home never asks for GPS: it uses what Food learned
 * (WYN-211 area check) or the user's own saved delivery pin.
 */
type FoodAreaMemory = { area: "inside" | "outside" | "none"; at: number };

const DAY = 86_400_000;
const areaKey = (userId: string) => `wynos-food-area-v1:${userId}`;
const hiddenKey = (userId: string) => `wynos-food-shortcut-hidden-v1:${userId}`;

function read(key: string) {
  try { return localStorage.getItem(key); } catch { return null; }
}

function write(key: string, value: string) {
  try { localStorage.setItem(key, value); } catch { /* private mode */ }
}

export function rememberFoodArea(userId: string, area: FoodAreaMemory["area"]) {
  write(areaKey(userId), JSON.stringify({ area, at: Date.now() } satisfies FoodAreaMemory));
}

function recall(userId: string): FoodAreaMemory | null {
  try {
    const value = JSON.parse(read(areaKey(userId)) ?? "null") as FoodAreaMemory | null;
    return value && typeof value.at === "number" ? value : null;
  } catch {
    return null;
  }
}

/** Ask again after a week when outside, after a day when we knew nothing. */
function stale(memory: FoodAreaMemory) {
  if (memory.area === "inside") return false;
  return Date.now() - memory.at > (memory.area === "outside" ? 7 * DAY : DAY);
}

async function learnFromSavedPin(client: SupabaseClient, userId: string) {
  const { data, error } = await client
    .from("food_customer_addresses")
    .select("latitude,longitude,is_default")
    .eq("user_id", userId)
    .not("latitude", "is", null)
    .order("is_default", { ascending: false })
    .limit(1);
  if (error) throw new Error(error.message);
  const pin = data?.[0];
  if (!pin || pin.latitude == null || pin.longitude == null) return "none" as const;
  // Same RPC as Food's area check (food_service_area_check, WYN-211).
  const check = await client.rpc("food_service_area_check", { p_latitude: Number(pin.latitude), p_longitude: Number(pin.longitude) });
  if (check.error) throw new Error(check.error.message);
  return check.data === true ? "inside" as const : "outside" as const;
}

export function useHomeFoodShortcut(client: SupabaseClient | null | undefined, userId: string | undefined) {
  const [state, setState] = useState<{ userId: string; visible: boolean } | null>(null);

  useEffect(() => {
    if (!client || !userId) return;
    let live = true;
    const memory = recall(userId);
    const known = read(hiddenKey(userId)) === "1"
      ? Promise.resolve(false)
      : memory && !stale(memory)
        ? Promise.resolve(memory.area === "inside")
        : learnFromSavedPin(client, userId).then((area) => { rememberFoodArea(userId, area); return area === "inside"; });
    void known
      .then((visible) => { if (live) setState({ userId, visible }); })
      .catch(() => { if (live) setState({ userId, visible: false }); });
    return () => { live = false; };
  }, [client, userId]);

  const hide = useCallback(() => {
    if (!userId) return;
    write(hiddenKey(userId), "1");
    setState({ userId, visible: false });
  }, [userId]);

  return { visible: Boolean(client && userId && state && state.userId === userId && state.visible), hide };
}
