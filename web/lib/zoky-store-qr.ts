// Founder 2026-11-04 ("ทำ ก+ข", "สแกนแล้ว ต้องเด้ง สั่งในไลน์"): one ZOKY
// store QR for the Merchant poster and the customer share sheet. The QR
// opens the store inside LINE (LIFF) when the ZOKY LIFF is configured, and
// the plain web share link otherwise. Browser-only (canvas).
import QRCode from "qrcode";

import { foodStoreShareUrl } from "@/lib/food-share";
import { configuredLiffIds, liffIdFor } from "@/lib/line-liff";

type QrStore = { id: string; name: string; share_code?: string | null; delivery_enabled?: boolean | null; pickup_enabled?: boolean | null };

const PINK = "#d61256";
const INK = "#16161a";
const SUB = "#6b6b76";
const FONT = "Anuphan, 'Noto Sans Thai', 'Thonburi', system-ui, -apple-system, sans-serif";

/** The in-app path the LIFF entry opens for this store (see safeLineDestination). */
export function foodStoreLinePath(store: Pick<QrStore, "id" | "share_code">): string {
  const web = new URL(foodStoreShareUrl(store));
  return web.pathname === "/" ? `/food${web.search}` : web.pathname;
}

/** What the QR opens: the store in LINE when the ZOKY LIFF exists, else the web link. */
export function foodStoreQrTarget(store: Pick<QrStore, "id" | "share_code">, liffId = liffIdFor("food", configuredLiffIds())): string {
  if (!liffId) return foodStoreShareUrl(store);
  return `https://liff.line.me/${liffId}?to=${encodeURIComponent(foodStoreLinePath(store))}`;
}

export function foodStoreQrSubtitle(store: Pick<QrStore, "delivery_enabled" | "pickup_enabled">): string {
  const modes = [store.delivery_enabled !== false ? "ส่งถึงบ้าน" : null, store.pickup_enabled ? "รับเองที่ร้าน" : null].filter(Boolean);
  return modes.join(" · ");
}

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error("image_failed"));
    image.src = src;
  });
}

function roundRect(context: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
  context.beginPath();
  context.moveTo(x + r, y);
  context.arcTo(x + w, y, x + w, y + h, r);
  context.arcTo(x + w, y + h, x, y + h, r);
  context.arcTo(x, y + h, x, y, r);
  context.arcTo(x, y, x + w, y, r);
  context.closePath();
}

/** A square QR with the ZOKY app icon in the middle (error correction H). */
export async function renderZokyQr(url: string, size = 640): Promise<HTMLCanvasElement> {
  const canvas = document.createElement("canvas");
  await QRCode.toCanvas(canvas, url, { width: size, margin: 1, errorCorrectionLevel: "H", color: { dark: INK, light: "#ffffff" } });
  const context = canvas.getContext("2d");
  if (!context) throw new Error("canvas unavailable");
  const logo = Math.round(size * 0.2);
  const pad = Math.round(logo * 0.12);
  const at = (size - logo) / 2;
  context.fillStyle = "#ffffff";
  roundRect(context, at - pad, at - pad, logo + pad * 2, logo + pad * 2, logo * 0.24);
  context.fill();
  try {
    const icon = await loadImage("/icons/zoky/icon-192-v1.png");
    context.save();
    roundRect(context, at, at, logo, logo, logo * 0.22);
    context.clip();
    context.drawImage(icon, at, at, logo, logo);
    context.restore();
  } catch {
    // The QR still scans without the logo.
  }
  return canvas;
}

function fitText(context: CanvasRenderingContext2D, text: string, max: number): string {
  if (context.measureText(text).width <= max) return text;
  let cut = text;
  while (cut.length > 1 && context.measureText(`${cut}…`).width > max) cut = cut.slice(0, -1);
  return `${cut}…`;
}

/** The printable ZOKY poster: pink header, store name, QR, readable link. */
export async function renderZokyStorePoster(store: QrStore, qrUrl = foodStoreQrTarget(store)): Promise<Blob> {
  const width = 1080;
  const height = 1440;
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext("2d");
  if (!context) throw new Error("canvas unavailable");
  context.fillStyle = "#ffffff";
  context.fillRect(0, 0, width, height);
  context.fillStyle = PINK;
  context.fillRect(0, 0, width, 300);
  context.textAlign = "center";
  context.textBaseline = "alphabetic";
  try {
    const mark = await loadImage("/icons/zoky/wordmark-white-v1.png");
    const markWidth = 300;
    context.drawImage(mark, (width - markWidth) / 2, 40, markWidth, markWidth * (mark.height / mark.width));
  } catch {
    context.fillStyle = "#ffffff";
    context.font = `700 96px ${FONT}`;
    context.fillText("ZOKY", width / 2, 150);
  }
  context.fillStyle = "#ffffff";
  context.font = `700 52px ${FONT}`;
  context.fillText("สแกนเพื่อสั่งอาหาร", width / 2, 268);

  context.fillStyle = INK;
  context.font = `700 76px ${FONT}`;
  context.fillText(fitText(context, store.name, width - 120), width / 2, 410);
  const subtitle = foodStoreQrSubtitle(store);
  if (subtitle) {
    context.fillStyle = SUB;
    context.font = `400 36px ${FONT}`;
    context.fillText(subtitle, width / 2, 480);
  }

  context.strokeStyle = "#ebebef";
  context.lineWidth = 4;
  roundRect(context, 170, 530, 740, 740, 40);
  context.stroke();
  context.drawImage(await renderZokyQr(qrUrl, 680), 200, 560, 680, 680);

  context.fillStyle = SUB;
  context.font = `500 36px ${FONT}`;
  context.fillText(foodStoreShareUrl(store).replace(/^https:\/\//, ""), width / 2, 1330);
  context.font = `400 30px ${FONT}`;
  context.fillText(qrUrl.startsWith("https://liff.line.me/") ? "สแกนด้วยกล้องมือถือ เปิดร้านใน LINE" : "เปิดกล้องมือถือ แล้วสแกน QR นี้", width / 2, 1388);

  return await new Promise<Blob>((resolve, reject) => canvas.toBlob((blob) => (blob ? resolve(blob) : reject(new Error("poster_failed"))), "image/png"));
}

export function zokyQrFileName(store: Pick<QrStore, "id" | "share_code">): string {
  return `zoky-qr-${(store.share_code ?? store.id).slice(0, 8)}.png`;
}
