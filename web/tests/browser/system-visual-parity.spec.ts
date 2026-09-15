import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const read = (path: string) => readFileSync(join(root, path), "utf8");

test("source-derived system parity stylesheet is imported before interaction closure", () => {
  const layout = read("app/layout.tsx");
  const sourceLayer = 'import "./system-parity-final.css";';
  const interactionLayer = 'import "./interaction-parity-final.css";';
  expect(layout).toContain(sourceLayer);
  expect(layout).toContain(interactionLayer);
  expect(layout.lastIndexOf(sourceLayer)).toBeGreaterThan(layout.lastIndexOf('import "./system-parity-lock.css";'));
  expect(layout.lastIndexOf(interactionLayer)).toBeGreaterThan(layout.lastIndexOf(sourceLayer));
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
  const navCss = read("app/bottom-nav.css");
  const metrics = read("../app/lib/core/design/wynos_founder_metrics.dart");
  const nav = read("../app/lib/features/root/presentation/widgets/wynos_founder_bottom_navigation.dart");
  expect(metrics).toContain("bottomNavContentHeight = 80");
  expect(metrics).toContain("createActionDiameter = 56");
  expect(nav).toContain("Icon(icon, size: 28)");
  expect(nav).toContain("fontSize: 11.5");
  expect(navCss).toContain("height: calc(var(--wyn-bottom-nav-height) + env(safe-area-inset-bottom))");
  expect(navCss).toContain("width: var(--wyn-create-action)");
  expect(navCss).toContain("width: 28px");
});

test("bottom navigation has exactly one canonical stylesheet (no competing override layer)", () => {
  // WYN-158: .route-bottom-nav/.route-nav-link used to be redefined across
  // parity-final/phase3/pixel-parity-final/system-parity-final (4 files)
  // with slightly different heights/paddings each time. app/bottom-nav.css
  // is now the only file allowed to define them.
  const otherCssFiles = ["parity-final.css", "phase3.css", "pixel-parity-final.css", "system-parity-final.css"];
  for (const file of otherCssFiles) {
    const content = read(`app/${file}`);
    expect(content, `${file} must not redefine .route-bottom-nav`).not.toContain(".route-bottom-nav {");
    expect(content, `${file} must not redefine .route-nav-link`).not.toContain(".route-nav-link {");
  }
  const layout = read("app/layout.tsx");
  expect(layout).toContain('import "./bottom-nav.css";');
});

test("Home actions mirror current Flutter: Like Comment Repost Share, no View", () => {
  const postActions = read("components/home/post-actions.tsx");
  const flutterPage = read("../app/lib/features/home/presentation/widgets/mode_feed_page.dart");
  const flutterCard = read("../app/lib/features/home/presentation/widgets/home_drop_card.dart");
  expect(flutterPage).toContain("showViewCount: false");
  expect(flutterPage).toContain("hideZeroActionCounts: false");
  expect(flutterCard).toContain("Icons.send_outlined");
  // Home renders every count (including zero) directly in React — no
  // hideZeroActionCounts prop, no CSS `content: "0"` fallback needed.
  expect(postActions).toContain("wyn-action-share");
  expect(postActions).not.toContain("hideZeroCount");
  expect(postActions).toContain("<span className=\"wyn-action-button-count\">{likeCount}</span>");
  expect(postActions).not.toContain("Eye");
  expect(postActions).not.toContain("visibility");
});

test("Creation surface matches Beta4 composer metrics while keeping the no Check-in product rule", () => {
  const composer = read("components/beta4-composer.tsx");
  const finalLock = read("app/system-parity-final.css");
  const interaction = read("app/interaction-parity-final.css");
  const flutter = read("../app/lib/features/drop/presentation/create_drop_screen.dart");
  expect(composer).toContain('className="beta4-composer-header"');
  expect(composer).not.toContain('className="beta4-drafts"');
  expect(composer).toContain('className="beta4-toolbar"');
  expect(composer).toContain('className="beta4-ratio-chips"');
  expect(composer).not.toContain("เช็คอิน");
  expect(composer).not.toContain("Check-in");
  expect(composer).not.toContain("สถานที่");
  expect(finalLock).toContain("height: calc(70px + env(safe-area-inset-top))");
  expect(finalLock).toContain("font-size: 22px");
  expect(finalLock).toContain("min-width: 72px");
  expect(finalLock).toContain("height: 42px");
  expect(interaction).not.toContain(".beta4-friend-picker");
  expect(interaction).not.toContain(".beta4-mention-suggestions");
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

test("Post Detail closes the exact current Flutter geometry and interaction gaps", () => {
  const detail = read("components/post-detail-route.tsx");
  const finalLock = read("app/system-parity-final.css");
  const interaction = read("app/interaction-parity-final.css");
  const flutter = read("../app/lib/features/drop/presentation/drop_detail_screen.dart");
  expect(detail).toContain('className={`detail-floating-header');
  expect(detail).toContain('size={44}');
  expect(detail).toContain('size={isReply ? 32 : 36}');
  expect(detail).toContain('placeholder="แสดงความคิดเห็น..."');
  expect(detail).toContain('<BarChart3 size={22} />');
  expect(detail).not.toContain("window.prompt");
  expect(detail).not.toContain("window.confirm");
  expect(interaction).toContain(".detail-dialog-backdrop");
  expect(finalLock).toContain("margin: 7px 10px 0");
  expect(finalLock).toContain("color: var(--wyn-accent)");
  expect(finalLock).toContain("height: 46px");
  expect(flutter).toContain("floating: true");
  expect(flutter).toContain("snap: true");
  expect(flutter).toContain("radius: 22");
  expect(flutter).toContain("radius: isReply ? 16 : 18");
});

test("Profile own action matches the Founder-supplied reference: plain text, no cover photo", () => {
  const profile = read("components/profile-route.tsx");
  const profileGoldenCss = read("app/profile-golden-final.css");
  // Cut to match the reference exactly: no cover photo, no icon inside the
  // edit/share buttons, no separate recommendations/bookmarks icon buttons.
  expect(profile).not.toContain("<Pencil");
  expect(profile).not.toContain("flutter-profile-cover");
  expect(profile).toContain('onClick={() => setEditing(true)}>แก้ไขโปรไฟล์');
  expect(profile).toContain('onClick={() => void share()}>แชร์โปรไฟล์');
  expect(profileGoldenCss).toContain(".wyn-profile-action-primary");
  expect(profileGoldenCss).not.toContain("flutter-profile-cover");
});
