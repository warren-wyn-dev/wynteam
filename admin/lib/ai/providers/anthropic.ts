import "server-only";

import Anthropic from "@anthropic-ai/sdk";

import { resolveTier } from "../models.ts";
import type { ChatMessage, ModelProvider, ProviderRequest, ProviderTurn, StopReason } from "../types.ts";

/**
 * Claude adapter for the AI Secretary. Server-only: the API key is read from
 * ANTHROPIC_API_KEY on the server and never reaches the browser.
 *
 * Uses the beta Messages endpoint for the server-side refusal fallback
 * (`fallbacks: "default"`), which reroutes a safety decline to another model
 * inside the same call.
 */
export class AnthropicProvider implements ModelProvider {
  readonly id = "anthropic";
  private readonly client: Anthropic;

  constructor(apiKey: string) {
    // The SDK retries 408/409/429/5xx and connection errors itself.
    this.client = new Anthropic({ apiKey, maxRetries: 2, timeout: 120_000 });
  }

  async streamTurn(request: ProviderRequest): Promise<ProviderTurn> {
    const tier = resolveTier(request.tier);
    const stream = this.client.beta.messages.stream(
      {
        model: tier.model,
        max_tokens: tier.maxTokens,
        thinking: { type: "adaptive" },
        output_config: { effort: tier.effort },
        // Stable prompt + tool list: cache them across turns and requests.
        system: [{ type: "text", text: request.system, cache_control: { type: "ephemeral" } }],
        tools: request.tools.map((tool) => ({
          name: tool.name,
          description: tool.description,
          input_schema: tool.inputSchema as Anthropic.Beta.BetaTool.InputSchema,
        })),
        messages: request.messages.map(toAnthropicMessage),
        ...(tier.refusalFallback ? { betas: ["server-side-fallback-2026-07-01"], fallbacks: "default" as const } : {}),
      },
      { signal: request.signal },
    );

    if (request.onTextDelta) stream.on("text", request.onTextDelta);
    const message = await stream.finalMessage();

    const blocks: ProviderTurn["blocks"] = [];
    for (const block of message.content) {
      if (block.type === "text") blocks.push({ type: "text", text: block.text });
      else if (block.type === "tool_use") blocks.push({ type: "tool_use", id: block.id, name: block.name, input: block.input });
    }

    const usage = message.usage;
    return {
      blocks,
      providerContent: message.content,
      stopReason: mapStopReason(message.stop_reason),
      usage: {
        inputTokens:
          (usage.input_tokens ?? 0) + (usage.cache_creation_input_tokens ?? 0) + (usage.cache_read_input_tokens ?? 0),
        outputTokens: usage.output_tokens ?? 0,
      },
      model: message.model,
    };
  }
}

function toAnthropicMessage(message: ChatMessage): Anthropic.Beta.BetaMessageParam {
  if (message.role === "assistant") {
    // Replay the provider's own content unchanged (thinking blocks included).
    if (message.providerContent) {
      return { role: "assistant", content: message.providerContent as Anthropic.Beta.BetaContentBlockParam[] };
    }
    if (typeof message.content === "string") return { role: "assistant", content: message.content };
    return {
      role: "assistant",
      content: message.content.map((block) =>
        block.type === "text"
          ? { type: "text" as const, text: block.text }
          : { type: "tool_use" as const, id: block.id, name: block.name, input: block.input },
      ),
    };
  }
  if (typeof message.content === "string") return { role: "user", content: message.content };
  return {
    role: "user",
    content: message.content.map((block) => ({
      type: "tool_result" as const,
      tool_use_id: block.toolUseId,
      content: block.content,
      is_error: block.isError,
    })),
  };
}

function mapStopReason(reason: string | null): StopReason {
  switch (reason) {
    case "end_turn":
    case "tool_use":
    case "max_tokens":
    case "refusal":
      return reason;
    default:
      return "other";
  }
}
