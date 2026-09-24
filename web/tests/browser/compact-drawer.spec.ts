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
