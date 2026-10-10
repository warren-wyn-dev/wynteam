import { fetchAdminAccess } from "@/lib/admin-permissions";
import { cleanUserText } from "@/lib/ai/guard";
import { isModelTier } from "@/lib/ai/models";
import { runSecretary, SecretaryRunError } from "@/lib/ai/orchestrator";
import { userTurnPreamble } from "@/lib/ai/prompt";
import { AnthropicProvider } from "@/lib/ai/providers/anthropic";
import {
  beginSecretaryRequest,
  fetchConversationMessages,
  listMemoryItems,
  recordSecretaryReply,
  recordToolRun,
  secretaryEnvironment,
} from "@/lib/ai/store";
import { SECRETARY_TOOLS } from "@/lib/ai/tools";
import type { ChatMessage, SecretaryEvent } from "@/lib/ai/types";
import { createClient } from "@/lib/supabase/server";

// A tool loop with several model turns can take a while.
export const maxDuration = 300;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const MAX_BODY_BYTES = 20_000;

function jsonError(status: number, message: string) {
  return Response.json({ error: message }, { status });
}

/**
 * WYN-220 AI Secretary chat. Streams NDJSON SecretaryEvents.
 *
 * Order of checks (each fails closed): deploy switch + provider key (env) →
 * same-origin JSON request → signed-in user → database gate
 * (ai_secretary_begin_request: super admin, kill switch, rate limit, token
 * budget) → per-tool policy inside the orchestrator.
 */
export async function POST(request: Request) {
  const env = secretaryEnvironment();
  if (!env.enabledByEnv) return jsonError(503, "AI Secretary ยังไม่เปิดใน environment นี้ (AI_SECRETARY_ENABLED)");
  if (!env.hasProviderKey) return jsonError(503, "ยังไม่ได้ตั้งค่า AI provider key บน server");

  // CSRF: the session cookie is sent cross-site, so only accept JSON from our own origin.
  const origin = request.headers.get("origin");
  const host = request.headers.get("host");
  if (!origin || !host || originHost(origin) !== host) return jsonError(403, "Forbidden origin");
  if (!request.headers.get("content-type")?.includes("application/json")) return jsonError(415, "Expected JSON");

  const raw = await request.text();
  if (raw.length > MAX_BODY_BYTES) return jsonError(413, "Request too large");
  let body: unknown;
  try {
    body = JSON.parse(raw);
  } catch {
    return jsonError(400, "Invalid JSON");
  }
  const { message, conversationId, tier } = (body ?? {}) as Record<string, unknown>;
  if (typeof message !== "string") return jsonError(400, "message is required");
  if (conversationId !== undefined && conversationId !== null && (typeof conversationId !== "string" || !UUID.test(conversationId))) {
    return jsonError(400, "Invalid conversationId");
  }
  const modelTier = tier === undefined ? "standard" : tier;
  if (!isModelTier(modelTier)) return jsonError(400, "Invalid tier");
  const text = cleanUserText(message);

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return jsonError(401, "Not signed in");

  const begin = await beginSecretaryRequest((conversationId as string | null | undefined) ?? null, text);
  if (!begin.ok) return jsonError(begin.status, begin.message);
  const activeConversation = begin.conversationId;

  const [access, history] = await Promise.all([fetchAdminAccess(), fetchConversationMessages(activeConversation, 20)]);
  const messages = toChatMessages(history);
  const last = messages[messages.length - 1];
  if (last?.role === "user" && typeof last.content === "string") {
    last.content = `${userTurnPreamble()}\n\n${last.content}`;
  }

  const provider = new AnthropicProvider(process.env.ANTHROPIC_API_KEY!.trim());
  const encoder = new TextEncoder();
  const started = Date.now();

  const stream = new ReadableStream<Uint8Array>({
    async start(controller) {
      let closed = false;
      const emit = (event: SecretaryEvent) => {
        if (closed) return;
        try {
          controller.enqueue(encoder.encode(`${JSON.stringify(event)}\n`));
        } catch {
          closed = true;
        }
      };

      emit({ type: "conversation", conversationId: activeConversation });
      try {
        const outcome = await runSecretary(
          { messages, tier: modelTier, signal: request.signal },
          {
            provider,
            tools: SECRETARY_TOOLS,
            access,
            toolContext: {
              rpc: async (name, args) => {
                const { data, error } = await supabase.rpc(name, args);
                if (error) throw new Error(error.message);
                return data;
              },
              listMemory: () => listMemoryItems(),
            },
            recordToolRun: (record) => recordToolRun(activeConversation, record),
            emit,
          },
        );
        const durationMs = Date.now() - started;
        await recordSecretaryReply({
          conversationId: activeConversation,
          content: outcome.text,
          model: outcome.model,
          inputTokens: outcome.usage.inputTokens,
          outputTokens: outcome.usage.outputTokens,
          durationMs,
        });
        emit({ type: "done", usage: outcome.usage, model: outcome.model, durationMs });
      } catch (error) {
        console.error("[ai-secretary] request failed", error instanceof Error ? error.message : error);
        // Tokens spent before the failure still count against the budget.
        if (error instanceof SecretaryRunError && error.partial.usage.inputTokens + error.partial.usage.outputTokens > 0) {
          await recordSecretaryReply({
            conversationId: activeConversation,
            content: error.partial.text,
            model: error.partial.model,
            inputTokens: error.partial.usage.inputTokens,
            outputTokens: error.partial.usage.outputTokens,
            durationMs: Date.now() - started,
          }).catch(() => undefined);
        }
        emit({
          type: "error",
          message: request.signal.aborted ? "ยกเลิกคำขอแล้ว" : "AI Secretary ทำงานไม่สำเร็จ ลองใหม่อีกครั้ง",
        });
      } finally {
        closed = true;
        controller.close();
      }
    },
  });

  return new Response(stream, {
    headers: {
      "content-type": "application/x-ndjson; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
    },
  });
}

function originHost(origin: string): string | null {
  try {
    return new URL(origin).host;
  } catch {
    return null;
  }
}

/** Stored history → model messages: plain text turns, starting with a user turn. */
function toChatMessages(history: Array<{ role: "user" | "assistant"; content: string }>): ChatMessage[] {
  const start = history.findIndex((m) => m.role === "user");
  if (start < 0) return [];
  return history.slice(start).map((m) =>
    m.role === "user" ? { role: "user", content: m.content } : { role: "assistant", content: m.content },
  );
}
