/**
 * WYN-220: provider-neutral types for the AI Secretary. The orchestrator,
 * tools and UI only see these; each provider adapter (providers/*.ts) maps
 * them to and from its own API, so a provider can be swapped without
 * touching the rest.
 *
 * Files under lib/ai/ that the unit tests load import each other with
 * relative `.ts` paths (no `@/` alias, no Next.js imports) so `node --test`
 * can run them directly.
 */

import type { AdminLevel, AdminSystem, AdminSystemAccess } from "../admin-systems.ts";

export type ModelTier = "fast" | "standard" | "deep";

export type TextBlock = { type: "text"; text: string };
export type ToolUseBlock = { type: "tool_use"; id: string; name: string; input: unknown };
export type ToolResultBlock = { type: "tool_result"; toolUseId: string; content: string; isError: boolean };

export type ChatMessage =
  | { role: "user"; content: string | ToolResultBlock[] }
  /**
   * `providerContent` is the provider's own copy of the turn (thinking
   * blocks included). Adapters replay it unchanged inside a tool loop.
   */
  | { role: "assistant"; content: string | Array<TextBlock | ToolUseBlock>; providerContent?: unknown };

export type ToolSpec = {
  name: string;
  description: string;
  inputSchema: Record<string, unknown>;
};

export type StopReason = "end_turn" | "tool_use" | "max_tokens" | "refusal" | "other";

export type TokenUsage = { inputTokens: number; outputTokens: number };

export type ProviderTurn = {
  blocks: Array<TextBlock | ToolUseBlock>;
  providerContent: unknown;
  stopReason: StopReason;
  usage: TokenUsage;
  model: string;
};

export type ProviderRequest = {
  tier: ModelTier;
  system: string;
  messages: ChatMessage[];
  tools: ToolSpec[];
  signal?: AbortSignal;
  onTextDelta?: (delta: string) => void;
};

export interface ModelProvider {
  readonly id: string;
  streamTurn(request: ProviderRequest): Promise<ProviderTurn>;
}

/** 1 = read & analyze, 2 = controlled action, 3 = restricted action. */
export type PermissionLevel = 1 | 2 | 3;

/** Where a tool's data came from, shown next to the answer as evidence. */
export type DataSource = {
  /** e.g. "WYNOS Social", "WYNOS Food". */
  system: string;
  /** The RPC or table read. */
  reference: string;
  /** Human-readable period the numbers cover. */
  window: string;
  retrievedAt: string;
};

export type ToolResult = { data: unknown; source: DataSource };

export type ToolContext = {
  /** Calls a Supabase RPC as the signed-in admin (RLS and RPC checks apply). */
  rpc: (name: string, args?: Record<string, unknown>) => Promise<unknown>;
  /** The signed-in admin's own memory notes (RLS applies). */
  listMemory: () => Promise<Array<{ kind: string; content: string; created_at: string }>>;
  signal: AbortSignal;
};

export type ToolDefinition = {
  name: string;
  /** Thai label for the UI. */
  label: string;
  description: string;
  level: PermissionLevel;
  /** null = not tied to one system (e.g. the connection map). */
  system: AdminSystem | null;
  access: AdminLevel;
  inputSchema: Record<string, unknown>;
  /** Returns the cleaned input, or an error message. */
  validate: (input: unknown) => { ok: true; value: Record<string, unknown> } | { ok: false; error: string };
  run: (ctx: ToolContext, input: Record<string, unknown>) => Promise<ToolResult>;
  /** Reads are idempotent, so a transient failure may be retried once. */
  idempotent: boolean;
  timeoutMs: number;
};

export type ToolRunStatus = "succeeded" | "failed" | "denied" | "timed_out";

export type ToolRunRecord = {
  toolName: string;
  level: PermissionLevel;
  status: ToolRunStatus;
  source: string | null;
  input: Record<string, unknown>;
  outputSummary: Record<string, unknown> | null;
  error: string | null;
  durationMs: number;
};

/** Events streamed to the browser as NDJSON, one per line. */
export type SecretaryEvent =
  | { type: "conversation"; conversationId: string }
  | { type: "status"; phase: "analyzing" | "calling_tools" | "writing" }
  | { type: "text"; delta: string }
  | {
      type: "tool";
      id: string;
      name: string;
      label: string;
      status: "running" | ToolRunStatus;
      /** Set when status is "denied" because the action needs approval. */
      needsApproval?: boolean;
      source?: DataSource;
      error?: string;
    }
  | { type: "verification"; unverifiedNumbers: string[] }
  | { type: "notice"; message: string }
  | { type: "done"; usage: TokenUsage; model: string; durationMs: number }
  | { type: "error"; message: string };

export type SecretaryAccess = AdminSystemAccess;
