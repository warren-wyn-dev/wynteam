import type { SupabaseClient } from "@supabase/supabase-js";

export type FoodHomePlacementKind = "banner" | "featured";
export type FoodHomeAnalytics = ReturnType<typeof createFoodHomeAnalytics>;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isFoodHomePlacement(kind: unknown, id: unknown): kind is FoodHomePlacementKind {
  return (kind === "banner" || kind === "featured") && typeof id === "string" && UUID.test(id);
}

type Exposure = { id: string; impression?: Promise<boolean>; click?: Promise<boolean> };

/** A page-lifetime receipt key, never a stored or account-linked visitor identity. */
export function createFoodHomeAnalytics(client: Pick<SupabaseClient, "rpc">) {
  const exposures = new Map<string, Exposure>();
  let disposed = false;

  function exposureFor(kind: FoodHomePlacementKind, id: string): Exposure | undefined {
    if (disposed || !isFoodHomePlacement(kind, id)) return;
    const key = `${kind}:${id.toLowerCase()}`;
    const existing = exposures.get(key);
    if (existing) return existing;
    try {
      const exposure = { id: globalThis.crypto.randomUUID() };
      exposures.set(key, exposure);
      return exposure;
    } catch {
      // Browsing continues when secure random IDs are unavailable.
      return;
    }
  }

  async function send(kind: FoodHomePlacementKind, id: string, exposure: Exposure, event: "impression" | "click") {
    for (let attempt = 0; attempt < 2; attempt += 1) {
      try {
        const { data, error } = await client.rpc("food_record_home_placement_event", {
          p_placement_kind: kind,
          p_placement_id: id,
          p_exposure_id: exposure.id,
          p_event_type: event,
        }).abortSignal(AbortSignal.timeout(3_000));
        if (error) continue;
        if (data && typeof data === "object" && typeof data.recorded === "boolean") {
          return data.recorded || data.reason === "duplicate";
        }
      } catch {
        // Retry an uncertain transport result once with the same receipt key.
      }
    }
    return false;
  }

  function observeImpression(kind: FoodHomePlacementKind, id: string): Promise<boolean> {
    const exposure = exposureFor(kind, id);
    if (!exposure) return Promise.resolve(false);
    exposure.impression ??= send(kind, id, exposure, "impression");
    return exposure.impression;
  }

  function recordClick(kind: FoodHomePlacementKind, id: string): Promise<boolean> {
    const exposure = exposureFor(kind, id);
    if (!exposure) return Promise.resolve(false);
    // Intentional activation also qualifies an impression. Await the same write
    // if the visibility timer already started it, preserving server attribution.
    exposure.click ??= (async () => {
      if (!await observeImpression(kind, id)) return false;
      return send(kind, id, exposure, "click");
    })();
    return exposure.click;
  }

  return {
    observeImpression,
    recordClick,
    dispose() {
      // Stop new work, but let an activation already awaiting its impression
      // finish its bounded writes after in-app navigation unmounts the Home.
      disposed = true;
      exposures.clear();
    },
  };
}
