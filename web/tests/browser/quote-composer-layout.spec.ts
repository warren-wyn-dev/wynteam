import { readFile } from "node:fs/promises";
import path from "node:path";
import { expect, test } from "@playwright/test";

// The authenticated posting flow and iOS keyboard need manual device QA;
// guard the exact structure that previously displaced and stretched the quote.
test("Home and Profile use the same full-screen quote composer with signed-in identity", async () => {
  const root = process.cwd();
  const [composer, home, profileCard, identity] = await Promise.all([
    readFile(path.join(root, "components/quote-redrop-composer.tsx"), "utf8"),
    readFile(path.join(root, "components/home/home-screen.tsx"), "utf8"),
    readFile(path.join(root, "components/golden-drop-card.tsx"), "utf8"),
    readFile(path.join(root, "lib/home-parity-data.ts"), "utf8"),
  ]);
  expect(home).toContain("viewer={identity}");
  expect(home).toContain("viewerId={userId}");
  expect(profileCard).toContain("<QuoteRedropComposer");
  expect(profileCard).toContain("viewerId={userId}");
  expect(composer).toContain('select("username,display_name,avatar_url,is_verified")');
  expect(identity).toContain('select("id,username,display_name,avatar_url,is_verified")');
  expect(composer).toContain("actor?.avatar_url");
  expect(composer).toContain("actor?.is_verified");
  expect(composer).toContain("row.author_is_verified");
  expect(composer).not.toContain('label="WYNOS" size={44}');
});

test("Quote layout stays within the mobile visual viewport and anchors quoted post near comment", async () => {
  const root = process.cwd();
  const [composer, css] = await Promise.all([
    readFile(path.join(root, "components/quote-redrop-composer.tsx"), "utf8"),
    readFile(path.join(root, "app/system-parity-final.css"), "utf8"),
  ]);
  expect(composer).toContain('import { createPortal } from "react-dom"');
  expect(composer).toContain("document.body,");
  expect(composer).toContain("window.visualViewport");
  expect(composer).toContain('visual?.addEventListener("resize", update)');
  expect(composer).toContain('visual?.addEventListener("scroll", update)');
  expect(composer).toContain('visual?.removeEventListener("resize", update)');
  expect(composer).toContain('style={viewport ? { top: viewport.top, height: viewport.height } : undefined}');
  expect(composer).toContain('className="wyn-quote-original"');
  expect(composer).toContain('className="beta4-compose-text wyn-quote-text"');
  expect(composer).toContain('rows={2}');
  expect(composer).not.toContain('autoFocus');
  expect(composer).toContain('node.style.height = "auto"');
  expect(css).toContain(".wyn-quote-composer .wyn-quote-row");
  expect(css).toContain("grid-template-columns: 44px minmax(0, 1fr)");
  expect(css).toContain(".wyn-quote-composer .wyn-quote-original-text");
  expect(css).toContain("-webkit-line-clamp: 4");
  expect(css).toContain("height: clamp(92px, 26vw, 156px)");
  expect(css).toContain(".wyn-quote-composer .wyn-quote-scroll");
  expect(css).toContain("-webkit-overflow-scrolling: touch");
});
