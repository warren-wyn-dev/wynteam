import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const read = (path: string) => readFileSync(join(root, path), "utf8");

test("system parity lock is the final stylesheet", () => {
  const layout = read("app/layout.tsx");
  const finalImport = 'import "./system-parity-lock.css";';
  expect(layout).toContain(finalImport);
  expect(layout.lastIndexOf(finalImport)).toBeGreaterThan(layout.lastIndexOf('import "./founder-parity-lock.css";'));
  expect(layout.indexOf(finalImport)).toBe(layout.lastIndexOf(finalImport));
});

test("Search keeps the current Flutter Discovery then three-tab contract", () => {
  const search = read("components/search-route.tsx");
  expect(search).toContain('useState<"user" | "drop" | "club">');
  expect(search).toContain("User");
  expect(search).toContain("โพสต์");
  expect(search).toContain("Club");
  expect(search).not.toContain('setTab("all")');
});

test("Notifications keep All/Mentions plus Flutter day grouping", () => {
  const notifications = read("components/notifications-route.tsx");
  expect(notifications).toContain('setTab("all")');
  expect(notifications).toContain('setTab("mentions")');
  expect(notifications).toContain('today: "วันนี้"');
  expect(notifications).toContain('yesterday: "เมื่อวานนี้"');
  expect(notifications).toContain('older: "เก่ากว่านี้"');
  expect(notifications).toContain("groupWithinDay");
});

test("Chat inbox matches Flutter title and three pill destinations", () => {
  const page = read("app/chat/page.tsx");
  const chat = read("components/chat-inbox-parity.tsx");
  const lock = read("app/system-parity-lock.css");
  expect(page).toContain("ChatInboxParityRoute");
  expect(chat).toContain("<h1>ข้อความ</h1>");
  expect(chat).toContain("ทั้งหมด");
  expect(chat).toContain("ยังไม่อ่าน");
  expect(chat).toContain('const requestLabel = requests.length > 0 ? `คำขอ (${requests.length})` : "คำขอ";');
  expect(lock).toContain("height: 62px");
  expect(lock).toContain(".flutter-chat-pill-tabs");
  expect(lock).toContain("height: 36px");
});

test("Settings root preserves the current seven-row Beta4 contract", () => {
  const settings = read("components/settings-route.tsx");
  for (const label of [
    'title="บัญชี"',
    'title="ความเป็นส่วนตัว"',
    'title="การแจ้งเตือน"',
    'title="ธีมเข้ม"',
    'title="ช่วยเหลือ"',
    'title="ข้อกำหนดและความเป็นส่วนตัว"',
    'title="ออกจากระบบ"',
  ]) expect(settings).toContain(label);
  expect(settings).toContain('useState("V1.0.0 Beta4")');
  const lock = read("app/system-parity-lock.css");
  expect(lock).toContain("border-radius: 18px");
  expect(lock).toContain("min-height: 64px");
});

test("Home actions and creation surface keep current product decisions", () => {
  const lock = read("app/system-parity-lock.css");
  const home = read("components/parity-home-final.tsx");
  expect(lock).toContain(".audit-feed-post .audit-share-action");
  expect(lock).toContain('button[aria-label="แชร์"]');
  expect(lock).toContain('content: "0"');
  expect(lock).toContain('content: "ยกเลิก"');
  expect(home).not.toContain("เช็คอิน");
  expect(home).not.toContain("Check-in");
});

test("Post activity remains exactly Likes and Reposts", () => {
  const detail = read("components/post-detail-route.tsx");
  expect(detail).toContain('type ActivityTab = "likes" | "redrops";');
  expect(detail).toContain("กิจกรรมโพสต์");
  expect(detail).toContain("ถูกใจ");
  expect(detail).toContain("รีโพสต์");
  expect(detail).not.toContain('setActivityTab("all")');
});
