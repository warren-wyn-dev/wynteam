export type PostingPrompt = {
  key: string;
  text: string;
};

const DAILY_PROMPTS: PostingPrompt[] = [
  { key: "daily-now", text: "วันนี้มีอะไรเกิดขึ้นกับคุณบ้าง?" },
  { key: "daily-listening", text: "ช่วงนี้คุณกำลังฟังเพลงอะไรอยู่?" },
  { key: "daily-smallwin", text: "วันนี้มีเรื่องเล็ก ๆ อะไรที่ทำให้คุณรู้สึกดี?" },
  { key: "daily-question", text: "มีคำถามอะไรที่อยากถามคนบน WYNOS ไหม?" },
  { key: "daily-photo", text: "วันนี้มีรูปไหนที่อยากแชร์?" },
  { key: "daily-interest", text: "ช่วงนี้คุณกำลังสนใจเรื่องอะไรเป็นพิเศษ?" },
  { key: "daily-weekend", text: "ถ้ามีเวลาว่างตอนนี้ คุณอยากทำอะไร?" },
];

export const FIRST_POST_PROMPTS: PostingPrompt[] = [
  { key: "first-intro", text: "แนะนำตัวสั้น ๆ ให้ทุกคนรู้จักคุณ" },
  { key: "first-today", text: "เล่าเรื่องหนึ่งอย่างเกี่ยวกับวันนี้" },
  { key: "first-question", text: "ถามคำถามที่คุณอยากฟังความคิดเห็นจากคนอื่น" },
];

function localDayNumber(date: Date): number {
  const start = new Date(date.getFullYear(), 0, 0);
  const diff = date.getTime() - start.getTime();
  return Math.floor(diff / 86_400_000);
}

export function dailyPostingPrompt(date = new Date()): PostingPrompt {
  const index = Math.abs(localDayNumber(date)) % DAILY_PROMPTS.length;
  return DAILY_PROMPTS[index];
}

export function postingPromptByKey(key: string | null | undefined, date = new Date()): PostingPrompt | null {
  if (!key) return null;
  const first = FIRST_POST_PROMPTS.find((prompt) => prompt.key === key);
  if (first) return first;
  const daily = DAILY_PROMPTS.find((prompt) => prompt.key === key);
  if (daily) return daily;
  if (key === "daily") return dailyPostingPrompt(date);
  return null;
}

export function allPostingPromptTexts(): string[] {
  return [...DAILY_PROMPTS, ...FIRST_POST_PROMPTS].map((prompt) => prompt.text);
}
