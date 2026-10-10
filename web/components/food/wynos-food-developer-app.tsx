"use client";

import {
  ArrowLeft,
  BadgePercent,
  Bell,
  Bike,
  Check,
  ChevronDown,
  ChevronRight,
  CircleAlert,
  Clock3,
  Copy,
  CreditCard,
  Download,
  Gift,
  Heart,
  Hourglass,
  House,
  LogOut,
  MapPin,
  MessageCircle,
  Minus,
  PackageCheck,
  Pencil,
  Phone,
  Plus,
  ReceiptText,
  RefreshCw,
  Search,
  Share2,
  ShoppingBag,
  Star,
  Store,
  Ticket,
  Timer,
  TimerOff,
  Trash2,
  Upload,
  UserRound,
  UtensilsCrossed,
  WifiOff,
  X,
} from "lucide-react";
import type { SupabaseClient } from "@supabase/supabase-js";
import Link from "next/link";
import Image from "next/image";
import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { FoodGuestBrowse, readGuestFoodBasket, clearGuestFoodBasket } from "@/components/food/food-guest-browse";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";
import { FoodDeliveryMapPicker } from "@/components/food/food-delivery-map-picker";
import { FoodPromotionCenter } from "@/components/food/food-promotion-center";
import { PullToRefreshIndicator } from "@/components/ui/pull-to-refresh-indicator";
import {
  clearRequestedOrder,
  clearSharedFoodStore,
  hasShareRef,
  rememberShareRef,
  requestedOrderNumber,
  foodStoreShareData,
  pendingSharedFoodStore,
  rememberSharedFoodStore,
  sharedFoodStoreId,
} from "@/lib/food-share";
import { shareOrCopyLink } from "@/lib/share";
import {
  isCurrentDevicePushEnabled,
  pushReasonDescription,
  subscribeToPushNotifications,
} from "@/lib/push-notifications";
import { usePullToRefresh } from "@/lib/use-pull-to-refresh";
import {
  foodEstimateDeliveryRange,
  foodMenuIsEffectivelyAvailable,
  foodStoreIsEffectivelyOpen,
  foodStoreStatusText,
  foodStoreTodayHoursText,
} from "@/lib/food-store-availability";
import {
  cancelFoodCustomerOrder,
  createFoodCustomerOrder,
  deleteFoodCustomerAddress,
  fetchFoodCustomerSnapshot,
  fetchFoodCustomerOrdersPage,
  markFoodOrderFromShare,
  fetchFoodPromptPayQr,
  checkFoodDeliveryAvailability,
  foodCartLineKey,
  foodCartLineOptionText,
  foodCartLineOptionsValid,
  foodCartLineUnitPrice,
  foodCustomerError,
  foodMenuQuantityLimit,
  foodMoney,
  foodOrderStatusLabel,
  foodPaymentStatusLabel,
  foodPrivateSignedUrl,
  orderDeliveryProof,
  foodPublicUrl,
  quoteFoodCustomerOrder,
  addressLocation,
  foodCustomerAddressStructuredComplete,
  fetchStorePlatformCampaigns,
  fetchFoodStoreDirectory,
  fetchFoodStoreReviewFeed,
  FOOD_REVIEW_TAGS,
  maskFoodReviewerName,
  recordFoodAdClick,
  submitFoodStoreReview,
  type FoodDirectoryStore,
  storeHasDeliveryZone,
  type FoodLocation,
  type FoodPlace,
  saveFoodCustomerAddress,
  prepareFoodManualPayment,
  startFoodStripeCheckout,
  submitFoodPayment,
  subscribeFoodCustomerOrders,
  uploadFoodPaymentSlip,
  type FoodAddressDraft,
  type FoodCartLine,
  type FoodCustomerAddress,
  type FoodCustomerMenuItem,
  type FoodCustomerOrder,
  type FoodCustomerOwnReview,
  type FoodCustomerSnapshot,
  type FoodOrderQuote,
  type FoodStoreReviewFeed,
  type FoodCustomerStore,
} from "@/lib/food-customer";

type FoodTab = "home" | "orders" | "messages" | "cart" | "account";

type InstallPromptEvent = Event & {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: "accepted" | "dismissed" }>;
};

const EMPTY_ADDRESS: FoodAddressDraft = {
  label: "ที่อยู่ของฉัน",
  recipientName: "",
  recipientPhone: "",
  address: "",
  addressLine1: "",
  moo: "",
  soi: "",
  road: "",
  subdistrict: "",
  district: "",
  province: "",
  postalCode: "",
  deliveryNote: "",
  placeId: null,
  placeName: "",
  buildingName: "",
  floor: "",
  room: "",
  landmark: "",
  isDefault: true,
  location: null,
};

const WYNOS_MAPS_PIN_STORAGE_KEY = "wynos:maps:last-pin";
const WYNOS_MAPS_PIN_MAX_AGE_MS = 30 * 60 * 1000;

type StoredWynosMapsPin = {
  location?: FoodLocation;
  place?: FoodPlace;
  savedAt?: string;
};

function normalizeThaiAdminPart(value: string) {
  return value
    .replace(/^(?:ตำบล|แขวง|อำเภอ|เขต|จังหวัด|ต\.|อ\.|จ\.)\s*/u, "")
    .replace(/\s+/g, " ")
    .trim();
}

function structuredAddressPartsFromPlace(place?: FoodPlace | null) {
  const address = place?.address?.trim() ?? "";
  const combined = [place?.name, address].filter(Boolean).join(", ");
  const pick = (pattern: RegExp) => normalizeThaiAdminPart(combined.match(pattern)?.[1] ?? "");
  let subdistrict = pick(/(?:ตำบล|แขวง|ต\.)\s*([^,]+?)(?=\s*(?:อำเภอ|เขต|อ\.|จังหวัด|จ\.|\d{5}|,|$))/u);
  let district = pick(/(?:อำเภอ|เขต|อ\.)\s*([^,]+?)(?=\s*(?:จังหวัด|จ\.|\d{5}|,|$))/u);
  let province = pick(/(?:จังหวัด|จ\.)\s*([^,]+?)(?=\s*(?:\d{5}|ประเทศไทย|,|$))/u);
  const postalCode = combined.match(/(?:^|\D)(\d{5})(?:\D|$)/u)?.[1] ?? "";

  if ((!subdistrict || !district || !province) && address.includes(",")) {
    const parts = address.split(",").map((value) => value.trim()).filter(Boolean)
      .filter((value) => !/^(?:ประเทศไทย|Thailand)$/iu.test(value))
      .map((value) => value.replace(/\b\d{5}\b/u, "").trim())
      .filter(Boolean);
    if (!province && parts.length >= 1) province = normalizeThaiAdminPart(parts.at(-1) ?? "");
    if (!district && parts.length >= 2) district = normalizeThaiAdminPart(parts.at(-2) ?? "");
    if (!subdistrict && parts.length >= 3) subdistrict = normalizeThaiAdminPart(parts.at(-3) ?? "");
  }

  return { subdistrict, district, province, postalCode };
}

function draftWithLastWynosMapsPin(draft: FoodAddressDraft): FoodAddressDraft {
  if (draft.id || draft.location || typeof window === "undefined") return draft;
  try {
    const raw = window.localStorage.getItem(WYNOS_MAPS_PIN_STORAGE_KEY);
    if (!raw) return draft;
    const saved = JSON.parse(raw) as StoredWynosMapsPin;
    const savedAt = saved.savedAt ? Date.parse(saved.savedAt) : Number.NaN;
    if (!Number.isFinite(savedAt) || Date.now() - savedAt > WYNOS_MAPS_PIN_MAX_AGE_MS) return draft;
    const latitude = Number(saved.location?.latitude);
    const longitude = Number(saved.location?.longitude);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return draft;
    const place = saved.place;
    const parts = structuredAddressPartsFromPlace(place);
    return {
      ...draft,
      location: { latitude, longitude },
      placeId: place?.placeId ?? null,
      placeName: place?.name ?? "",
      subdistrict: draft.subdistrict || parts.subdistrict,
      district: draft.district || parts.district,
      province: draft.province || parts.province,
      postalCode: draft.postalCode || parts.postalCode,
    };
  } catch {
    return draft;
  }
}

const TRACKING_STEPS: Array<{
  status: FoodCustomerOrder["status"];
  label: string;
}> = [
  { status: "pending_acceptance", label: "รอร้านรับออเดอร์" },
  { status: "preparing", label: "กำลังเตรียมอาหาร" },
  { status: "ready_for_delivery", label: "พร้อมจัดส่ง" },
  { status: "out_for_delivery", label: "กำลังจัดส่ง" },
  { status: "delivered", label: "จัดส่งสำเร็จ" },
];

function formatDate(value: string) {
  return new Intl.DateTimeFormat("th-TH", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value));
}

function itemFor(menu: FoodCustomerMenuItem[], id: string) {
  return menu.find((item) => item.id === id) ?? null;
}

function FoodLoading() {
  return (
    <main className="wyn-food fx-app fx-loading" aria-busy="true" aria-label="กำลังโหลด WYNOS Food">
      <div className="fx-brand fx-loading-brand">
        <Image className="wf-brand-logo" src="/icons/food/icon-192-v12.png" width={32} height={32} alt="" />
        <span>WYNOS <b>Food</b></span>
      </div>
      <div className="fx-skel fx-skel--line" style={{ width: 180 }} />
      <div className="fx-skel fx-skel--pill" />
      <div className="fx-skel fx-skel--banner" />
      <div className="fx-skel-row">
        <div className="fx-skel fx-skel--chip" /><div className="fx-skel fx-skel--chip" /><div className="fx-skel fx-skel--chip" />
      </div>
      <div className="fx-skel-grid">
        <div><div className="fx-skel fx-skel--card" /><div className="fx-skel fx-skel--line" /></div>
        <div><div className="fx-skel fx-skel--card" /><div className="fx-skel fx-skel--line" /></div>
      </div>
    </main>
  );
}

function FoodStateScreen({
  icon,
  title,
  children,
  action,
  secondary,
  role,
}: {
  icon: React.ReactNode;
  title: string;
  children?: React.ReactNode;
  action?: React.ReactNode;
  secondary?: React.ReactNode;
  role?: "alert" | "status";
}) {
  return (
    <section className="fx-state" role={role}>
      <span className="fx-state-icon">{icon}</span>
      <h2>{title}</h2>
      {children ? <div className="fx-state-copy">{children}</div> : null}
      {action ? <div className="fx-state-action">{action}</div> : null}
      {secondary ? <div className="fx-state-secondary">{secondary}</div> : null}
    </section>
  );
}

function FoodDenied() {
  return (
    <main className="wyn-food fx-app fx-app--bare">
      <FoodStateScreen
        icon={<UtensilsCrossed size={46} strokeWidth={1.6} />}
        title="ยังเข้าใช้ WYNOS Food ไม่ได้"
        action={<Link className="fx-btn fx-btn--primary" href="/food/login">เข้าสู่ระบบ WYNOS Food</Link>}
        secondary={<a className="fx-link-muted" href="https://wynos.online/">กลับ WYNOS</a>}
      >
        <p>บัญชีนี้ยังไม่ผ่านเงื่อนไขการใช้งาน WYNOS Food หรือเซสชันหมดอายุ กรุณาเข้าสู่ระบบอีกครั้ง</p>
      </FoodStateScreen>
    </main>
  );
}

function FoodLoadError({ message, onRetry }: { message: string; onRetry: () => void }) {
  const offline = typeof navigator !== "undefined" && navigator.onLine === false;
  return (
    <main className="wyn-food fx-app fx-app--bare">
      {offline ? <div className="fx-offline-bar" role="status"><WifiOff size={18} />ไม่มีการเชื่อมต่ออินเทอร์เน็ต</div> : null}
      <FoodStateScreen
        role="alert"
        icon={offline ? <WifiOff size={46} strokeWidth={1.6} /> : <CircleAlert size={46} strokeWidth={1.6} />}
        title={offline ? "เชื่อมต่อไม่ได้" : "โหลด WYNOS Food ไม่สำเร็จ"}
        action={<button className="fx-btn fx-btn--primary" type="button" onClick={onRetry}><RefreshCw size={18} />ลองอีกครั้ง</button>}
        secondary={<a className="fx-link-muted" href="https://wynos.online/">กลับ WYNOS</a>}
      >
        <p>{offline ? "ตรวจสอบ Wi-Fi หรือเน็ตมือถือ แล้วลองอีกครั้ง ตะกร้าของคุณยังอยู่" : message}</p>
      </FoodStateScreen>
    </main>
  );
}

function FoodHeader({
  cartCount,
  homeLocationLabel,
  onCart,
  onLocation,
  onFavorites,
}: {
  cartCount: number;
  homeLocationLabel?: string;
  onCart: () => void;
  onLocation?: () => void;
  onFavorites?: () => void;
}) {
  return (
    <header className="fx-header">
      <div className="fx-header-top">
        <div className="fx-brand">
          <Image className="wf-brand-logo" src="/icons/food/icon-192-v12.png" width={32} height={32} alt="" />
          <span>WYNOS <b>Food</b></span>
        </div>
        <div className="fx-header-actions">
          {onFavorites ? (
            <button className="fx-icon-btn" type="button" aria-label="ร้านโปรด" onClick={onFavorites}>
              <Heart size={22} strokeWidth={1.9} />
            </button>
          ) : null}
          <button className="fx-icon-btn" type="button" aria-label={cartCount ? `ตะกร้า ${cartCount} รายการ` : "ตะกร้า"} onClick={onCart}>
            <ShoppingBag size={22} strokeWidth={1.9} />
            {cartCount ? <i className="fx-badge">{cartCount > 9 ? "9+" : cartCount}</i> : null}
          </button>
        </div>
      </div>
      <button className="fx-location" type="button" onClick={onLocation} aria-label="เลือกที่อยู่จัดส่ง">
        <MapPin size={20} fill="currentColor" strokeWidth={0} />
        <span>
          <small>ส่งถึง</small>
          <strong>{homeLocationLabel || "เลือกที่อยู่จัดส่ง"}<ChevronDown size={16} strokeWidth={2.4} /></strong>
        </span>
      </button>
    </header>
  );
}

function FoodPageHeader({
  title,
  onBack,
  action,
  center = false,
}: {
  title: string;
  onBack?: () => void;
  action?: React.ReactNode;
  center?: boolean;
}) {
  return (
    <header className={`fx-page-head${center ? " is-center" : ""}${onBack ? " has-back" : ""}`}>
      {onBack ? (
        <button className="fx-icon-btn" type="button" aria-label="ย้อนกลับ" onClick={onBack}>
          <ArrowLeft size={22} strokeWidth={2.1} />
        </button>
      ) : null}
      <h1>{title}</h1>
      {action ? <div className="fx-page-head-action">{action}</div> : center && onBack ? <span className="fx-page-head-spacer" /> : null}
    </header>
  );
}

function FoodNav({
  tab,
  activeCount,
  onTab,
}: {
  tab: FoodTab;
  activeCount: number;
  onTab: (tab: FoodTab) => void;
}) {
  const items: Array<{ key: FoodTab; label: string; icon: React.ReactNode }> = [
    { key: "home", label: "หน้าหลัก", icon: <House size={22} strokeWidth={tab === "home" ? 2.3 : 1.9} fill={tab === "home" ? "currentColor" : "none"} /> },
    { key: "orders", label: "ออเดอร์", icon: <ReceiptText size={22} strokeWidth={tab === "orders" ? 2.3 : 1.9} /> },
    { key: "messages", label: "ข้อความ", icon: <MessageCircle size={22} strokeWidth={tab === "messages" ? 2.3 : 1.9} /> },
    { key: "account", label: "บัญชี", icon: <UserRound size={22} strokeWidth={tab === "account" ? 2.3 : 1.9} /> },
  ];
  return (
    <nav className="fx-nav" aria-label="WYNOS Food">
      {items.map((item) => (
        <button
          key={item.key}
          type="button"
          className={tab === item.key ? "is-active" : ""}
          aria-current={tab === item.key ? "page" : undefined}
          onClick={() => onTab(item.key)}
        >
          <span className="fx-nav-pill">
            {item.icon}
            {item.key === "orders" && activeCount ? (
              <i className="fx-badge" aria-label={`${activeCount} ออเดอร์ที่กำลังดำเนินการ`}>{activeCount > 9 ? "9+" : activeCount}</i>
            ) : null}
          </span>
          <small>{item.label}</small>
        </button>
      ))}
    </nav>
  );
}

function MenuImage({
  client,
  item,
  className = "",
}: {
  client: SupabaseClient;
  item: FoodCustomerMenuItem;
  className?: string;
}) {
  const url = foodPublicUrl(client, item.image_path);
  return (
    <span className={`fx-menu-image ${className}`}>
      {url ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={url} alt="" loading="lazy" decoding="async" />
      ) : <UtensilsCrossed size={26} strokeWidth={1.45} />}
    </span>
  );
}

/**
 * Founder-approved WYNOS Food Home directory.
 * Paid ads remain labelled. The home itself never exposes a favorite toggle:
 * customers favorite a store only from inside that store.
 */
function foodDistanceKm(
  from: { latitude: number; longitude: number } | null,
  to: { latitude?: number | null; longitude?: number | null },
) {
  if (!from || to.latitude == null || to.longitude == null) return null;
  const earthKm = 6371;
  const rad = (value: number) => value * Math.PI / 180;
  const dLat = rad(Number(to.latitude) - from.latitude);
  const dLng = rad(Number(to.longitude) - from.longitude);
  const a = Math.sin(dLat / 2) ** 2
    + Math.cos(rad(from.latitude)) * Math.cos(rad(Number(to.latitude))) * Math.sin(dLng / 2) ** 2;
  return earthKm * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function foodPromoLabel(store: FoodDirectoryStore) {
  if (!store.promo_name) return null;
  if (store.promo_type === "free_delivery") return "ส่งฟรี";
  const value = Number(store.promo_value ?? 0);
  if (store.promo_type === "percentage") return `ลด ${value}%`;
  if (store.promo_type === "fixed") return `ลด ${foodMoney(value)}`;
  return store.promo_name;
}

function foodDistanceLabel(distance: number | null) {
  if (distance == null) return null;
  if (distance < 0.1) return "ใกล้คุณ";
  return `${distance < 10 ? distance.toFixed(1) : Math.round(distance)} กม.`;
}

function FoodDirectoryStoreCard({
  client,
  store,
  distance,
  onPick,
}: {
  client: SupabaseClient;
  store: FoodDirectoryStore;
  distance: number | null;
  onPick: () => void;
}) {
  const cover = foodPublicUrl(client, store.cover_path);
  const rating = Number(store.rating_average ?? 0);
  const ratingCount = Number(store.rating_count ?? 0);
  const categories = Array.isArray(store.categories) ? store.categories.slice(0, 2) : [];
  const eta = foodEstimateDeliveryRange(store, distance);
  const promo = foodPromoLabel(store);
  const distanceLabel = foodDistanceLabel(distance);
  return (
    <button className={`fx-store-card${store.is_open ? "" : " is-closed"}`} type="button" onClick={onPick}>
      <span className="fx-store-card-photo">
        {cover ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={cover} alt="" loading="lazy" decoding="async" />
        ) : <UtensilsCrossed size={30} strokeWidth={1.4} />}
        {store.is_ad ? <b className="fx-ad-label">โฆษณา</b> : null}
        {!store.is_open ? <b className="fx-closed-label"><Clock3 size={12} strokeWidth={2.4} />ปิดอยู่</b> : null}
        {promo ? <b className="fx-promo-tag">{promo}</b> : null}
        <b className="fx-eta-chip">{eta.min}–{eta.max} นาที</b>
      </span>
      <span className="fx-store-card-name">{store.name}</span>
      <span className="fx-store-card-meta">
        <Star size={13} fill="#F5A623" strokeWidth={0} />
        {rating > 0 ? (
          <>
            <b>{rating.toFixed(1)}</b>
            {ratingCount > 0 ? <span>({new Intl.NumberFormat("th-TH").format(ratingCount)})</span> : null}
          </>
        ) : <b>ร้านใหม่</b>}
        {distanceLabel ? <span>· {distanceLabel}</span> : null}
      </span>
      <span className="fx-store-card-tags">
        {categories.length ? categories.map((name) => <span key={name}>{name}</span>) : <span>อาหาร</span>}
        <span>ค่าส่ง {foodMoney(store.delivery_fee)}</span>
      </span>
    </button>
  );
}

function FoodRecentStoreTile({
  client,
  store,
  onPick,
}: {
  client: SupabaseClient;
  store: FoodDirectoryStore;
  onPick: () => void;
}) {
  const cover = foodPublicUrl(client, store.cover_path);
  return (
    <button className="fx-recent-store" type="button" onClick={onPick}>
      <span>
        {cover ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={cover} alt="" loading="lazy" decoding="async" />
        ) : <UtensilsCrossed size={26} strokeWidth={1.4} />}
      </span>
      <strong>{store.name}</strong>
    </button>
  );
}

function FoodHomeSectionHeader({ title, onAll }: { title: string; onAll?: () => void }) {
  return (
    <div className="fx-section-head">
      <h2>{title}</h2>
      {onAll ? <button type="button" onClick={onAll}>ดูทั้งหมด <ChevronRight size={16} strokeWidth={2.4} /></button> : null}
    </div>
  );
}

type FoodDirectoryFilter = "all" | "free" | "promo" | "near" | "rating";

const FOOD_DIRECTORY_FILTERS: Array<{ key: FoodDirectoryFilter; label: string }> = [
  { key: "all", label: "ทั้งหมด" },
  { key: "free", label: "ส่งฟรี" },
  { key: "promo", label: "มีโปรฯ" },
  { key: "near", label: "ใกล้ฉัน" },
  { key: "rating", label: "เรตติ้ง 4.5+" },
];

function StoreDirectory({
  client,
  userId,
  orders,
  addresses,
  onPick,
  onLocation,
}: {
  client: SupabaseClient;
  userId: string;
  orders: FoodCustomerOrder[];
  addresses: FoodCustomerAddress[];
  onPick: (store: FoodDirectoryStore, placement: "home" | "search") => void;
  onLocation: () => void;
}) {
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState<FoodDirectoryFilter>("all");
  const [stores, setStores] = useState<FoodDirectoryStore[] | null>(null);
  const [browse, setBrowse] = useState<"promos" | "recent" | "nearby" | "popular" | null>(null);
  const promoKey = `wynos-food-collected-promos-v1:${userId}`;
  const [collectedPromos, setCollectedPromos] = useState<string[]>(() => {
    if (typeof window === "undefined") return [];
    try {
      const saved = JSON.parse(localStorage.getItem(promoKey) ?? "[]");
      return Array.isArray(saved) ? saved.filter((value): value is string => typeof value === "string") : [];
    } catch {
      return [];
    }
  });

  useEffect(() => {
    let live = true;
    const timer = window.setTimeout(() => {
      void fetchFoodStoreDirectory(client, query).then((next) => { if (live) setStores(next); });
    }, query ? 280 : 0);
    return () => { live = false; window.clearTimeout(timer); };
  }, [client, query]);

  const primaryAddress = addresses.find((address) => address.is_default) ?? addresses[0] ?? null;
  const customerLocation = addressLocation(primaryAddress);
  const directory = stores ?? [];
  const distanceFor = (store: FoodDirectoryStore) => foodDistanceKm(customerLocation, store);
  const storeMap = new Map(directory.map((store) => [store.id, store]));

  const recentStores = Array.from(new Set(
    [...orders]
      .filter((order) => order.status !== "cancelled")
      .sort((a, b) => Date.parse(b.created_at) - Date.parse(a.created_at))
      .map((order) => order.store_id),
  )).map((id) => storeMap.get(id)).filter((store): store is FoodDirectoryStore => Boolean(store));

  const matchesFilter = (store: FoodDirectoryStore) => {
    if (filter === "free") return store.promo_type === "free_delivery";
    if (filter === "promo") return Boolean(store.promo_name);
    if (filter === "near") {
      const distance = distanceFor(store);
      return distance != null && distance <= 3;
    }
    if (filter === "rating") return Number(store.rating_average ?? 0) >= 4.5;
    return true;
  };
  const filtered = directory.filter(matchesFilter);

  const nearbyStores = [...filtered].sort((a, b) => {
    const da = distanceFor(a);
    const db = distanceFor(b);
    if (Number(b.is_open) !== Number(a.is_open)) return Number(b.is_open) - Number(a.is_open);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da - db;
  });
  const popularStores = [...filtered].sort((a, b) => {
    const ordersDelta = Number(b.delivered_order_count ?? 0) - Number(a.delivered_order_count ?? 0);
    if (ordersDelta) return ordersDelta;
    const ratingDelta = Number(b.rating_average ?? 0) - Number(a.rating_average ?? 0);
    if (ratingDelta) return ratingDelta;
    return a.name.localeCompare(b.name, "th");
  });
  const promoStores = directory.filter((store) => Boolean(store.promo_name));

  const toggleCollected = (store: FoodDirectoryStore) => {
    const id = store.id;
    setCollectedPromos((current) => {
      const next = current.includes(id) ? current.filter((value) => value !== id) : [...current, id];
      try { localStorage.setItem(promoKey, JSON.stringify(next)); } catch { /* private mode */ }
      return next;
    });
  };

  const promoCard = (store: FoodDirectoryStore) => {
    const label = foodPromoLabel(store) ?? store.promo_name ?? "โปรร้าน";
    const minimum = Number(store.promo_min_subtotal ?? 0);
    const collected = collectedPromos.includes(store.id);
    return (
      <article className="fx-deal" key={store.id}>
        <span className="fx-deal-icon">{store.promo_type === "free_delivery" ? <Bike size={26} /> : <Ticket size={26} />}</span>
        <span className="fx-deal-copy">
          <small>{store.name}</small>
          <strong>{label}</strong>
          <span>{minimum > 0 ? `เมื่อสั่งครบ ${foodMoney(minimum)}` : store.promo_name}</span>
        </span>
        <button type="button" className={collected ? "is-collected" : ""} aria-pressed={collected} onClick={() => toggleCollected(store)}>
          {collected ? "เก็บแล้ว" : "เก็บโค้ด"}
        </button>
      </article>
    );
  };

  const card = (store: FoodDirectoryStore, placement: "home" | "search" = "home") => (
    <FoodDirectoryStoreCard
      key={store.id}
      client={client}
      store={store}
      distance={distanceFor(store)}
      onPick={() => onPick(store, placement)}
    />
  );

  const searching = Boolean(query.trim());

  return (
    <section className="fx-directory">
      <label className="fx-search">
        <Search size={20} strokeWidth={2} />
        <input
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder="ค้นหาร้านหรือเมนูอาหาร"
          aria-label="ค้นหาร้านหรือเมนูอาหาร"
          autoComplete="off"
          enterKeyHint="search"
        />
        {query ? <button type="button" className="fx-search-clear" aria-label="ล้างการค้นหา" onClick={() => setQuery("")}><X size={14} strokeWidth={3} /></button> : null}
      </label>

      {stores === null ? (
        <div className="fx-skel-grid fx-skel-grid--inline" aria-busy="true" aria-label="กำลังโหลดร้านอาหาร">
          <div><div className="fx-skel fx-skel--card" /><div className="fx-skel fx-skel--line" /></div>
          <div><div className="fx-skel fx-skel--card" /><div className="fx-skel fx-skel--line" /></div>
        </div>
      ) : searching ? (
        <section className="fx-home-section">
          <FoodHomeSectionHeader title={`ผลการค้นหา “${query.trim()}”`} />
          {directory.length ? <div className="fx-store-grid">{directory.map((store) => card(store, "search"))}</div> : (
            <FoodStateScreen icon={<Search size={44} strokeWidth={1.6} />} title={`ไม่พบ “${query.trim()}” ใกล้คุณ`}>
              <p>ลองค้นด้วยชื่อร้าน ชื่อเมนู หรือคำที่สั้นลง</p>
            </FoodStateScreen>
          )}
        </section>
      ) : !directory.length ? (
        <FoodStateScreen
          icon={<Store size={46} strokeWidth={1.6} />}
          title="ยังไม่มีร้านในพื้นที่นี้"
          action={<button className="fx-btn fx-btn--primary" type="button" onClick={onLocation}>เปลี่ยนที่อยู่จัดส่ง</button>}
        >
          <p>WYNOS Food กำลังขยายพื้นที่ให้บริการ ลองเปลี่ยนที่อยู่จัดส่ง หรือกลับมาใหม่เร็วๆ นี้</p>
        </FoodStateScreen>
      ) : (
        <>
          <div className="fx-chips" role="group" aria-label="ตัวกรองร้านอาหาร">
            {FOOD_DIRECTORY_FILTERS.map((option) => (
              <button
                key={option.key}
                type="button"
                className={`fx-chip${filter === option.key ? " is-active" : ""}`}
                aria-pressed={filter === option.key}
                onClick={() => setFilter(option.key)}
              >
                {option.label}
              </button>
            ))}
          </div>

          {filter === "all" && promoStores.length ? (
            <section className="fx-home-section">
              <FoodHomeSectionHeader title="รวมโค้ดลดเพิ่ม" onAll={() => setBrowse("promos")} />
              <div className="fx-deals">{promoStores.slice(0, 4).map(promoCard)}</div>
            </section>
          ) : null}

          {filter === "all" && recentStores.length ? (
            <section className="fx-home-section">
              <FoodHomeSectionHeader title="สั่งอีกครั้ง" onAll={() => setBrowse("recent")} />
              <div className="fx-recent-stores">
                {recentStores.slice(0, 6).map((store) => (
                  <FoodRecentStoreTile key={store.id} client={client} store={store} onPick={() => onPick(store, "home")} />
                ))}
              </div>
            </section>
          ) : null}

          <section className="fx-home-section">
            <FoodHomeSectionHeader title="ร้านใกล้คุณ" onAll={nearbyStores.length > 4 ? () => setBrowse("nearby") : undefined} />
            {nearbyStores.length ? <div className="fx-store-grid">{nearbyStores.slice(0, 4).map((store) => card(store))}</div> : (
              <p className="fx-empty-line">ไม่มีร้านที่ตรงกับตัวกรองนี้</p>
            )}
          </section>

          {filter === "all" && popularStores.length > 1 ? (
            <section className="fx-home-section">
              <FoodHomeSectionHeader title="ร้านยอดนิยม" onAll={popularStores.length > 4 ? () => setBrowse("popular") : undefined} />
              <div className="fx-store-grid">{popularStores.slice(0, 4).map((store) => card(store))}</div>
            </section>
          ) : null}
        </>
      )}

      {browse ? (
        <Sheet
          title={browse === "promos" ? "รวมโค้ดลดเพิ่ม" : browse === "recent" ? "สั่งอีกครั้ง" : browse === "nearby" ? "ร้านใกล้คุณ" : "ร้านยอดนิยม"}
          onClose={() => setBrowse(null)}
        >
          {browse === "promos" ? (
            <div className="fx-deals fx-deals--stack">{promoStores.map(promoCard)}</div>
          ) : browse === "recent" ? (
            <div className="fx-store-grid">{recentStores.map((store) => card(store))}</div>
          ) : browse === "nearby" ? (
            <div className="fx-store-grid">{nearbyStores.map((store) => card(store))}</div>
          ) : (
            <div className="fx-store-grid">{popularStores.map((store) => card(store))}</div>
          )}
        </Sheet>
      ) : null}
    </section>
  );
}

function FavoriteStoresSheet({
  client,
  userId,
  onClose,
  onPick,
}: {
  client: SupabaseClient;
  userId: string;
  onClose: () => void;
  onPick: (store: FoodDirectoryStore) => void;
}) {
  const [stores, setStores] = useState<FoodDirectoryStore[] | null>(null);
  useEffect(() => {
    let live = true;
    void fetchFoodStoreDirectory(client).then((next) => { if (live) setStores(next); });
    return () => { live = false; };
  }, [client]);

  let ids: string[] = [];
  try {
    const saved = JSON.parse(localStorage.getItem(`wynos-food-favorite-stores-v1:${userId}`) ?? "[]");
    ids = Array.isArray(saved) ? saved.filter((value): value is string => typeof value === "string") : [];
  } catch {
    ids = [];
  }
  const favorites = (stores ?? []).filter((store) => ids.includes(store.id));

  return (
    <Sheet title="ร้านโปรด" onClose={onClose}>
      {stores === null ? <div className="wf-mini-loader" /> : favorites.length ? (
        <div className="wf-favorite-store-list">
          {favorites.map((store) => {
            const logo = foodPublicUrl(client, store.logo_path);
            return (
              <button key={store.id} type="button" onClick={() => onPick(store)}>
                <span>{logo ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={logo} alt="" loading="lazy" decoding="async" />
                ) : <Store size={20} />}</span>
                <div><strong>{store.name}</strong><small>{store.address || (store.is_open ? "เปิดรับออเดอร์" : "ปิดอยู่")}</small></div>
                <ChevronRight size={18} />
              </button>
            );
          })}
        </div>
      ) : <div className="wf-empty wf-empty--compact"><Heart size={34} strokeWidth={1.4} /><strong>ยังไม่มีร้านโปรด</strong><p>เข้าไปที่หน้าร้าน แล้วกดหัวใจเพื่อบันทึกร้านโปรด</p></div>}
    </Sheet>
  );
}

function ReviewStars({ rating, compact = false }: { rating: number; compact?: boolean }) {
  return (
    <span className={`wf-review-stars${compact ? " is-compact" : ""}`} aria-label={`${rating} จาก 5 ดาว`}>
      {[1, 2, 3, 4, 5].map((value) => (
        <Star key={value} size={compact ? 14 : 17} strokeWidth={1.8} fill={value <= Math.round(rating) ? "currentColor" : "none"} />
      ))}
    </span>
  );
}

function StoreReviewsSection({ client, storeId }: { client: SupabaseClient; storeId: string }) {
  const [feed, setFeed] = useState<FoodStoreReviewFeed>({ average: 0, count: 0, reviews: [] });
  const [expanded, setExpanded] = useState(false);

  useEffect(() => {
    let live = true;
    void fetchFoodStoreReviewFeed(client, storeId, 20)
      .then((next) => {
        if (live) setFeed(next);
      })
      .catch(() => undefined);
    return () => { live = false; };
  }, [client, storeId]);

  const shown = expanded ? feed.reviews : feed.reviews.slice(0, 3);

  return (
    <section className="wf-reviews">
      <div className="wf-reviews-head">
        <div><small>จากออเดอร์ที่ส่งสำเร็จ</small><h2>รีวิวจากลูกค้า</h2></div>
        {feed.count ? (
          <div className="wf-rating-summary">
            <Star size={17} fill="currentColor" />
            <strong>{feed.average.toFixed(1)}</strong>
            <small>({feed.count} รีวิว)</small>
          </div>
        ) : null}
      </div>
      {feed.count ? (
        <>
          <div className="wf-review-list">
            {shown.map((review) => (
              <article key={review.id} className="wf-review-card">
                <div className="wf-review-card-head">
                  <div><strong>{review.reviewer_label}</strong><span>สั่งจริงกับ WYNOS Food</span></div>
                  <ReviewStars rating={review.rating} compact />
                </div>
                {review.review_text ? <p>{review.review_text}</p> : null}
                {review.tags.length ? <div className="wf-review-tags">{review.tags.map((tag) => <span key={tag}>{tag}</span>)}</div> : null}
                <small>{formatDate(review.created_at)}</small>
                {review.merchant_reply ? (
                  <div className="wf-review-reply"><strong>ร้านตอบกลับ</strong><p>{review.merchant_reply}</p></div>
                ) : null}
              </article>
            ))}
          </div>
          {feed.reviews.length > 3 ? (
            <button className="wf-review-more" type="button" onClick={() => setExpanded((value) => !value)}>
              {expanded ? "แสดงน้อยลง" : `ดูรีวิวทั้งหมด (${feed.count})`}
            </button>
          ) : null}
        </>
      ) : (
        <div className="wf-review-empty"><Star size={22} /><span><strong>ยังไม่มีรีวิว</strong><small>รีวิวจะมาจากออเดอร์ที่ส่งสำเร็จเท่านั้น</small></span></div>
      )}
    </section>
  );
}

function MenuSearchSheet({
  client,
  menu,
  historyKey,
  onItem,
  onClose,
}: {
  client: SupabaseClient;
  menu: FoodCustomerMenuItem[];
  historyKey: string;
  onItem: (item: FoodCustomerMenuItem) => void;
  onClose: () => void;
}) {
  const [query, setQuery] = useState("");
  const [recent, setRecent] = useState<string[]>(() => {
    if (typeof window === "undefined") return [];
    try {
      const saved = JSON.parse(localStorage.getItem(historyKey) ?? "[]");
      return Array.isArray(saved) ? saved.filter((value): value is string => typeof value === "string").slice(0, 5) : [];
    } catch {
      return [];
    }
  });
  const resultsRef = useRef<HTMLDivElement | null>(null);
  const popular = useMemo(
    () => menu.filter((item) => foodMenuIsEffectivelyAvailable(item) && foodMenuQuantityLimit(item) > 0).slice(0, 4),
    [menu],
  );
  const results = useMemo(() => {
    const q = query.trim().toLocaleLowerCase("th-TH");
    const source = q
      ? menu.filter((item) => `${item.name} ${item.category} ${item.description ?? ""}`.toLocaleLowerCase("th-TH").includes(q))
      : menu;
    return source.slice(0, 30);
  }, [menu, query]);

  const rememberSearch = (value: string) => {
    const clean = value.trim();
    if (!clean) return;
    const next = [clean, ...recent.filter((item) => item !== clean)].slice(0, 5);
    setRecent(next);
    try { localStorage.setItem(historyKey, JSON.stringify(next)); } catch { /* private mode */ }
  };

  const openItem = (item: FoodCustomerMenuItem) => {
    rememberSearch(query);
    onClose();
    onItem(item);
  };

  return (
    <Sheet title="ค้นหาเมนูอาหาร" onClose={onClose}>
      <label className="wf-menu-search-field">
        <Search size={19} strokeWidth={1.8} />
        <input
          autoFocus
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          onKeyDown={(event) => { if (event.key === "Enter") rememberSearch(query); }}
          placeholder="ค้นหาเมนูอาหาร"
          autoComplete="off"
        />
        {query ? <button type="button" aria-label="ปิด" onClick={() => setQuery("")}><X size={17} /></button> : null}
      </label>

      {!query.trim() && popular.length ? (
        <section className="wf-menu-search-section">
          <div className="wf-menu-search-heading">
            <h3>เมนูยอดนิยม</h3>
            <button type="button" onClick={() => resultsRef.current?.scrollIntoView({ behavior: "smooth", block: "start" })}>ดูทั้งหมด</button>
          </div>
          <div className="wf-menu-popular">
            {popular.map((item) => (
              <button key={item.id} type="button" onClick={() => openItem(item)}>
                <MenuImage client={client} item={item} className="wf-menu-popular-image" />
                <strong>{item.name}</strong>
                <b>{foodMoney(item.price)}</b>
              </button>
            ))}
          </div>
        </section>
      ) : null}

      {!query.trim() && recent.length ? (
        <section className="wf-menu-search-section">
          <div className="wf-menu-search-heading"><h3>คำค้นหาล่าสุด</h3></div>
          <div className="wf-menu-recent">
            {recent.map((value) => (
              <button key={value} type="button" onClick={() => setQuery(value)}>
                <Clock3 size={15} />{value}
              </button>
            ))}
          </div>
        </section>
      ) : null}

      <section className="wf-menu-search-section" ref={resultsRef}>
        <div className="wf-menu-search-heading">
          <h3>{query.trim() ? "ผลการค้นหา" : "เมนูทั้งหมด"}</h3>
          <small>{results.length} เมนู</small>
        </div>
        {results.length ? (
          <div className="wf-menu-search-list">
            {results.map((item) => (
              <div className="wf-menu-search-row" key={item.id}>
                <button className="wf-menu-search-main" type="button" onClick={() => openItem(item)}>
                  <MenuImage client={client} item={item} className="wf-menu-search-image" />
                  <span>
                    <strong>{item.name}</strong>
                    <small>{item.category}</small>
                    <b>{foodMoney(item.price)}</b>
                  </span>
                </button>
                <button className="wf-menu-search-add" type="button" aria-label={item.name} onClick={() => openItem(item)}>
                  <Plus size={19} strokeWidth={2.2} />
                </button>
              </div>
            ))}
          </div>
        ) : (
          <div className="wf-empty wf-empty--compact">
            <Search size={35} strokeWidth={1.4} />
            <strong>ไม่พบเมนู</strong>
          </div>
        )}
      </section>
    </Sheet>
  );
}

function foodMenuStockNote(item: FoodCustomerMenuItem) {
  if (!foodMenuIsEffectivelyAvailable(item)) return { tone: "off" as const, text: "หมดชั่วคราว" };
  if (foodMenuQuantityLimit(item) <= 0) return { tone: "off" as const, text: "ขายหมดวันนี้ · พรุ่งนี้มีขายใหม่" };
  if (item.remaining_stock != null && item.remaining_stock <= 5) return { tone: "low" as const, text: `เหลือ ${Math.max(0, item.remaining_stock)} ชิ้นวันนี้` };
  if (item.daily_stock_limit) return { tone: "info" as const, text: `จำกัด ${item.daily_stock_limit} ชิ้น/วัน` };
  return null;
}

function FoodMenuRow({
  client,
  item,
  onItem,
}: {
  client: SupabaseClient;
  item: FoodCustomerMenuItem;
  onItem: (item: FoodCustomerMenuItem) => void;
}) {
  const available = foodMenuIsEffectivelyAvailable(item) && foodMenuQuantityLimit(item) > 0;
  const note = foodMenuStockNote(item);
  return (
    <button type="button" className={`fx-menu-row${available ? "" : " is-off"}`} onClick={() => onItem(item)} aria-label={`${item.name} ${foodMoney(item.price)}${available ? "" : " สินค้าหมด"}`}>
      <span className="fx-menu-row-copy">
        <strong>{item.name}</strong>
        {item.description ? <small>{item.description}</small> : null}
        {note ? <em className={`fx-stock-note is-${note.tone}`}>{note.text}</em> : null}
        <b>{foodMoney(item.price)}</b>
      </span>
      <span className="fx-menu-row-photo">
        <MenuImage client={client} item={item} />
        {available ? <span className="fx-plus" aria-hidden="true"><Plus size={18} strokeWidth={2.8} /></span> : <span className="fx-soldout-tag">สินค้าหมด</span>}
      </span>
    </button>
  );
}

function HomePanel({
  client,
  userId,
  store,
  menu,
  onItem,
  onPickStore,
  onShareStore,
  onBackStorefront,
  storefrontOpen,
  orders,
  addresses,
  onLocation,
}: {
  client: SupabaseClient;
  userId: string;
  store: FoodCustomerStore | null;
  menu: FoodCustomerMenuItem[];
  onItem: (item: FoodCustomerMenuItem) => void;
  onPickStore: (store: FoodDirectoryStore, placement: "home" | "search") => void;
  onShareStore: () => void;
  onBackStorefront: () => void;
  storefrontOpen: boolean;
  orders: FoodCustomerOrder[];
  addresses: FoodCustomerAddress[];
  onLocation: () => void;
}) {
  const [category, setCategory] = useState("ทั้งหมด");
  const [searchOpen, setSearchOpen] = useState(false);
  const [storeSection, setStoreSection] = useState<"menu" | "reviews" | "info">("menu");
  const [campaigns, setCampaigns] = useState<string[]>([]);
  const [reviewSummary, setReviewSummary] = useState<{ storeId: string | null; average: number; count: number }>({ storeId: null, average: 0, count: 0 });
  const storeId = store?.id ?? null;
  const favoriteKey = `wynos-food-favorite-stores-v1:${userId}`;
  const [favorite, setFavorite] = useState(() => {
    if (!storeId || typeof window === "undefined") return false;
    try {
      const saved = JSON.parse(localStorage.getItem(favoriteKey) ?? "[]");
      return Array.isArray(saved) && saved.includes(storeId);
    } catch {
      return false;
    }
  });

  // WYN-206: show the WYNOS campaigns this store joined.
  useEffect(() => {
    if (!storeId) return;
    let live = true;
    void fetchStorePlatformCampaigns(client, storeId).then((names) => { if (live) setCampaigns(names); });
    void fetchFoodStoreReviewFeed(client, storeId, 1)
      .then((feed) => {
        if (live) setReviewSummary({ storeId, average: feed.average, count: feed.count });
      })
      .catch(() => undefined);
    return () => { live = false; };
  }, [client, storeId]);
  const categories = useMemo(() => {
    const present = Array.from(new Set(menu.map((item) => item.category)));
    const preferred = Array.isArray(store?.menu_category_order) ? store.menu_category_order : [];
    const ordered = [...preferred.filter((name) => present.includes(name)), ...present.filter((name) => !preferred.includes(name))];
    return ["ทั้งหมด", ...ordered];
  }, [menu, store]);
  const isOrderable = (item: FoodCustomerMenuItem) => foodMenuIsEffectivelyAvailable(item) && foodMenuQuantityLimit(item) > 0;
  // Sold-out dishes stay visible with their real photo, after the dishes that can be ordered.
  const byAvailability = (items: FoodCustomerMenuItem[]) => [...items.filter(isOrderable), ...items.filter((item) => !isOrderable(item))];
  const visible = useMemo(
    () => menu.filter((item) => category === "ทั้งหมด" || item.category === category),
    [category, menu],
  );

  if (!storefrontOpen) {
    return (
      <>
        <StoreDirectory
          client={client}
          userId={userId}
          orders={orders}
          addresses={addresses}
          onPick={onPickStore}
          onLocation={onLocation}
        />
        <a className="fx-social-promo" href="https://wynos.online/" aria-label="เปิด WYNOS Social">
          <span className="fx-social-promo-mark">W</span>
          <span className="fx-social-promo-copy">
            <strong>WYNOS Social</strong>
            <small>โพสต์ พูดคุย ติดตาม และค้นหาคอนเทนต์บน wynos.online</small>
          </span>
          <ChevronRight size={18} />
        </a>
      </>
    );
  }

  if (!store) {
    return (
      <FoodStateScreen icon={<Store size={46} strokeWidth={1.6} />} title="ยังไม่มีร้านสำหรับ WYNOS Food" action={<button className="fx-btn fx-btn--primary" type="button" onClick={onBackStorefront}>กลับหน้าหลัก</button>}>
        <p>ร้านค้าสามารถสร้างและตั้งค่าร้านผ่าน WYNOS Merchant เพื่อเริ่มขายบน WYNOS Food</p>
      </FoodStateScreen>
    );
  }

  const cover = foodPublicUrl(client, store.cover_path);
  const open = foodStoreIsEffectivelyOpen(store);
  const statusText = foodStoreStatusText(store);
  const hoursText = foodStoreTodayHoursText(store) || store.business_hours;
  const primaryAddress = addresses.find((address) => address.is_default) ?? addresses[0] ?? null;
  const distance = foodDistanceKm(addressLocation(primaryAddress), store);
  const distanceLabel = foodDistanceLabel(distance);
  const eta = foodEstimateDeliveryRange(store, distance);
  const hasRating = reviewSummary.storeId === store.id && reviewSummary.count > 0;
  const recommended = category === "ทั้งหมด" ? menu.filter(isOrderable).slice(0, 6) : [];
  const toggleFavorite = () => {
    const next = !favorite;
    setFavorite(next);
    try {
      const saved = JSON.parse(localStorage.getItem(favoriteKey) ?? "[]");
      const ids = new Set<string>(
        Array.isArray(saved) ? saved.filter((value): value is string => typeof value === "string") : [],
      );
      if (next) ids.add(store.id);
      else ids.delete(store.id);
      localStorage.setItem(favoriteKey, JSON.stringify(Array.from(ids)));
    } catch {
      // Favorite still works for this session when browser storage is unavailable.
    }
  };

  const groups = category === "ทั้งหมด"
    ? categories.slice(1).map((name) => ({ name, items: byAvailability(menu.filter((item) => item.category === name)) })).filter((group) => group.items.length)
    : [{ name: category, items: byAvailability(visible) }];

  return (
    <>
      <section className={`fx-store-hero${open ? "" : " is-closed"}`}>
        <div className="fx-store-cover">
          {cover ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={cover} alt="" decoding="async" fetchPriority="high" />
          ) : <Store size={46} strokeWidth={1.25} />}
        </div>
        <div className="fx-store-hero-actions">
          <button className="fx-float-btn" type="button" aria-label="กลับหน้าหลัก WYNOS Food" onClick={onBackStorefront}>
            <ArrowLeft size={21} strokeWidth={2.3} />
          </button>
          <span className="fx-store-hero-right">
            <button className="fx-float-btn" type="button" aria-label="ค้นหาเมนูอาหาร" onClick={() => setSearchOpen(true)}>
              <Search size={19} strokeWidth={2.3} />
            </button>
            <button
              className={`fx-float-btn${favorite ? " is-active" : ""}`}
              type="button"
              aria-label="รายการโปรด"
              aria-pressed={favorite}
              onClick={toggleFavorite}
            >
              <Heart size={19} strokeWidth={2.2} fill={favorite ? "currentColor" : "none"} />
            </button>
            <button className="fx-float-btn" type="button" aria-label={`แชร์ลิงก์ร้าน ${store.name}`} onClick={onShareStore}>
              <Share2 size={18} strokeWidth={2.2} />
            </button>
          </span>
        </div>
        {!open ? <span className="fx-store-closed-badge"><Clock3 size={16} strokeWidth={2.4} />ร้านปิดอยู่</span> : null}
      </section>

      <section className="fx-store-info">
        <h1>{store.name}</h1>
        <p className="fx-store-meta">
          <Star size={14} fill="#F5A623" strokeWidth={0} />
          {hasRating ? <><b>{reviewSummary.average.toFixed(1)}</b> ({new Intl.NumberFormat("th-TH").format(reviewSummary.count)})</> : <b>ร้านใหม่</b>}
          {distanceLabel ? <> · {distanceLabel}</> : null}
          {" · "}{eta.min}–{eta.max} นาที · {foodMoney(store.delivery_fee)}
        </p>
        {open ? (
          <p className="fx-store-open"><Clock3 size={14} strokeWidth={2.3} />เปิดอยู่{hoursText ? <span>{hoursText}</span> : null}</p>
        ) : (
          <div className="fx-store-closed-box" role="status">
            <strong>ปิดรับออเดอร์ชั่วคราว</strong>
            <span>{statusText} · ดูเมนูไว้ก่อนได้</span>
          </div>
        )}
        {Number(store.minimum_order) > 0 ? <p className="fx-store-min">สั่งขั้นต่ำ {foodMoney(store.minimum_order)}</p> : null}
        {campaigns.length ? (
          <div className="fx-store-campaigns">
            {campaigns.map((name) => <span key={name}><Ticket size={16} />{`แคมเปญ WYNOS · ${name}`}</span>)}
          </div>
        ) : null}
      </section>

      <nav className="fx-tabs" aria-label="ข้อมูลร้าน">
        <button type="button" className={storeSection === "menu" ? "is-active" : ""} aria-pressed={storeSection === "menu"} onClick={() => setStoreSection("menu")}>เมนู</button>
        <button type="button" className={storeSection === "reviews" ? "is-active" : ""} aria-pressed={storeSection === "reviews"} onClick={() => setStoreSection("reviews")}>{hasRating ? `รีวิว (${new Intl.NumberFormat("th-TH").format(reviewSummary.count)})` : "รีวิว"}</button>
        <button type="button" className={storeSection === "info" ? "is-active" : ""} aria-pressed={storeSection === "info"} onClick={() => setStoreSection("info")}>ข้อมูลร้าน</button>
      </nav>

      {storeSection === "reviews" ? <StoreReviewsSection client={client} storeId={store.id} /> : null}

      {storeSection === "info" ? (
        <section className="fx-store-details">
          {store.description ? <p>{store.description}</p> : null}
          {store.address ? <div><MapPin size={19} /><span><small>ที่อยู่ร้าน</small><strong>{store.address}</strong></span></div> : null}
          {store.phone ? <a href={`tel:${store.phone}`}><Phone size={19} /><span><small>เบอร์ติดต่อ</small><strong>{store.phone}</strong></span></a> : null}
          {hoursText ? <div><Clock3 size={19} /><span><small>เวลาเปิด–ปิด</small><strong>{hoursText}</strong></span></div> : null}
          <div><Timer size={19} /><span><small>เวลาเตรียมอาหาร</small><strong>ประมาณ {Number(store.prep_time_min_minutes ?? 15)}–{Number(store.prep_time_max_minutes ?? 30)} นาที</strong></span></div>
          {store.delivery_area ? <div><Bike size={19} /><span><small>พื้นที่จัดส่ง</small><strong>{store.delivery_area}</strong></span></div> : null}
        </section>
      ) : null}

      {storeSection === "menu" ? (
        <section className="fx-store-menu">
          {categories.length > 2 ? (
            <div className="fx-chips fx-chips--menu" role="group" aria-label="หมวดเมนู">
              {categories.map((name) => (
                <button key={name} type="button" className={`fx-chip${category === name ? " is-active" : ""}`} aria-pressed={category === name} onClick={() => setCategory(name)}>
                  {name}
                </button>
              ))}
            </div>
          ) : null}

          {recommended.length >= 3 ? (
            <section className="fx-menu-section">
              <h2>เมนูแนะนำ</h2>
              <div className="fx-menu-tiles">
                {recommended.map((item) => (
                  <button key={item.id} type="button" className="fx-menu-tile" onClick={() => onItem(item)} aria-label={`${item.name} ${foodMoney(item.price)}`}>
                    <span className="fx-menu-tile-photo">
                      <MenuImage client={client} item={item} />
                      <span className="fx-plus" aria-hidden="true"><Plus size={18} strokeWidth={2.8} /></span>
                    </span>
                    <strong>{item.name}</strong>
                    <b>{foodMoney(item.price)}</b>
                  </button>
                ))}
              </div>
            </section>
          ) : null}

          {groups.length ? groups.map((group) => (
            <section className="fx-menu-section" key={group.name}>
              <h2>{group.name}</h2>
              <div className="fx-menu-list">
                {group.items.map((item) => <FoodMenuRow key={item.id} client={client} item={item} onItem={onItem} />)}
              </div>
            </section>
          )) : (
            <FoodStateScreen icon={<UtensilsCrossed size={44} strokeWidth={1.6} />} title="ยังไม่มีเมนู">
              <p>ร้านยังไม่ได้เพิ่มเมนูในหมวดนี้</p>
            </FoodStateScreen>
          )}
        </section>
      ) : null}

      {searchOpen ? (
        <MenuSearchSheet
          client={client}
          menu={menu}
          historyKey={`wynos-food-menu-search-v1:${userId}:${store.id}`}
          onItem={onItem}
          onClose={() => setSearchOpen(false)}
        />
      ) : null}
    </>
  );
}

function CartPanel({
  client,
  store,
  menu,
  cart,
  quote,
  onCart,
  onCheckout,
  onBack,
  onBrowse,
}: {
  client: SupabaseClient;
  store: FoodCustomerStore | null;
  menu: FoodCustomerMenuItem[];
  cart: FoodCartLine[];
  quote: FoodOrderQuote | null;
  onCart: (cart: FoodCartLine[]) => void;
  onCheckout: () => void;
  onBack: () => void;
  onBrowse: () => void;
}) {
  const [firstOrderState, setFirstOrderState] = useState<{ storeId: string; eligible: boolean } | null>(null);
  const storeId = store?.id;
  const firstOrderOffer = Boolean(storeId && firstOrderState?.storeId === storeId && firstOrderState.eligible);
  useEffect(() => {
    if (!storeId) return;
    let live = true;
    void Promise.resolve(client.rpc("food_first_order_offer", { p_store_id: storeId }))
      .then(({ data, error }) => {
        if (live) setFirstOrderState({ storeId, eligible: !error && data?.eligible === true });
      })
      .catch(() => {
        if (live) setFirstOrderState({ storeId, eligible: false });
      });
    return () => { live = false; };
  }, [client, storeId]);

  const priced = cart.map((line) => {
    const item = itemFor(menu, line.menu_item_id);
    return { line, item, key: foodCartLineKey(line), unitPrice: item ? foodCartLineUnitPrice(item, line) : 0 };
  });
  const clientSubtotal = priced.reduce((sum, row) => sum + row.unitPrice * row.line.quantity, 0);
  const subtotal = Number(quote?.subtotal ?? clientSubtotal);
  const delivery = Number(quote?.delivery_fee ?? store?.delivery_fee ?? 0);
  const campaignDiscount = Number(quote?.campaign_discount ?? 0);
  const deliveryDiscount = Number(quote?.delivery_discount ?? 0);
  const total = quote?.total ?? subtotal + delivery;
  const quantityByMenu = new Map<string, number>();
  for (const line of cart) quantityByMenu.set(line.menu_item_id, (quantityByMenu.get(line.menu_item_id) ?? 0) + line.quantity);
  const hasUnavailable = priced.some((row) => {
    if (!row.item || !foodMenuIsEffectivelyAvailable(row.item) || !foodCartLineOptionsValid(row.item, row.line)) return true;
    const limit = foodMenuQuantityLimit(row.item);
    return limit <= 0 || (quantityByMenu.get(row.line.menu_item_id) ?? 0) > limit;
  });
  const minimum = Number(store?.minimum_order ?? 0);
  const belowMinimum = subtotal < minimum;
  const storeOpen = !!store && foodStoreIsEffectivelyOpen(store);
  const canCheckout = !!store && storeOpen && cart.length > 0 && !hasUnavailable && !belowMinimum;
  const logo = store ? foodPublicUrl(client, store.logo_path) : null;
  const eta = store ? foodEstimateDeliveryRange(store, quote?.delivery_distance_km ?? null) : null;

  const changeQuantity = (key: string, delta: number) => {
    onCart(cart
      .map((line) => {
        if (foodCartLineKey(line) !== key) return line;
        const item = itemFor(menu, line.menu_item_id);
        const limit = item ? foodMenuQuantityLimit(item) : 99;
        const otherQuantity = cart.reduce((sum, row) => sum + (row.menu_item_id === line.menu_item_id && foodCartLineKey(row) !== key ? row.quantity : 0), 0);
        const lineLimit = Math.max(0, limit - otherQuantity);
        const next = line.quantity + delta;
        return { ...line, quantity: delta > 0 ? Math.min(next, lineLimit) : next };
      })
      .filter((line) => line.quantity > 0));
  };
  const removeLine = (key: string) => onCart(cart.filter((line) => foodCartLineKey(line) !== key));
  const clearCart = () => {
    if (window.confirm("ล้างทุกรายการในตะกร้า?")) onCart([]);
  };

  return (
    <div className="fx-page fx-cart">
      <FoodPageHeader
        title="ตะกร้าสินค้า"
        onBack={onBack}
        action={cart.length ? <button className="fx-text-btn" type="button" onClick={clearCart}><Trash2 size={16} />ล้างตะกร้า</button> : null}
      />

      {!cart.length ? (
        <FoodStateScreen
          icon={<ShoppingBag size={48} strokeWidth={1.6} />}
          title="ตะกร้ายังว่างอยู่"
          action={<button className="fx-btn fx-btn--primary" type="button" onClick={onBrowse}>เลือกร้านอาหาร</button>}
        >
          <p>เลือกเมนูจากร้านใกล้คุณ แล้วกด + เพื่อใส่ตะกร้า</p>
        </FoodStateScreen>
      ) : (
        <>
          {store ? (
            <div className="fx-cart-store">
              <span className="fx-cart-store-logo">
                {logo ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={logo} alt="" />
                ) : <Store size={22} />}
              </span>
              <span>
                <strong>{store.name}</strong>
                <small>{storeOpen ? `${eta?.min ?? 0}–${eta?.max ?? 0} นาที` : foodStoreStatusText(store)}</small>
              </span>
            </div>
          ) : null}

          <div className="fx-cart-lines">
            {priced.map(({ line, item, key, unitPrice }) => {
              const limit = item ? foodMenuQuantityLimit(item) : 0;
              const totalMenuQuantity = quantityByMenu.get(line.menu_item_id) ?? line.quantity;
              const unavailable = !item || !foodMenuIsEffectivelyAvailable(item) || !foodCartLineOptionsValid(item, line) || limit <= 0 || totalMenuQuantity > limit;
              const optionText = foodCartLineOptionText(line, item);
              return (
                <article key={key} className={`fx-cart-line${unavailable ? " is-off" : ""}`}>
                  {item ? <MenuImage client={client} item={item} className="fx-cart-thumb" /> : <span className="fx-menu-image fx-cart-thumb"><UtensilsCrossed size={22} /></span>}
                  <div className="fx-cart-line-copy">
                    <strong>{item?.name ?? "เมนูไม่พร้อมใช้งาน"}</strong>
                    {optionText ? <small>{optionText}</small> : null}
                    {line.note ? <small>หมายเหตุ · {line.note}</small> : null}
                    <b>{item ? foodMoney(unitPrice * line.quantity) : "—"}</b>
                    {unavailable ? <em>{limit <= 0 ? "เมนูนี้ขายครบสำหรับวันนี้แล้ว" : item && !foodCartLineOptionsValid(item, line) ? "ตัวเลือกเมนูเปลี่ยนแล้ว กรุณาเลือกใหม่" : "จำนวนหรือสถานะเมนูเปลี่ยนไป กรุณาปรับตะกร้า"}</em> : null}
                  </div>
                  <div className="fx-cart-line-side">
                    <div className="fx-stepper fx-stepper--sm">
                      <button type="button" aria-label="ลดจำนวน" onClick={() => changeQuantity(key, -1)}>
                        {line.quantity === 1 ? <Trash2 size={15} /> : <Minus size={15} strokeWidth={2.6} />}
                      </button>
                      <b aria-live="polite">{line.quantity}</b>
                      <button type="button" aria-label="เพิ่มจำนวน" disabled={!item || totalMenuQuantity >= limit} onClick={() => changeQuantity(key, 1)}>
                        <Plus size={15} strokeWidth={2.6} />
                      </button>
                    </div>
                    {line.quantity > 1 ? (
                      <button className="fx-icon-btn fx-icon-btn--sm" type="button" aria-label={`ลบ ${item?.name ?? "รายการ"}`} onClick={() => removeLine(key)}><Trash2 size={16} /></button>
                    ) : null}
                  </div>
                </article>
              );
            })}
          </div>

          <button className="fx-add-more" type="button" onClick={onBrowse}><Plus size={18} strokeWidth={2.6} />เพิ่มเมนูอื่นจากร้านนี้</button>

          {quote?.campaign_name ? <div className="fx-note fx-note--success"><BadgePercent size={18} /><span><strong>ใช้แคมเปญ {quote.campaign_name}</strong><small>WYNOS เลือกโปรที่ประหยัดที่สุดให้อัตโนมัติ</small></span></div> : null}
          {firstOrderOffer ? (
            <div className="fx-note fx-note--success" role="status">
              <Gift size={18} />
              <span>
                <strong>สิทธิ์ลูกค้าใหม่ · ค่าอาหารครบ ฿100 ลดทันที ฿40</strong>
                <small>{subtotal < 100 ? `เพิ่มค่าอาหารอีก ${foodMoney(100 - subtotal)} เพื่อถึงยอดขั้นต่ำ` : "ระบบคำนวณส่วนลดที่เหมาะสมให้อัตโนมัติ ไม่ต้องใส่โค้ด"}</small>
              </span>
            </div>
          ) : null}

          <div className="fx-summary">
            <div><span>ค่าอาหาร</span><b>{foodMoney(subtotal)}</b></div>
            <div><span>ค่าจัดส่ง</span><b>{foodMoney(delivery)}</b></div>
            {campaignDiscount > 0 ? <div className="is-discount"><span>{quote?.campaign_name ? "ส่วนลด · " + quote.campaign_name : "ส่วนลดแคมเปญ"}</span><b>−{foodMoney(campaignDiscount)}</b></div> : null}
            {deliveryDiscount > 0 ? <div className="is-discount"><span>ส่วนลดค่าส่ง</span><b>−{foodMoney(deliveryDiscount)}</b></div> : null}
          </div>

          {belowMinimum && store ? (
            <div className="fx-note fx-note--warn">เพิ่มอีก {foodMoney(Math.max(0, minimum - subtotal))} เพื่อถึงยอดขั้นต่ำ {foodMoney(minimum)}</div>
          ) : null}
          {hasUnavailable ? <div className="fx-note fx-note--warn">มีเมนูที่หมดหรือจำนวนเกินสต็อกวันนี้ กรุณาปรับตะกร้าก่อนชำระเงิน</div> : null}
          {store && !storeOpen ? <div className="fx-note fx-note--warn">{foodStoreStatusText(store)}</div> : null}

          <div className="fx-bottom-bar">
            <div className="fx-bottom-total"><span>ยอดรวม</span><b>{foodMoney(total)}</b></div>
            <button className="fx-btn fx-btn--primary fx-btn--block" type="button" disabled={!canCheckout} onClick={onCheckout}>
              ไปชำระเงิน
            </button>
          </div>
        </>
      )}
    </div>
  );
}

function OrdersPanel({
  orders,
  reviewedOrderIds,
  hasMore,
  loadingMore,
  onLoadMore,
  onOrder,
  onReorder,
  onBrowse,
}: {
  orders: FoodCustomerOrder[];
  reviewedOrderIds: Set<string>;
  hasMore: boolean;
  loadingMore: boolean;
  onLoadMore: () => void;
  onOrder: (order: FoodCustomerOrder) => void;
  onReorder: (order: FoodCustomerOrder) => void;
  onBrowse: () => void;
}) {
  const active = orders.filter((order) => !["delivered", "cancelled"].includes(order.status));
  const history = orders.filter((order) => ["delivered", "cancelled"].includes(order.status));
  const [view, setView] = useState<"active" | "history">(() => (active.length || !history.length ? "active" : "history"));
  const shown = view === "active" ? active : history;

  return (
    <div className="fx-page">
      <FoodPageHeader title="ออเดอร์ของฉัน" />
      <div className="fx-segment" role="tablist" aria-label="ออเดอร์">
        <button type="button" role="tab" aria-selected={view === "active"} className={view === "active" ? "is-active" : ""} onClick={() => setView("active")}>
          กำลังดำเนินการ{active.length ? ` (${active.length})` : ""}
        </button>
        <button type="button" role="tab" aria-selected={view === "history"} className={view === "history" ? "is-active" : ""} onClick={() => setView("history")}>
          ประวัติ
        </button>
      </div>
      {shown.length ? (
        <div className="fx-order-list">
          {shown.map((order) => (
            <OrderCard
              key={order.id}
              order={order}
              reviewPending={order.status === "delivered" && !reviewedOrderIds.has(order.id)}
              onOpen={() => onOrder(order)}
              onReorder={() => onReorder(order)}
            />
          ))}
        </div>
      ) : (
        <FoodStateScreen
          icon={<ReceiptText size={48} strokeWidth={1.6} />}
          title={view === "active" ? "ยังไม่มีออเดอร์" : "ยังไม่มีประวัติการสั่ง"}
          action={<button className="fx-btn fx-btn--primary" type="button" onClick={onBrowse}>สั่งอาหารเลย</button>}
        >
          <p>{view === "active" ? "ออเดอร์ที่กำลังทำจะแสดงที่นี่ ติดตามสถานะได้ตลอดจนถึงมือคุณ" : "ออเดอร์ที่ส่งสำเร็จหรือยกเลิกจะแสดงที่นี่"}</p>
        </FoodStateScreen>
      )}
      {view === "history" && hasMore ? <button className="fx-btn fx-btn--outline-neutral fx-btn--block fx-load-more" type="button" disabled={loadingMore} onClick={onLoadMore}>{loadingMore ? "กำลังโหลด…" : "ดูคำสั่งซื้อเก่ากว่านี้"}</button> : null}
    </div>
  );
}

function MessagesPanel() {
  return (
    <div className="fx-page">
      <FoodPageHeader title="ข้อความ" />
      <FoodStateScreen icon={<MessageCircle size={48} strokeWidth={1.6} />} title="ยังไม่มีข้อความ">
        <p>การสนทนากับร้านและผู้จัดส่งจะแสดงที่นี่</p>
        <p>แชท WYNOS Food แยกจากแชท WYNOS</p>
      </FoodStateScreen>
    </div>
  );
}

function foodOrderTone(order: FoodCustomerOrder) {
  if (order.status === "cancelled") return "muted";
  if (order.status === "delivered") return "success";
  if (["pending", "issue"].includes(order.payment_status)) return "danger";
  if (order.payment_status === "submitted") return "warn";
  return "brand";
}

function OrderCard({
  order,
  reviewPending = false,
  onOpen,
  onReorder,
}: {
  order: FoodCustomerOrder;
  reviewPending?: boolean;
  onOpen: () => void;
  onReorder: () => void;
}) {
  const count = order.food_order_items?.reduce((sum, item) => sum + item.quantity, 0) ?? 0;
  const names = (order.food_order_items ?? []).map((item) => item.item_name).slice(0, 2).join(", ");
  const awaitingPayment = order.status !== "cancelled" && ["pending", "issue"].includes(order.payment_status);
  const label = awaitingPayment ? foodPaymentStatusLabel(order.payment_status)
    : order.payment_status === "submitted" && order.status === "pending_acceptance" ? foodPaymentStatusLabel(order.payment_status)
      : foodOrderStatusLabel(order.status);
  const done = ["delivered", "cancelled"].includes(order.status);
  return (
    <article className="fx-order-card">
      <button className="fx-order-card-main" type="button" onClick={onOpen} aria-label={`ออเดอร์ #${order.order_number} ${label}`}>
        <span className="fx-order-card-top">
          <b>#{order.order_number}</b>
          <span className={`fx-status is-${foodOrderTone(order)}`}>{label}</span>
        </span>
        <span className="fx-order-card-body">
          <strong>{names || `${count} รายการ`}{(order.food_order_items?.length ?? 0) > 2 ? " และอื่นๆ" : ""}</strong>
          <small>{count} รายการ · {foodMoney(order.total)}</small>
          <small>{formatDate(order.created_at)}</small>
          {order.scheduled_for ? <small className="fx-order-scheduled"><Clock3 size={13} />นัดรับ/จัดส่ง {formatDate(order.scheduled_for)}</small> : null}
        </span>
      </button>
      <div className="fx-order-card-actions">
        {awaitingPayment ? (
          <button className="fx-btn fx-btn--primary fx-btn--sm" type="button" onClick={onOpen}>ชำระเงิน</button>
        ) : done ? (
          <>
            {reviewPending ? <button className="fx-btn fx-btn--outline fx-btn--sm" type="button" onClick={onOpen}>ให้คะแนน</button> : <button className="fx-btn fx-btn--outline-neutral fx-btn--sm" type="button" onClick={onOpen}>ดูรายละเอียด</button>}
            <button className="fx-btn fx-btn--primary fx-btn--sm" type="button" onClick={onReorder}>สั่งอีกครั้ง</button>
          </>
        ) : (
          <>
            <button className="fx-btn fx-btn--outline fx-btn--sm" type="button" onClick={onOpen}>ดูรายละเอียด</button>
            <button className="fx-btn fx-btn--primary fx-btn--sm" type="button" onClick={onOpen}>ติดตาม</button>
          </>
        )}
      </div>
    </article>
  );
}

function AccountPanel({
  addresses,
  installPrompt,
  notificationsEnabled,
  onAddAddress,
  onEditAddress,
  onDeleteAddress,
  onInstall,
  onNotifications,
  onSignOut,
  onOrders,
}: {
  addresses: FoodCustomerAddress[];
  installPrompt: InstallPromptEvent | null;
  notificationsEnabled: boolean;
  onAddAddress: () => void;
  onEditAddress: (address: FoodCustomerAddress) => void;
  onDeleteAddress: (id: string) => void;
  onInstall: () => void;
  onNotifications: () => void;
  onSignOut: () => void;
  onOrders: () => void;
}) {
  const primary = addresses.find((address) => address.is_default) ?? addresses[0] ?? null;
  const initial = (primary?.recipient_name.trim() || "W").slice(0, 1);

  return (
    <div className="fx-page fx-account">
      <FoodPageHeader title="บัญชี" />

      {primary ? (
        <button className="fx-profile-card" type="button" onClick={() => onEditAddress(primary)}>
          <span className="fx-avatar" aria-hidden="true">{initial}</span>
          <span className="fx-profile-copy">
            <strong>{primary.recipient_name}</strong>
            <small>{primary.recipient_phone} · โปรไฟล์ WYNOS Food</small>
            <small>ข้อมูลสำหรับการสั่งและจัดส่งอาหารเท่านั้น</small>
          </span>
          <ChevronRight size={20} />
        </button>
      ) : (
        <div className="fx-profile-card is-empty">
          <span className="fx-avatar" aria-hidden="true"><UserRound size={24} /></span>
          <span className="fx-profile-copy">
            <strong>ตั้งค่าโปรไฟล์ก่อนสั่งอาหาร</strong>
            <small>กรอกชื่อผู้รับ เบอร์โทร ที่อยู่ และปักหมุด</small>
          </span>
          <button className="fx-btn fx-btn--primary fx-btn--sm" type="button" onClick={onAddAddress}>ตั้งค่า</button>
        </div>
      )}

      <section className="fx-account-section">
        <div className="fx-section-head">
          <h2>ที่อยู่จัดส่ง</h2>
          <button type="button" onClick={onAddAddress}><Plus size={16} strokeWidth={2.6} /> เพิ่มที่อยู่ใหม่</button>
        </div>
        {addresses.length ? (
          <div className="fx-address-list">
            {addresses.map((address) => {
              const located = Boolean(addressLocation(address));
              const complete = foodCustomerAddressStructuredComplete(address);
              const extra = [address.place_name, address.building_name, address.floor ? `ชั้น ${address.floor}` : null, address.room ? `ห้อง ${address.room}` : null, address.landmark].filter(Boolean).join(" · ");
              return (
                <article key={address.id} className={`fx-address${address.is_default ? " is-default" : ""}`}>
                  <MapPin size={20} className="fx-address-pin" fill={address.is_default ? "currentColor" : "none"} />
                  <div className="fx-address-copy">
                    {address.is_default ? <span className="fx-address-flag">ที่อยู่หลัก</span> : null}
                    <strong>{address.label}</strong>
                    <small>{address.recipient_name} · {address.recipient_phone}</small>
                    <p>{address.address}</p>
                    {extra ? <small>{extra}</small> : null}
                    {address.delivery_note ? <small>รายละเอียดเพิ่มเติม · {address.delivery_note}</small> : null}
                    <small className={complete && located ? "is-ready" : "is-missing"}>
                      {!complete ? "ต้องอัปเดตข้อมูลที่อยู่" : located ? "ปักหมุดแล้ว" : "ยังไม่ได้ปักหมุดโลเคชั่น"}
                    </small>
                  </div>
                  <div className="fx-address-actions">
                    <button className="fx-icon-btn fx-icon-btn--soft" type="button" aria-label={`แก้ไขที่อยู่ ${address.label}`} onClick={() => onEditAddress(address)}><Pencil size={16} /></button>
                    <button className="fx-icon-btn fx-icon-btn--soft" type="button" aria-label={`ลบที่อยู่ ${address.label}`} onClick={() => onDeleteAddress(address.id)}><Trash2 size={16} /></button>
                  </div>
                </article>
              );
            })}
          </div>
        ) : <p className="fx-empty-line">ยังไม่มีที่อยู่จัดส่ง</p>}
      </section>

      <div className="fx-menu-list-settings">
        <button type="button" onClick={onOrders}>
          <ReceiptText size={21} /><span><strong>ประวัติการสั่งอาหาร</strong></span><ChevronRight size={18} />
        </button>
        <button type="button" onClick={onNotifications}>
          <Bell size={21} /><span><strong>การแจ้งเตือน</strong><small>{notificationsEnabled ? "เปิดแล้วสำหรับอุปกรณ์นี้" : "แจ้งสถานะคำสั่งซื้อและการจัดส่ง"}</small></span><ChevronRight size={18} />
        </button>
        {installPrompt ? (
          <button type="button" onClick={onInstall}>
            <Download size={21} /><span><strong>ติดตั้ง WYNOS Food</strong><small>เพิ่ม WYNOS Food ไว้บนหน้าจอหลัก</small></span><ChevronRight size={18} />
          </button>
        ) : null}
        <a href="https://lin.ee/SKQAOtm" target="_blank" rel="noreferrer" aria-label="ขายอาหารบน WYNOS Food ติดต่อ LINE @352lvyoi">
          <Store size={21} /><span><strong>ขายอาหารบน WYNOS Food</strong><small>สนใจเปิดร้าน ติดต่อทีมงานผ่าน LINE · @352lvyoi</small></span><ChevronRight size={18} />
        </a>
        <a href="https://wynos.online/login">
          <ArrowLeft size={21} /><span><strong>เปิด WYNOS Social</strong><small>ใช้ WYNOS Account เดิม แล้วค่อยตั้งโปรไฟล์ Social เมื่อต้องการ</small></span><ChevronRight size={18} />
        </a>
      </div>

      <button className="fx-btn fx-btn--soft fx-btn--block fx-signout" type="button" onClick={onSignOut}>
        <LogOut size={18} />ออกจากระบบ
      </button>
    </div>
  );
}

function Sheet({
  title,
  onClose,
  children,
  variant = "page",
  footer,
}: {
  title: string;
  onClose: () => void;
  children: React.ReactNode;
  variant?: "sheet" | "page";
  footer?: React.ReactNode;
}) {
  const page = variant === "page";
  return (
    <div
      className={`fx-sheet-backdrop${page ? " is-page" : ""}`}
      role="presentation"
      onMouseDown={(event) => {
        if (!page && event.target === event.currentTarget) onClose();
      }}
    >
      <section className={`fx-sheet${page ? " is-page" : ""}`} role="dialog" aria-modal="true" aria-label={title}>
        <header className="fx-sheet-head">
          <button className="fx-icon-btn" type="button" aria-label={page ? "ย้อนกลับ" : "ปิด"} onClick={onClose}>
            {page ? <ArrowLeft size={22} strokeWidth={2.1} /> : <X size={22} />}
          </button>
          <h2>{title}</h2>
          <span />
        </header>
        <div className="fx-sheet-body">{children}</div>
        {footer ? <footer className="fx-sheet-footer">{footer}</footer> : null}
      </section>
    </div>
  );
}

function ItemSheet({
  client,
  item,
  existing,
  cartQuantity,
  storeOpen,
  storeStatus,
  onClose,
  onAdd,
}: {
  client: SupabaseClient;
  item: FoodCustomerMenuItem;
  existing: FoodCartLine | null;
  cartQuantity: number;
  storeOpen: boolean;
  storeStatus: string;
  onClose: () => void;
  onAdd: (line: FoodCartLine, replaceKey?: string) => void;
}) {
  const [quantity, setQuantity] = useState(existing?.quantity ?? 1);
  const [note, setNote] = useState(existing?.note ?? "");
  const [selected, setSelected] = useState<Record<string, string[]>>(() => {
    const initial: Record<string, string[]> = {};
    for (const option of existing?.selected_options ?? []) {
      initial[option.group_id] = [...(initial[option.group_id] ?? []), option.choice_id];
    }
    return initial;
  });
  const image = foodPublicUrl(client, item.image_path);
  const itemAvailable = foodMenuIsEffectivelyAvailable(item);
  const optionGroups = Array.isArray(item.options) ? item.options : [];
  const stockLimit = foodMenuQuantityLimit(item);
  const reservedByOtherVariants = Math.max(0, cartQuantity - (existing?.quantity ?? 0));
  const quantityLimit = Math.max(0, stockLimit - reservedByOtherVariants);
  const selectionValid = optionGroups.every((group) => !group.required || (selected[group.id]?.length ?? 0) > 0);
  const selectedOptions = optionGroups.flatMap((group) => {
    const ids = new Set(selected[group.id] ?? []);
    return group.choices
      .filter((choice) => ids.has(choice.id))
      .map((choice) => ({
        group_id: group.id,
        group_name: group.name,
        choice_id: choice.id,
        choice_name: choice.name,
        price: Number(choice.price ?? 0),
      }));
  });
  const unitPrice = Number(item.price) + selectedOptions.reduce((sum, option) => sum + Math.max(0, Number(option.price ?? 0)), 0);
  const orderingDisabled = !itemAvailable || !storeOpen || quantityLimit <= 0;
  const canAdd = !orderingDisabled && selectionValid && quantity <= quantityLimit;
  const closedActionLabel = storeStatus.startsWith("ปิด") ? `ร้าน${storeStatus}` : `ร้านปิด · ${storeStatus}`;
  const actionLabel = !storeOpen
    ? closedActionLabel
    : !itemAvailable
      ? "เมนูหมดชั่วคราว"
      : quantityLimit <= 0
        ? "ขายหมดวันนี้"
        : !selectionValid
          ? "เลือกตัวเลือกที่จำเป็นก่อน"
          : `${existing ? "อัปเดตตะกร้า" : "เพิ่มลงตะกร้า"} · ${foodMoney(unitPrice * quantity)}`;
  const note2 = foodMenuStockNote(item);

  const toggleOption = (groupId: string, choiceId: string, maxSelect: number) => {
    setSelected((current) => {
      const before = current[groupId] ?? [];
      if (maxSelect <= 1) return { ...current, [groupId]: before.includes(choiceId) ? [] : [choiceId] };
      if (before.includes(choiceId)) return { ...current, [groupId]: before.filter((id) => id !== choiceId) };
      if (before.length >= maxSelect) return current;
      return { ...current, [groupId]: [...before, choiceId] };
    });
  };

  return (
    <div className="fx-sheet-backdrop is-page fx-item-backdrop" role="presentation">
      <section
        className={`fx-sheet is-page fx-item${orderingDisabled ? " is-disabled" : ""}`}
        role="dialog"
        aria-modal="true"
        aria-label={item.name}
      >
        <button className="fx-float-btn fx-item-close" type="button" aria-label="ปิด" onClick={onClose}><X size={20} strokeWidth={2.4} /></button>

        <div className="fx-item-scroll">
          <div className="fx-item-photo">
            {image ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={image} alt="" />
            ) : <UtensilsCrossed size={48} strokeWidth={1.35} />}
            {!itemAvailable || quantityLimit <= 0 ? <span className="fx-soldout-tag fx-soldout-tag--lg">สินค้าหมด</span> : null}
          </div>

          <div className="fx-item-head">
            <h3>{item.name}</h3>
            {item.description ? <p>{item.description}</p> : null}
            {note2 ? <em className={`fx-stock-note is-${note2.tone}`}>{note2.text}</em> : null}
            <strong>{foodMoney(unitPrice)}</strong>
          </div>

          {!storeOpen ? (
            <div className="fx-note fx-note--danger" role="status"><Clock3 size={18} /><span><strong>{storeStatus}</strong><small>ดูเมนูไว้ก่อนได้ สั่งได้เมื่อร้านเปิด</small></span></div>
          ) : null}

          {optionGroups.map((group) => {
            const maxSelect = Math.max(1, Math.min(20, Number(group.max_select ?? 1)));
            const chosen = selected[group.id] ?? [];
            return (
              <section className="fx-option-group" key={group.id}>
                <div className="fx-option-head">
                  <strong>{group.name}</strong>
                  {group.required ? (
                    <span className={`fx-required${chosen.length ? " is-done" : ""}`}>{chosen.length ? "เลือกแล้ว" : "ต้องเลือก"}</span>
                  ) : <small>{maxSelect === 1 ? "เลือกได้ 1 รายการ" : `เลือกได้สูงสุด ${maxSelect} รายการ`}</small>}
                </div>
                {group.required ? <small className="fx-option-hint">{maxSelect === 1 ? "เลือก 1 รายการ" : `เลือกได้สูงสุด ${maxSelect} รายการ`}</small> : null}
                <div className="fx-option-choices">
                  {group.choices.map((choice) => {
                    const active = chosen.includes(choice.id);
                    const extra = Math.max(0, Number(choice.price ?? 0));
                    return (
                      <button
                        key={choice.id}
                        type="button"
                        className={active ? "is-active" : ""}
                        role={maxSelect === 1 ? "radio" : "checkbox"}
                        aria-checked={active}
                        disabled={orderingDisabled}
                        onClick={() => toggleOption(group.id, choice.id, maxSelect)}
                      >
                        <i className={`fx-control ${maxSelect === 1 ? "is-radio" : "is-checkbox"}`} aria-hidden="true">{maxSelect > 1 && active ? <Check size={14} strokeWidth={3} /> : null}</i>
                        <span>{choice.name}</span>
                        <b>{extra > 0 ? `+${foodMoney(extra)}` : ""}</b>
                      </button>
                    );
                  })}
                </div>
              </section>
            );
          })}
          {!selectionValid && !orderingDisabled ? <div className="fx-note fx-note--warn fx-item-warn" role="status">กรุณาเลือกตัวเลือกที่จำเป็นให้ครบ</div> : null}

          <label className="fx-field fx-item-note">
            <span className="fx-field-label"><strong>หมายเหตุถึงร้าน</strong><small>{note.length}/200</small></span>
            <textarea
              value={note}
              maxLength={200}
              disabled={orderingDisabled}
              onChange={(event) => setNote(event.target.value)}
              placeholder="เช่น ไม่ใส่ผัก, แยกน้ำจิ้ม"
            />
          </label>
        </div>

        <div className="fx-item-actions">
          <div className="fx-stepper">
            <button
              type="button"
              aria-label="ลดจำนวน"
              disabled={orderingDisabled || quantity <= 1}
              onClick={() => setQuantity((value) => Math.max(1, value - 1))}
            ><Minus size={18} strokeWidth={2.6} /></button>
            <b aria-live="polite">{quantity}</b>
            <button
              type="button"
              aria-label="เพิ่มจำนวน"
              disabled={orderingDisabled || quantity >= quantityLimit}
              onClick={() => setQuantity((value) => Math.min(quantityLimit, value + 1))}
            ><Plus size={18} strokeWidth={2.6} /></button>
          </div>
          <button
            className="fx-btn fx-btn--primary fx-btn--grow"
            type="button"
            disabled={!canAdd}
            onClick={() => onAdd(
              { menu_item_id: item.id, quantity, note: note.trim(), selected_options: selectedOptions },
              existing ? foodCartLineKey(existing) : undefined,
            )}
          >
            {actionLabel}
          </button>
        </div>
      </section>
    </div>
  );
}

/**
 * Delivery coordinates are chosen on an interactive map. Search uses the
 * server-side LocationIQ proxy; map rendering uses MapLibre + OpenFreeMap.
 */
function DeliveryPinPicker({
  client,
  storeId,
  location,
  onChange,
}: {
  client: SupabaseClient;
  storeId: string | null;
  location: FoodLocation | null;
  onChange: (location: FoodLocation | null, place?: FoodPlace) => void;
}) {
  const [mapOpen, setMapOpen] = useState(false);

  return (
    <div className="wf-pin wf-pin--map">
      <div className="wf-pin-summary">
        <span className={location ? "is-ready" : ""}><MapPin size={18} /></span>
        <div>
          <strong>{location ? "ปักหมุดแล้ว" : "ยังไม่ได้ปักหมุด"}</strong>
          <small>{location ? "ตำแหน่งนี้จะใช้คำนวณระยะทางและส่งอาหาร" : "ค้นหาที่อยู่แล้วเลื่อนแผนที่ให้ตรงจุดรับอาหาร"}</small>
          {location ? <em data-i18n-skip="">{location.latitude.toFixed(5)}, {location.longitude.toFixed(5)}</em> : null}
        </div>
      </div>
      <button className="wf-secondary wf-full" type="button" onClick={() => setMapOpen(true)}>
        <MapPin size={17} /> {location ? "แก้ไขหมุดบนแผนที่" : "ค้นหาและปักหมุดบนแผนที่"}
      </button>
      {location ? <button className="wf-pin-clear" type="button" onClick={() => onChange(null)}>ล้างตำแหน่ง</button> : null}

      {mapOpen ? (
        <FoodDeliveryMapPicker
          client={client}
          storeId={storeId}
          initialLocation={location}
          onClose={() => setMapOpen(false)}
          onConfirm={(next, place) => {
            onChange(next, place);
            setMapOpen(false);
          }}
        />
      ) : null}
    </div>
  );
}

function AddressEditor({
  client,
  storeId,
  showPin,
  draft,
  onClose,
  onSave,
  busy,
}: {
  client: SupabaseClient;
  storeId: string | null;
  /** Only stores with a delivery zone need a pin (WYN-196). */
  showPin: boolean;
  draft: FoodAddressDraft;
  onClose: () => void;
  onSave: (draft: FoodAddressDraft) => void;
  busy: boolean;
}) {
  const [form, setForm] = useState(() => draftWithLastWynosMapsPin(draft));
  const locationKey = form.location ? `${form.location.latitude},${form.location.longitude}` : "";
  const [availabilityState, setAvailabilityState] = useState<{
    key: string;
    value: Awaited<ReturnType<typeof checkFoodDeliveryAvailability>>;
  } | null>(null);

  useEffect(() => {
    if (!storeId || !form.location) return;
    let live = true;
    const key = `${storeId}|${locationKey}`;
    const point = form.location;
    void checkFoodDeliveryAvailability(client, storeId, point)
      .then((value) => { if (live) setAvailabilityState({ key, value }); })
      .catch(() => { if (live) setAvailabilityState({ key, value: null }); });
    return () => { live = false; };
  }, [client, form.location, locationKey, storeId]);

  const availabilityKey = storeId && locationKey ? `${storeId}|${locationKey}` : "";
  const availability = availabilityState?.key === availabilityKey ? availabilityState.value : null;
  const complete = Boolean(
    form.recipientName.trim()
      && form.recipientPhone.trim()
      && (form.addressLine1.trim() || form.address.trim())
      && form.subdistrict.trim()
      && form.district.trim()
      && form.province.trim()
      && /^\d{5}$/.test(form.postalCode.trim())
      && form.location,
  );
  const deliveryMessage = !availability
    ? ""
    : availability.can_deliver
      ? `ร้านนี้ส่งถึง · ${availability.distance_km == null ? "" : `${availability.distance_km.toFixed(1)} กม. · `}ค่าส่ง ${foodMoney(availability.delivery_fee ?? 0)}`
      : availability.reason === "outside_delivery_area"
        ? `อยู่นอกระยะจัดส่งของร้าน${availability.delivery_radius_km == null ? "" : ` · ร้านส่งได้ประมาณ ${availability.delivery_radius_km} กม.`}`
        : availability.reason === "outside_service_area"
          ? "ตำแหน่งนี้อยู่นอกพื้นที่ให้บริการของ WYNOS Food"
          : availability.reason === "store_unavailable"
            ? "ร้านนี้ยังไม่พร้อมรับการจัดส่ง"
            : "กรุณาตรวจสอบตำแหน่งจัดส่ง";
  return (
    <Sheet title={form.id ? "แก้ไขข้อมูลจัดส่ง" : "เพิ่มข้อมูลจัดส่ง"} onClose={onClose} variant="page">
      <div className="wf-form wf-address-form">
        <div className="wf-form-note">ข้อมูลนี้เป็นของ WYNOS Food เท่านั้น และไม่แก้ไขโปรไฟล์ WYNOS</div>

        <label>ชื่อที่อยู่ <small>เช่น บ้าน / หอพัก / ที่ทำงาน</small>
          <input value={form.label} onChange={(event) => setForm({ ...form, label: event.target.value })} placeholder="ที่อยู่ของฉัน" />
        </label>
        <label>ชื่อผู้รับ <b>*</b>
          <input autoComplete="name" value={form.recipientName} onChange={(event) => setForm({ ...form, recipientName: event.target.value })} placeholder="ชื่อผู้รับอาหาร" />
        </label>
        <label>เบอร์โทร <b>*</b>
          <input inputMode="tel" autoComplete="tel" value={form.recipientPhone} onChange={(event) => setForm({ ...form, recipientPhone: event.target.value })} placeholder="เบอร์สำหรับติดต่อจัดส่ง" />
        </label>

        <div className="wf-address-form-section">
          <strong>ตำแหน่งจัดส่ง</strong>
          <small>ปักหมุดก่อน ระบบจะช่วยเติมจังหวัด อำเภอ ตำบล และรหัสไปรษณีย์เมื่อข้อมูลแผนที่รองรับ</small>
        </div>
        {showPin || form.location ? <DeliveryPinPicker
          client={client}
          storeId={storeId}
          location={form.location}
          onChange={(location, place) => setForm((current) => {
            const parts = structuredAddressPartsFromPlace(place);
            return {
              ...current,
              location,
              placeId: location ? place?.placeId ?? null : null,
              placeName: location ? place?.name ?? "" : "",
              subdistrict: location ? current.subdistrict || parts.subdistrict : current.subdistrict,
              district: location ? current.district || parts.district : current.district,
              province: location ? current.province || parts.province : current.province,
              postalCode: location ? current.postalCode || parts.postalCode : current.postalCode,
            };
          })}
        /> : null}
        {form.placeName ? <div className="wf-form-note">WYNOS Place · {form.placeName}</div> : null}
        {storeId && form.location && deliveryMessage ? (
          <div className={availability?.can_deliver ? "wf-form-note" : "wf-inline-warning"}>{deliveryMessage}</div>
        ) : null}

        <div className="wf-address-form-section">
          <strong>รายละเอียดที่อยู่</strong>
          <small>กรอกตามที่อยู่จริงเพื่อให้ร้านและผู้จัดส่งหาได้ถูกต้อง</small>
        </div>
        <label>บ้านเลขที่ / ที่อยู่ <b>*</b>
          <input
            autoComplete="address-line1"
            value={form.addressLine1 || form.address}
            onChange={(event) => setForm({ ...form, addressLine1: event.target.value, address: "" })}
            placeholder="เช่น 123/45"
          />
        </label>
        <label>ชื่ออาคาร / หมู่บ้าน
          <input value={form.buildingName} onChange={(event) => setForm({ ...form, buildingName: event.target.value })} placeholder="เช่น หอพักธาราทิพย์ / คอนโด A" />
        </label>
        <div className="wf-form-grid wf-form-grid--3">
          <label>หมู่ที่<input value={form.moo} onChange={(event) => setForm({ ...form, moo: event.target.value })} placeholder="เช่น 11" /></label>
          <label>ชั้น<input value={form.floor} onChange={(event) => setForm({ ...form, floor: event.target.value })} placeholder="เช่น 5" /></label>
          <label>ห้อง<input value={form.room} onChange={(event) => setForm({ ...form, room: event.target.value })} placeholder="เช่น 508" /></label>
        </div>
        <div className="wf-form-grid">
          <label>ซอย<input value={form.soi} onChange={(event) => setForm({ ...form, soi: event.target.value })} placeholder="เช่น ซอย 3" /></label>
          <label>ถนน<input value={form.road} onChange={(event) => setForm({ ...form, road: event.target.value })} placeholder="เช่น ถนนนครสวรรค์" /></label>
        </div>
        <label>จังหวัด <b>*</b>
          <input autoComplete="address-level1" value={form.province} onChange={(event) => setForm({ ...form, province: event.target.value })} placeholder="เช่น มหาสารคาม" />
        </label>
        <div className="wf-form-grid">
          <label>อำเภอ / เขต <b>*</b>
            <input autoComplete="address-level2" value={form.district} onChange={(event) => setForm({ ...form, district: event.target.value })} placeholder="เช่น กันทรวิชัย" />
          </label>
          <label>ตำบล / แขวง <b>*</b>
            <input autoComplete="address-level3" value={form.subdistrict} onChange={(event) => setForm({ ...form, subdistrict: event.target.value })} placeholder="เช่น ขามเรียง" />
          </label>
        </div>
        <label>รหัสไปรษณีย์ <b>*</b>
          <input
            inputMode="numeric"
            autoComplete="postal-code"
            maxLength={5}
            value={form.postalCode}
            onChange={(event) => setForm({ ...form, postalCode: event.target.value.replace(/\D/g, "").slice(0, 5) })}
            placeholder="เช่น 44150"
          />
        </label>

        <label>จุดสังเกต
          <textarea value={form.landmark} onChange={(event) => setForm({ ...form, landmark: event.target.value })} placeholder="เช่น ทางเข้าอยู่ข้างร้านสะดวกซื้อ" />
        </label>
        <label>หมายเหตุถึงผู้จัดส่ง
          <textarea value={form.deliveryNote} onChange={(event) => setForm({ ...form, deliveryNote: event.target.value })} placeholder="เช่น โทรเมื่อถึง / ฝากไว้กับ รปภ." />
        </label>
        <label className="wf-check">
          <input type="checkbox" checked={form.isDefault} onChange={(event) => setForm({ ...form, isDefault: event.target.checked })} />
          <span><strong>ใช้เป็นที่อยู่หลัก</strong><small>WYNOS Food จะเลือกข้อมูลนี้ให้อัตโนมัติตอน Checkout</small></span>
        </label>

        {!form.location ? <div className="wf-inline-warning">กรุณาปักหมุดโลเคชั่นก่อนบันทึก เพื่อให้ร้านและผู้จัดส่งหาได้ถูกต้อง</div> : null}
        {form.location && (!form.subdistrict.trim() || !form.district.trim() || !form.province.trim() || !/^\d{5}$/.test(form.postalCode.trim())) ? (
          <div className="wf-inline-warning">กรอกจังหวัด อำเภอ/เขต ตำบล/แขวง และรหัสไปรษณีย์ให้ครบก่อนบันทึก</div>
        ) : null}
        <button className="wf-primary wf-full" type="button" disabled={busy || !complete} onClick={() => onSave(form)}>
          {busy ? "กำลังบันทึก…" : "บันทึกข้อมูล WYNOS Food"}
        </button>
      </div>
    </Sheet>
  );
}

function CheckoutSheet({
  client,
  store,
  menu,
  cart,
  addresses,
  quote,
  busy,
  onClose,
  onAddAddress,
  onEditAddress,
  onSubmit,
}: {
  client: SupabaseClient;
  store: FoodCustomerStore;
  menu: FoodCustomerMenuItem[];
  cart: FoodCartLine[];
  addresses: FoodCustomerAddress[];
  quote: FoodOrderQuote | null;
  busy: boolean;
  onClose: () => void;
  onAddAddress: () => void;
  onEditAddress: (address: FoodCustomerAddress) => void;
  onSubmit: (address: FoodCustomerAddress, note: string, couponCode?: string | null) => void;
}) {
  const initialAddressId = (
    addresses.find((address) => address.is_default && foodCustomerAddressStructuredComplete(address))
    ?? addresses.find((address) => foodCustomerAddressStructuredComplete(address))
    ?? addresses.find((address) => address.is_default)
    ?? addresses[0]
  )?.id ?? "";
  const [addressId, setAddressId] = useState(initialAddressId);
  const [note, setNote] = useState("");
  const [couponDraft, setCouponDraft] = useState(() => {
    if (typeof window === "undefined") return "";
    const fromLink = new URLSearchParams(window.location.search).get("promo");
    let saved: string | null = null;
    try { saved = localStorage.getItem("wynos-food-promo-code-v1"); } catch { /* private mode */ }
    return (fromLink || saved || "").toUpperCase().replace(/[^A-Z0-9_-]/g, "").slice(0,24);
  });
  const [couponCode, setCouponCode] = useState<string | null>(() => {
    if (typeof window === "undefined") return null;
    let stored: string | null = null;
    try { stored = localStorage.getItem("wynos-food-promo-code-v1"); } catch { /* private mode */ }
    const linked = new URLSearchParams(window.location.search).get("promo");
    const code = (linked || stored || "").toUpperCase();
    return /^[A-Z0-9][A-Z0-9_-]{3,23}$/.test(code) ? code : null;
  });
  const [showAddressPicker, setShowAddressPicker] = useState(false);

  const address = addresses.find((row) => row.id === addressId) ?? null;
  const subtotal = cart.reduce((sum, line) => {
    const item = itemFor(menu, line.menu_item_id);
    return sum + (item ? foodCartLineUnitPrice(item, line) * line.quantity : 0);
  }, 0);

  const zone = storeHasDeliveryZone(store);
  const location = addressLocation(address);
  const locationKey = location ? `${location.latitude},${location.longitude}` : "";
  const [addressQuote, setAddressQuote] = useState<{ key: string; quote: FoodOrderQuote | null; error: string } | null>(null);

  useEffect(() => {
    let live = true;
    const key = `${addressId}|${locationKey}|${couponCode ?? ""}`;
    const loc = zone && locationKey
      ? { latitude: Number(locationKey.split(",")[0]), longitude: Number(locationKey.split(",")[1]) }
      : null;
    if (!addressId || (zone && !loc)) return () => { live = false; };
    void quoteFoodCustomerOrder(client, store.id, cart, loc, couponCode)
      .then((next) => { if (live) setAddressQuote({ key, quote: next, error: "" }); })
      .catch((error) => { if (live) setAddressQuote({ key, quote: null, error: foodCustomerError(error) }); });
    return () => { live = false; };
  }, [addressId, cart, client, couponCode, locationKey, store.id, zone]);

  const current = addressQuote?.key === `${addressId}|${locationKey}|${couponCode ?? ""}` ? addressQuote : null;
  const quoteLoading = Boolean(address) && (!zone || Boolean(location)) && current === null;
  const effectiveQuote = current?.quote ?? quote;

  const checkoutQuantityByMenu = new Map<string, number>();
  for (const line of cart) {
    checkoutQuantityByMenu.set(line.menu_item_id, (checkoutQuantityByMenu.get(line.menu_item_id) ?? 0) + line.quantity);
  }
  const cartUnavailable = cart.some((line) => {
    const item = itemFor(menu, line.menu_item_id);
    if (!item || !foodMenuIsEffectivelyAvailable(item) || !foodCartLineOptionsValid(item, line)) return true;
    const limit = foodMenuQuantityLimit(item);
    return limit <= 0 || (checkoutQuantityByMenu.get(line.menu_item_id) ?? 0) > limit;
  });

  const serverSubtotal = Number(effectiveQuote?.subtotal ?? subtotal);
  const minimum = Number(store.minimum_order ?? 0);
  const minimumMissing = Math.max(0, minimum - serverSubtotal);
  const couponFailed = Boolean(couponCode && current?.error);
  const quoteError = current?.error && !couponFailed ? current.error : "";
  const quoteAddressError = /ที่อยู่|พื้นที่|ปักหมุด|ตำแหน่ง|จังหวัด/.test(quoteError);
  const addressProblem = !address
    ? ""
    : !foodCustomerAddressStructuredComplete(address)
      ? "ที่อยู่นี้เป็นข้อมูลเก่า กรุณากดแก้ไขและกรอกจังหวัด อำเภอ/เขต ตำบล/แขวง และรหัสไปรษณีย์ให้ครบก่อนสั่ง"
      : zone && !location
        ? "ที่อยู่นี้ยังไม่ได้ปักหมุดตำแหน่ง แก้ไขที่อยู่เพื่อปักหมุดก่อนสั่ง"
        : quoteAddressError
          ? quoteError
          : "";
  const blockedReason = addressProblem
    || (quoteError && !quoteAddressError ? quoteError : "")
    || (cartUnavailable ? "มีเมนูที่หมดหรือจำนวนเกินสต็อกวันนี้ กรุณากลับไปปรับตะกร้า" : "")
    || (minimumMissing > 0 ? `เพิ่มอีก ${foodMoney(minimumMissing)} เพื่อถึงยอดขั้นต่ำ ${foodMoney(minimum)}` : "")
    || (couponFailed ? "ลบโค้ดที่ใช้ไม่ได้ก่อนยืนยันคำสั่งซื้อ" : "");

  const deliveryFee = Number(effectiveQuote?.delivery_fee ?? store.delivery_fee);
  const campaignDiscount = Number(effectiveQuote?.campaign_discount ?? 0);
  const deliveryDiscount = Number(effectiveQuote?.delivery_discount ?? 0);
  const total = effectiveQuote?.total ?? serverSubtotal + deliveryFee;
  const eta = foodEstimateDeliveryRange(store, effectiveQuote?.delivery_distance_km);
  const itemCount = cart.reduce((sum, line) => sum + line.quantity, 0);

  const confirmDisabled = !address || busy || quoteLoading || Boolean(blockedReason);
  const confirmLabel = busy
    ? "กำลังสร้างออเดอร์…"
    : !address
      ? "เพิ่มที่อยู่ก่อนสั่ง"
      : addressProblem
        ? "เปลี่ยนที่อยู่ก่อนสั่ง"
        : quoteLoading
          ? "กำลังคำนวณค่าส่ง…"
          : "ยืนยันคำสั่งซื้อ";

  const submitOrder = () => {
    if (!address) return;
    onSubmit(address, note, couponCode);
  };

  const paymentMethods = [
    store.promptpay_id || store.payment_qr_path ? "สแกน QR พร้อมเพย์" : null,
    store.bank_account_number ? "โอนแล้วแนบสลิป" : null,
    store.stripe_payments_enabled ? "บัตร" : null,
  ].filter(Boolean);

  const applyCoupon = () => {
    const normalized = couponDraft.trim().toUpperCase();
    setCouponCode(normalized || null);
    try { if (normalized) localStorage.setItem("wynos-food-promo-code-v1", normalized); } catch { /* private mode */ }
  };
  const removeCoupon = () => {
    setCouponCode(null);
    setCouponDraft("");
    try { localStorage.removeItem("wynos-food-promo-code-v1"); } catch { /* private mode */ }
  };

  return (
    <Sheet
      title="ชำระเงิน"
      onClose={onClose}
      variant="page"
      footer={(
        <div className="fx-checkout-footer">
          <div className="fx-bottom-total"><span>ยอดรวม</span><b>{foodMoney(total)}</b></div>
          <button className="fx-btn fx-btn--primary fx-btn--block" type="button" disabled={confirmDisabled} onClick={submitOrder}>
            {confirmLabel}
          </button>
          {addressProblem && addresses.length > 1 ? (
            <button className="fx-btn fx-btn--outline fx-btn--block" type="button" onClick={() => setShowAddressPicker(true)}>เลือกที่อยู่อื่น</button>
          ) : null}
        </div>
      )}
    >
      <div className="fx-checkout">
        <div className="fx-section-head">
          <h2>ที่อยู่จัดส่ง</h2>
          <button type="button" onClick={onAddAddress}><Plus size={16} strokeWidth={2.6} /> เพิ่มที่อยู่</button>
        </div>

        {address ? (
          <>
            <div className={`fx-checkout-address${addressProblem ? " is-error" : ""}`}>
              <MapPin size={20} fill="currentColor" strokeWidth={0} className="fx-address-pin" />
              <div className="fx-address-copy">
                <strong>{address.label}</strong>
                <small>{address.recipient_name} · {address.recipient_phone}</small>
                <p>{address.address}</p>
                {address.building_name || address.floor || address.room ? (
                  <small>{[address.building_name, address.floor ? `ชั้น ${address.floor}` : null, address.room ? `ห้อง ${address.room}` : null].filter(Boolean).join(" · ")}</small>
                ) : null}
                {address.delivery_note ? <small>{address.delivery_note}</small> : null}
              </div>
              <div className="fx-checkout-address-actions">
                {addresses.length > 1 ? (
                  <button className="fx-text-btn" type="button" aria-expanded={showAddressPicker} onClick={() => setShowAddressPicker((value) => !value)}>เปลี่ยน</button>
                ) : null}
                <button className="fx-text-btn fx-text-btn--muted" type="button" onClick={() => onEditAddress(address)}>แก้ไข</button>
              </div>
            </div>
            {addressProblem ? (
              <div className="fx-note fx-note--danger" role="alert"><CircleAlert size={18} /><span><strong>{addressProblem}</strong><small>เลือกที่อยู่อื่น หรือแก้ไขแล้วปักหมุดใหม่</small></span></div>
            ) : null}

            {showAddressPicker ? (
              <div className="fx-address-picker" role="radiogroup" aria-label="เลือกที่อยู่จัดส่ง">
                {addresses.map((row) => (
                  <button
                    key={row.id}
                    type="button"
                    role="radio"
                    aria-checked={addressId === row.id}
                    className={addressId === row.id ? "is-active" : ""}
                    onClick={() => {
                      setAddressId(row.id);
                      setShowAddressPicker(false);
                    }}
                  >
                    <i className="fx-control is-radio" aria-hidden="true" />
                    <span>
                      <strong>{row.label}</strong>
                      <small>{row.recipient_name} · {row.recipient_phone}</small>
                      <small>{row.address}</small>
                      {!foodCustomerAddressStructuredComplete(row) ? <small className="is-missing">ต้องอัปเดตข้อมูลที่อยู่</small> : null}
                    </span>
                  </button>
                ))}
              </div>
            ) : null}
          </>
        ) : (
          <button className="fx-checkout-address is-empty" type="button" onClick={onAddAddress}>
            <MapPin size={20} className="fx-address-pin" />
            <span className="fx-address-copy"><strong>เพิ่มที่อยู่จัดส่ง</strong><small>ต้องมีที่อยู่และหมุดตำแหน่งก่อนสั่งอาหาร</small></span>
            <ChevronRight size={18} />
          </button>
        )}

        <label className="fx-field">
          <span className="fx-field-label"><strong>หมายเหตุถึงผู้จัดส่ง</strong></span>
          <textarea value={note} onChange={(event) => setNote(event.target.value)} placeholder="เช่น โทรเมื่อถึง, วางไว้หน้าประตู" />
        </label>

        <section className="fx-coupon" aria-label="โค้ดส่วนลด">
          <label htmlFor="wynos-food-coupon" className="fx-field-label"><strong>โค้ดส่วนลด WYNOS Food</strong></label>
          <div className="fx-coupon-row">
            <input id="wynos-food-coupon" type="text" autoCapitalize="characters" maxLength={24}
              placeholder="เช่น FOOD50" value={couponDraft}
              onChange={(event) => setCouponDraft(event.target.value.toUpperCase())} />
            {couponCode ? (
              <button type="button" className="fx-btn fx-btn--outline-neutral fx-btn--sm" onClick={removeCoupon}>ลบ</button>
            ) : (
              <button type="button" className="fx-btn fx-btn--outline fx-btn--sm" onClick={applyCoupon} disabled={busy || !couponDraft.trim()}>ใช้โค้ด</button>
            )}
          </div>
          {couponCode && current?.quote?.coupon_applied ? <p role="status" className="fx-coupon-ok"><Check size={15} strokeWidth={3} />ใช้โค้ด {couponCode} สำเร็จ · ยอดสุทธิคำนวณโดยระบบแล้ว</p> : null}
          {couponFailed ? <p role="alert" className="fx-coupon-error">ใช้โค้ดนี้ไม่ได้: {current?.error} · ลบโค้ดเพื่อใช้โปรโมชันปกติ</p> : null}
        </section>

        <div className="fx-section-head"><h2>สรุปคำสั่งซื้อ</h2><small>{itemCount} รายการ</small></div>
        <div className="fx-checkout-items">
          {cart.map((line) => {
            const item = itemFor(menu, line.menu_item_id);
            const optionText = foodCartLineOptionText(line, item);
            return (
              <div className="fx-checkout-item" key={foodCartLineKey(line)}>
                {item ? <MenuImage client={client} item={item} className="fx-checkout-thumb" /> : <span className="fx-menu-image fx-checkout-thumb"><UtensilsCrossed size={18} /></span>}
                <span className="fx-checkout-item-copy">
                  <strong><span className="fx-qty-tag">{line.quantity}×</span>{item?.name ?? "เมนู"}</strong>
                  {optionText ? <small>{optionText}</small> : null}
                  {line.note ? <small>{line.note}</small> : null}
                </span>
                <b>{item ? foodMoney(foodCartLineUnitPrice(item, line) * line.quantity) : "—"}</b>
              </div>
            );
          })}
        </div>

        <div className="fx-summary">
          <div><span>ค่าอาหาร</span><b>{foodMoney(serverSubtotal)}</b></div>
          <div><span>ค่าจัดส่ง{current?.quote?.delivery_distance_km != null ? ` · ${current.quote.delivery_distance_km.toFixed(1)} กม.` : ""}</span><b>{addressProblem ? "—" : foodMoney(deliveryFee)}</b></div>
          {campaignDiscount > 0 ? <div className="is-discount"><span>{effectiveQuote?.campaign_name ? "ส่วนลด · " + effectiveQuote.campaign_name : "ส่วนลดค่าอาหาร"}</span><b>−{foodMoney(campaignDiscount)}</b></div> : null}
          {deliveryDiscount > 0 ? <div className="is-discount"><span>ส่วนลดค่าส่ง</span><b>−{foodMoney(deliveryDiscount)}</b></div> : null}
          <div className="is-eta"><span>เวลาถึงโดยประมาณ</span><b>{eta.min}–{eta.max} นาที</b></div>
        </div>

        <div className="fx-note fx-note--info" role="note">
          <Timer size={18} />
          <span>
            <strong>กรุณาชำระเงินหรือส่งสลิปภายใน 10 นาทีหลังยืนยันออเดอร์</strong>
            <small>{paymentMethods.length ? `${paymentMethods.join(" · ")} · ` : ""}หากยังไม่ชำระหรือไม่ส่งสลิป ระบบจะยกเลิกออเดอร์อัตโนมัติ</small>
          </span>
        </div>

        {blockedReason && !addressProblem ? <div className="fx-note fx-note--warn" role="alert">{blockedReason}</div> : null}
        {effectiveQuote?.campaign_name ? (
          <div className="fx-note fx-note--success">
            <BadgePercent size={18} />
            <span>
              <strong>แคมเปญ {effectiveQuote.campaign_name}</strong>
              <small>{effectiveQuote.campaign_name.startsWith("โปรลูกค้าใหม่") ? "สิทธิ์สั่งครั้งแรกเท่านั้น · ส่วนลดได้รับการสนับสนุนจากร้านอาหาร · ระบบจะตรวจสอบสิทธิ์อีกครั้ง" : "ส่วนลดจะยืนยันอีกครั้งโดยระบบก่อนสร้างออเดอร์"}</small>
            </span>
          </div>
        ) : null}
        <p className="fx-server-note">ยอดจริงจะถูกตรวจและคำนวณจากระบบอีกครั้งก่อนสร้างออเดอร์</p>
      </div>
    </Sheet>
  );
}

const FOOD_RATING_WORDS = ["", "แย่", "พอใช้", "โอเค", "ดี", "ดีมาก"];

function ReviewSheet({
  client,
  order,
  onClose,
  onSubmitted,
  onMessage,
}: {
  client: SupabaseClient;
  order: FoodCustomerOrder;
  onClose: () => void;
  onSubmitted: () => Promise<void>;
  onMessage: (message: string) => void;
}) {
  const [rating, setRating] = useState(0);
  const [tags, setTags] = useState<string[]>([]);
  const [reviewText, setReviewText] = useState("");
  const [anonymous, setAnonymous] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const reviewerLabel = anonymous ? "ไม่ระบุชื่อ" : maskFoodReviewerName(order.recipient_name);

  const toggleTag = (tag: string) => {
    setTags((current) => current.includes(tag)
      ? current.filter((value) => value !== tag)
      : current.length >= 5 ? current : [...current, tag]);
  };

  const submit = async () => {
    if (!rating || submitting) return;
    setSubmitting(true);
    try {
      await submitFoodStoreReview(client, {
        orderId: order.id,
        rating,
        reviewText,
        tags,
        anonymous,
      });
      onMessage("ขอบคุณสำหรับรีวิว");
      await onSubmitted();
    } catch (error) {
      onMessage(foodCustomerError(error, "ส่งรีวิวไม่สำเร็จ"));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <Sheet
      title="ให้คะแนน"
      onClose={onClose}
      footer={(
        <button className="fx-btn fx-btn--primary fx-btn--block" type="button" disabled={!rating || submitting} onClick={() => void submit()}>
          {submitting ? "กำลังส่งรีวิว…" : rating ? "ส่งรีวิว" : "เลือกดาวก่อนส่งรีวิว"}
        </button>
      )}
    >
      <div className="fx-review">
        <div className="fx-review-order"><ReceiptText size={20} /><span><strong>ออเดอร์ #{order.order_number}</strong><small>{formatDate(order.created_at)}</small></span></div>
        <h3>อาหารเป็นอย่างไรบ้าง?</h3>
        <div className="fx-review-stars" role="radiogroup" aria-label="ให้คะแนนร้าน">
          {[1, 2, 3, 4, 5].map((value) => (
            <button key={value} type="button" role="radio" aria-checked={rating === value} aria-label={`${value} ดาว`} onClick={() => setRating(value)}>
              <Star size={38} strokeWidth={1.6} fill={value <= rating ? "#F5A623" : "#E4E4E9"} color={value <= rating ? "#F5A623" : "#E4E4E9"} />
            </button>
          ))}
        </div>
        <p className="fx-review-word">{rating ? FOOD_RATING_WORDS[rating] : "แตะดาวเพื่อให้คะแนน"}</p>
        <div className="fx-section-head"><h2>ชอบอะไรบ้าง</h2><small>เลือกได้สูงสุด 5</small></div>
        <div className="fx-chips fx-chips--wrap">
          {FOOD_REVIEW_TAGS.map((tag) => (
            <button key={tag} type="button" className={`fx-chip fx-chip--soft${tags.includes(tag) ? " is-active" : ""}`} aria-pressed={tags.includes(tag)} onClick={() => toggleTag(tag)}>{tag}</button>
          ))}
        </div>
        <label className="fx-field">
          <span className="fx-field-label"><strong>เขียนรีวิว</strong><small>{reviewText.length}/500 · ไม่บังคับ</small></span>
          <textarea maxLength={500} value={reviewText} onChange={(event) => setReviewText(event.target.value)} placeholder="เล่าให้คนอื่นฟังหน่อย อาหารเป็นอย่างไร" />
        </label>
        <label className="fx-toggle-row">
          <input type="checkbox" checked={anonymous} onChange={(event) => setAnonymous(event.target.checked)} />
          <span><strong>ไม่ระบุชื่อ</strong><small>ชื่อที่จะแสดง: {reviewerLabel} · ไม่แสดง @username หรือรูปโปรไฟล์</small></span>
        </label>
        <p className="fx-server-note">รีวิวนี้มาจากออเดอร์ที่ส่งสำเร็จและจะแสดงป้าย “สั่งจริงกับ WYNOS Food”</p>
      </div>
    </Sheet>
  );
}

const FOOD_TRACK_SHORT: Record<FoodCustomerOrder["status"], string> = {
  pending_acceptance: "รอร้านรับ",
  preparing: "เตรียมอาหาร",
  ready_for_delivery: "พร้อมส่ง",
  out_for_delivery: "กำลังส่ง",
  delivered: "ส่งสำเร็จ",
  cancelled: "ยกเลิก",
};

const FOOD_TRACK_DETAIL: Record<FoodCustomerOrder["status"], string> = {
  pending_acceptance: "รอร้านยืนยันออเดอร์",
  preparing: "ร้านกำลังเตรียมอาหาร",
  ready_for_delivery: "อาหารพร้อม รอผู้จัดส่งรับ",
  out_for_delivery: "อาหารกำลังเดินทางไปหาคุณ",
  delivered: "จัดส่งสำเร็จแล้ว",
  cancelled: "ออเดอร์ถูกยกเลิก",
};

function copyText(value: string, onMessage: (message: string) => void) {
  const done = () => onMessage("คัดลอกแล้ว");
  if (navigator.clipboard?.writeText) {
    void navigator.clipboard.writeText(value).then(done).catch(() => onMessage(value));
  } else {
    onMessage(value);
  }
}

function OrderDetailSheet({
  client,
  userId,
  store,
  order,
  busy,
  ownReview,
  onClose,
  onReview,
  onReload,
  onMessage,
  onReorder,
}: {
  client: SupabaseClient;
  userId: string;
  store: FoodCustomerStore | null;
  order: FoodCustomerOrder;
  busy: boolean;
  ownReview: FoodCustomerOwnReview | null;
  onClose: () => void;
  onReview: () => void;
  onReload: () => Promise<void>;
  onMessage: (message: string) => void;
  onReorder: () => void;
}) {
  const [slipFile, setSlipFile] = useState<File | null>(null);
  const [slipPreviewUrl, setSlipPreviewUrl] = useState<string | null>(null);
  const [proofUrl, setProofUrl] = useState<string | null>(null);
  const [dynamicPaymentQr, setDynamicPaymentQr] = useState<string | null>(null);
  const [working, setWorking] = useState(false);
  const [clockNow, setClockNow] = useState(() => Date.now());
  const slipInputRef = useRef<HTMLInputElement>(null);
  const slipPreviewUrlRef = useRef<string | null>(null);
  const proof = orderDeliveryProof(order);
  // The store that owns this order; an order from another store keeps its own payment details private to that store.
  const orderStore = store?.id === order.store_id ? store : null;
  useEffect(() => {
    if (!order.payment_due_at || !["pending", "issue"].includes(order.payment_status) || order.status === "cancelled") return;
    const timer = window.setInterval(() => setClockNow(Date.now()), 1000);
    return () => window.clearInterval(timer);
  }, [order.payment_due_at, order.payment_status, order.status]);

  useEffect(() => () => {
    if (slipPreviewUrlRef.current) URL.revokeObjectURL(slipPreviewUrlRef.current);
  }, []);

  useEffect(() => {
    let live = true;
    void foodPrivateSignedUrl(client, proof?.image_path).then((url) => { if (live) setProofUrl(url); });
    return () => { live = false; };
  }, [client, order.id, proof?.image_path]);

  useEffect(() => {
    let live = true;
    const timer = window.setTimeout(() => {
      if (!live) return;
      // The QR is built server-side for this order's own store, so it is safe even when another store is open.
      if ((orderStore && !orderStore.promptpay_id) || !["pending", "issue"].includes(order.payment_status) || order.status === "cancelled") {
        setDynamicPaymentQr(null);
        return;
      }
      void fetchFoodPromptPayQr(client, order.id).then((result) => {
        if (live) setDynamicPaymentQr(result?.dataUrl ?? null);
      });
    }, 0);
    return () => {
      live = false;
      window.clearTimeout(timer);
    };
  }, [client, order.id, order.payment_status, order.status, orderStore]);

  const selectSlip = (file: File | null) => {
    if (slipPreviewUrlRef.current) URL.revokeObjectURL(slipPreviewUrlRef.current);
    const previewUrl = file ? URL.createObjectURL(file) : null;
    slipPreviewUrlRef.current = previewUrl;
    setSlipPreviewUrl(previewUrl);
    setSlipFile(file);
  };

  const clearSlip = () => {
    selectSlip(null);
    if (slipInputRef.current) slipInputRef.current.value = "";
  };

  const payWithStripe = async () => {
    setWorking(true);
    try {
      const url = await startFoodStripeCheckout(client, order.id);
      window.location.assign(url);
    } catch (error) {
      onMessage(foodCustomerError(error, "เปิดหน้าชำระเงิน Stripe ไม่สำเร็จ"));
      setWorking(false);
    }
  };

  const submitSlip = async () => {
    if (!slipFile) {
      onMessage("กรุณาเลือกรูปสลิป");
      return;
    }
    setWorking(true);
    try {
      if (order.stripe_checkout_session_id) {
        await prepareFoodManualPayment(client, order.id);
      }
      const path = await uploadFoodPaymentSlip(client, userId, order.id, slipFile);
      const verification = await submitFoodPayment(client, order.id, path);
      onMessage(
        verification.status === "auto_verified"
          ? "ตรวจสอบสลิปอัตโนมัติสำเร็จ ชำระเงินแล้ว"
          : verification.status === "rejected"
            ? "ตรวจสอบสลิปไม่ผ่าน กรุณาตรวจสอบและส่งใหม่"
            : "รับสลิปแล้ว กำลังรอร้านตรวจสอบ",
      );
      clearSlip();
      await onReload();
    } catch (error) {
      onMessage(foodCustomerError(error));
    } finally {
      setWorking(false);
    }
  };

  const cancel = async () => {
    if (!window.confirm("ยืนยันยกเลิกออเดอร์นี้?")) return;
    setWorking(true);
    try {
      await cancelFoodCustomerOrder(client, order.id, "ยกเลิกโดยลูกค้าใน WYNOS Food");
      onMessage("ยกเลิกออเดอร์แล้ว");
      await onReload();
    } catch (error) {
      onMessage(foodCustomerError(error));
    } finally {
      setWorking(false);
    }
  };

  const currentIndex = TRACKING_STEPS.findIndex((step) => step.status === order.status);
  const isCancelled = order.status === "cancelled";
  const secondsLeft = order.payment_due_at ? Math.max(0, Math.ceil((new Date(order.payment_due_at).getTime() - clockNow) / 1000)) : null;
  const paymentExpired = secondsLeft === 0;
  const awaitingPayment = ["pending", "issue"].includes(order.payment_status);
  const canPay = !isCancelled && !paymentExpired && awaitingPayment;
  const canCancel = order.status === "pending_acceptance" && awaitingPayment;
  const paymentQr = dynamicPaymentQr ?? foodPublicUrl(client, orderStore?.payment_qr_path);
  const combinedBusy = busy || working;
  const slipUnderReview = !isCancelled && order.payment_status === "submitted";
  const countdown = secondsLeft == null ? null : `${Math.floor(secondsLeft / 60).toString().padStart(2, "0")}:${(secondsLeft % 60).toString().padStart(2, "0")}`;
  const itemCount = (order.food_order_items ?? []).reduce((sum, item) => sum + item.quantity, 0);

  const slipPicker = (
    <input
      ref={slipInputRef}
      type="file"
      accept="image/jpeg,image/png,image/webp"
      disabled={combinedBusy}
      onChange={(event) => selectSlip(event.target.files?.[0] ?? null)}
    />
  );

  return (
    <Sheet
      title={canPay ? "ชำระเงิน" : `ออเดอร์ #${order.order_number}`}
      onClose={onClose}
      variant="page"
      footer={canPay ? (
        <div className="fx-pay-footer">
          {slipFile ? (
            <button className="fx-btn fx-btn--primary fx-btn--block" type="button" disabled={combinedBusy} onClick={() => void submitSlip()}>
              {combinedBusy ? "กำลังส่ง…" : "แจ้งชำระเงิน · ส่งสลิป"}
            </button>
          ) : (
            <label className={`fx-btn fx-btn--primary fx-btn--block fx-file-btn${combinedBusy ? " is-disabled" : ""}`}>
              {slipPicker}
              <Upload size={19} />แนบสลิปการโอน
            </label>
          )}
        </div>
      ) : null}
    >
      <div className="fx-order-detail">
        {canPay ? (
          <>
            {countdown ? (
              <div className="fx-countdown" role="status">
                <Timer size={22} />
                <span>ชำระภายในเวลา ไม่งั้นออเดอร์จะถูกยกเลิก</span>
                <b>{countdown}</b>
              </div>
            ) : null}
            <section className="fx-pay-card">
              <small>ยอดที่ต้องชำระ · ออเดอร์ #{order.order_number}</small>
              <strong className="fx-pay-amount">{foodMoney(order.total)}</strong>
              {paymentQr ? (
                <div className="fx-pay-qr">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={paymentQr} alt="QR รับชำระเงินของร้าน" />
                </div>
              ) : null}
              {dynamicPaymentQr ? <small className="fx-pay-qr-note">QR นี้ตั้งยอด {foodMoney(order.total)} ให้อัตโนมัติ · สแกนด้วยแอปธนาคารใดก็ได้</small> : null}
              <div className="fx-bank-rows">
                {orderStore?.promptpay_name || orderStore?.promptpay_id ? (
                  <div>
                    <span><small>พร้อมเพย์</small><strong>{orderStore.promptpay_name || "—"}</strong><b>{orderStore.promptpay_id || "—"}</b></span>
                    {orderStore.promptpay_id ? <button className="fx-btn fx-btn--outline fx-btn--sm" type="button" onClick={() => copyText(orderStore.promptpay_id!, onMessage)}><Copy size={15} />คัดลอก</button> : null}
                  </div>
                ) : null}
                {orderStore?.bank_name || orderStore?.bank_account_number ? (
                  <div>
                    <span><small>{orderStore.bank_name || "บัญชีธนาคาร"}</small><strong>{orderStore.bank_account_name || "—"}</strong><b>{orderStore.bank_account_number || "—"}</b></span>
                    {orderStore.bank_account_number ? <button className="fx-btn fx-btn--outline fx-btn--sm" type="button" onClick={() => copyText(orderStore.bank_account_number!, onMessage)}><Copy size={15} />คัดลอก</button> : null}
                  </div>
                ) : null}
              </div>
              <small className="fx-pay-qr-note">{orderStore?.stripe_payments_enabled ? "โอนเงินเข้าบัญชีร้านโดยตรงและแนบสลิปเป็นช่องทางสำรอง" : "โอนเงินเข้าบัญชีร้านโดยตรง แล้วแนบสลิปเพื่อให้ระบบตรวจสอบ"}</small>
              {orderStore && !orderStore.stripe_payments_enabled && !paymentQr && !orderStore.promptpay_id && !orderStore.bank_account_number ? <div className="fx-note fx-note--warn">ร้านยังไม่ได้ตั้งค่าช่องทางรับเงิน กรุณาติดต่อร้าน</div> : null}
              {!orderStore && !paymentQr ? <div className="fx-note fx-note--warn">เปิดหน้าร้านของออเดอร์นี้เพื่อดูข้อมูลบัญชีรับเงิน</div> : null}
            </section>

            {orderStore?.stripe_payments_enabled ? (
              <button className="fx-pay-option" type="button" disabled={combinedBusy} onClick={() => void payWithStripe()}>
                <CreditCard size={22} />
                <span><strong>{combinedBusy ? "กำลังเปิด Stripe…" : "จ่ายด้วยบัตร"}</strong><small>บัตร หรือพร้อมเพย์ผ่าน Stripe · ยืนยันสถานะอัตโนมัติ</small></span>
                <ChevronRight size={18} />
              </button>
            ) : null}

            {slipFile ? (
              <div className="fx-slip">
                <div className="fx-slip-image">
                  {slipPreviewUrl ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={slipPreviewUrl} alt="รูปตัวอย่างสลิปที่เลือก" />
                  ) : null}
                </div>
                <div className="fx-slip-copy">
                  <span className="fx-slip-ok"><Check size={14} strokeWidth={3} />เพิ่มสลิปแล้ว</span>
                  <strong title={slipFile.name}>{slipFile.name}</strong>
                  <div className="fx-slip-actions">
                    <label className={`fx-btn fx-btn--outline-neutral fx-btn--sm fx-file-btn${combinedBusy ? " is-disabled" : ""}`}>
                      {slipPicker}
                      <Upload size={15} />เปลี่ยนรูป
                    </label>
                    <button className="fx-btn fx-btn--outline-neutral fx-btn--sm" type="button" disabled={combinedBusy} onClick={clearSlip}>
                      <Trash2 size={15} />ลบรูป
                    </button>
                  </div>
                </div>
              </div>
            ) : null}
            {order.payment_note ? <div className="fx-note fx-note--warn">{order.payment_note}</div> : null}
          </>
        ) : null}

        {slipUnderReview ? (
          <div className="fx-note fx-note--amber" role="status">
            <Hourglass size={20} />
            <span>
              <strong>{order.payment_verification_status === "manual_review" ? "กำลังตรวจสอบสลิป" : foodPaymentStatusLabel(order.payment_status)}</strong>
              <small>ร้านกำลังตรวจยอดโอน {foodMoney(order.total)} · ออเดอร์จะไม่ถูกยกเลิกระหว่างรอตรวจ</small>
            </span>
          </div>
        ) : null}

        {!isCancelled && awaitingPayment && paymentExpired ? (
          <FoodStateScreen icon={<TimerOff size={44} strokeWidth={1.6} />} title="หมดเวลาชำระเงินแล้ว" role="status">
            <p>ระบบกำลังยกเลิกออเดอร์อัตโนมัติ หากโอนเงินไปแล้ว กรุณาติดต่อร้าน</p>
          </FoodStateScreen>
        ) : null}

        {isCancelled ? (
          <div className="fx-cancelled" role="status">
            <X size={22} />
            <span>
              <strong>{awaitingPayment ? "ยกเลิกแล้ว · หมดเวลาชำระเงิน" : "ออเดอร์ถูกยกเลิก"}</strong>
              <small>{order.cancelled_at ? formatDate(order.cancelled_at) : ""}</small>
            </span>
          </div>
        ) : !canPay ? (
          <>
            <ol className="fx-track" aria-label="สถานะออเดอร์">
              {TRACKING_STEPS.map((step, index) => {
                const done = currentIndex > index;
                const current = currentIndex === index;
                return (
                  <li key={step.status} className={`${done ? "is-done" : ""}${current ? " is-current" : ""}`} aria-current={current ? "step" : undefined}>
                    <span className="fx-track-dot">{done || (current && step.status === "delivered") ? <Check size={14} strokeWidth={3} /> : null}</span>
                    <small>{FOOD_TRACK_SHORT[step.status]}</small>
                  </li>
                );
              })}
            </ol>
            <div className="fx-track-card">
              <span className="fx-track-card-icon">{order.status === "delivered" ? <PackageCheck size={22} /> : order.status === "out_for_delivery" ? <Bike size={22} /> : <UtensilsCrossed size={22} />}</span>
              <span>
                <strong>{FOOD_TRACK_DETAIL[order.status]}</strong>
                <small>{order.status === "preparing" && order.eta_minutes ? `คาดว่าจะเสร็จภายใน ${order.eta_minutes} นาที` : `${foodPaymentStatusLabel(order.payment_status)} · ${formatDate(order.created_at)}`}</small>
              </span>
            </div>
          </>
        ) : null}

        {order.scheduled_for ? <div className="fx-note fx-note--info"><Clock3 size={18} /><span><strong>ออเดอร์ล่วงหน้า</strong><small>{formatDate(order.scheduled_for)}</small></span></div> : null}

        {order.status === "delivered" ? (
          <section className="fx-proof">
            <PackageCheck size={26} />
            <div><strong>จัดส่งสำเร็จแล้ว</strong><small>{order.delivered_at ? formatDate(order.delivered_at) : ""}</small>{proof?.location_note ? <p>วางไว้: {proof.location_note}</p> : <p>{proof?.method === "direct" ? "ส่งให้ผู้รับโดยตรง" : ""}</p>}</div>
            {proofUrl ? <a href={proofUrl} target="_blank" rel="noreferrer">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={proofUrl} alt="หลักฐานการจัดส่ง" />
            </a> : null}
          </section>
        ) : null}

        {order.status === "delivered" ? (
          ownReview ? (
            <section className="fx-review-done">
              <span><strong>ขอบคุณที่รีวิวร้าน</strong><small>รีวิวจากออเดอร์จริงของคุณ</small></span>
              <ReviewStars rating={ownReview.rating} compact />
            </section>
          ) : (
            <button className="fx-review-cta" type="button" onClick={onReview}>
              <span className="fx-review-cta-icon"><Star size={22} fill="currentColor" /></span>
              <span><strong>อาหารเป็นอย่างไรบ้าง?</strong><small>ให้คะแนนร้าน 1–5 ดาวจากออเดอร์นี้</small></span>
              <ChevronRight size={19} />
            </button>
          )
        ) : null}

        <section className="fx-order-block">
          <div className="fx-section-head"><h2>รายการอาหาร</h2><small>{itemCount} รายการ</small></div>
          <div className="fx-order-items">
            {(order.food_order_items ?? []).map((item) => {
              const optionText = foodCartLineOptionText({ selected_options: item.selected_options });
              return (
                <div key={item.id}>
                  <span><strong><span className="fx-qty-tag">{item.quantity}×</span>{item.item_name}</strong>{optionText ? <small>{optionText}</small> : null}{item.item_note ? <small>{item.item_note}</small> : null}</span>
                  <b>{foodMoney(Number(item.unit_price) * item.quantity)}</b>
                </div>
              );
            })}
          </div>
          <div className="fx-summary">
            <div><span>ค่าอาหาร</span><b>{foodMoney(order.subtotal)}</b></div>
            <div><span>ค่าจัดส่ง</span><b>{foodMoney(order.delivery_fee)}</b></div>
            {Number(order.campaign_discount ?? 0) > 0 ? <div className="is-discount"><span>{order.campaign_name ? "ส่วนลด · " + order.campaign_name : "ส่วนลดแคมเปญ"}</span><b>−{foodMoney(order.campaign_discount)}</b></div> : null}
            {Number(order.delivery_discount ?? 0) > 0 ? <div className="is-discount"><span>ส่วนลดค่าส่ง</span><b>−{foodMoney(order.delivery_discount)}</b></div> : null}
            <div className="is-total"><span>ยอดรวม</span><b>{foodMoney(order.total)}</b></div>
            <div><span>การชำระเงิน</span><b className={`fx-pay-state is-${order.payment_status}`}>{foodPaymentStatusLabel(order.payment_status)}</b></div>
          </div>
        </section>

        <section className="fx-order-block">
          <div className="fx-section-head"><h2>จัดส่งไปที่</h2></div>
          <div className="fx-delivery-to"><MapPin size={20} fill="currentColor" strokeWidth={0} /><div><strong>{order.recipient_name}</strong><small>{order.recipient_phone}</small><p>{order.shipping_address}</p>{order.customer_note ? <em>{order.customer_note}</em> : null}</div></div>
          {orderStore?.phone ? <a className="fx-btn fx-btn--outline fx-btn--block" href={`tel:${orderStore.phone}`}><Phone size={17} />ติดต่อร้าน</a> : null}
        </section>

        {["delivered", "cancelled"].includes(order.status) ? (
          <button className="fx-btn fx-btn--primary fx-btn--block" type="button" onClick={onReorder}>สั่งรายการเดิมอีกครั้ง</button>
        ) : null}
        {canCancel ? <button className="fx-btn fx-btn--danger-outline fx-btn--block" type="button" disabled={combinedBusy} onClick={() => void cancel()}>ยกเลิกออเดอร์</button> : null}
      </div>
    </Sheet>
  );
}

function FoodCustomerInner({
  client,
  userId,
  signOut,
}: {
  client: SupabaseClient;
  userId: string;
  signOut: () => Promise<void>;
}) {
  const [snapshot, setSnapshot] = useState<FoodCustomerSnapshot | null>(null);
  const [loadError, setLoadError] = useState("");
  // WYN-207: the store picked from the directory (remembered on this device).
  const storeKey = `wynos-food-store-v1:${userId}`;
  // A shared link (?store=, or one kept across sign-in) wins over the pick
  // remembered on this device. Opening another store empties the cart, the
  // same as picking a different store from the directory.
  const [opening] = useState(() => {
    if (typeof window === "undefined") return { storeId: "", fromLink: false, cartCleared: false };
    let remembered = "";
    try { remembered = localStorage.getItem(storeKey) ?? ""; } catch { /* private mode */ }
    const shared = sharedFoodStoreId(window.location.search) ?? pendingSharedFoodStore();
    if (!shared) return { storeId: remembered, fromLink: false, cartCleared: false };
    let hasCart = false;
    try {
      const saved = JSON.parse(localStorage.getItem(`wynos-food-cart-v1:${userId}`) ?? "[]");
      hasCart = Array.isArray(saved) && saved.length > 0;
    } catch { /* unreadable cart is treated as empty */ }
    return { storeId: shared, fromLink: true, cartCleared: hasCart && shared !== remembered };
  });
  const pickedStoreRef = useRef<string>(opening.storeId);
  useEffect(() => {
    if (!opening.fromLink) return;
    clearSharedFoodStore();
    rememberShareRef(opening.storeId);
    try { localStorage.setItem(storeKey, opening.storeId); } catch { /* private mode */ }
    // Drop ?store= so a later pick from the directory survives a reload.
    const url = new URL(window.location.href);
    if (url.searchParams.has("store")) {
      url.searchParams.delete("store");
      window.history.replaceState(window.history.state, "", `${url.pathname}${url.search}${url.hash}`);
    }
  }, [opening, storeKey]);
  const [tab, setTab] = useState<FoodTab>("home");
  const [storefrontOpen, setStorefrontOpen] = useState(() => opening.fromLink && Boolean(opening.storeId));
  // Bring an anonymous basket into the signed-in cart only for the store the
  // customer explicitly selected. All actual prices/availability are still
  // validated server-side when the customer submits an order.
  const [guestBasket] = useState(() => readGuestFoodBasket());
  const [cart, setCart] = useState<FoodCartLine[]>(() => {
    if (guestBasket?.storeId === opening.storeId && guestBasket.lines.length) return guestBasket.lines;
    if (typeof window === "undefined" || opening.cartCleared) return [];
    try {
      const raw = localStorage.getItem(`wynos-food-cart-v1:${userId}`);
      const parsed = raw ? JSON.parse(raw) : [];
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  });
  const [selectedItem, setSelectedItem] = useState<FoodCustomerMenuItem | null>(null);
  const [selectedOrder, setSelectedOrder] = useState<FoodCustomerOrder | null>(null);
  // A tapped order notification (?order=WF0015) opens that order once loaded.
  const requestedOrderRef = useRef<string | null>(typeof window === "undefined" ? null : requestedOrderNumber(window.location.search));
  const [reviewOrder, setReviewOrder] = useState<FoodCustomerOrder | null>(null);
  const [checkoutOpen, setCheckoutOpen] = useState(false);
  const [quote, setQuote] = useState<FoodOrderQuote | null>(null);
  const [addressDraft, setAddressDraft] = useState<FoodAddressDraft | null>(null);
  const [message, setMessage] = useState(() => opening.cartCleared ? "เปิดร้านจากลิงก์ที่แชร์ ตะกร้าเดิมถูกล้างแล้ว" : "");
  const [busy, setBusy] = useState(false);
  const [, setRefreshing] = useState(false);
  const [loadingMoreOrders, setLoadingMoreOrders] = useState(false);
  const [installPrompt, setInstallPrompt] = useState<InstallPromptEvent | null>(null);
  const [notificationsEnabled, setNotificationsEnabled] = useState(false);
  const [favoritesOpen, setFavoritesOpen] = useState(false);
  const loadingRef = useRef(false);
  const previousOrdersRef = useRef<Map<string, string>>(new Map());

  const load = useCallback(async (quiet = false) => {
    if (loadingRef.current) return null;
    loadingRef.current = true;
    if (quiet) setRefreshing(true);
    try {
      const next = await fetchFoodCustomerSnapshot(client, userId, pickedStoreRef.current || null);
      setLoadError("");
      if (!next.allowed) {
        setSnapshot(next);
        return next;
      }

      const previous = previousOrdersRef.current;
      for (const order of next.orders) {
        const prior = previous.get(order.id);
        if (prior && prior !== order.status) {
          setMessage(`ออเดอร์ #${order.order_number} · ${foodOrderStatusLabel(order.status)}`);
          // The backend already emits a Food-scoped Web Push for order events.
          // Keep the in-app toast here, but do not show a second local banner.
        }
      }
      previousOrdersRef.current = new Map(next.orders.map((order) => [order.id, order.status]));

      setSnapshot(next);
      const requested = requestedOrderRef.current;
      const requestedOrder = requested ? next.orders.find((order) => order.order_number === requested) ?? null : null;
      if (requested) {
        requestedOrderRef.current = null;
        clearRequestedOrder();
      }
      if (requestedOrder) {
        setTab("orders");
        setSelectedOrder(requestedOrder);
      } else {
        setSelectedOrder((current) => current ? next.orders.find((order) => order.id === current.id) ?? null : null);
      }
      return next;
    } catch (error) {
      const copy = foodCustomerError(error, "โหลด WYNOS Food ไม่สำเร็จ");
      setLoadError(copy);
      setMessage(copy);
      return null;
    } finally {
      loadingRef.current = false;
      setRefreshing(false);
    }
  }, [client, userId]);

  useEffect(() => {
    const timer = window.setTimeout(() => void load(), 0);
    return () => window.clearTimeout(timer);
  }, [load]);

  useEffect(() => {
    let live = true;
    if (!snapshot?.store || !cart.length) {
      const timer = window.setTimeout(() => {
        if (live) setQuote(null);
      }, 0);
      return () => {
        live = false;
        window.clearTimeout(timer);
      };
    }

    const timer = window.setTimeout(() => {
      void quoteFoodCustomerOrder(client, snapshot.store!.id, cart)
        .then((next) => { if (live) setQuote(next); })
        .catch(() => { if (live) setQuote(null); });
    }, 180);

    return () => {
      live = false;
      window.clearTimeout(timer);
    };
  }, [cart, client, snapshot?.store]);

  useEffect(() => {
    try {
      localStorage.setItem(`wynos-food-cart-v1:${userId}`, JSON.stringify(cart));
    } catch {
      // Private/locked-down storage: cart remains available for this session.
    }
  }, [cart, userId]);

  useEffect(() => {
    if (guestBasket?.storeId === opening.storeId) clearGuestFoodBasket();
  }, [guestBasket, opening.storeId]);

  useEffect(() => {
    if (!snapshot?.allowed) return;
    const channel = subscribeFoodCustomerOrders(client, userId, () => void load(true));
    return () => { void client.removeChannel(channel); };
  }, [client, load, snapshot?.allowed, userId]);

  useEffect(() => {
    let live = true;
    void isCurrentDevicePushEnabled(client, userId).then((enabled) => {
      if (live && enabled != null) setNotificationsEnabled(enabled);
    });
    return () => { live = false; };
  }, [client, userId]);

  useEffect(() => {
    const handler = (event: Event) => {
      event.preventDefault();
      setInstallPrompt(event as InstallPromptEvent);
    };
    window.addEventListener("beforeinstallprompt", handler);
    return () => window.removeEventListener("beforeinstallprompt", handler);
  }, []);

  const menu = snapshot?.menu ?? [];
  const orders = snapshot?.orders ?? [];
  const addresses = snapshot?.addresses ?? [];
  const ownReviews = useMemo(() => snapshot?.ownReviews ?? [], [snapshot?.ownReviews]);
  const reviewedOrderIds = useMemo(() => new Set(ownReviews.map((review) => review.order_id)), [ownReviews]);
  const store = snapshot?.store ?? null;
  const cartCount = cart.reduce((sum, line) => sum + line.quantity, 0);
  const cartSubtotal = cart.reduce((sum, line) => {
    const item = itemFor(menu, line.menu_item_id);
    return sum + (item ? foodCartLineUnitPrice(item, line) * line.quantity : 0);
  }, 0);
  const activeCount = orders.filter((order) => !["delivered", "cancelled"].includes(order.status)).length;
  const primaryAddress = addresses.find((address) => address.is_default) ?? addresses[0] ?? null;
  const homeLocationLabel = primaryAddress?.place_name || primaryAddress?.label || "เลือกที่อยู่จัดส่ง";

  const addItem = (line: FoodCartLine, replaceKey?: string) => {
    setCart((current) => {
      const item = itemFor(menu, line.menu_item_id);
      const limit = item ? foodMenuQuantityLimit(item) : 99;
      if (replaceKey) {
        const otherQuantity = current.reduce((sum, row) => sum + (row.menu_item_id === line.menu_item_id && foodCartLineKey(row) !== replaceKey ? row.quantity : 0), 0);
        const lineLimit = Math.max(0, limit - otherQuantity);
        if (lineLimit <= 0) return current;
        return current.map((row) => foodCartLineKey(row) === replaceKey ? { ...line, quantity: Math.min(line.quantity, lineLimit) } : row);
      }
      const usedQuantity = current.reduce((sum, row) => sum + (row.menu_item_id === line.menu_item_id ? row.quantity : 0), 0);
      const remaining = Math.max(0, limit - usedQuantity);
      if (remaining <= 0) return current;
      const normalized = { ...line, quantity: Math.max(1, Math.min(line.quantity, remaining)) };
      const key = foodCartLineKey(normalized);
      const index = current.findIndex((row) => foodCartLineKey(row) === key);
      if (index < 0) return [...current, normalized];
      return current.map((row, rowIndex) => rowIndex === index
        ? { ...row, quantity: Math.min(remaining + row.quantity, row.quantity + normalized.quantity) }
        : row);
    });
    setSelectedItem(null);
    setTab("home");
    setStorefrontOpen(true);
  };

  const loadMoreOrders = async () => {
    if (!snapshot?.has_more_orders || loadingMoreOrders) return;
    setLoadingMoreOrders(true);
    try {
      const page = await fetchFoodCustomerOrdersPage(client, userId, orders.length);
      setSnapshot((current) => current ? {
        ...current,
        orders: [...current.orders, ...page.orders.filter((order) => !current.orders.some((row) => row.id === order.id))],
        has_more_orders: page.hasMore,
      } : current);
    } catch (error) {
      setMessage(foodCustomerError(error, "โหลดคำสั่งซื้อเพิ่มเติมไม่สำเร็จ"));
    } finally {
      setLoadingMoreOrders(false);
    }
  };

  const saveAddress = async (draft: FoodAddressDraft) => {
    setBusy(true);
    try {
      await saveFoodCustomerAddress(client, draft);
      try { window.localStorage.removeItem(WYNOS_MAPS_PIN_STORAGE_KEY); } catch { /* private mode */ }
      setMessage("บันทึกที่อยู่แล้ว");
      setAddressDraft(null);
      await load(true);
    } catch (error) {
      setMessage(foodCustomerError(error));
    } finally {
      setBusy(false);
    }
  };

  const deleteAddress = async (id: string) => {
    if (!window.confirm("ลบที่อยู่นี้?")) return;
    setBusy(true);
    try {
      await deleteFoodCustomerAddress(client, id);
      setMessage("ลบที่อยู่แล้ว");
      await load(true);
    } catch (error) {
      setMessage(foodCustomerError(error));
    } finally {
      setBusy(false);
    }
  };

  // Founder decision (2026-10-10): WYNOS Food offers delivery as soon as possible only; no scheduled orders and no pickup.
  const createOrder = async (address: FoodCustomerAddress, note: string, couponCode?: string | null) => {
    if (!store) return;
    setBusy(true);
    try {
      const structuredAddress = [
        address.building_name ? `อาคาร/หมู่บ้าน ${address.building_name}` : "",
        address.floor ? `ชั้น ${address.floor}` : "",
        address.room ? `ห้อง ${address.room}` : "",
        address.landmark ? `จุดสังเกต ${address.landmark}` : "",
      ].filter(Boolean).join(" · ");
      const combinedNote = [structuredAddress, address.delivery_note, note.trim()].filter(Boolean).join(" · ");
      const orderId = await createFoodCustomerOrder(client, store.id, {
        recipientName: address.recipient_name,
        recipientPhone: address.recipient_phone,
        shippingAddress: address.address,
        customerNote: combinedNote,
        items: cart,
        location: storeHasDeliveryZone(store) ? addressLocation(address) : null,
        scheduledFor: null,
        couponCode: couponCode ?? null,
      });
      // Lets the store see orders that came from its shared link.
      if (hasShareRef(store.id)) void markFoodOrderFromShare(client, orderId).catch(() => undefined);
      setCart([]);
      setCheckoutOpen(false);
      const next = await load(true);
      const order = next?.orders.find((row) => row.id === orderId);
      if (order) setSelectedOrder(order);
      setTab("orders");
      setMessage("สร้างออเดอร์แล้ว กรุณาชำระเงินภายใน 10 นาที");
    } catch (error) {
      setMessage(foodCustomerError(error));
    } finally {
      setBusy(false);
    }
  };

  const requestNotifications = async () => {
    const result = await subscribeToPushNotifications(client, userId);
    setNotificationsEnabled(result.ok);
    setMessage(result.ok ? "เปิดการแจ้งเตือน WYNOS Food แล้ว" : pushReasonDescription(result.reason));
  };

  const install = async () => {
    if (!installPrompt) return;
    await installPrompt.prompt();
    await installPrompt.userChoice;
    setInstallPrompt(null);
  };

  // WYN-201: pull down to refresh the store, menu and orders.
  const pickStore = (next: FoodDirectoryStore, placement: "home" | "search") => {
    if (next.is_ad) void recordFoodAdClick(client, next.id, placement).catch(() => undefined);
    if (next.id === store?.id) {
      setStorefrontOpen(true);
      window.scrollTo({ top: 0, behavior: "smooth" });
      return;
    }
    if (cart.length && !window.confirm(`เปลี่ยนไปร้าน “${next.name}”? ตะกร้าเดิมจะถูกล้าง`)) return;
    if (cart.length) setCart([]);
    pickedStoreRef.current = next.id;
    try { localStorage.setItem(storeKey, next.id); } catch { /* private mode */ }
    window.scrollTo({ top: 0, behavior: "smooth" });
    void load(true).then((nextSnapshot) => {
      if (nextSnapshot?.store?.id === next.id) setStorefrontOpen(true);
    });
  };
  const shareStore = () => {
    if (!store) return;
    void shareOrCopyLink(foodStoreShareData(store), setMessage);
  };
  // Rebuilds the cart from a past order. Prices, stock and options are checked again in the cart and on the server.
  const reorder = (order: FoodCustomerOrder) => {
    const lines: FoodCartLine[] = (order.food_order_items ?? [])
      .filter((row) => row.menu_item_id)
      .map((row) => ({
        menu_item_id: row.menu_item_id!,
        quantity: row.quantity,
        note: row.item_note ?? "",
        selected_options: Array.isArray(row.selected_options) ? row.selected_options : [],
      }));
    if (!lines.length) {
      setMessage("ไม่พบเมนูเดิมของออเดอร์นี้");
      return;
    }
    if (cart.length && !window.confirm("แทนที่รายการในตะกร้าเดิมด้วยออเดอร์นี้?")) return;
    setSelectedOrder(null);
    if (order.store_id === store?.id) {
      setCart(lines);
      setTab("cart");
      return;
    }
    pickedStoreRef.current = order.store_id;
    try { localStorage.setItem(storeKey, order.store_id); } catch { /* private mode */ }
    void load(true).then((nextSnapshot) => {
      if (nextSnapshot?.store?.id === order.store_id) {
        setCart(lines);
        setTab("cart");
      } else {
        setMessage("ร้านนี้ยังไม่เปิดให้สั่งในตอนนี้");
      }
    });
  };
  const openStoreOrDirectory = () => {
    setTab("home");
    setStorefrontOpen(Boolean(store));
    window.scrollTo({ top: 0, behavior: "smooth" });
  };
  const openDirectory = () => {
    setTab("home");
    setStorefrontOpen(false);
    window.scrollTo({ top: 0, behavior: "smooth" });
  };
  const pull = usePullToRefresh({ enabled: tab === "home" || tab === "orders", onRefresh: async () => { await load(true); } });

  if (!snapshot) return loadError ? <FoodLoadError message={loadError} onRetry={() => { setLoadError(""); void load(); }} /> : <FoodLoading />;
  if (!snapshot.allowed) return <FoodDenied />;
  return (
    <main className={`wyn-food fx-app${tab === "home" && storefrontOpen ? " fx-storefront-open" : ""}${tab === "home" && storefrontOpen && cartCount > 0 ? " has-cart-bar" : ""}`}>
      {tab === "home" && !storefrontOpen ? (
        <FoodHeader
          cartCount={cartCount}
          homeLocationLabel={homeLocationLabel}
          onCart={() => setTab("cart")}
          onLocation={() => setTab("account")}
          onFavorites={() => setFavoritesOpen(true)}
        />
      ) : null}
      {message ? <div className="fx-toast" role="status"><span>{message}</span><button type="button" aria-label="ปิด" onClick={() => setMessage("")}><X size={16} /></button></div> : null}

      <PullToRefreshIndicator pull={pull} topOffset="0px" refreshingLabel="กำลังอัปเดต WYNOS Food" />
      <section className="fx-content" onTouchStart={pull.onTouchStart} onTouchMove={pull.onTouchMove} onTouchEnd={pull.onTouchEnd} onTouchCancel={pull.onTouchCancel}>
        {tab === "home" && !storefrontOpen && <FoodPromotionCenter client={client} userId={userId} />}
        {tab === "home" ? (
          <HomePanel
            key={`${store?.id ?? "none"}:${storefrontOpen ? "open" : "directory"}`}
            client={client}
            userId={userId}
            store={store}
            menu={menu}
            onItem={setSelectedItem}
            onPickStore={pickStore}
            onShareStore={shareStore}
            onBackStorefront={() => {
              setStorefrontOpen(false);
              window.scrollTo({ top: 0, behavior: "smooth" });
            }}
            storefrontOpen={storefrontOpen}
            orders={orders}
            addresses={addresses}
            onLocation={() => setTab("account")}
          />
        ) : null}
        {tab === "orders" ? <OrdersPanel orders={orders} reviewedOrderIds={reviewedOrderIds} hasMore={snapshot.has_more_orders} loadingMore={loadingMoreOrders} onLoadMore={() => void loadMoreOrders()} onOrder={setSelectedOrder} onReorder={reorder} onBrowse={openDirectory} /> : null}
        {tab === "messages" ? <MessagesPanel /> : null}
        {tab === "cart" ? <CartPanel client={client} store={store} menu={menu} cart={cart} quote={quote} onCart={setCart} onCheckout={() => setCheckoutOpen(true)} onBack={openStoreOrDirectory} onBrowse={cart.length ? openStoreOrDirectory : openDirectory} /> : null}
        {tab === "account" ? (
          <AccountPanel
            addresses={addresses}
            installPrompt={installPrompt}
            notificationsEnabled={notificationsEnabled}
            onAddAddress={() => setAddressDraft({ ...EMPTY_ADDRESS, isDefault: addresses.length === 0 })}
            onEditAddress={(address) => setAddressDraft({
              id: address.id,
              label: address.label,
              recipientName: address.recipient_name,
              recipientPhone: address.recipient_phone,
              address: address.address,
              addressLine1: address.address_line1 ?? address.address,
              moo: address.moo ?? "",
              soi: address.soi ?? "",
              road: address.road ?? "",
              subdistrict: address.subdistrict ?? "",
              district: address.district ?? "",
              province: address.province ?? "",
              postalCode: address.postal_code ?? "",
              deliveryNote: address.delivery_note ?? "",
              placeId: address.place_id ?? null,
              placeName: address.place_name ?? "",
              buildingName: address.building_name ?? "",
              floor: address.floor ?? "",
              room: address.room ?? "",
              landmark: address.landmark ?? "",
              isDefault: address.is_default,
              location: addressLocation(address),
            })}
            onDeleteAddress={(id) => void deleteAddress(id)}
            onInstall={() => void install()}
            onNotifications={() => void requestNotifications()}
            onSignOut={() => void signOut()}
            onOrders={() => setTab("orders")}
          />
        ) : null}
      </section>

      {tab === "home" && storefrontOpen && cartCount > 0 ? (
        <button className="fx-cart-bar" type="button" onClick={() => setTab("cart")} aria-label={`ดูตะกร้า ${cartCount} รายการ ${foodMoney(cartSubtotal)}`}>
          <span className="fx-cart-bar-count">{cartCount > 99 ? "99+" : cartCount}</span>
          <span className="fx-cart-bar-label">ดูตะกร้า</span>
          <b>{foodMoney(cartSubtotal)}</b>
        </button>
      ) : null}

      <FoodNav
        tab={tab}
        activeCount={activeCount}
        onTab={(next) => {
          if (next === "home") setStorefrontOpen(false);
          setTab(next);
        }}
      />

      {favoritesOpen ? (
        <FavoriteStoresSheet
          client={client}
          userId={userId}
          onClose={() => setFavoritesOpen(false)}
          onPick={(favoriteStore) => {
            setFavoritesOpen(false);
            pickStore(favoriteStore, "home");
          }}
        />
      ) : null}

      {selectedItem && store ? (
        <ItemSheet
          client={client}
          item={selectedItem}
          existing={(selectedItem.options?.length ?? 0) > 0 ? null : cart.find((line) => line.menu_item_id === selectedItem.id) ?? null}
          cartQuantity={cart.reduce((sum, line) => sum + (line.menu_item_id === selectedItem.id ? line.quantity : 0), 0)}
          storeOpen={foodStoreIsEffectivelyOpen(store)}
          storeStatus={foodStoreStatusText(store)}
          onClose={() => setSelectedItem(null)}
          onAdd={addItem}
        />
      ) : null}

      {checkoutOpen && store ? (
        <CheckoutSheet
          client={client}
          store={store}
          menu={menu}
          cart={cart}
          addresses={addresses}
          quote={quote}
          busy={busy}
          onClose={() => setCheckoutOpen(false)}
          onAddAddress={() => setAddressDraft({ ...EMPTY_ADDRESS, isDefault: addresses.length === 0 })}
          onEditAddress={(address) => setAddressDraft({
            id: address.id,
            label: address.label,
            recipientName: address.recipient_name,
            recipientPhone: address.recipient_phone,
            address: address.address,
            addressLine1: address.address_line1 ?? address.address,
            moo: address.moo ?? "",
            soi: address.soi ?? "",
            road: address.road ?? "",
            subdistrict: address.subdistrict ?? "",
            district: address.district ?? "",
            province: address.province ?? "",
            postalCode: address.postal_code ?? "",
            deliveryNote: address.delivery_note ?? "",
            placeId: address.place_id ?? null,
            placeName: address.place_name ?? "",
            buildingName: address.building_name ?? "",
            floor: address.floor ?? "",
            room: address.room ?? "",
            landmark: address.landmark ?? "",
            isDefault: address.is_default,
            location: addressLocation(address),
          })}
          onSubmit={(address, note, couponCode) => void createOrder(address, note, couponCode)}
        />
      ) : null}

      {addressDraft ? (
        <AddressEditor client={client} storeId={store?.id ?? null} showPin={true} draft={addressDraft} busy={busy} onClose={() => setAddressDraft(null)} onSave={(draft) => void saveAddress(draft)} />
      ) : null}

      {reviewOrder ? (
        <ReviewSheet
          client={client}
          order={reviewOrder}
          onClose={() => setReviewOrder(null)}
          onSubmitted={async () => { setReviewOrder(null); await load(true); setTab("orders"); }}
          onMessage={setMessage}
        />
      ) : null}

      {selectedOrder ? (
        <OrderDetailSheet
          client={client}
          userId={userId}
          store={store}
          order={selectedOrder}
          busy={busy}
          ownReview={ownReviews.find((review) => review.order_id === selectedOrder.id) ?? null}
          onClose={() => setSelectedOrder(null)}
          onReview={() => { setReviewOrder(selectedOrder); setSelectedOrder(null); }}
          onReload={async () => { await load(true); }}
          onMessage={setMessage}
          onReorder={() => reorder(selectedOrder)}
        />
      ) : null}
    </main>
  );
}

export function WynosFoodDeveloperApp() {
  const client = useMemo(() => getSupabaseBrowserClient(), []);
  const [signedIn, setSignedIn] = useState<boolean | null>(null);

  // A signed-out visitor can see only the public, published catalogue.
  // Do not relax the authenticated gate for orders, payment, addresses,
  // notifications or any other WYNOS product.
  useEffect(() => {
    if (!client) return;
    let live = true;
    let newerAuthEvent = false;
    const { data: { subscription } } = client.auth.onAuthStateChange((event, session) => {
      if (!live || event === "INITIAL_SESSION") return;
      newerAuthEvent = true;
      setSignedIn(Boolean(session));
    });
    void client.auth.getSession().then(({ data }) => {
      if (live && !newerAuthEvent) setSignedIn(Boolean(data.session));
    }).catch(() => {
      if (live && !newerAuthEvent) setSignedIn(false);
    });
    return () => { live = false; subscription.unsubscribe(); };
  }, [client]);

  // Keep shared store deep links through a login/Google OAuth round trip.
  useLayoutEffect(() => {
    const shared = sharedFoodStoreId(window.location.search);
    if (shared) rememberSharedFoodStore(shared);
  }, []);

  if (!client) return <FoodDenied />;
  if (signedIn === null) return <FoodLoading />;
  if (!signedIn) return <FoodGuestBrowse client={client} />;
  return (
    <DeveloperRouteGate signedOutPath="/food/login" afterSignOutPath="/food/login">
      {({ client, userId, signOut }) => <FoodCustomerInner key={userId} client={client} userId={userId} signOut={signOut} />}
    </DeveloperRouteGate>
  );
}
