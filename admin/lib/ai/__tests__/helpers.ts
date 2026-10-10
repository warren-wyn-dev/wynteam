import type {
  ModelProvider,
  ProviderRequest,
  ProviderTurn,
  SecretaryAccess,
  SecretaryEvent,
  ToolDefinition,
  ToolRunRecord,
} from "../types.ts";

export const SUPER_ADMIN: SecretaryAccess = { available: true, superAdmin: true, permissions: {} };
export const NO_ACCESS: SecretaryAccess = { available: true, superAdmin: false, permissions: {} };
export const NOT_INSTALLED: SecretaryAccess = { available: false, superAdmin: false, permissions: {} };

/** Replays scripted turns and records every request it was given. */
export class ScriptedProvider implements ModelProvider {
  readonly id = "scripted";
  readonly requests: ProviderRequest[] = [];
  private readonly turns: Array<Partial<ProviderTurn> | Error>;

  constructor(turns: Array<Partial<ProviderTurn> | Error>) {
    this.turns = turns;
  }

  async streamTurn(request: ProviderRequest): Promise<ProviderTurn> {
    this.requests.push({ ...request, messages: [...request.messages] });
    const next = this.turns.shift();
    if (!next) throw new Error("no scripted turn left");
    if (next instanceof Error) throw next;
    for (const block of next.blocks ?? []) {
      if (block.type === "text") request.onTextDelta?.(block.text);
    }
    return {
      blocks: [],
      providerContent: next.blocks ?? [],
      stopReason: "end_turn",
      usage: { inputTokens: 100, outputTokens: 50 },
      model: "test-model",
      ...next,
    };
  }
}

export function fakeTool(overrides: Partial<ToolDefinition> = {}): ToolDefinition {
  return {
    name: "fake_metric",
    label: "fake",
    description: "fake",
    level: 1,
    system: "social",
    access: "view",
    inputSchema: { type: "object", properties: {} },
    validate: () => ({ ok: true, value: {} }),
    run: async () => ({
      data: { orders_today: 1234, sales_today: 56789.5 },
      source: { system: "WYNOS Food", reference: "rpc fake", window: "today", retrievedAt: "2026-10-10T00:00:00Z" },
    }),
    idempotent: true,
    timeoutMs: 1000,
    ...overrides,
  };
}

export function harness(provider: ModelProvider, tools: ToolDefinition[], access: SecretaryAccess = SUPER_ADMIN) {
  const events: SecretaryEvent[] = [];
  const records: ToolRunRecord[] = [];
  return {
    events,
    records,
    deps: {
      provider,
      tools,
      access,
      toolContext: { rpc: async () => null, listMemory: async () => [] },
      recordToolRun: async (record: ToolRunRecord) => {
        records.push(record);
      },
      emit: (event: SecretaryEvent) => events.push(event),
    },
  };
}
