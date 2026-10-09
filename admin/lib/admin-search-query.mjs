/**
 * Pure URL-query validation for the staff search page.
 * Search terms go in browser history, so never allow email, phone numbers,
 * SQL/PostgREST operators, wildcards, commas, quotes or newlines.
 */
export function parseAdminSearchQuery(raw) {
  if (raw === undefined || raw === null || raw === "") return { query: "", hasQuery: false };
  if (typeof raw !== "string") throw new Error("กรุณาระบุคำค้นหาเพียงหนึ่งรายการ");
  if (/[\r\n\t\u0000-\u001f\u007f]/.test(raw)) throw new Error("ไม่รองรับอักขระควบคุม");
  const query = raw.trim().replace(/\s+/g, " ");
  if (query.length < 3 || query.length > 48) throw new Error("กรุณากรอกคำค้นหา 3–48 ตัวอักษร");
  // Public username/name, store name and order-number lookup only. Any
  // contact information, control characters or wildcard syntax is rejected.
  if (!/^[\p{L}\p{M}\p{N}_.\- ]+$/u.test(query)) {
    throw new Error("ค้นหาได้เฉพาะชื่อผู้ใช้ ชื่อร้าน และหมายเลขออเดอร์ ไม่รองรับอีเมลหรือเบอร์โทร");
  }
  if (/^\d{9,12}$/.test(query)) {
    throw new Error("ห้ามค้นหาด้วยเบอร์โทรศัพท์");
  }
  return { query, hasQuery: true };
}

/** Escapes SQL LIKE wildcard characters without constructing a PostgREST OR expression. */
export function toSafeIlikePattern(query) {
  return "%" + query.replace(/[\\%_]/g, "\\$&") + "%";
}
