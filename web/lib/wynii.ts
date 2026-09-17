import type { RealtimeChannel, SupabaseClient } from "@supabase/supabase-js";

export type WyniiRow = {
  conversation_id: string;
  user_a_id: string;
  user_b_id: string;
  age_days: number;
  cycle_started_at?: string | null;
  user_a_done: boolean;
  user_b_done: boolean;
  next_cycle_at: string;
  last_completed_at?: string | null;
  created_at: string;
  updated_at: string;
};

export type WyniiStage = "egg" | "hatching" | "baby" | "growing" | "mature" | "max";

const wyniiColumns = "conversation_id,user_a_id,user_b_id,age_days,cycle_started_at,user_a_done,user_b_done,next_cycle_at,last_completed_at,created_at,updated_at";

function fail(error: { message?: string } | null | undefined, fallback: string) {
  if (error) throw new Error(error.message || fallback);
}

export function wyniiStage(ageDays: number): WyniiStage {
  if (ageDays <= 0) return "egg";
  if (ageDays <= 6) return "hatching";
  if (ageDays <= 29) return "baby";
  if (ageDays <= 99) return "growing";
  if (ageDays <= 364) return "mature";
  return "max";
}

export function wyniiStageLabel(stage: WyniiStage): string {
  switch (stage) {
    case "egg": return "ไข่";
    case "hatching": return "กำลังฟัก";
    case "baby": return "วัยเด็ก";
    case "growing": return "วัยเติบโต";
    case "mature": return "วัยโต";
    case "max": return "MAX Form";
  }
}

export function wyniiNextMilestone(ageDays: number): number | null {
  if (ageDays < 1) return 1;
  if (ageDays < 7) return 7;
  if (ageDays < 30) return 30;
  if (ageDays < 100) return 100;
  if (ageDays < 365) return 365;
  return null;
}

export async function fetchWynii(client: SupabaseClient, conversationId: string): Promise<WyniiRow | null> {
  const result = await client
    .from("conversation_wynii")
    .select(wyniiColumns)
    .eq("conversation_id", conversationId)
    .maybeSingle();
  fail(result.error, "โหลด Wynii ไม่สำเร็จ");
  return result.data ? (result.data as WyniiRow) : null;
}

export async function startWynii(client: SupabaseClient, conversationId: string): Promise<WyniiRow> {
  const result = await client.rpc("start_conversation_wynii", { p_conversation_id: conversationId });
  fail(result.error, "เริ่มเลี้ยง Wynii ไม่สำเร็จ");
  const pet = await fetchWynii(client, conversationId);
  if (!pet) throw new Error("สร้าง Wynii ไม่สำเร็จ");
  return pet;
}

export function subscribeWyniiMessages(
  client: SupabaseClient,
  conversationId: string,
  onChange: () => void,
): RealtimeChannel {
  return client
    .channel(`wynii-messages-${conversationId}-${Math.random().toString(36).slice(2)}`)
    .on(
      "postgres_changes",
      { event: "INSERT", schema: "public", table: "messages", filter: `conversation_id=eq.${conversationId}` },
      () => onChange(),
    )
    .subscribe();
}
