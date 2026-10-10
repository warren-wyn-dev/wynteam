import type { ModelTier } from "./types.ts";

/**
 * WYN-220 model routing. Each tier names a model and an effort level; the
 * admin picks the tier per question in the chat UI:
 *   fast     -- short lookups and simple summaries (cheapest)
 *   standard -- the default; tool use and normal analysis
 *   deep     -- multi-source analysis where correctness matters more than cost
 * Models can be overridden per environment (AI_MODEL_FAST/_STANDARD/_DEEP)
 * without code changes.
 */
export type TierConfig = {
  model: string;
  effort: "low" | "medium" | "high";
  maxTokens: number;
  /** Server-side refusal fallback (not offered for Haiku models). */
  refusalFallback: boolean;
};

const DEFAULT_TIERS: Record<ModelTier, TierConfig> = {
  fast: { model: "claude-haiku-5-5", effort: "low", maxTokens: 8000, refusalFallback: false },
  standard: { model: "claude-opus-5-5", effort: "medium", maxTokens: 16000, refusalFallback: true },
  deep: { model: "claude-opus-5-5", effort: "high", maxTokens: 32000, refusalFallback: true },
};

export const MODEL_TIERS = ["fast", "standard", "deep"] as const satisfies readonly ModelTier[];

export const MODEL_TIER_LABEL: Record<ModelTier, string> = {
  fast: "เร็ว",
  standard: "มาตรฐาน",
  deep: "วิเคราะห์ลึก",
};

const MODEL_ID = /^[a-z0-9][a-z0-9.-]{2,63}$/;

/** Known per-model prices (USD / 1M tokens); unknown overrides show no estimate. */
const PRICES: Record<string, { in: number; out: number }> = {
  "claude-haiku-5-5": { in: 0.1, out: 0.5 },
  "claude-sonnet-5-5": { in: 2, out: 10 },
  "claude-opus-5-5": { in: 4, out: 20 },
};

export function isModelTier(value: unknown): value is ModelTier {
  return typeof value === "string" && (MODEL_TIERS as readonly string[]).includes(value);
}

export function resolveTier(tier: ModelTier, env: Record<string, string | undefined> = process.env): TierConfig {
  const base = DEFAULT_TIERS[tier];
  const override = env[`AI_MODEL_${tier.toUpperCase()}`]?.trim();
  if (!override || !MODEL_ID.test(override) || override === base.model) return base;
  return { ...base, model: override, refusalFallback: !override.includes("haiku") };
}

/** Estimated USD cost, or null for a model without a known price. */
export function estimateCostUsd(model: string, inputTokens: number, outputTokens: number): number | null {
  const price = PRICES[model];
  if (!price) return null;
  return (inputTokens * price.in + outputTokens * price.out) / 1_000_000;
}
