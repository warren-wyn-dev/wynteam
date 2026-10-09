/**
 * Pure, bounded rendering utilities for independently-sourced Admin metrics.
 * Never convert missing or invalid source data into an apparently real zero.
 */
const ISO_DAY = /^\d{4}-\d{2}-\d{2}$/;

export function safeMetric(value, options = {}) {
  const { integer = true } = options;
  if (typeof value !== "number" && !(typeof value === "string" && /^\d+(?:\.\d+)?$/.test(value))) return null;
  if (value === "" || value === null || value === undefined) return null;
  const result = Number(value);
  if (!Number.isFinite(result) || result < 0 || (integer && !Number.isSafeInteger(result))) return null;
  return result;
}

export function validIsoDay(day) {
  if (typeof day !== "string" || !ISO_DAY.test(day)) return false;
  const date = new Date(day + "T00:00:00.000Z");
  return !Number.isNaN(date.valueOf()) && date.toISOString().slice(0, 10) === day;
}

/** Supplied points only: never synthesize a zero for a missing calendar day. */
export function safeDaySeries(input, { dateKey, countKey, limit = 14 } = {}) {
  if (!Array.isArray(input) || typeof dateKey !== "string" || typeof countKey !== "string" ||
      !Number.isSafeInteger(limit) || limit < 1 || limit > 31) return null;

  const unique = new Map();
  // A huge or malformed RPC result must not require a large render/aggregation.
  if (input.length > 40) return null;
  for (const row of input) {
    const day = row?.[dateKey];
    const count = safeMetric(row?.[countKey]);
    if (!validIsoDay(day) || count === null || unique.has(day)) return null;
    unique.set(day, { day, count });
  }
  return [...unique.values()].sort((a, b) => a.day.localeCompare(b.day)).slice(-limit);
}

export function safeMerchantSample(rows, cap = 200) {
  if (!Array.isArray(rows) || rows.length > cap || !Number.isSafeInteger(cap) || cap < 1) return null;
  const seen = new Set();
  const counts = { pending: 0, approved: 0, rejected: 0 };
  for (const row of rows) {
    if (!row || typeof row.id !== "string" || seen.has(row.id) ||
        !Object.hasOwn(counts, row.status)) return null;
    seen.add(row.id);
    counts[row.status]++;
  }
  return { ...counts, sampled: rows.length, capped: rows.length === cap };
}
