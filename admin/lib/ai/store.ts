import "server-only";

import { createClient } from "@/lib/supabase/server";

import type { ToolRunRecord } from "./types.ts";

/**
 * WYN-220 data access for the AI Secretary. Everything runs as the signed-in
 * admin (publishable key + their session): the ai_secretary_* RPCs and RLS
 * decide what is allowed, this file never does.
 */

export type SecretaryStatus = {
  /** false until the WYN-220 migration exists in this database. */
  installed: boolean;
  allowed: boolean;
  enabled: boolean;
  dailyTokenLimit: number;
  requestsPerMinute: number;
  tokensUsedToday: number;
  updatedAt: string | null;
};

/** Deploy-level switch and provider key (server env only, never sent to the browser). */
export function secretaryEnvironment() {
  return {
    enabledByEnv: process.env.AI_SECRETARY_ENABLED === "true",
    hasProviderKey: Boolean(process.env.ANTHROPIC_API_KEY?.trim()),
  };
}

export async function fetchSecretaryStatus(): Promise<SecretaryStatus> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("ai_secretary_status");
  if (error || !data) {
    return { installed: false, allowed: false, enabled: false, dailyTokenLimit: 0, requestsPerMinute: 0, tokensUsedToday: 0, updatedAt: null };
  }
  const s = data as Record<string, unknown>;
  return {
    installed: true,
    allowed: s.allowed === true,
    enabled: s.enabled === true,
    dailyTokenLimit: Number(s.daily_token_limit ?? 0),
    requestsPerMinute: Number(s.requests_per_minute ?? 0),
    tokensUsedToday: Number(s.tokens_used_today ?? 0),
    updatedAt: typeof s.updated_at === "string" ? s.updated_at : null,
  };
}

export type BeginResult =
  | { ok: true; conversationId: string }
  | { ok: false; status: number; message: string };

/** The database gate: access, kill switch, rate limit and token budget. */
export async function beginSecretaryRequest(conversationId: string | null, message: string): Promise<BeginResult> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("ai_secretary_begin_request", {
    p_conversation_id: conversationId,
    p_message: message,
  });
  if (!error && typeof data === "string") return { ok: true, conversationId: data };
  switch (error?.code) {
    case "42501":
      return { ok: false, status: 403, message: "บัญชีนี้ยังไม่ได้รับสิทธิ์ใช้ AI Secretary" };
    case "55000":
      return { ok: false, status: 503, message: "AI Secretary ถูกปิดอยู่ (kill switch)" };
    case "54000":
      return {
        ok: false,
        status: 429,
        message: error.message.includes("budget")
          ? "ใช้ token ครบโควตาของวันนี้แล้ว ปรับได้ที่หน้าตั้งค่า"
          : "ส่งคำถามถี่เกินไป รอสักครู่แล้วลองใหม่",
      };
    case "22023":
      return { ok: false, status: 400, message: "ข้อความต้องยาว 1–4,000 ตัวอักษร" };
    case "P0002":
      return { ok: false, status: 404, message: "ไม่พบบทสนทนานี้ (อาจหมดอายุแล้ว)" };
    default:
      return { ok: false, status: 503, message: "ยังเริ่มคำขอไม่ได้ ตรวจว่าติดตั้ง migration WYN-220 แล้ว" };
  }
}

export type StoredMessage = { role: "user" | "assistant"; content: string; created_at: string };

export async function fetchConversationMessages(conversationId: string, limit = 20): Promise<StoredMessage[]> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("ai_secretary_conversation_messages", {
    p_conversation_id: conversationId,
    p_limit: limit,
  });
  if (error) throw error;
  return (data ?? []) as StoredMessage[];
}

export async function recordSecretaryReply(params: {
  conversationId: string;
  content: string;
  model: string;
  inputTokens: number;
  outputTokens: number;
  durationMs: number;
}): Promise<void> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("ai_secretary_record_reply", {
    p_conversation_id: params.conversationId,
    p_content: params.content,
    p_model: params.model,
    p_input_tokens: params.inputTokens,
    p_output_tokens: params.outputTokens,
    p_duration_ms: params.durationMs,
  });
  if (error) throw error;
}

export async function recordToolRun(conversationId: string, record: ToolRunRecord): Promise<void> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("ai_secretary_record_tool_run", {
    p_conversation_id: conversationId,
    p_tool_name: record.toolName,
    p_permission_level: record.level,
    p_status: record.status,
    p_source: record.source,
    p_input: record.input,
    p_output_summary: record.outputSummary,
    p_error: record.error,
    p_duration_ms: record.durationMs,
  });
  if (error) throw error;
}

export type ConversationSummary = { id: string; title: string; updated_at: string };

export async function listConversations(limit = 20): Promise<ConversationSummary[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("ai_conversations")
    .select("id, title, updated_at")
    .order("updated_at", { ascending: false })
    .limit(limit);
  if (error) return [];
  return data ?? [];
}

export type MemoryItem = { id: string; kind: "note" | "decision" | "context"; content: string; created_at: string; expires_at: string };

export async function listMemoryItems(): Promise<MemoryItem[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("ai_memory_items")
    .select("id, kind, content, created_at, expires_at")
    .order("created_at", { ascending: false })
    .limit(200);
  if (error) throw error;
  return (data ?? []) as MemoryItem[];
}

export type ToolRunRow = {
  id: number;
  tool_name: string;
  permission_level: number;
  status: string;
  source: string | null;
  error: string | null;
  duration_ms: number | null;
  created_at: string;
};

export async function listToolRuns(limit = 100): Promise<ToolRunRow[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("ai_tool_runs")
    .select("id, tool_name, permission_level, status, source, error, duration_ms, created_at")
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw error;
  return (data ?? []) as ToolRunRow[];
}

export type UsageRow = { model: string; input_tokens: number; output_tokens: number; duration_ms: number | null; created_at: string };

/** Usage rows of the last `days` days (own rows only, via RLS). */
export async function listUsage(days = 30): Promise<UsageRow[]> {
  const supabase = await createClient();
  const since = new Date(Date.now() - days * 86_400_000).toISOString();
  const { data, error } = await supabase
    .from("ai_usage")
    .select("model, input_tokens, output_tokens, duration_ms, created_at")
    .gte("created_at", since)
    .order("created_at", { ascending: false })
    .limit(5000);
  if (error) throw error;
  return (data ?? []) as UsageRow[];
}
