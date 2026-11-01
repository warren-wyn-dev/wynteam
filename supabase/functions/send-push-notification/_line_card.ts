// ZOKY-LINE-001 v2 (Founder 2026-11-01): LINE cards for Food (customer) and
// Merchant (store) notifications — status colour bar, order details, fewer
// messages. Web Push is unchanged and still receives every notification.
// Pure: classification and rendering only, no network.
import type { LineAudience } from "./_line.ts";

export type LineKind =
  | "new_order"      // Merchant: an order the store can accept now
  | "reminder"       // Merchant: order still waiting to be accepted
  | "paid"           // Customer: payment confirmed
  | "preparing"      // Customer: store accepted
  | "delivering"     // Customer: on the way
  | "ready_pickup"   // Customer: ready at the store
  | "done"           // Customer: delivered / picked up
  | "cancelled"
  | "cancel_request" // Merchant: customer asked to cancel
  | "refund"
  | "issue"          // Customer: slip needs another check
  | "test"
  | "info";

export type LineEvent = {
  kind: LineKind;
  orderNumber: string | null;
  /** The original event text, minus the "WYNOS Merchant · " prefix. */
  content: string;
  /** Extra line taken from the event text (ETA minutes, pickup code...). */
  minutes: number | null;
  pickupCode: string | null;
  /** Merchant "ออเดอร์ใหม่" before payment: decided once the order is known. */
  newOrderBeforePayment: boolean;
};

export type LineOrder = {
  orderNumber: string;
  storeName: string | null;
  total: number | null;
  paymentStatus: string | null;
  paymentMethod: string | null;
  fulfillmentType: string | null;
  customerNote: string | null;
  items: { name: string; quantity: number; unitPrice: number | null }[];
};

const MERCHANT_PREFIX = "WYNOS Merchant · ";
const ORDER_NUMBER = /#(WF\d{4,9})\b/;

/** What a notification is, from the text its database trigger wrote. */
export function lineEventFor(app: LineAudience, text: string): LineEvent {
  const content = text.startsWith(MERCHANT_PREFIX) ? text.slice(MERCHANT_PREFIX.length) : text;
  const orderNumber = ORDER_NUMBER.exec(content)?.[1] ?? null;
  const minutesMatch = /(\d{1,3})\s*นาที/.exec(content);
  const minutes = minutesMatch ? Number(minutesMatch[1]) : null;
  const pickupCode = /รหัสรับอาหาร\s*([A-Za-z0-9-]{3,12})/.exec(content)?.[1] ?? null;
  const base = { orderNumber, content, minutes, pickupCode, newOrderBeforePayment: false };
  const is = (pattern: RegExp) => pattern.test(content);

  if (app === "merchant") {
    if (is(/^ทดสอบการแจ้งเตือน/)) return { ...base, kind: "test" };
    if (is(/^ออเดอร์ใหม่ #/)) return { ...base, kind: "new_order", newOrderBeforePayment: true };
    if (is(/^ลูกค้าส่งสลิป #/)) return { ...base, kind: "info" };
    if (is(/^ชำระเงินแล้ว #/)) return { ...base, kind: "new_order" };
    if (is(/^ลูกค้าขอยกเลิก/)) return { ...base, kind: "cancel_request" };
    if (is(/ยกเลิก/) && !is(/คืนเงิน|ได้รับเงิน/)) return { ...base, kind: "cancelled" };
    if (is(/คืนเงิน|ได้รับเงินออเดอร์/)) return { ...base, kind: "refund" };
    if (is(/^ออเดอร์ #WF\d+ รอรับ/)) return { ...base, kind: "reminder" };
    return { ...base, kind: "info" };
  }

  if (is(/^ชำระเงินออเดอร์ #/)) return { ...base, kind: "paid" };
  if (is(/^สลิปออเดอร์ #/)) return { ...base, kind: "issue" };
  if (is(/ยกเลิก/)) return { ...base, kind: "cancelled" };
  if (is(/คืนเงิน/)) return { ...base, kind: "refund" };
  if (is(/ร้านรับออเดอร์แล้ว/)) return { ...base, kind: "preparing" };
  if (is(/กำลังจัดส่ง/)) return { ...base, kind: "delivering" };
  if (is(/พร้อมให้รับที่ร้าน/)) return { ...base, kind: "ready_pickup" };
  if (is(/ส่งถึงแล้ว|รับอาหารเรียบร้อย/)) return { ...base, kind: "done" };
  return { ...base, kind: "info" };
}

/**
 * Fewer LINE messages (Web Push still gets all of them):
 *  - Merchant "ลูกค้าส่งสลิป" is skipped: the slip is checked automatically and
 *    "ชำระเงินแล้ว" follows as the single "new order, paid" card.
 *  - Merchant "ออเดอร์ใหม่" is skipped while a transfer order is still unpaid;
 *    COD orders (and anything already paid) are sent at once. When the order
 *    cannot be read, the message is sent: never silently drop an order.
 */
export function shouldSendLine(app: LineAudience, event: LineEvent, order: LineOrder | null): boolean {
  if (app === "merchant" && /^ลูกค้าส่งสลิป #/.test(event.content)) return false;
  if (event.newOrderBeforePayment && order) {
    return order.paymentMethod === "cod" || order.paymentStatus === "paid";
  }
  return true;
}

type Lang = "th" | "en";

const COLORS: Record<LineKind, string> = {
  new_order: "#E2246F",
  reminder: "#E2246F",
  preparing: "#E2246F",
  paid: "#0A9F55",
  ready_pickup: "#0A9F55",
  done: "#0A9F55",
  delivering: "#1E7FD6",
  cancelled: "#D32F2F",
  cancel_request: "#D32F2F",
  refund: "#EF6C00",
  issue: "#EF6C00",
  test: "#E2246F",
  info: "#7A6A73",
};

function headline(event: LineEvent, order: LineOrder | null, lang: Lang): string {
  const en = lang === "en";
  const cod = order?.paymentMethod === "cod";
  const pickup = order?.fulfillmentType === "pickup";
  switch (event.kind) {
    case "new_order":
      if (cod) return en ? "🆕 New order · Cash on delivery" : "🆕 ออเดอร์ใหม่ · เก็บเงินปลายทาง";
      return en ? "🆕 New order · Paid, ready to accept" : "🆕 ออเดอร์ใหม่ · ชำระแล้ว พร้อมรับ";
    case "reminder":
      return event.minutes != null
        ? (en ? `⏰ Waiting ${event.minutes} min to be accepted` : `⏰ ออเดอร์รอรับ ${event.minutes} นาทีแล้ว`)
        : (en ? "⏰ Order waiting to be accepted" : "⏰ ออเดอร์รอรับ");
    case "paid":
      return en ? "✅ Payment received · waiting for the store" : "✅ ชำระเงินสำเร็จ · รอร้านรับออเดอร์";
    case "preparing":
      return event.minutes != null
        ? (en ? `👨‍🍳 Accepted · ready in about ${event.minutes} min` : `👨‍🍳 ร้านรับออเดอร์แล้ว · ประมาณ ${event.minutes} นาที`)
        : (en ? "👨‍🍳 Accepted · cooking now" : "👨‍🍳 ร้านรับออเดอร์แล้ว · กำลังทำอาหาร");
    case "delivering":
      return en ? "🛵 On the way · get ready" : "🛵 กำลังนำส่ง · เตรียมรับอาหารได้เลย";
    case "ready_pickup":
      return en ? "🛍️ Ready for pickup at the store" : "🛍️ อาหารพร้อมให้รับที่ร้านแล้ว";
    case "done":
      return pickup || /รับอาหาร/.test(event.content)
        ? (en ? "🎉 Picked up · enjoy your meal" : "🎉 รับอาหารเรียบร้อย · ทานให้อร่อยนะ")
        : (en ? "🎉 Delivered · enjoy your meal" : "🎉 ส่งถึงแล้ว · ทานให้อร่อยนะ");
    case "cancelled":
      return en ? "❌ Order cancelled" : "❌ ออเดอร์ถูกยกเลิก";
    case "cancel_request":
      return en ? "⚠️ Customer asked to cancel" : "⚠️ ลูกค้าขอยกเลิกออเดอร์";
    case "refund":
      return en ? "↩️ Refund update" : "↩️ อัปเดตการคืนเงิน";
    case "issue":
      return en ? "⚠️ Payment slip needs another check" : "⚠️ สลิปต้องตรวจสอบอีกครั้ง";
    case "test":
      return en ? "🔔 Test notification" : "🔔 ทดสอบการแจ้งเตือน";
    default:
      return en ? "🔔 ZOKY update" : "🔔 แจ้งเตือนจาก ZOKY";
  }
}

/** The event sentence shown under the headline when it adds information. */
function detailLine(event: LineEvent): string | null {
  // The headline already says it all for these.
  if (["new_order", "test", "reminder", "paid", "preparing", "delivering", "ready_pickup", "done"].includes(event.kind)) {
    return null;
  }
  // Drop the "ออเดอร์ #WFxxxx" lead-in already shown as the order line.
  const text = event.content.replace(/^(ออเดอร์|ชำระเงินออเดอร์|สลิปออเดอร์)\s*#WF\d+\s*/, "").trim();
  return text && text.length > 2 ? text : null;
}

function clip(text: string, max: number): string {
  const chars = Array.from(text.replace(/\s+/g, " ").trim());
  return chars.length <= max ? chars.join("") : `${chars.slice(0, max - 1).join("")}…`;
}

export function baht(value: number): string {
  return `฿${value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

const text = (t: string, extra: Record<string, unknown> = {}) => ({ type: "text", text: t, wrap: true, ...extra });
const row = (left: string, right: string, extra: Record<string, unknown> = {}) => ({
  type: "box",
  layout: "horizontal",
  contents: [
    text(left, { size: "sm", color: "#3B2F35", flex: 5, ...extra }),
    text(right, { size: "sm", color: "#3B2F35", align: "end", flex: 2, ...extra }),
  ],
});

const MAX_ITEMS = 4;

/**
 * One Flex bubble: coloured status bar, order number and store, up to four
 * items, the customer's note (store only), total, and one button. Never
 * includes the customer's name, phone or address (privacy decision D5).
 */
export function lineCardMessages(
  app: LineAudience,
  event: LineEvent,
  order: LineOrder | null,
  url: string,
  lang: Lang,
): unknown[] {
  const en = lang === "en";
  const title = headline(event, order, lang);
  const orderNumber = order?.orderNumber ?? event.orderNumber;
  const body: unknown[] = [];

  const orderLine = [orderNumber ? `#${orderNumber}` : null, order?.storeName ? clip(order.storeName, 40) : null]
    .filter(Boolean).join(" · ");
  if (orderLine) body.push(text(orderLine, { weight: "bold", size: "md", color: "#1F1A1D" }));

  const detail = detailLine(event);
  if (detail) body.push(text(clip(detail, 160), { size: "sm", color: "#6B5F66" }));

  if (event.kind === "ready_pickup" && event.pickupCode) {
    body.push(row(en ? "Pickup code" : "รหัสรับอาหาร", event.pickupCode, { weight: "bold", size: "lg" }));
  }

  const showItems = order && order.items.length > 0 &&
    ["new_order", "reminder", "paid", "preparing", "cancel_request"].includes(event.kind);
  if (showItems) {
    body.push({ type: "separator", margin: "md" });
    for (const item of order.items.slice(0, MAX_ITEMS)) {
      const price = item.unitPrice != null ? baht(item.unitPrice * item.quantity) : "";
      body.push(row(`${item.quantity}× ${clip(item.name, 30)}`, price));
    }
    const more = order.items.length - MAX_ITEMS;
    if (more > 0) body.push(text(en ? `+ ${more} more item(s)` : `+ อีก ${more} รายการ`, { size: "xs", color: "#7A6A73" }));
    if (app === "merchant" && order.customerNote?.trim()) {
      body.push(text(`📝 ${clip(order.customerNote, 120)}`, { size: "sm", color: "#3B2F35" }));
    }
  }
  if (order?.total != null && event.kind !== "test" && event.kind !== "info") {
    body.push({ type: "separator", margin: "md" });
    body.push(row(en ? "Total" : "ยอดรวม", baht(order.total), { weight: "bold", size: "md" }));
  }
  if (body.length === 0) body.push(text(clip(event.content, 160), { size: "sm", color: "#3B2F35" }));

  const button = app === "merchant"
    ? (en ? "View order" : "ดูออเดอร์")
    : (event.kind === "done" ? (en ? "View order" : "ดูออเดอร์") : (en ? "Track order" : "ติดตามออเดอร์"));

  const altText = clip([title, orderNumber ? `#${orderNumber}` : null, order?.total != null ? baht(order.total) : null]
    .filter(Boolean).join(" · "), 400);

  return [{
    type: "flex",
    altText,
    contents: {
      type: "bubble",
      size: "kilo",
      header: {
        type: "box",
        layout: "vertical",
        backgroundColor: COLORS[event.kind],
        paddingAll: "14px",
        contents: [text(title, { color: "#FFFFFF", weight: "bold", size: "md" })],
      },
      body: { type: "box", layout: "vertical", spacing: "sm", paddingAll: "16px", contents: body },
      footer: {
        type: "box",
        layout: "vertical",
        paddingAll: "12px",
        contents: [{
          type: "button",
          style: "primary",
          color: "#E2246F",
          height: "sm",
          action: { type: "uri", label: button, uri: url },
        }],
      },
    },
  }];
}

/** Defensive parse of the PostgREST order row (embedded store and items). */
export function lineOrderFrom(row: unknown): LineOrder | null {
  if (!row || typeof row !== "object") return null;
  const r = row as Record<string, unknown>;
  if (typeof r.order_number !== "string") return null;
  const num = (v: unknown) => (typeof v === "number" ? v : typeof v === "string" && v.trim() !== "" && !Number.isNaN(Number(v)) ? Number(v) : null);
  const str = (v: unknown) => (typeof v === "string" ? v : null);
  const store = r.food_stores as Record<string, unknown> | null | undefined;
  const items = Array.isArray(r.food_order_items) ? r.food_order_items : [];
  return {
    orderNumber: r.order_number,
    storeName: str(store?.name),
    total: num(r.total),
    paymentStatus: str(r.payment_status),
    paymentMethod: str(r.payment_method),
    fulfillmentType: str(r.fulfillment_type),
    customerNote: str(r.customer_note),
    items: items.flatMap((item) => {
      const i = item as Record<string, unknown>;
      const name = str(i.item_name);
      const quantity = num(i.quantity);
      return name && quantity ? [{ name, quantity, unitPrice: num(i.unit_price) }] : [];
    }),
  };
}
