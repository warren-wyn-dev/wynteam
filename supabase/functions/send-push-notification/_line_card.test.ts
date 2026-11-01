import { assert, assertEquals } from "jsr:@std/assert@1";

import { baht, lineCardMessages, lineEventFor, type LineOrder, lineOrderFrom, shouldSendLine } from "./_line_card.ts";

const URL = "https://liff.line.me/1234567890-AbCdEfGh?to=%2Fmerchant%3Forder%3DWF0033";

const order = (overrides: Partial<LineOrder> = {}): LineOrder => ({
  orderNumber: "WF0033",
  storeName: "ร้านป้าแดง",
  total: 70,
  paymentStatus: "paid",
  paymentMethod: "transfer",
  fulfillmentType: "delivery",
  customerNote: "ไม่ใส่ผักชี",
  items: [
    { name: "ข้าวมันไก่", quantity: 2, unitPrice: 30 },
    { name: "น้ำเปล่า", quantity: 1, unitPrice: 10 },
  ],
  ...overrides,
});

type Bubble = {
  altText: string;
  contents: {
    header: { backgroundColor: string; contents: { text: string }[] };
    body: { contents: Record<string, unknown>[] };
    footer: { contents: { action: { type?: string; label: string; uri: string } }[] };
  };
};
const card = (messages: unknown[]) => messages[0] as Bubble;
const allText = (bubble: Bubble) => JSON.stringify(bubble.contents.body);

// Every event text the production triggers write (merchant prefix included).
Deno.test("merchant events are classified from their trigger text", () => {
  const kind = (text: string) => lineEventFor("merchant", text).kind;
  assertEquals(kind("WYNOS Merchant · ออเดอร์ใหม่ #WF0033 · ฿70.00"), "new_order");
  assertEquals(kind("WYNOS Merchant · ชำระเงินแล้ว #WF0033"), "new_order");
  assertEquals(kind("WYNOS Merchant · ลูกค้ายกเลิกออเดอร์ #WF0033"), "cancelled");
  assertEquals(kind("WYNOS Merchant · ออเดอร์ #WF0033 ยกเลิกอัตโนมัติ (ไม่ได้ชำระเงินภายใน 10 นาที)"), "cancelled");
  assertEquals(kind("WYNOS Merchant · ลูกค้าขอยกเลิกออเดอร์ #WF0033"), "cancel_request");
  assertEquals(kind("WYNOS Merchant · คืนเงินออเดอร์ #WF0033 รอลูกค้ากรอกบัญชีรับเงินคืนในอีเมลจาก Stripe"), "refund");
  assertEquals(kind("WYNOS Merchant · คืนเงินอัตโนมัติออเดอร์ #WF0033"), "refund");
  assertEquals(kind("WYNOS Merchant · ได้รับเงินออเดอร์ #WF0033 หลังยกเลิก ระบบกำลังคืนเงินลูกค้าอัตโนมัติ"), "refund");
  assertEquals(kind("WYNOS Merchant · ออเดอร์ #WF0033 รอรับ 3 นาทีแล้ว"), "reminder");
  assertEquals(kind("WYNOS Merchant · ทดสอบการแจ้งเตือน"), "test");
  assertEquals(kind("ร้าน ป้าแดง ถูกระงับชั่วคราวโดยทีม WYNOS"), "info");
});

Deno.test("customer events are classified from their trigger text", () => {
  const kind = (text: string) => lineEventFor("food", text).kind;
  assertEquals(kind("ชำระเงินออเดอร์ #WF0033 สำเร็จแล้ว"), "paid");
  assertEquals(kind("สลิปออเดอร์ #WF0033 ต้องตรวจสอบอีกครั้ง"), "issue");
  assertEquals(kind("ออเดอร์ #WF0033 ร้านรับออเดอร์แล้ว · กำลังเตรียมอาหาร (ประมาณ 15 นาที)"), "preparing");
  assertEquals(kind("ออเดอร์ #WF0033 กำลังจัดส่ง · เตรียมรับอาหารได้เลย"), "delivering");
  assertEquals(kind("ออเดอร์ #WF0033 พร้อมให้รับที่ร้านแล้ว · รหัสรับอาหาร 4821"), "ready_pickup");
  assertEquals(kind("ออเดอร์ #WF0033 ส่งถึงแล้ว · ดูรูปยืนยันการจัดส่งได้ในหน้าออเดอร์"), "done");
  assertEquals(kind("ออเดอร์ #WF0033 รับอาหารเรียบร้อยแล้ว"), "done");
  assertEquals(kind("ออเดอร์ #WF0033 ถูกร้านยกเลิก · ร้านจะคืนเงินให้คุณ"), "cancelled");
  assertEquals(kind("ออเดอร์ #WF0033 ถูกยกเลิกอัตโนมัติ เพราะไม่ชำระเงินภายใน 10 นาที"), "cancelled");
  assertEquals(kind("ออเดอร์ #WF0033 ถูกยกเลิกแล้ว ระบบกำลังคืนเงินให้อัตโนมัติ"), "cancelled");
  assertEquals(kind("คืนเงินออเดอร์ #WF0033 แล้ว"), "refund");
  assertEquals(kind("คืนเงินออเดอร์ #WF0033 มีปัญหา กรุณาติดต่อร้าน"), "refund");
});

Deno.test("ETA minutes and pickup code are read from the event text", () => {
  assertEquals(lineEventFor("food", "ออเดอร์ #WF0033 ร้านรับออเดอร์แล้ว · กำลังเตรียมอาหาร (ประมาณ 15 นาที)").minutes, 15);
  assertEquals(lineEventFor("food", "ออเดอร์ #WF0033 พร้อมให้รับที่ร้านแล้ว · รหัสรับอาหาร 4821").pickupCode, "4821");
  assertEquals(lineEventFor("merchant", "WYNOS Merchant · ชำระเงินแล้ว #WF0033").orderNumber, "WF0033");
});

Deno.test("store gets one card per normal transfer order (slip and unpaid new order skipped)", () => {
  const unpaid = order({ paymentStatus: "pending" });
  assertEquals(shouldSendLine("merchant", lineEventFor("merchant", "WYNOS Merchant · ออเดอร์ใหม่ #WF0033 · ฿70.00"), unpaid), false);
  assertEquals(shouldSendLine("merchant", lineEventFor("merchant", "WYNOS Merchant · ลูกค้าส่งสลิป #WF0033"), unpaid), false);
  assertEquals(shouldSendLine("merchant", lineEventFor("merchant", "WYNOS Merchant · ชำระเงินแล้ว #WF0033"), order()), true);
});

Deno.test("COD and already-paid new orders are sent at once", () => {
  const event = lineEventFor("merchant", "WYNOS Merchant · ออเดอร์ใหม่ #WF0034 · ฿90.00");
  assertEquals(shouldSendLine("merchant", event, order({ paymentMethod: "cod", paymentStatus: "pending" })), true);
  assertEquals(shouldSendLine("merchant", event, order({ paymentStatus: "paid" })), true);
});

Deno.test("an unreadable order never drops a new order", () => {
  const event = lineEventFor("merchant", "WYNOS Merchant · ออเดอร์ใหม่ #WF0034 · ฿90.00");
  assertEquals(shouldSendLine("merchant", event, null), true);
});

Deno.test("cancellations, refunds, reminders and customer events are always sent", () => {
  for (const text of [
    "WYNOS Merchant · ลูกค้ายกเลิกออเดอร์ #WF0033",
    "WYNOS Merchant · ออเดอร์ #WF0033 รอรับ 3 นาทีแล้ว",
    "WYNOS Merchant · คืนเงินอัตโนมัติออเดอร์ #WF0033",
  ]) assertEquals(shouldSendLine("merchant", lineEventFor("merchant", text), order()), true, text);
  for (const text of ["ชำระเงินออเดอร์ #WF0033 สำเร็จแล้ว", "สลิปออเดอร์ #WF0033 ต้องตรวจสอบอีกครั้ง", "คืนเงินออเดอร์ #WF0033 แล้ว"]) {
    assertEquals(shouldSendLine("food", lineEventFor("food", text), order()), true, text);
  }
});

Deno.test("the paid card shows status bar, store, items, note, total and one button", () => {
  const bubble = card(lineCardMessages("merchant", lineEventFor("merchant", "WYNOS Merchant · ชำระเงินแล้ว #WF0033"), order(), URL, "th"));
  assertEquals(bubble.contents.header.contents[0].text, "🆕 ออเดอร์ใหม่ · ชำระแล้ว พร้อมรับ");
  assertEquals(bubble.contents.header.backgroundColor, "#E2246F");
  const body = allText(bubble);
  for (const expected of ["#WF0033 · ร้านป้าแดง", "2× ข้าวมันไก่", "฿60.00", "1× น้ำเปล่า", "📝 ไม่ใส่ผักชี", "ยอดรวม", "฿70.00"]) {
    assert(body.includes(expected), expected);
  }
  assertEquals(bubble.contents.footer.contents[0].action, { type: "uri", label: "ดูออเดอร์", uri: URL });
  assertEquals(bubble.altText, "🆕 ออเดอร์ใหม่ · ชำระแล้ว พร้อมรับ · #WF0033 · ฿70.00");
});

Deno.test("COD new order says cash on delivery", () => {
  const bubble = card(lineCardMessages("merchant", lineEventFor("merchant", "WYNOS Merchant · ออเดอร์ใหม่ #WF0034 · ฿90.00"), order({ paymentMethod: "cod", paymentStatus: "pending" }), URL, "th"));
  assertEquals(bubble.contents.header.contents[0].text, "🆕 ออเดอร์ใหม่ · เก็บเงินปลายทาง");
});

Deno.test("customer cards never show the store-only note; status colours follow the event", () => {
  const cases: [string, string, string][] = [
    ["ชำระเงินออเดอร์ #WF0033 สำเร็จแล้ว", "✅ ชำระเงินสำเร็จ · รอร้านรับออเดอร์", "#0A9F55"],
    ["ออเดอร์ #WF0033 ร้านรับออเดอร์แล้ว · กำลังเตรียมอาหาร (ประมาณ 15 นาที)", "👨‍🍳 ร้านรับออเดอร์แล้ว · ประมาณ 15 นาที", "#E2246F"],
    ["ออเดอร์ #WF0033 กำลังจัดส่ง · เตรียมรับอาหารได้เลย", "🛵 กำลังนำส่ง · เตรียมรับอาหารได้เลย", "#1E7FD6"],
    ["ออเดอร์ #WF0033 ส่งถึงแล้ว · ดูรูปยืนยันการจัดส่งได้ในหน้าออเดอร์", "🎉 ส่งถึงแล้ว · ทานให้อร่อยนะ", "#0A9F55"],
    ["ออเดอร์ #WF0033 ถูกร้านยกเลิก · ร้านจะคืนเงินให้คุณ", "❌ ออเดอร์ถูกยกเลิก", "#D32F2F"],
    ["คืนเงินออเดอร์ #WF0033 แล้ว", "↩️ อัปเดตการคืนเงิน", "#EF6C00"],
  ];
  for (const [text, title, colour] of cases) {
    const bubble = card(lineCardMessages("food", lineEventFor("food", text), order(), URL, "th"));
    assertEquals(bubble.contents.header.contents[0].text, title, text);
    assertEquals(bubble.contents.header.backgroundColor, colour, text);
    assert(!allText(bubble).includes("ไม่ใส่ผักชี"), `${text}: customer note leaked`);
  }
});

Deno.test("cancellation and refund cards keep the reason sentence", () => {
  const bubble = card(lineCardMessages("food", lineEventFor("food", "ออเดอร์ #WF0033 ถูกร้านยกเลิก · ร้านจะคืนเงินให้คุณ"), order(), URL, "th"));
  assert(allText(bubble).includes("ถูกร้านยกเลิก · ร้านจะคืนเงินให้คุณ"));
});

Deno.test("pickup card shows the pickup code", () => {
  const bubble = card(lineCardMessages("food", lineEventFor("food", "ออเดอร์ #WF0033 พร้อมให้รับที่ร้านแล้ว · รหัสรับอาหาร 4821"), order({ fulfillmentType: "pickup" }), URL, "th"));
  assert(allText(bubble).includes("รหัสรับอาหาร") && allText(bubble).includes("4821"));
});

Deno.test("long orders list four items then a count; long names are clipped", () => {
  const items = Array.from({ length: 7 }, (_, i) => ({ name: `เมนูยาวมาก ${"ก".repeat(40)} ${i}`, quantity: 1, unitPrice: 10 }));
  const bubble = card(lineCardMessages("merchant", lineEventFor("merchant", "WYNOS Merchant · ชำระเงินแล้ว #WF0033"), order({ items }), URL, "th"));
  const body = allText(bubble);
  assert(body.includes("+ อีก 3 รายการ"));
  assertEquals((body.match(/1× /g) ?? []).length, 4);
  assert(body.includes("…"));
});

Deno.test("card works without order details and in English", () => {
  const bubble = card(lineCardMessages("merchant", lineEventFor("merchant", "WYNOS Merchant · ทดสอบการแจ้งเตือน"), null, URL, "en"));
  assertEquals(bubble.contents.header.contents[0].text, "🔔 Test notification");
  assertEquals(bubble.contents.footer.contents[0].action.label, "View order");
  assert(allText(bubble).includes("ทดสอบการแจ้งเตือน"));
});

Deno.test("cards never contain the customer's name, phone or address", () => {
  const leaky = { ...order(), recipient_name: "สมชาย", recipient_phone: "0812345678", shipping_address: "99 ถนนสุขุมวิท" };
  const parsed = lineOrderFrom({
    order_number: "WF0033", total: "70.00", payment_status: "paid", customer_note: null,
    food_stores: { name: "ร้านป้าแดง" }, food_order_items: [{ item_name: "ข้าว", quantity: 1, unit_price: "70" }],
    recipient_name: leaky.recipient_name, recipient_phone: leaky.recipient_phone, shipping_address: leaky.shipping_address,
  });
  const dump = JSON.stringify(lineCardMessages("merchant", lineEventFor("merchant", "WYNOS Merchant · ชำระเงินแล้ว #WF0033"), parsed, URL, "th"));
  for (const secret of ["สมชาย", "0812345678", "สุขุมวิท"]) assert(!dump.includes(secret), secret);
});

Deno.test("order rows are parsed defensively", () => {
  assertEquals(lineOrderFrom(null), null);
  assertEquals(lineOrderFrom({ total: 1 }), null);
  const parsed = lineOrderFrom({ order_number: "WF0033", total: "70.50", food_order_items: [{ item_name: "x", quantity: "2" }, { quantity: 1 }] })!;
  assertEquals(parsed.total, 70.5);
  assertEquals(parsed.items, [{ name: "x", quantity: 2, unitPrice: null }]);
  assertEquals(parsed.paymentMethod, null);
  assertEquals(baht(1234.5), "฿1,234.50");
});
