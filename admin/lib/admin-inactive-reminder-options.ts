// Shared by the client form and the server history (no server-only imports).

/** How long someone has not used WYNOS: 24 hours, 3 days or 7 days. */
export type InactiveDays = 1 | 3 | 7;

export const INACTIVE_DAY_OPTIONS: { value: InactiveDays; label: string }[] = [
  { value: 1, label: "ไม่ได้ใช้งานเกิน 24 ชั่วโมง" },
  { value: 3, label: "ไม่ได้ใช้งานเกิน 3 วัน" },
  { value: 7, label: "ไม่ได้ใช้งานเกิน 7 วัน" },
];

export const INACTIVE_REMINDER_MAX_LENGTH = 500;
