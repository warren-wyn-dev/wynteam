import { readFile } from "node:fs/promises";
import path from "node:path";
import { expect, test } from "@playwright/test";

test("drawer uses founder-approved compact four-item layout and anchored footer", async () => {
  const root = process.cwd();
  const [drawer, css, layout] = await Promise.all([
    readFile(path.join(root, "components/home/home-drawer.tsx"), "utf8"),
    readFile(path.join(root, "app/drawer-v2.css"), "utf8"),
    readFile(path.join(root, "app/layout.tsx"), "utf8"),
  ]);
  expect(drawer).not.toContain('className="home-drawer-close"');
  expect(drawer).not.toContain('name="close"');
  expect(drawer).not.toContain('go("/drafts")');
  expect(drawer).not.toContain('className="drawer-menu-row" type="button" onClick={() => go("/add-to-home.html")');
  const options = [...drawer.matchAll(/className="drawer-menu-row" type="button" onClick=\{\(\) => go\("([^"]+)"\)\}/g)].map((match) => match[1]);
  expect(options).toEqual(["/clubs", "/clubs/new", "/clubs?mine=1", "/bookmarks"]);
  expect(drawer).toContain('className="wynos-drawer-footer"');
  expect(drawer).toContain('setPanel("feedback")');
  expect(drawer).toContain('setPanel("help")');
  expect(drawer).toContain('event.key !== "Escape"');
  expect(drawer).toContain('origin.x - touch.clientX > 90');
  expect(css).toContain("padding: calc(env(safe-area-inset-top) + 10px)");
  expect(css).toContain("calc(env(safe-area-inset-bottom) + 14px)");
  expect(css).toContain("grid-template-columns: minmax(0, 1fr) minmax(0, 1fr)");
  expect(layout).toContain('import "./drawer-v2.css";');
});

test("help and feedback footer buttons have real actions, without claiming a server submission", async () => {
  const root = process.cwd();
  const drawer = await readFile(path.join(root, "components/home/home-drawer.tsx"), "utf8");
  expect(drawer).toContain('navigator.clipboard.writeText(feedback.trim())');
  expect(drawer).toContain('navigator.share({ title: "ข้อเสนอแนะ WYNOS", text: feedback.trim() })');
  expect(drawer).toContain('window.open("/add-to-home.html"');
  expect(drawer).toContain('go("/settings")');
  expect(drawer).toContain("คัดลอกข้อความได้");
});

test("drawer polish keeps a dark profile name, centered badge and smaller accessible rows", async ({ page }) => {
  const root = process.cwd();
  const css = await readFile(path.join(root, "app/drawer-v2.css"), "utf8");
  expect(css).toContain("border-top-color: color-mix(in srgb, var(--hairline) 62%, transparent)");
  await page.setContent(
    '<style>:root{--paper:#fff;--ink:#12120f;--graphite:#8a8880;--hairline:#e8e6e0;--surface:#f1efe9}*{box-sizing:border-box}.drawer-identity-copy>span{color:var(--graphite)}button{border:0}</style>' +
      "<style>" + css + "</style>" +
      '<aside class="home-drawer wynos-drawer-v2">' +
      '<button class="drawer-identity"><span class="drawer-identity-copy">' +
      '<span class="wynos-drawer-name"><strong>WYNOS ONLINE</strong><span class="route-verified">✓</span></span>' +
      '<small>@wynos_online</small></span></button>' +
      '<nav class="drawer-menu-list"><button class="drawer-menu-row"><span class="drawer-menu-icon"></span>สำรวจ Club</button>' +
      '<button class="drawer-menu-row"><span class="drawer-menu-icon"></span>สร้าง Club</button></nav></aside>',
  );
  const actual = await page.evaluate(() => {
    const name = document.querySelector(".wynos-drawer-name")!;
    const strong = name.querySelector("strong")!;
    const badge = name.querySelector(".route-verified")!;
    const row = document.querySelector(".drawer-menu-row")!;
    const icon = row.querySelector(".drawer-menu-icon")!;
    const nextRow = document.querySelectorAll(".drawer-menu-row")[1];
    return {
      nameColor: getComputedStyle(name).color,
      strongColor: getComputedStyle(strong).color,
      badgeAlign: getComputedStyle(badge).alignSelf,
      rowHeight: getComputedStyle(row).height,
      iconWidth: getComputedStyle(icon).width,
      iconHeight: getComputedStyle(icon).height,
      separator: getComputedStyle(nextRow).borderTopColor,
    };
  });
  expect(actual.nameColor).toBe("rgb(18, 18, 15)");
  expect(actual.strongColor).toBe("rgb(18, 18, 15)");
  expect(actual.badgeAlign).toBe("center");
  expect(actual.rowHeight).toBe("58px");
  expect(actual.iconWidth).toBe("36px");
  expect(actual.iconHeight).toBe("36px");
  expect(actual.separator).not.toBe("rgb(232, 230, 224)");
});
