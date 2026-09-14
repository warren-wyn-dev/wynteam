import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const read = (path: string) => readFileSync(join(root, path), "utf8");

test("source-derived system parity stylesheet is imported last", () => {
  const layout = read("app/layout.tsx");
  const finalImport = 'import "./system-parity-final.css";';
  expect(layout).toContain(finalImport);
  expect(layout.lastIndexOf(finalImport)).toBeGreaterThan(layout.lastIndexOf('import "./system-parity-lock.css";'));
  expect(layout.indexOf(finalImport)).toBe(layout.lastIndexOf(finalImport));
});

test("Search keeps the current Flutter Discovery then three-tab contract", () => {
  const search = read("components/search-route.tsx");
  const flutter = read("../app/lib/features/search/presentation/search_screen.dart");
  expect(search).toContain('useState<"user" | "drop" | "club">');
  expect(search).toContain("User");
  expect(search).toContain("โพสต์");
  expect(search).toContain("Club");
  expect(search).not.toContain('setTab("all")');
  expect(flutter).toContain("const WynosSocialTabBar(labels: ['User', 'โพสต์', 'Club'])");
  expect(flutter).toContain("height: 64");
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
  const flutter = read("../app/lib/features/chat/presentation/chat_inbox_screen.dart");
  expect(page).toContain("ChatInboxParityRoute");
  expect(chat).toContain("<h1>ข้อความ</h1>");
  expect(chat).toContain("ทั้งหมด");
  expect(chat).toContain("ยังไม่อ่าน");
  expect(chat).toContain('const requestLabel = requests.length > 0 ? `คำขอ (${requests.length})` : "คำขอ";');
  expect(lock).toContain("height: 62px");
  expect(lock).toContain(".flutter-chat-pill-tabs");
  expect(lock).toContain("height: 36px");
  expect(flutter).toContain("toolbarHeight: 62");
  expect(flutter).toContain("label: requestLabel");
  expect(flutter).toContain(": 'คำขอ';");
});

test("Settings root preserves exact current seven-row Beta4 structure", () => {
  const settings = read("components/settings-route.tsx");
  const finalLock = read("app/system-parity-final.css");
  const flutter = read("../app/lib/features/settings/presentation/settings_screen.dart");
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
  expect(settings).toContain("settings-leading-icon");
  expect(settings).not.toContain('title="ธีมเข้ม" description=');
  expect(settings).not.toContain('title="ช่วยเหลือ" description=');
  expect(finalLock).toContain("min-height: 52px");
  expect(finalLock).toContain("width: 34px");
  expect(finalLock).toContain("font-size: 13px");
  expect(flutter).toContain("BoxConstraints(minHeight: 52)");
  expect(flutter).toContain("width: 34");
  expect(flutter).toContain("height: 34");
});

test("root navigation matches Founder metrics", () => {
  const finalLock = read("app/system-parity-final.css");
  const metrics = read("../app/lib/core/design/wynos_founder_metrics.dart");
  const nav = read("../app/lib/features/root/presentation/widgets/wynos_founder_bottom_navigation.dart");
  expect(metrics).toContain("bottomNavContentHeight = 80");
  expect(metrics).toContain("createActionDiameter = 56");
  expect(nav).toContain("Icon(icon, size: 28)");
  expect(nav).toContain("fontSize: 11.5");
  expect(finalLock).toContain("height: calc(80px + env(safe-area-inset-bottom))");
  expect(finalLock).toContain("width: 56px");
  expect(finalLock).toContain("width: 28px");
});

test("Home actions mirror current Flutter: Like Comment Repost Share, no View", () => {
  const lock = read("app/system-parity-lock.css");
  const home = read("components/parity-home-final.tsx");
  const flutterPage = read("../app/lib/features/home/presentation/widgets/mode_feed_page.dart");
  const flutterCard = read("../app/lib/features/home/presentation/widgets/home_drop_card.dart");

  expect(flutterPage).toContain("showViewCount: false");
  expect(flutterPage).toContain("hideZeroActionCounts: false");
  expect(flutterCard).toContain("Icons.send_outlined");
  expect(home).toContain("audit-share-action");
  expect(lock).not.toMatch(/\.audit-share-action\s*\{[\s\S]*?display:\s*none/);
  expect(lock).not.toMatch(/button\[aria-label="แชร์"\]\s*\{[\s\S]*?display:\s*none/);
  expect(lock).toContain('content: "0"');
});

test("Creation surface matches Beta4 composer metrics while keeping the no Check-in product rule", () => {
  const composer = read("components/beta4-composer.tsx");
  const finalLock = read("app/system-parity-final.css");
  const flutter = read("../app/lib/features/drop/presentation/create_drop_screen.dart");
  expect(composer).toContain('className="beta4-composer-header"');
  expect(composer).toContain('className="beta4-drafts"');
  expect(composer).toContain('className="beta4-toolbar"');
  expect(composer).toContain('className="beta4-ratio-chips"');
  expect(composer).not.toContain("เช็คอิน");
  expect(composer).not.toContain("Check-in");
  expect(composer).not.toContain("สถานที่");
  expect(finalLock).toContain("height: calc(70px + env(safe-area-inset-top))");
  expect(finalLock).toContain("font-size: 22px");
  expect(finalLock).toContain("min-width: 72px");
  expect(finalLock).toContain("height: 42px");
  expect(flutter).toContain("height: 70");
  expect(flutter).toContain("fontSize: 22");
});

test("Post activity remains exactly Likes and Reposts", () => {
  const detail = read("components/post-detail-route.tsx");
  expect(detail).toContain('type ActivityTab = "likes" | "redrops";');
  expect(detail).toContain("กิจกรรมโพสต์");
  expect(detail).toContain("ถูกใจ");
  expect(detail).toContain("รีโพสต์");
  expect(detail).not.toContain('setActivityTab("all")');
});


test("Post Detail closes the exact current Flutter geometry gaps", () => {
  const detail = read("components/post-detail-route.tsx");
  const finalLock = read("app/system-parity-final.css");
  const flutter = read("../app/lib/features/drop/presentation/drop_detail_screen.dart");
  expect(detail).toContain('className={`detail-floating-header');
  expect(detail).toContain('size={44}');
  expect(detail).toContain('className="detail-author-primary"');
  expect(detail).toContain('size={isReply ? 32 : 36}');
  expect(detail).toContain('placeholder="แสดงความคิดเห็น..."');
  expect(detail).toContain('<BarChart3 size={22} />');
  expect(finalLock).toContain("margin: 7px 10px 0");
  expect(finalLock).toContain("color: #f44336");
  expect(finalLock).toContain("height: 46px");
  expect(flutter).toContain("floating: true");
  expect(flutter).toContain("snap: true");
  expect(flutter).toContain("radius: 22");
  expect(flutter).toContain("radius: isReply ? 16 : 18");
});

test("Profile own action keeps the Founder edit icon and exact dimensions", () => {
  const profile = read("components/profile-route.tsx");
  const finalLock = read("app/system-parity-final.css");
  const flutter = read("../app/lib/features/profile/presentation/view_profile_screen.dart");
  expect(profile).toContain('<Pencil size={20} />แก้ไขโปรไฟล์');
  expect(finalLock).toContain("font-size: 15.5px");
  expect(finalLock).toContain("width: 20px");
  expect(flutter).toContain("Icons.edit_outlined, size: 20");
});
