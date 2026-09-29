import { assertEquals } from "jsr:@std/assert";
import { reactivationMessage } from "./_lib.ts";

Deno.test("Thai onboarding stages use the approved WYNOS copy", () => {
  assertEquals(reactivationMessage(1, "th"), {
    title: "ยินดีต้อนรับสู่ WYNOS 👋",
    body: "บัญชีของคุณพร้อมแล้ว เข้ามาเริ่มต้นใช้งานกันได้เลย",
  });
  assertEquals(reactivationMessage(2, "th").title, "แวะมาดู WYNOS กัน 👀");
  assertEquals(reactivationMessage(3, "th").title, "WYNOS ยังรอคุณอยู่นะ ✨");
});

Deno.test("weekly reactivation copy rotates every three sends", () => {
  assertEquals(
    reactivationMessage(4, "th"),
    reactivationMessage(7, "th"),
  );
  assertEquals(
    reactivationMessage(5, "th"),
    reactivationMessage(8, "th"),
  );
  assertEquals(
    reactivationMessage(6, "th"),
    reactivationMessage(9, "th"),
  );
});

Deno.test("English users get English copy and invalid stages fall back safely", () => {
  assertEquals(reactivationMessage(1, "en").title, "Welcome to WYNOS 👋");
  assertEquals(reactivationMessage(0, "en"), reactivationMessage(1, "en"));
});
