import { findUngroundedNumbers, sanitizeValue, wrapToolOutput } from "./guard.ts";
import { authorizeTool } from "./policy.ts";
import { SECRETARY_SYSTEM_PROMPT } from "./prompt.ts";
import type {
  ChatMessage,
  ModelProvider,
  ModelTier,
  SecretaryAccess,
  SecretaryEvent,
  TextBlock,
  TokenUsage,
  ToolContext,
  ToolDefinition,
  ToolResultBlock,
  ToolRunRecord,
  ToolUseBlock,
} from "./types.ts";

/** Model turns per request; each turn may call several tools in parallel. */
export const MAX_STEPS = 6;
const TOOL_NAME = /^[a-z][a-z0-9_]{0,63}$/;

export type OrchestratorDeps = {
  provider: ModelProvider;
  tools: ToolDefinition[];
  access: SecretaryAccess;
  toolContext: Omit<ToolContext, "signal">;
  /** Writes the audit row. Throwing makes the tool call fail (fail closed). */
  recordToolRun: (record: ToolRunRecord) => Promise<void>;
  emit: (event: SecretaryEvent) => void;
};

export type RunInput = {
  /** Earlier turns plus the new user message last. */
  messages: ChatMessage[];
  tier: ModelTier;
  signal: AbortSignal;
};

export type RunOutcome = {
  text: string;
  usage: TokenUsage;
  model: string;
  ending: "complete" | "max_steps" | "max_tokens" | "refusal";
};

class ToolTimeoutError extends Error {}

/** Thrown when a run fails part-way; carries the tokens already spent so they still count against the budget. */
export class SecretaryRunError extends Error {
  readonly partial: Pick<RunOutcome, "text" | "usage" | "model">;

  constructor(cause: unknown, partial: Pick<RunOutcome, "text" | "usage" | "model">) {
    super(cause instanceof Error ? cause.message : "AI Secretary run failed", { cause });
    this.partial = partial;
  }
}

/**
 * Understand → plan → call tools → verify → report. The loop is the only
 * place tools run, and every call goes through the same steps in order:
 * authorize (server-side policy) → validate input → run with timeout and
 * one retry for idempotent reads → audit → return cleaned, wrapped output.
 */
export async function runSecretary(input: RunInput, deps: OrchestratorDeps): Promise<RunOutcome> {
  const state = { usage: { inputTokens: 0, outputTokens: 0 }, answer: [] as string[], model: "" };
  try {
    return await runLoop(input, deps, state);
  } catch (error) {
    throw new SecretaryRunError(error, { text: state.answer.join("\n\n"), usage: state.usage, model: state.model });
  }
}

async function runLoop(
  input: RunInput,
  deps: OrchestratorDeps,
  state: { usage: TokenUsage; answer: string[]; model: string },
): Promise<RunOutcome> {
  const { emit } = deps;
  const { usage, answer } = state;
  const messages = [...input.messages];
  const toolOutputs: unknown[] = [];
  let ending: RunOutcome["ending"] = "max_steps";

  const toolSpecs = deps.tools.map((tool) => ({
    name: tool.name,
    description: tool.description,
    inputSchema: tool.inputSchema,
  }));

  for (let step = 0; step < MAX_STEPS; step++) {
    emit({ type: "status", phase: step === 0 ? "analyzing" : "writing" });
    const turn = await deps.provider.streamTurn({
      tier: input.tier,
      system: SECRETARY_SYSTEM_PROMPT,
      messages,
      tools: toolSpecs,
      signal: input.signal,
      onTextDelta: (delta) => emit({ type: "text", delta }),
    });
    usage.inputTokens += turn.usage.inputTokens;
    usage.outputTokens += turn.usage.outputTokens;
    state.model = turn.model;

    const text = turn.blocks
      .filter((block): block is TextBlock => block.type === "text")
      .map((block) => block.text)
      .join("");
    if (text.trim()) answer.push(text.trim());

    const toolUses = turn.blocks.filter((block): block is ToolUseBlock => block.type === "tool_use");

    if (turn.stopReason === "refusal") {
      ending = "refusal";
      emit({ type: "notice", message: "โมเดลปฏิเสธคำขอนี้ ลองเปลี่ยนคำถาม" });
      break;
    }
    if (turn.stopReason === "max_tokens") {
      // A tool call cut off at the limit may look valid; never run it.
      ending = "max_tokens";
      emit({ type: "notice", message: "คำตอบยาวเกินขีดจำกัดและถูกตัด ลองถามให้แคบลงหรือใช้โหมดวิเคราะห์ลึก" });
      break;
    }
    if (turn.stopReason !== "tool_use" || toolUses.length === 0) {
      ending = "complete";
      break;
    }

    messages.push({ role: "assistant", content: turn.blocks, providerContent: turn.providerContent });
    emit({ type: "status", phase: "calling_tools" });
    const results = await Promise.all(toolUses.map((use) => executeToolCall(use, deps, input.signal, toolOutputs)));
    messages.push({ role: "user", content: results });
  }

  if (ending === "max_steps") {
    emit({ type: "notice", message: `หยุดหลังจากใช้เครื่องมือครบ ${MAX_STEPS} รอบ คำตอบอาจยังไม่สมบูรณ์` });
  }

  const text = answer.join("\n\n");
  const unverifiedNumbers = findUngroundedNumbers(text, toolOutputs);
  if (unverifiedNumbers.length > 0) emit({ type: "verification", unverifiedNumbers });

  return { text, usage, model: state.model, ending };
}

async function executeToolCall(
  use: ToolUseBlock,
  deps: OrchestratorDeps,
  signal: AbortSignal,
  toolOutputs: unknown[],
): Promise<ToolResultBlock> {
  const tool = deps.tools.find((candidate) => candidate.name === use.name);
  const name = TOOL_NAME.test(use.name) ? use.name : "unknown_tool";
  const label = tool?.label ?? name;
  const started = Date.now();
  const fail = (content: string): ToolResultBlock => ({ type: "tool_result", toolUseId: use.id, content, isError: true });

  const decision = authorizeTool(tool, deps.access);
  if (!decision.allowed || !tool) {
    const message = decision.allowed ? "ไม่มีเครื่องมือนี้ในระบบ" : decision.message;
    await safeRecord(deps, {
      toolName: name,
      level: tool?.level ?? 3,
      status: "denied",
      source: null,
      input: {},
      outputSummary: null,
      error: decision.allowed ? "unknown_tool" : decision.reason,
      durationMs: 0,
    });
    deps.emit({
      type: "tool",
      id: use.id,
      name,
      label,
      status: "denied",
      needsApproval: !decision.allowed && decision.reason === "needs_approval",
      error: message,
    });
    return fail(`Denied: ${message}`);
  }

  const parsed = tool.validate(use.input);
  if (!parsed.ok) {
    await safeRecord(deps, {
      toolName: name,
      level: tool.level,
      status: "failed",
      source: null,
      input: {},
      outputSummary: null,
      error: `invalid input: ${parsed.error}`.slice(0, 200),
      durationMs: 0,
    });
    deps.emit({ type: "tool", id: use.id, name, label, status: "failed", error: "ข้อมูลที่ส่งให้เครื่องมือไม่ถูกต้อง" });
    return fail(`Invalid input: ${parsed.error}`);
  }

  deps.emit({ type: "tool", id: use.id, name, label, status: "running" });

  const attempts = tool.idempotent ? 2 : 1;
  let lastError: unknown;
  for (let attempt = 0; attempt < attempts; attempt++) {
    if (signal.aborted) break;
    try {
      const result = await withTimeout(
        (toolSignal) => tool.run({ ...deps.toolContext, signal: toolSignal }, parsed.value),
        tool.timeoutMs,
        signal,
      );
      const clean = sanitizeValue(result.data);
      try {
        await deps.recordToolRun({
          toolName: name,
          level: tool.level,
          status: "succeeded",
          source: result.source.reference,
          input: parsed.value,
          outputSummary: summarize(clean),
          error: null,
          durationMs: Date.now() - started,
        });
      } catch {
        deps.emit({ type: "tool", id: use.id, name, label, status: "failed", error: "บันทึก audit ไม่สำเร็จ จึงไม่ใช้ผลลัพธ์นี้" });
        return fail("The audit record could not be written, so this result was discarded.");
      }
      toolOutputs.push(clean);
      deps.emit({ type: "tool", id: use.id, name, label, status: "succeeded", source: result.source });
      return {
        type: "tool_result",
        toolUseId: use.id,
        content: wrapToolOutput(name, { source: result.source, data: clean }),
        isError: false,
      };
    } catch (error) {
      lastError = error;
      if (error instanceof ToolTimeoutError) break;
    }
  }

  const timedOut = lastError instanceof ToolTimeoutError;
  const message = timedOut ? "เครื่องมือใช้เวลานานเกินกำหนด" : "เรียกข้อมูลไม่สำเร็จ";
  await safeRecord(deps, {
    toolName: name,
    level: tool.level,
    status: timedOut ? "timed_out" : "failed",
    source: null,
    input: parsed.value,
    outputSummary: null,
    error: errorText(lastError),
    durationMs: Date.now() - started,
  });
  deps.emit({ type: "tool", id: use.id, name, label, status: timedOut ? "timed_out" : "failed", error: message });
  return fail(timedOut ? "The tool timed out." : `The tool failed: ${errorText(lastError)}`);
}

/** For denied/failed calls the answer is already an error; a lost audit row is logged server-side. */
async function safeRecord(deps: OrchestratorDeps, record: ToolRunRecord) {
  try {
    await deps.recordToolRun(record);
  } catch (error) {
    console.error("[ai-secretary] could not record tool run", record.toolName, errorText(error));
  }
}

async function withTimeout<T>(run: (signal: AbortSignal) => Promise<T>, timeoutMs: number, parent: AbortSignal): Promise<T> {
  const controller = new AbortController();
  const onAbort = () => controller.abort();
  parent.addEventListener("abort", onAbort, { once: true });
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([
      run(controller.signal),
      new Promise<never>((_, reject) => {
        timer = setTimeout(() => {
          // Reject first: aborting makes the tool reject too, and that must not win the race.
          reject(new ToolTimeoutError(`timed out after ${timeoutMs} ms`));
          controller.abort();
        }, timeoutMs);
      }),
    ]);
  } finally {
    clearTimeout(timer);
    parent.removeEventListener("abort", onAbort);
  }
}

/** What the audit row keeps of an output: its shape, not its content. */
function summarize(value: unknown): Record<string, unknown> {
  if (Array.isArray(value)) return { kind: "array", length: value.length };
  if (value && typeof value === "object") return { kind: "object", keys: Object.keys(value).slice(0, 40) };
  return { kind: typeof value };
}

function errorText(error: unknown): string {
  const message = error instanceof Error ? error.message : String((error as { message?: unknown })?.message ?? error);
  return message.slice(0, 200);
}
