"use client";

import type { SupabaseClient } from "@supabase/supabase-js";
import { Download, QrCode, Share2, X } from "lucide-react";
import QRCode from "qrcode";
import { useEffect, useState } from "react";

import type { FoodStore } from "@/lib/food-merchant";
import { foodStoreShareData, foodStoreShareUrl } from "@/lib/food-share";
import { shareOrCopyLink } from "@/lib/share";

type ShareStats = { opens: number; orders: number; sales: number };

/** Opens, orders and sales from the store's share link in the last 7 days. */
async function fetchShareStats(client: SupabaseClient, storeId: string): Promise<ShareStats | null> {
  const { data, error } = await client.rpc("food_share_stats", { p_store_id: storeId, p_days: 7 });
  const row = Array.isArray(data) ? data[0] : null;
  if (error || !row) return null;
  return { opens: Number(row.opens ?? 0), orders: Number(row.orders ?? 0), sales: Number(row.sales ?? 0) };
}

/**
 * A printable poster: store name, QR code of the short share link and the
 * link itself, drawn on a canvas so it saves as one PNG.
 */
async function renderQrPoster(storeName: string, url: string): Promise<string> {
  const width = 900;
  const height = 1200;
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext("2d");
  if (!context) throw new Error("canvas unavailable");
  const font = "system-ui, -apple-system, 'Segoe UI', sans-serif";

  context.fillStyle = "#ffffff";
  context.fillRect(0, 0, width, height);
  context.fillStyle = "#e32636";
  context.fillRect(0, 0, width, 180);
  context.textAlign = "center";
  context.fillStyle = "#ffffff";
  context.font = `700 44px ${font}`;
  context.fillText("WYNOS Food", width / 2, 80);
  context.font = `500 32px ${font}`;
  context.fillText("สแกนเพื่อสั่งอาหาร", width / 2, 135);

  context.fillStyle = "#111111";
  context.font = `800 52px ${font}`;
  const name = storeName.length > 22 ? `${storeName.slice(0, 21)}…` : storeName;
  context.fillText(name, width / 2, 270);

  const qr = document.createElement("canvas");
  await QRCode.toCanvas(qr, url, { width: 640, margin: 2, errorCorrectionLevel: "M", color: { dark: "#111111", light: "#ffffff" } });
  context.drawImage(qr, (width - 640) / 2, 320, 640, 640);

  context.fillStyle = "#555555";
  context.font = `500 34px ${font}`;
  context.fillText(url.replace(/^https:\/\//, ""), width / 2, 1040);
  context.font = `400 26px ${font}`;
  context.fillText("เปิดกล้องมือถือแล้วสแกน QR นี้", width / 2, 1100);
  return canvas.toDataURL("image/png");
}

export function MerchantShareCard({
  client,
  store,
  onMessage,
}: {
  client: SupabaseClient;
  store: FoodStore;
  onMessage: (message: string) => void;
}) {
  const [stats, setStats] = useState<ShareStats | null>(null);
  const [qrOpen, setQrOpen] = useState(false);
  const [poster, setPoster] = useState<string | null>(null);
  const url = foodStoreShareUrl(store);

  useEffect(() => {
    let live = true;
    void fetchShareStats(client, store.id).then((next) => { if (live) setStats(next); }).catch(() => undefined);
    return () => { live = false; };
  }, [client, store.id]);

  const openQr = async () => {
    setQrOpen(true);
    if (poster) return;
    try {
      setPoster(await renderQrPoster(store.name, url));
    } catch {
      setQrOpen(false);
      onMessage("สร้าง QR ไม่สำเร็จ");
    }
  };

  const fileName = `wynos-food-qr-${(store.share_code ?? store.id).slice(0, 8)}.png`;
  const sharePoster = async () => {
    if (!poster) return;
    try {
      const blob = await (await fetch(poster)).blob();
      const file = new File([blob], fileName, { type: "image/png" });
      if (navigator.canShare?.({ files: [file] })) {
        await navigator.share({ files: [file], title: store.name });
        return;
      }
    } catch (error) {
      if (error instanceof DOMException && error.name === "AbortError") return;
    }
    onMessage("กดค้างที่รูปเพื่อบันทึก หรือใช้ปุ่มบันทึกรูป");
  };

  return (
    <section className="wm-share-card" aria-label="ชวนลูกค้าสั่งผ่านลิงก์">
      <div className="wm-share-head">
        <span><strong>ชวนลูกค้าสั่งผ่านลิงก์</strong><small data-i18n-skip="">{url.replace(/^https:\/\//, "")}</small></span>
      </div>
      <div className="wm-share-actions">
        <button className="wm-primary" type="button" onClick={() => void shareOrCopyLink(foodStoreShareData(store), onMessage)}><Share2 size={18} />แชร์ลิงก์</button>
        <button className="wm-secondary" type="button" onClick={() => void openQr()}><QrCode size={18} />QR ร้าน</button>
      </div>
      {stats ? (
        <p className="wm-share-stats">
          <span>7 วันที่ผ่านมา</span>
          <b>{`เปิดลิงก์ ${stats.opens.toLocaleString("th-TH")} ครั้ง`}</b>
          <b>{`สั่ง ${stats.orders.toLocaleString("th-TH")} ออเดอร์`}</b>
          {stats.orders > 0 ? <b>{`฿${stats.sales.toLocaleString("th-TH", { maximumFractionDigits: 2 })}`}</b> : null}
        </p>
      ) : null}

      {qrOpen ? (
        <div className="wm-sheet-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) setQrOpen(false); }}>
          <section className="wm-sheet" role="dialog" aria-modal="true" aria-label="QR ร้าน">
            <header><span /><h2>QR ร้าน</h2><button className="wm-share-close" type="button" aria-label="ปิด" onClick={() => setQrOpen(false)}><X size={20} /></button></header>
            <div className="wm-sheet-body wm-share-qr">
              {poster ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={poster} alt={`QR สั่งอาหารร้าน ${store.name}`} />
              ) : <div className="wm-share-qr-loading" aria-label="กำลังสร้าง QR" />}
              <p>พิมพ์ติดหน้าร้าน แนบไปกับถุงอาหาร หรือส่งรูปนี้ในกลุ่ม ลูกค้าสแกนแล้วเข้าร้านคุณได้ทันที</p>
              <a className={`wm-primary wm-full ${poster ? "" : "is-disabled"}`} href={poster ?? undefined} download={fileName} aria-disabled={!poster}><Download size={18} />บันทึกรูป</a>
              <button className="wm-secondary wm-full" type="button" disabled={!poster} onClick={() => void sharePoster()}><Share2 size={18} />แชร์รูป QR</button>
            </div>
          </section>
        </div>
      ) : null}
    </section>
  );
}
