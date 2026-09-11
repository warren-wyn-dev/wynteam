import { assertEquals } from "jsr:@std/assert@1";

import {
  dmMessagePreview,
  messageFor,
  splitPushMessage,
} from "./_lib.ts";

Deno.test("DM push preview uses the exact trimmed text", () => {
  assertEquals(dmMessagePreview("  ไปกินข้าวไหม  ", null, null), "ไปกินข้าวไหม");
});

Deno.test("DM push preview describes image and view-once image", () => {
  assertEquals(dmMessagePreview(null, "image", null), "ส่งรูปภาพ");
  assertEquals(
    dmMessagePreview(null, "image", null, true),
    "ส่งรูปภาพแบบดูครั้งเดียว",
  );
});

Deno.test("DM push preview describes shared content", () => {
  assertEquals(dmMessagePreview(null, null, "drop"), "แชร์โพสต์กับคุณ");
  assertEquals(dmMessagePreview(null, null, "profile"), "แชร์โปรไฟล์กับคุณ");
  assertEquals(dmMessagePreview(null, null, "club"), "แชร์ Club กับคุณ");
});

Deno.test("new_message push becomes sender title plus message body", () => {
  const sentence = messageFor(
    "new_message",
    "Alice",
    null,
    null,
    null,
    "ไปกินข้าวไหม",
  );
  assertEquals(sentence, "Alice ไปกินข้าวไหม");
  assertEquals(splitPushMessage(sentence, "Alice"), {
    title: "Alice",
    body: "ไปกินข้าวไหม",
  });
});
