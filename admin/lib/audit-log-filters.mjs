/**
 * Pure, server-side Audit Log filter contract. Can be tested without Supabase.
 * Invalid query parameters fail closed; never interpolate unvalidated input
 * into a PostgREST OR expression.
 */

export const AUDIT_EVENT_TYPES = Object.freeze([
  "moderation_action_applied",
  "appeal_decided",
  "system_notification_sent",
  "account_deleted",
  "data_exported",
  "admin_user_action_applied",
  "admin_user_unbanned",
  "admin_content_removed",
  "admin_content_restored",
  "admin_announcement_sent",
  "admin_inactive_reminder_sent",
]);

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DAY = /^\d{4}-\d{2}-\d{2}$/;
const TIMESTAMP = /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,6})?(?:Z|[+-]\d\d:\d\d)$/;

function validDay(value) {
  if (!DAY.test(value)) return false;
  const date = new Date(value + "T00:00:00.000Z");
  return !Number.isNaN(date.valueOf()) && date.toISOString().slice(0, 10) === value;
}

function getSingle(raw, key) {
  const value = raw[key];
  if (Array.isArray(value)) throw new Error("กรุณาระบุตัวกรองครั้งละหนึ่งค่า");
  if (typeof value !== "string") return "";
  if (value.length > 250) throw new Error("ตัวกรองยาวเกินกำหนด");
  return value.trim();
}

export function encodeAuditCursor(row) {
  const t = String(row.created_at ?? "");
  const id = String(row.id ?? "");
  if (!TIMESTAMP.test(t) || Number.isNaN(Date.parse(t)) || !UUID.test(id)) {
    throw new Error("Invalid Audit Log cursor source");
  }
  return Buffer.from(JSON.stringify({ t, id })).toString("base64url");
}

export function decodeAuditCursor(raw) {
  if (!raw || typeof raw !== "string" || !/^[\w-]{1,500}$/.test(raw)) {
    throw new Error("Invalid Audit Log cursor");
  }
  let value;
  try {
    value = JSON.parse(Buffer.from(raw, "base64url").toString("utf8"));
  } catch {
    throw new Error("Invalid Audit Log cursor");
  }
  if (!value || typeof value.t !== "string" || typeof value.id !== "string" ||
      !TIMESTAMP.test(value.t) || Number.isNaN(Date.parse(value.t)) ||
      !UUID.test(value.id)) {
    throw new Error("Invalid Audit Log cursor");
  }
  return { createdAt: value.t, id: value.id };
}

/**
 * Bound date filters use Bangkok business-calendar days, end exclusive.
 * Page size is fixed to 50; offset-based deep scans are intentionally avoided.
 */
export function parseAuditFilters(raw) {
  const eventType = getSingle(raw, "event_type");
  const actorId = getSingle(raw, "actor_id");
  const from = getSingle(raw, "from");
  const to = getSingle(raw, "to");
  const cursorRaw = getSingle(raw, "cursor");

  if (eventType && eventType !== "all" && !AUDIT_EVENT_TYPES.includes(eventType)) {
    throw new Error("ประเภทเหตุการณ์ไม่ถูกต้อง");
  }
  if (actorId && !UUID.test(actorId)) throw new Error("รหัสเจ้าหน้าที่ต้องเป็น UUID");
  if ((from && !validDay(from)) || (to && !validDay(to))) throw new Error("วันที่ไม่ถูกต้อง");
  if (from && to && from > to) throw new Error("วันเริ่มต้องไม่เกินวันสิ้นสุด");

  return {
    eventType: eventType === "all" ? "" : eventType,
    actorId,
    from,
    to,
    cursor: cursorRaw ? decodeAuditCursor(cursorRaw) : null,
  };
}

export function nextBangkokDay(dateString) {
  if (!validDay(dateString)) throw new Error("Invalid calendar day");
  const next = new Date(dateString + "T00:00:00Z");
  next.setUTCDate(next.getUTCDate() + 1);
  return next.toISOString().slice(0, 10);
}

export function toBangkokMidnightIso(day) {
  if (!validDay(day)) throw new Error("Invalid calendar day");
  return new Date(day + "T00:00:00+07:00").toISOString();
}
