import { expect, type Locator } from "@playwright/test";

/**
 * Wait until the route transition around `field` has settled. During the
 * 90ms exit the outgoing page wrapper can briefly show the new route, and
 * typing into it is discarded when it unmounts (no person types that fast).
 */
export async function waitForSettledRoute(field: Locator) {
  await expect.poll(() => field.evaluate((input) => {
    for (let el: Element | null = input; el; el = el.parentElement) if (getComputedStyle(el).opacity !== "1") return false;
    const name = input.getAttribute("name");
    return !name || document.querySelectorAll(`[name="${name}"]`).length === 1;
  })).toBe(true);
}
