/* eslint-disable @next/next/no-img-element */
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { ArrowLeft } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import {
  FOOD_ORDER_STATUS_LABEL,
  FOOD_PAYMENT_STATUS_LABEL,
  fetchAdminFoodOrderDetail,
  formatBaht,
  formatThaiDate,
  signAdminFoodEvidence,
} from "@/lib/admin-food";
import { requireAdminRole } from "@/lib/auth";

/** WYN-203: one order for a complaint — items, timeline, slip, delivery photo (admin only, audited). */
export default async function FoodOrderDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { role } = await requireAdminRole();
  if (role !== "admin") redirect("/food");
  const { id } = await params;
  const detail = await fetchAdminFoodOrderDetail(id);
  if (!detail) notFound();
  const { order } = detail;
  const [slip, proof] = await Promise.all([
    signAdminFoodEvidence(order.payment_slip_path),
    signAdminFoodEvidence(detail.proof?.image_path),
  ]);

  return (
    <div className="flex flex-col gap-6 p-6">
      <Link href="/food/orders" className="inline-flex w-fit items-center gap-1 text-sm text-muted-foreground hover:text-foreground">
        <ArrowLeft className="size-4" /> ออเดอร์ทุกร้าน
      </Link>

      <section className="flex flex-col gap-2">
        <div className="flex flex-wrap items-center gap-2">
          <h2 className="text-xl font-semibold">ออเดอร์ #{order.order_number}</h2>
          <Badge variant="gray-tonal">{FOOD_ORDER_STATUS_LABEL[order.status] ?? order.status}</Badge>
          <Badge variant="outline">{FOOD_PAYMENT_STATUS_LABEL[order.payment_status] ?? order.payment_status}</Badge>
          {order.refund_status !== "none" ? <Badge variant="destructive">คืนเงิน: {order.refund_status}</Badge> : null}
        </div>
        <p className="text-sm text-muted-foreground">
          ร้าน <Link href={`/food/stores/${order.store_id}`} className="hover:underline">{detail.store_name ?? "—"}</Link> · สั่งเมื่อ {formatThaiDate(order.created_at)}
        </p>
        <p className="text-xs text-muted-foreground">การเปิดดูหน้านี้ถูกบันทึกใน Audit Log แล้ว</p>
      </section>

      <section className="grid gap-4 lg:grid-cols-2">
        <div className="rounded-xl border p-4">
          <h3 className="mb-2 text-sm font-semibold">ลูกค้า</h3>
          <p className="font-medium">{order.recipient_name}{detail.buyer_username ? <span className="text-muted-foreground"> · @{detail.buyer_username}</span> : null}</p>
          <p className="text-sm">{order.recipient_phone}</p>
          <p className="mt-1 text-sm text-muted-foreground">{order.shipping_address}</p>
          {order.customer_note ? <p className="mt-2 text-sm">หมายเหตุ: {order.customer_note}</p> : null}
        </div>
        <div className="rounded-xl border p-4">
          <h3 className="mb-2 text-sm font-semibold">รายการ</h3>
          <ul className="flex flex-col gap-1 text-sm">
            {detail.items.map((item, index) => (
              <li key={index} className="flex justify-between gap-3">
                <span>{item.quantity}× {item.item_name}{item.item_note ? <span className="text-muted-foreground"> ({item.item_note})</span> : null}</span>
                <span className="tabular-nums">{formatBaht(Number(item.unit_price) * item.quantity)}</span>
              </li>
            ))}
          </ul>
          <div className="mt-3 border-t pt-2 text-sm">
            <div className="flex justify-between"><span>ค่าอาหาร</span><span className="tabular-nums">{formatBaht(order.subtotal)}</span></div>
            <div className="flex justify-between"><span>ค่าส่ง</span><span className="tabular-nums">{formatBaht(order.delivery_fee)}</span></div>
            <div className="flex justify-between font-semibold"><span>รวม</span><span className="tabular-nums">{formatBaht(order.total)}</span></div>
          </div>
        </div>
      </section>

      <section className="grid gap-4 lg:grid-cols-2">
        <div className="rounded-xl border p-4">
          <h3 className="mb-2 text-sm font-semibold">สลิปชำระเงิน</h3>
          {slip.status === "ready" ? (
            <a href={slip.url} target="_blank" rel="noreferrer"><img src={slip.url} alt="สลิปชำระเงิน" className="max-h-96 rounded-lg border object-contain" /></a>
          ) : slip.status === "error" ? (
            <EvidenceError label="มีสลิปแนบไว้ แต่โหลดไฟล์ไม่สำเร็จ" />
          ) : <p className="text-sm text-muted-foreground">ไม่มีสลิป</p>}
          {order.payment_note ? <p className="mt-2 text-sm text-muted-foreground">{order.payment_note}</p> : null}
        </div>
        <div className="rounded-xl border p-4">
          <h3 className="mb-2 text-sm font-semibold">หลักฐานการจัดส่ง</h3>
          {detail.proof ? (
            <>
              <p className="text-sm">{detail.proof.method === "dropoff" ? `วางไว้: ${detail.proof.location_note ?? ""}` : "ส่งถึงมือผู้รับ"} · {formatThaiDate(detail.proof.created_at)}</p>
              {proof.status === "ready" ? (
                <a href={proof.url} target="_blank" rel="noreferrer"><img src={proof.url} alt="รูปยืนยันการจัดส่ง" className="mt-2 max-h-96 rounded-lg border object-contain" /></a>
              ) : proof.status === "error" ? (
                <EvidenceError label="มีรูปยืนยันการจัดส่ง แต่โหลดไฟล์ไม่สำเร็จ" />
              ) : null}
            </>
          ) : <p className="text-sm text-muted-foreground">ยังไม่ส่ง</p>}
        </div>
      </section>

      <section className="rounded-xl border p-4">
        <h3 className="mb-3 text-sm font-semibold">ประวัติสถานะ</h3>
        <ol className="flex flex-col gap-2 text-sm">
          {detail.events.map((event, index) => (
            <li key={index} className="flex flex-col gap-0.5 border-l-2 pl-3">
              <span className="font-medium">{event.to_status ? (FOOD_ORDER_STATUS_LABEL[event.to_status] ?? event.to_status) : event.event_type}</span>
              <span className="text-muted-foreground">{formatThaiDate(event.created_at)}{event.actor_username ? ` · @${event.actor_username}` : ""}{event.note ? ` · ${event.note}` : ""}</span>
            </li>
          ))}
          {detail.events.length === 0 ? <li className="text-muted-foreground">ไม่มีประวัติ</li> : null}
        </ol>
      </section>
    </div>
  );
}

function EvidenceError({ label }: { label: string }) {
  return (
    <p role="alert" className="mt-2 text-sm text-destructive">
      {label} · <a href="" className="underline">ลองโหลดอีกครั้ง</a>
    </p>
  );
}
