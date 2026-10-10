"use server";

import { refresh } from "next/cache";
import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

// Every write is re-checked in the database (super admin + RLS); these
// actions only validate the form shape and report the outcome.

function back(path: string, status: "saved" | "error"): never {
  redirect(`${path}?status=${status}`);
}

export async function setSecretaryEnabledAction(formData: FormData) {
  const enabled = formData.get("enabled") === "true";
  const supabase = await createClient();
  const { error } = await supabase.rpc("ai_secretary_set_enabled", { p_enabled: enabled });
  back("/ai/settings", error ? "error" : "saved");
}

export async function setSecretaryLimitsAction(formData: FormData) {
  const daily = Number(formData.get("daily_token_limit"));
  const rpm = Number(formData.get("requests_per_minute"));
  if (!Number.isInteger(daily) || !Number.isInteger(rpm)) back("/ai/settings", "error");
  const supabase = await createClient();
  const { error } = await supabase.rpc("ai_secretary_set_limits", {
    p_daily_token_limit: daily,
    p_requests_per_minute: rpm,
  });
  back("/ai/settings", error ? "error" : "saved");
}

const MEMORY_KINDS = new Set(["note", "decision", "context"]);
const MEMORY_DAYS = new Set([30, 90, 180, 365]);

export async function addMemoryAction(formData: FormData) {
  const content = String(formData.get("content") ?? "").trim();
  const kind = String(formData.get("kind") ?? "note");
  const days = Number(formData.get("days") ?? 180);
  if (!content || content.length > 2000 || !MEMORY_KINDS.has(kind) || !MEMORY_DAYS.has(days)) back("/ai/memory", "error");
  const supabase = await createClient();
  const { error } = await supabase.from("ai_memory_items").insert({
    kind,
    content,
    expires_at: new Date(Date.now() + days * 86_400_000).toISOString(),
  });
  back("/ai/memory", error ? "error" : "saved");
}

export async function deleteMemoryAction(formData: FormData) {
  const id = String(formData.get("id") ?? "");
  if (!/^[0-9a-f-]{36}$/i.test(id)) back("/ai/memory", "error");
  const supabase = await createClient();
  const { error } = await supabase.from("ai_memory_items").delete().eq("id", id);
  if (error) back("/ai/memory", "error");
  refresh();
}
