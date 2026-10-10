/**
 * WYN-220 prompt-injection and privacy guards.
 *
 * Tool output is data, never instructions: it is cleaned, size-capped,
 * personal identifiers are masked, and it is wrapped in an envelope the
 * system prompt tells the model to treat as untrusted. None of this makes
 * injection impossible -- the real control is that Phase 1 tools are
 * read-only and the model cannot raise its own permissions.
 */

const MAX_TOOL_OUTPUT_CHARS = 12_000;
const MAX_STRING_CHARS = 500;

const EMAIL = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi;
// Thai mobile / long digit runs that look like phone or account numbers.
const PHONE = /(?<![\d.])(?:\+?66|0)[\s-]?\d{1,2}[\s-]?\d{3}[\s-]?\d{4}(?![\d.])/g;
// Control characters except tab/newline.
const CONTROL = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F​-‏‪-‮⁦-⁩]/g;

export function maskPersonalData(text: string): string {
  return text.replace(EMAIL, "[email]").replace(PHONE, "[phone]");
}

/** Deep-copies JSON-like data, cleaning every string. */
export function sanitizeValue(value: unknown, depth = 0): unknown {
  if (depth > 8) return "[truncated]";
  if (typeof value === "string") {
    const cleaned = maskPersonalData(value.replace(CONTROL, ""));
    return cleaned.length > MAX_STRING_CHARS ? `${cleaned.slice(0, MAX_STRING_CHARS)}…` : cleaned;
  }
  if (typeof value === "number") return Number.isFinite(value) ? value : null;
  if (typeof value === "boolean" || value === null) return value;
  if (Array.isArray(value)) return value.slice(0, 100).map((item) => sanitizeValue(item, depth + 1));
  if (typeof value === "object") {
    const out: Record<string, unknown> = {};
    for (const [key, item] of Object.entries(value as Record<string, unknown>).slice(0, 100)) {
      out[key.replace(CONTROL, "").slice(0, 80)] = sanitizeValue(item, depth + 1);
    }
    return out;
  }
  return null;
}

/** The tool_result text the model sees. */
export function wrapToolOutput(toolName: string, payload: unknown): string {
  let json = JSON.stringify(sanitizeValue(payload));
  if (json.length > MAX_TOOL_OUTPUT_CHARS) {
    json = `${json.slice(0, MAX_TOOL_OUTPUT_CHARS)}…[truncated]`;
  }
  return `<tool_data tool="${toolName}" trust="untrusted">\n${json}\n</tool_data>`;
}

/** Removes control and bidi-override characters from text the admin typed (the DB caps its length). */
export function cleanUserText(text: string): string {
  return text.replace(CONTROL, "").trim();
}

/**
 * Grounding check: numbers in the answer that appear in no tool output.
 * Small integers (≤ 31, often dates or counts of days) are ignored, and a
 * number counts as found if it matches a tool value exactly or after
 * rounding to 0-2 decimals, so "12.3%" grounded on 12.345 passes. The
 * result is a warning for the reader, not proof of a wrong answer -- the
 * model may have derived a number legitimately.
 */
export function findUngroundedNumbers(answer: string, toolOutputs: unknown[]): string[] {
  const known = new Set<string>();
  const collect = (value: unknown) => {
    if (typeof value === "number" && Number.isFinite(value)) {
      for (const digits of [0, 1, 2]) known.add(String(Number(value.toFixed(digits))));
      known.add(String(value));
    } else if (typeof value === "string") {
      for (const match of value.matchAll(/-?\d[\d,]*(?:\.\d+)?/g)) known.add(normalizeNumber(match[0]));
    } else if (Array.isArray(value)) {
      value.forEach(collect);
    } else if (value && typeof value === "object") {
      Object.values(value).forEach(collect);
    }
  };
  toolOutputs.forEach(collect);

  const unverified: string[] = [];
  for (const match of answer.matchAll(/-?\d[\d,]*(?:\.\d+)?/g)) {
    const normalized = normalizeNumber(match[0]);
    const numeric = Number(normalized);
    if (!Number.isFinite(numeric) || Math.abs(numeric) <= 31) continue;
    // Calendar years in prose ("2026", "2569") are not data claims.
    if (Number.isInteger(numeric) && numeric >= 1900 && numeric <= 2700) continue;
    if (known.has(normalized) || known.has(String(Math.abs(numeric)))) continue;
    if (!unverified.includes(match[0])) unverified.push(match[0]);
  }
  return unverified.slice(0, 20);
}

function normalizeNumber(raw: string): string {
  const n = Number(raw.replace(/,/g, ""));
  return Number.isFinite(n) ? String(n) : raw;
}
