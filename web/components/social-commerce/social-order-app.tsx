/* eslint-disable @next/next/no-img-element */
"use client";

import {
  ArrowLeft,
  CheckCircle2,
  Minus,
  Plus,
  ReceiptText,
  ShoppingBag,
  Upload,
} from "lucide-react";
import type { SupabaseClient } from "@supabase/supabase-js";
import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import {
  cancelFoodCustomerOrder,
  fetchFoodPromptPayQr,
  foodMoney,
  foodPaymentStatusLabel,
  foodPublicUrl,
  submitFoodPayment,
  uploadFoodPaymentSlip,
  type FoodCustomerOrder,
} from "@/lib/food-customer";
import {
  createSocialCommerceOrder,
  fetchSocialCommerceOffer,
  fetchSocialCommerceOrder,
  socialCommerceError,
  subscribeSocialCommerceOrder,
  type SocialCommerceOffer,
} from "@/lib/social-commerce";

type PaymentQr = {
  dataUrl: string;
  amount: number;
  payeeName: string | null;
};

function statusCopy(order: FoodCustomerOrder) {
  if (order.payment_status === "paid") return "ชำระเงินสำเร็จแล้ว";
  if (order.payment_status === "submitted") return "ส่งสลิปแล้ว กำลังตรวจสอบ";
  if (order.payment_status === "issue") return "การชำระเงินต้องตรวจสอบอีกครั้ง";
  if (order.status === "cancelled") return "ออเดอร์ถูกยกเลิกแล้ว";
  return "รอชำระเงิน";
}

function SocialOrderInner({
  client,
  userId,
  dropId,
}: {
  client: SupabaseClient;
  userId: string;
  dropId: string;
}) {
  const [offer, setOffer] = useState<SocialCommerceOffer | null>(null);
  const [order, setOrder] = useState<FoodCustomerOrder | null>(null);
  const [qr, setQr] = useState<PaymentQr | null>(null);
  const [recipientName, setRecipientName] = useState("");
  const [recipientPhone, setRecipientPhone] = useState("");
  const [shippingAddress, setShippingAddress] = useState("");
  const [customerNote, setCustomerNote] = useState("");
  const [quantity, setQuantity] = useState(1);
  const [slipFile, setSlipFile] = useState<File | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");

  const loadOffer = useCallback(async () => {
    try {
      const next = await fetchSocialCommerceOffer(client, dropId);
      setOffer(next);
    } catch (error) {
      setMessage(socialCommerceError(error));
    } finally {
      setLoading(false);
    }
  }, [client, dropId]);

  const reloadOrder = useCallback(async (orderId: string) => {
    try {
      const next = await fetchSocialCommerceOrder(client, orderId);
      setOrder(next);
      if (next && next.payment_status !== "paid" && next.status !== "cancelled") {
        const nextQr = await fetchFoodPromptPayQr(client, next.id);
        setQr(nextQr);
      }
    } catch (error) {
      setMessage(socialCommerceError(error));
    }
  }, [client]);

  useEffect(() => {
    void loadOffer();
  }, [loadOffer]);

  useEffect(() => {
    if (!order?.id) return;
    const channel = subscribeSocialCommerceOrder(client, order.id, () => void reloadOrder(order.id));
    return () => { void client.removeChannel(channel); };
  }, [client, order?.id, reloadOrder]);

  const totals = useMemo(() => {
    const item = Number(offer?.price ?? 0) * quantity;
    const delivery = Number(offer?.delivery_fee ?? 0);
    return { item, delivery, total: item + delivery };
  }, [offer, quantity]);

  const createOrder = async () => {
    if (!offer) return;
    setBusy(true);
    setMessage("");
    try {
      const orderId = await createSocialCommerceOrder(client, dropId, {
        recipientName,
        recipientPhone,
        shippingAddress,
        customerNote,
        quantity,
      });
      await reloadOrder(orderId);
      setMessage("สร้างออเดอร์แล้ว กรุณาสแกน QR เพื่อชำระเงิน");
    } catch (error) {
      setMessage(socialCommerceError(error));
    } finally {
      setBusy(false);
    }
  };

  const submitSlip = async () => {
    if (!order || !slipFile) return;
    setBusy(true);
    setMessage("");
    try {
      const path = await uploadFoodPaymentSlip(client, userId, order.id, slipFile);
      const result = await submitFoodPayment(client, order.id, path);
      await reloadOrder(order.id);
      setSlipFile(null);
      if (result.status === "auto_verified") {
        setMessage("ตรวจสอบสลิปสำเร็จ ชำระเงินแล้ว");
      } else if (result.status === "rejected") {
        setMessage("สลิปไม่ผ่านการตรวจสอบ กรุณาตรวจสอบแล้วส่งใหม่");
      } else {
        setMessage("ส่งสลิปแล้ว ร้านจะตรวจสอบให้");
      }
    } catch (error) {
      setMessage(socialCommerceError(error));
    } finally {
      setBusy(false);
    }
  };

  const cancel = async () => {
    if (!order || !window.confirm("ยืนยันยกเลิกออเดอร์นี้?")) return;
    setBusy(true);
    try {
      await cancelFoodCustomerOrder(client, order.id, "ยกเลิกจาก Social Commerce");
      await reloadOrder(order.id);
      setMessage("ยกเลิกออเดอร์แล้ว");
    } catch (error) {
      setMessage(socialCommerceError(error));
    } finally {
      setBusy(false);
    }
  };

  if (loading) {
    return <main className="wsc-page"><div className="route-system-spinner" aria-label="กำลังโหลด" /></main>;
  }

  if (!offer) {
    return (
      <main className="wsc-page">
        <header className="wsc-header"><Link href={`/drop/${dropId}`} aria-label="กลับ"><ArrowLeft /></Link><strong>WYNOS Merchant</strong><span /></header>
        <section className="wsc-empty"><ShoppingBag size={42} strokeWidth={1.4} /><h1>สินค้านี้ยังไม่พร้อมสั่งซื้อ</h1><p>{message || "ร้านอาจหยุดขายหรือยกเลิกการเชื่อมโพสต์นี้แล้ว"}</p><Link href={`/drop/${dropId}`}>กลับไปที่โพสต์</Link></section>
      </main>
    );
  }

  const image = foodPublicUrl(client, offer.image_path);
  const minimum = Number(offer.minimum_order ?? 0);
  const minimumMet = totals.item >= minimum;
  const canOrder = offer.is_orderable && minimumMet;

  return (
    <main className="wsc-page">
      <header className="wsc-header">
        <Link href={`/drop/${dropId}`} aria-label="กลับ"><ArrowLeft /></Link>
        <strong>สั่งซื้อจาก WYNOS</strong>
        <span />
      </header>

      {message ? <div className="wsc-toast" role="status">{message}</div> : null}

      <section className="wsc-product">
        <div className="wsc-product-image">{image ? <img src={image} alt="" /> : <ShoppingBag size={34} strokeWidth={1.4} />}</div>
        <div className="wsc-product-copy">
          <small>{offer.store_name}</small>
          <h1>{offer.item_name}</h1>
          {offer.item_description ? <p>{offer.item_description}</p> : null}
          <strong>{foodMoney(offer.price)}</strong>
        </div>
      </section>

      {!order ? (
        <>
          <section className="wsc-card">
            <h2>จำนวน</h2>
            <div className="wsc-quantity">
              <button type="button" onClick={() => setQuantity((value) => Math.max(1, value - 1))}><Minus size={18} /></button>
              <strong>{quantity}</strong>
              <button type="button" onClick={() => setQuantity((value) => Math.min(99, value + 1))}><Plus size={18} /></button>
            </div>
            {!minimumMet ? <p className="wsc-warning">ยอดขั้นต่ำของร้าน {foodMoney(minimum)} กรุณาเพิ่มจำนวนสินค้า</p> : null}
          </section>

          <section className="wsc-card wsc-form">
            <h2>ข้อมูลจัดส่ง</h2>
            <label>ชื่อผู้รับ<input value={recipientName} onChange={(event) => setRecipientName(event.target.value)} autoComplete="name" /></label>
            <label>เบอร์โทร<input value={recipientPhone} onChange={(event) => setRecipientPhone(event.target.value)} inputMode="tel" autoComplete="tel" /></label>
            <label>ที่อยู่จัดส่ง<textarea value={shippingAddress} onChange={(event) => setShippingAddress(event.target.value)} autoComplete="street-address" /></label>
            <label>หมายเหตุ<textarea value={customerNote} onChange={(event) => setCustomerNote(event.target.value)} placeholder="รายละเอียดเพิ่มเติม (ถ้ามี)" /></label>
          </section>

          <section className="wsc-card wsc-summary">
            <div><span>ค่าสินค้า</span><strong>{foodMoney(totals.item)}</strong></div>
            <div><span>ค่าจัดส่ง</span><strong>{foodMoney(totals.delivery)}</strong></div>
            <div className="is-total"><span>ยอดรวม</span><strong>{foodMoney(totals.total)}</strong></div>
          </section>

          {!offer.store_open ? <div className="wsc-warning wsc-warning--block">ร้านปิดรับออเดอร์อยู่ในขณะนี้</div> : null}
          {!offer.payment_ready ? <div className="wsc-warning wsc-warning--block">ร้านยังไม่ได้ตั้งค่า PromptPay</div> : null}
          <button className="wsc-primary" type="button" disabled={!canOrder || busy} onClick={() => void createOrder()}>
            {busy ? "กำลังสร้างออเดอร์…" : "ยืนยันสั่งซื้อ"}
          </button>
        </>
      ) : (
        <>
          <section className="wsc-card wsc-order-status">
            <ReceiptText size={24} />
            <div><small>ออเดอร์ #{order.order_number}</small><strong>{statusCopy(order)}</strong><span>{foodPaymentStatusLabel(order.payment_status)}</span></div>
            {order.payment_status === "paid" ? <CheckCircle2 className="wsc-paid-icon" size={25} /> : null}
          </section>

          {order.payment_status === "paid" ? (
            <section className="wsc-success">
              <CheckCircle2 size={46} />
              <h2>ชำระเงินเรียบร้อย</h2>
              <p>ร้านได้รับแจ้งเตือนแล้ว และสามารถเริ่มดำเนินการออเดอร์ได้ทันที</p>
            </section>
          ) : order.status !== "cancelled" ? (
            <>
              <section className="wsc-card wsc-payment">
                <h2>ชำระด้วย PromptPay</h2>
                <strong className="wsc-total">{foodMoney(order.total)}</strong>
                {qr ? <img className="wsc-qr" src={qr.dataUrl} alt="PromptPay QR" /> : <div className="wsc-warning">สร้าง QR ไม่สำเร็จ กรุณาติดต่อร้าน</div>}
                {qr?.payeeName ? <small>ผู้รับ: {qr.payeeName}</small> : null}
                <p>สแกน QR ด้วยแอปธนาคาร แล้วแนบสลิปด้านล่าง</p>
              </section>

              {order.payment_status !== "submitted" ? (
                <section className="wsc-card wsc-slip">
                  <label className="wsc-upload">
                    <input type="file" accept="image/jpeg,image/png,image/webp" onChange={(event) => setSlipFile(event.target.files?.[0] ?? null)} />
                    <Upload size={21} />
                    <span>{slipFile ? slipFile.name : "แนบสลิปการโอนเงิน"}</span>
                  </label>
                  <button className="wsc-primary" type="button" disabled={!slipFile || busy} onClick={() => void submitSlip()}>
                    {busy ? "กำลังตรวจสอบ…" : "ส่งสลิปเพื่อตรวจสอบ"}
                  </button>
                </section>
              ) : (
                <div className="wsc-review">ระบบกำลังตรวจสอบสลิป หากตรวจอัตโนมัติไม่ได้ ร้านจะตรวจให้เอง</div>
              )}

              {order.status === "pending_acceptance" && ["pending", "issue"].includes(order.payment_status) ? (
                <button className="wsc-cancel" type="button" disabled={busy} onClick={() => void cancel()}>ยกเลิกออเดอร์</button>
              ) : null}
            </>
          ) : null}
        </>
      )}
    </main>
  );
}

export function SocialOrderApp({ dropId }: { dropId: string }) {
  return (
    <DeveloperRouteGate>
      {({ client, userId }) => <SocialOrderInner client={client} userId={userId} dropId={dropId} />}
    </DeveloperRouteGate>
  );
}
