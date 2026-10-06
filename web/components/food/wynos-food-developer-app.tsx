"use client";

import {
  ArrowLeft,
  Bell,
  Bike,
  CalendarDays,
  Check,
  ChevronRight,
  Clock3,
  Home,
  Heart,
  MapPin,
  MessageCircle,
  Minus,
  PackageCheck,
  Phone,
  Plus,
  ReceiptText,
  Search,
  Share2,
  ShoppingBag,
  Store,
  Trash2,
  Upload,
  UserRound,
  UtensilsCrossed,
  X,
  LocateFixed,
  LogOut,
  Star,
} from "lucide-react";
import type { SupabaseClient } from "@supabase/supabase-js";
import Link from "next/link";
import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { FoodDeliveryMapPicker } from "@/components/food/food-delivery-map-picker";
import { PullToRefreshIndicator } from "@/components/ui/pull-to-refresh-indicator";
import { rememberFoodArea } from "@/lib/food-area-memory";
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
  checkFoodServiceArea,
  checkFoodDeliveryAvailability,
  currentFoodLocation,
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
    return {
      ...draft,
      location: { latitude, longitude },
      placeId: place?.placeId ?? null,
      placeName: place?.name ?? "",
      address: draft.address.trim() || !place
        ? draft.address
        : [place.name, place.address].filter(Boolean).join(" "),
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
    <main className="wf-loading" aria-label="กำลังโหลด WYNOS Food">
      <div className="wf-loader" />
      <strong>WYNOS Food</strong>
    </main>
  );
}

function FoodDenied() {
  return (
    <main className="wyn-food wf-area">
      <section className="wf-area-card">
        <span className="wf-area-icon"><UtensilsCrossed size={30} /></span>
        <h1>ยังเข้าใช้ WYNOS Food ไม่ได้</h1>
        <p>บัญชีนี้ยังไม่ผ่านเงื่อนไขการใช้งาน WYNOS Food หรือเซสชันหมดอายุ กรุณาเข้าสู่ระบบอีกครั้ง</p>
        <Link className="wf-primary" href="/food/login">เข้าสู่ระบบ WYNOS Food</Link>
        <a className="wf-area-home" href="https://wynos.online/">กลับ WYNOS</a>
      </section>
    </main>
  );
}

function FoodLoadError({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <main className="wyn-food wf-area">
      <section className="wf-area-card" role="alert">
        <span className="wf-area-icon"><UtensilsCrossed size={30} /></span>
        <h1>โหลด WYNOS Food ไม่สำเร็จ</h1>
        <p>{message}</p>
        <button className="wf-primary" type="button" onClick={onRetry}>ลองใหม่</button>
        <a className="wf-area-home" href="https://wynos.online/">กลับ WYNOS</a>
      </section>
    </main>
  );
}

type FoodAreaState = "checking" | "inside" | "outside" | "unknown";

/** WYN-211: what customers outside Maha Sarakham (or without a location) see. */
function FoodServiceAreaIntro({
  client,
  state,
  onCheck,
  onUseLocation,
}: {
  client: SupabaseClient;
  state: FoodAreaState;
  onCheck: (location: FoodLocation) => void;
  onUseLocation: () => void;
}) {
  const [picking, setPicking] = useState(false);
  if (state === "checking") return <FoodLoading />;
  return (
    <main className="wyn-food wf-area">
      <section className="wf-area-card">
        <span className="wf-area-icon"><MapPin size={30} /></span>
        <h1>WYNOS Food เปิดให้บริการเฉพาะจังหวัดมหาสารคาม</h1>
        <p>
          {state === "outside"
            ? "ตำแหน่งของคุณอยู่นอกจังหวัดมหาสารคาม ตอนนี้ยังสั่งอาหารไม่ได้ เรากำลังขยายพื้นที่ให้บริการ"
            : "อนุญาตให้ใช้ตำแหน่ง หรือเลือกตำแหน่งบนแผนที่ เพื่อเช็กว่าคุณอยู่ในพื้นที่ให้บริการ"}
        </p>
        <button className="wf-primary" type="button" onClick={onUseLocation}><LocateFixed size={18} />ใช้ตำแหน่งปัจจุบัน</button>
        <button className="wf-secondary" type="button" onClick={() => setPicking(true)}><MapPin size={18} />เลือกตำแหน่งบนแผนที่</button>
        <a className="wf-area-home" href="https://wynos.online/">กลับหน้าหลัก</a>
      </section>
      {picking ? (
        <FoodDeliveryMapPicker
          client={client}
          storeId={null}
          initialLocation={null}
          onClose={() => setPicking(false)}
          onConfirm={(location) => { setPicking(false); onCheck(location); }}
        />
      ) : null}
    </main>
  );
}

function FoodHeader({
  cartCount,
  showBack,
  homeLocationLabel,
  onBack,
  onCart,
  onLocation,
  onFavorites,
  onRefresh,
  refreshing,
}: {
  cartCount: number;
  showBack: boolean;
  homeLocationLabel?: string;
  onBack: () => void;
  onCart: () => void;
  onLocation?: () => void;
  onFavorites?: () => void;
  onRefresh: () => void;
  refreshing: boolean;
}) {
  return (
    <header className={`wf-header${showBack ? "" : " wf-header--home"}`}>
      {showBack ? (
        <button className="wf-exit-button" type="button" aria-label="กลับหน้าหลัก WYNOS Food" onClick={onBack}>
          <ArrowLeft size={21} strokeWidth={2} />
        </button>
      ) : null}
      <div className="wf-brand-stack">
        <div className="wf-brand">
          <span>WYNOS</span>
          <b>Food</b>
        </div>
        {!showBack ? (
          <button className="wf-home-location" type="button" onClick={onLocation} aria-label="เลือกที่อยู่จัดส่ง">
            <MapPin size={16} fill="currentColor" />
            <small>จัดส่งที่</small>
            <strong>{homeLocationLabel || "เลือกที่อยู่จัดส่ง"}</strong>
            <ChevronRight size={15} />
          </button>
        ) : null}
      </div>
      <div className="wf-header-actions">
        {!showBack && onFavorites ? (
          <button className="wf-icon-button" type="button" aria-label="ร้านโปรด" onClick={onFavorites}>
            <Heart size={22} strokeWidth={1.9} />
          </button>
        ) : null}
        <button className="wf-icon-button wf-cart-button" type="button" aria-label={cartCount ? `ตะกร้า ${cartCount} รายการ` : "ตะกร้า"} onClick={onCart}>
          <ShoppingBag size={21} strokeWidth={1.9} />
          {cartCount ? <i>{cartCount > 9 ? "9+" : cartCount}</i> : null}
        </button>
        {showBack ? (
          <button className="wf-icon-button" type="button" aria-label="อัปเดตข้อมูล" onClick={onRefresh}>
            {refreshing ? <i className="wf-mini-loader" /> : <Clock3 size={21} strokeWidth={1.8} />}
          </button>
        ) : null}
      </div>
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
  return (
    <nav className="wf-nav" aria-label="WYNOS Food">
      <button type="button" className={tab === "home" ? "is-active" : ""} onClick={() => onTab("home")}>
        <span><Home /></span><small>หน้าหลัก</small>
      </button>
      <button type="button" className={tab === "orders" ? "is-active" : ""} onClick={() => onTab("orders")}>
        <span><ReceiptText />{activeCount ? <i>{activeCount > 9 ? "9+" : activeCount}</i> : null}</span><small>คำสั่งซื้อ</small>
      </button>
      <button type="button" className={tab === "messages" ? "is-active" : ""} onClick={() => onTab("messages")}>
        <span><MessageCircle /></span><small>ข้อความ</small>
      </button>
      <button type="button" className={tab === "account" ? "is-active" : ""} onClick={() => onTab("account")}>
        <span><UserRound /></span><small>โปรไฟล์</small>
      </button>
    </nav>
  );
}

function FoodStatus({ store }: { store: FoodCustomerStore }) {
  const open = foodStoreIsEffectivelyOpen(store);
  return (
    <span className={`wf-store-status ${open ? "is-open" : ""}`}>
      <i />{foodStoreStatusText(store)}
    </span>
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
    <span className={`wf-menu-image ${className}`}>
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

function FoodDirectoryStoreRow({
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
  const categories = Array.isArray(store.categories) ? store.categories.slice(0, 3) : [];
  const eta = foodEstimateDeliveryRange(store, distance);
  const promo = foodPromoLabel(store);
  const distanceLabel = distance == null
    ? "ดูระยะทางในร้าน"
    : distance < 0.1
      ? "ใกล้คุณ"
      : `${distance < 10 ? distance.toFixed(1) : Math.round(distance)} กม.`;
  return (
    <button className="wf-home-store-row" type="button" onClick={onPick}>
      <span className="wf-home-store-photo">
        {cover ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={cover} alt="" />
        ) : <UtensilsCrossed size={31} strokeWidth={1.4} />}
        {store.is_ad ? <b className="wf-ad-label">โฆษณา</b> : null}
      </span>
      <span className="wf-home-store-body">
        <span className="wf-home-store-head">
          <span className="wf-home-store-title">
            <strong>{store.name}</strong>
            <small>{store.address || (store.is_open ? "เปิดรับออเดอร์" : "ปิดอยู่")}</small>
          </span>
          <ChevronRight size={17} />
        </span>
        <span className="wf-home-store-quality">
          <span className="wf-home-rating">
            <Star size={13} fill="currentColor" />
            {rating > 0 ? rating.toFixed(1) : "ใหม่"}
            {ratingCount > 0 ? <small>({new Intl.NumberFormat("th-TH").format(ratingCount)})</small> : null}
          </span>
          {categories.length ? <span>{categories.join(" · ")}</span> : <span>อาหารและเครื่องดื่ม</span>}
        </span>
        <span className="wf-home-store-meta">
          <span><MapPin size={13} />{distanceLabel}</span>
          <span><Clock3 size={13} />{eta.min}–{eta.max} นาที</span>
          <span><Bike size={13} />ค่าส่ง {foodMoney(store.delivery_fee)}</span>
        </span>
        {promo ? <span className="wf-home-promo-badge">{promo}</span> : null}
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
    <button className="wf-recent-store" type="button" onClick={onPick}>
      <span>
        {cover ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={cover} alt="" />
        ) : <UtensilsCrossed size={30} strokeWidth={1.4} />}
      </span>
      <strong>{store.name}</strong>
    </button>
  );
}

function FoodHomeSectionHeader({ title, onAll }: { title: string; onAll?: () => void }) {
  return (
    <div className="wf-home-section-head">
      <h2>{title}</h2>
      {onAll ? <button type="button" onClick={onAll}>ดูทั้งหมด <ChevronRight size={15} /></button> : null}
    </div>
  );
}

function StoreDirectory({
  client,
  userId,
  orders,
  addresses,
  onPick,
  onMessage,
}: {
  client: SupabaseClient;
  userId: string;
  orders: FoodCustomerOrder[];
  addresses: FoodCustomerAddress[];
  onPick: (store: FoodDirectoryStore, placement: "home" | "search") => void;
  onMessage: (message: string) => void;
}) {
  const [query, setQuery] = useState("");
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

  const nearbyStores = [...directory].sort((a, b) => {
    const da = distanceFor(a);
    const db = distanceFor(b);
    if (da == null && db == null) return Number(b.is_open) - Number(a.is_open);
    if (da == null) return 1;
    if (db == null) return -1;
    return da - db;
  });
  const popularStores = [...directory].sort((a, b) => {
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
      <article className="wf-home-deal" key={store.id}>
        <span className="wf-home-deal-icon"><ReceiptText size={24} /></span>
        <span className="wf-home-deal-copy">
          <strong>{label}</strong>
          <small>{minimum > 0 ? `เมื่อสั่งครบ ${foodMoney(minimum)}` : store.promo_name}</small>
        </span>
        <button type="button" className={collected ? "is-collected" : ""} onClick={() => toggleCollected(store)}>
          {collected ? "เก็บแล้ว" : "เก็บโค้ด"}
        </button>
      </article>
    );
  };

  const row = (store: FoodDirectoryStore, placement: "home" | "search" = "home") => (
    <FoodDirectoryStoreRow
      key={store.id}
      client={client}
      store={store}
      distance={distanceFor(store)}
      onPick={() => onPick(store, placement)}
    />
  );

  if (!stores) return null;

  return (
    <section className="wf-directory wf-home-directory">
      <div className="wf-search wf-home-search">
        <Search size={20} strokeWidth={1.8} />
        <input
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder="ค้นหาร้านหรือเมนูอาหาร"
          aria-label="ค้นหาร้านหรือเมนูอาหาร"
          autoComplete="off"
        />
        {query ? <button type="button" aria-label="ล้างการค้นหา" onClick={() => setQuery("")}><X size={17} /></button> : null}
      </div>

      <div className="wf-fulfillment-tabs" aria-label="รูปแบบการรับอาหาร">
        <button type="button" className="is-active"><Bike size={15} />จัดส่ง</button>
        <button
          type="button"
          onClick={() => onMessage("รับเองที่ร้านกำลังเตรียมเปิดให้บริการ")}
          aria-label="รับเองที่ร้าน"
        ><Store size={15} />รับเองที่ร้าน</button>
      </div>

      {query.trim() ? (
        <section className="wf-home-search-results">
          <FoodHomeSectionHeader title="ผลการค้นหา" />
          {directory.length ? <div className="wf-home-store-list">{directory.map((store) => row(store, "search"))}</div> : <p className="wf-dir-empty">ไม่พบร้านหรือเมนูที่ค้นหา</p>}
        </section>
      ) : (
        <>
          <section className="wf-home-section">
            <FoodHomeSectionHeader title="รวมโค้ดลดเพิ่ม" onAll={() => setBrowse("promos")} />
            {promoStores.length ? (
              <div className="wf-home-deals">{promoStores.slice(0, 2).map(promoCard)}</div>
            ) : (
              <div className="wf-home-deals-empty"><ReceiptText size={20} /><span>ยังไม่มีโค้ดส่วนลดในตอนนี้</span></div>
            )}
          </section>

          <section className="wf-home-section">
            <FoodHomeSectionHeader title="ร้านที่เคยสั่งล่าสุด" onAll={() => setBrowse("recent")} />
            {recentStores.length ? (
              <div className="wf-recent-stores">
                {recentStores.slice(0, 4).map((store) => (
                  <FoodRecentStoreTile key={store.id} client={client} store={store} onPick={() => onPick(store, "home")} />
                ))}
              </div>
            ) : <p className="wf-home-empty">ร้านที่คุณสั่งครั้งแรกจะแสดงตรงนี้</p>}
          </section>

          <section className="wf-home-section">
            <FoodHomeSectionHeader title="ร้านค้าใกล้คุณ" onAll={() => setBrowse("nearby")} />
            <div className="wf-home-store-list">{nearbyStores.slice(0, 4).map((store) => row(store))}</div>
          </section>

          <section className="wf-home-section">
            <FoodHomeSectionHeader title="ร้านค้ายอดนิยม" onAll={() => setBrowse("popular")} />
            <div className="wf-home-store-list">{popularStores.slice(0, 4).map((store) => row(store))}</div>
          </section>
        </>
      )}

      {browse ? (
        <Sheet
          title={browse === "promos" ? "รวมโค้ดลดเพิ่ม" : browse === "recent" ? "ร้านที่เคยสั่งล่าสุด" : browse === "nearby" ? "ร้านค้าใกล้คุณ" : "ร้านค้ายอดนิยม"}
          onClose={() => setBrowse(null)}
        >
          {browse === "promos" ? (
            promoStores.length ? <div className="wf-home-deals wf-home-deals--sheet">{promoStores.map(promoCard)}</div> : <p className="wf-home-empty">ยังไม่มีโค้ดส่วนลดในตอนนี้</p>
          ) : browse === "recent" ? (
            recentStores.length ? <div className="wf-home-store-list">{recentStores.map((store) => row(store))}</div> : <p className="wf-home-empty">ยังไม่มีร้านที่เคยสั่ง</p>
          ) : browse === "nearby" ? (
            <div className="wf-home-store-list">{nearbyStores.map((store) => row(store))}</div>
          ) : (
            <div className="wf-home-store-list">{popularStores.map((store) => row(store))}</div>
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
                  <img src={logo} alt="" />
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
    void fetchFoodStoreReviewFeed(client, storeId, 20).then((next) => {
      if (live) setFeed(next);
    });
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
  onMessage,
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
  onMessage: (message: string) => void;
}) {
  const [category, setCategory] = useState("ทั้งหมด");
  const [searchOpen, setSearchOpen] = useState(false);
  const [storeSection, setStoreSection] = useState<"menu" | "reviews" | "info">("menu");
  const [campaigns, setCampaigns] = useState<string[]>([]);
  const [reviewSummary, setReviewSummary] = useState({ average: 0, count: 0 });
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
        if (live) setReviewSummary({ average: feed.average, count: feed.count });
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
  const visible = useMemo(
    () => menu.filter((item) => category === "ทั้งหมด" || item.category === category),
    [category, menu],
  );

  if (!storefrontOpen) {
    return (
      <>
        <a className="wf-social-promo" href="https://wynos.online/" aria-label="เปิด WYNOS Social">
          <span className="wf-social-promo-mark">W</span>
          <span className="wf-social-promo-copy">
            <strong>WYNOS Social</strong>
            <small>โพสต์ พูดคุย ติดตาม และค้นหาคอนเทนต์บน wynos.online</small>
          </span>
          <span className="wf-social-promo-action">เปิด <ChevronRight size={17} /></span>
        </a>
        <StoreDirectory
          client={client}
          userId={userId}
          orders={orders}
          addresses={addresses}
          onPick={onPickStore}
          onMessage={onMessage}
        />
        {!store ? (
          <div className="wf-empty">
            <Store size={40} strokeWidth={1.4} />
            <strong>ยังไม่มีร้านสำหรับ WYNOS Food</strong>
            <p>ร้านค้าสามารถสร้างและตั้งค่าร้านผ่าน WYNOS Merchant เพื่อเริ่มขายบน WYNOS Food</p>
          </div>
        ) : null}
      </>
    );
  }

  if (!store) {
    return (
      <div className="wf-empty">
        <Store size={40} strokeWidth={1.4} />
        <strong>ยังไม่มีร้านสำหรับ WYNOS Food</strong>
        <p>ร้านค้าสามารถสร้างและตั้งค่าร้านผ่าน WYNOS Merchant เพื่อเริ่มขายบน WYNOS Food</p>
      </div>
    );
  }

  const cover = foodPublicUrl(client, store.cover_path);
  const logo = foodPublicUrl(client, store.logo_path);
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

  return (
    <>
      <section className="wf-store-hero">
        <button className="wf-store-back" type="button" aria-label="กลับหน้าหลัก WYNOS Food" onClick={onBackStorefront}>
          <ArrowLeft size={22} strokeWidth={2} />
        </button>
        <div className="wf-store-actions">
          <button
            className={`wf-store-favorite ${favorite ? "is-active" : ""}`}
            type="button"
            aria-label="รายการโปรด"
            aria-pressed={favorite}
            onClick={toggleFavorite}
          >
            <Heart size={21} strokeWidth={2} fill={favorite ? "currentColor" : "none"} />
          </button>
          <button className="wf-store-share" type="button" aria-label={`แชร์ลิงก์ร้าน ${store.name}`} onClick={onShareStore}>
            <Share2 size={19} strokeWidth={2} />
          </button>
        </div>
        <div className="wf-store-cover">
          {cover ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={cover} alt="" decoding="async" fetchPriority="high" />
          ) : <Store size={46} strokeWidth={1.25} />}
        </div>
        <div className="wf-store-main">
          <span className="wf-store-logo">
            {logo ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={logo} alt="" decoding="async" />
            ) : <Store size={25} strokeWidth={1.45} />}
          </span>
          <div className="wf-store-copy">
            <div><h1>{store.name}</h1><FoodStatus store={store} /></div>
            {campaigns.length ? (
              <div className="wf-campaign-badges">{campaigns.map((name) => <span key={name}>{`แคมเปญ WYNOS · ${name}`}</span>)}</div>
            ) : null}
            {store.description ? <p>{store.description}</p> : null}
            <div className="wf-store-meta">
              {reviewSummary.count > 0 ? (
                <span className="wf-store-rating-summary">
                  <Star size={14} fill="currentColor" />
                  <strong>{reviewSummary.average.toFixed(1)}</strong>
                  <small>({new Intl.NumberFormat("th-TH").format(reviewSummary.count)} รีวิว)</small>
                </span>
              ) : null}
              {foodStoreTodayHoursText(store) ? <span><Clock3 size={14} />{foodStoreTodayHoursText(store)}</span> : store.business_hours ? <span><Clock3 size={14} />{store.business_hours}</span> : null}
              <span><Clock3 size={14} />เตรียมประมาณ {Number(store.prep_time_min_minutes ?? 15)}–{Number(store.prep_time_max_minutes ?? 30)} นาที</span>
              <span><MapPin size={14} />ค่าส่ง {foodMoney(store.delivery_fee)}</span>
              {Number(store.minimum_order) > 0 ? <span>ขั้นต่ำ {foodMoney(store.minimum_order)}</span> : null}
            </div>
          </div>
        </div>
      </section>

      <nav className="wf-store-tabs" aria-label="ข้อมูลร้าน">
        <button type="button" className={storeSection === "menu" ? "is-active" : ""} onClick={() => setStoreSection("menu")}>เมนู</button>
        <button type="button" className={storeSection === "reviews" ? "is-active" : ""} onClick={() => setStoreSection("reviews")}>รีวิวจากลูกค้า</button>
        <button type="button" className={storeSection === "info" ? "is-active" : ""} onClick={() => setStoreSection("info")}>ข้อมูลร้าน</button>
      </nav>

      {storeSection === "reviews" ? <StoreReviewsSection client={client} storeId={store.id} /> : null}

      {storeSection === "info" ? (
        <section className="wf-store-info">
          {store.description ? <p>{store.description}</p> : null}
          {store.address ? <div><MapPin size={18} /><span><small>ที่อยู่ร้าน</small><strong>{store.address}</strong></span></div> : null}
          {store.phone ? <a href={`tel:${store.phone}`}><Phone size={18} /><span><small>เบอร์ติดต่อ</small><strong>{store.phone}</strong></span></a> : null}
          {foodStoreTodayHoursText(store) || store.business_hours ? <div><Clock3 size={18} /><span><small>เวลาเปิด–ปิด</small><strong>{foodStoreTodayHoursText(store) || store.business_hours}</strong></span></div> : null}
          {store.delivery_area ? <div><MapPin size={18} /><span><small>พื้นที่จัดส่ง</small><strong>{store.delivery_area}</strong></span></div> : null}
        </section>
      ) : null}

      {storeSection === "menu" ? (
      <section className={`wf-store-menu ${category === "ทั้งหมด" ? "is-all" : "is-category"}`}>
      <div className="wf-menu-filter-bar">
        <button className="wf-menu-search-trigger" type="button" aria-label="ค้นหาเมนูอาหาร" onClick={() => setSearchOpen(true)}>
          <Search size={19} strokeWidth={1.85} />
        </button>
        <div className="wf-category-tabs">
          {categories.map((name) => (
            <button key={name} type="button" className={category === name ? "is-active" : ""} onClick={() => setCategory(name)}>
              {name}
            </button>
          ))}
        </div>
      </div>

      <div className="wf-section-title">
        <h2>{category === "ทั้งหมด" ? "เมนูแนะนำ" : category}</h2>
        <small>{visible.length} เมนู</small>
      </div>

      {visible.length ? (
        <div className="wf-menu-list">
          {visible.map((item) => {
            const available = foodMenuIsEffectivelyAvailable(item) && foodMenuQuantityLimit(item) > 0;
            return (
            <button key={item.id} type="button" className={`wf-menu-row ${available ? "" : "is-off"}`} onClick={() => onItem(item)}>
              <MenuImage client={client} item={item} />
              <span className="wf-menu-copy">
                <strong>{item.name}</strong>
                {item.description ? <small>{item.description}</small> : <small>{item.category}</small>}
                {item.remaining_stock != null
                  ? <small>เหลือ {Math.max(0, item.remaining_stock)} ชิ้นวันนี้</small>
                  : item.daily_stock_limit ? <small>จำนวนจำกัด · สูงสุด {item.daily_stock_limit} ชิ้น/วัน</small> : null}
                <b>{foodMoney(item.price)}</b>
              </span>
              <span className={available ? "wf-add" : "wf-soldout"}>
                {available ? <Plus size={18} /> : "หมดชั่วคราว"}
              </span>
            </button>
            );
          })}
        </div>
      ) : (
        <div className="wf-empty wf-empty--compact">
          <Search size={35} strokeWidth={1.4} />
          <strong>ไม่พบเมนู</strong>
        </div>
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
  store,
  menu,
  cart,
  quote,
  onCart,
  onCheckout,
}: {
  store: FoodCustomerStore | null;
  menu: FoodCustomerMenuItem[];
  cart: FoodCartLine[];
  quote: FoodOrderQuote | null;
  onCart: (cart: FoodCartLine[]) => void;
  onCheckout: () => void;
}) {
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

  return (
    <>
      <div className="wf-page-title">
        <div><small>รายการที่เลือก</small><h1>ตะกร้า</h1></div>
        {cart.length ? <button type="button" onClick={() => onCart([])}>ล้างทั้งหมด</button> : null}
      </div>

      {!cart.length ? (
        <div className="wf-empty">
          <ShoppingBag size={40} strokeWidth={1.4} />
          <strong>ตะกร้ายังว่าง</strong>
          <p>เลือกเมนูจากหน้าหลักเพื่อเริ่มออเดอร์</p>
        </div>
      ) : (
        <>
          <div className="wf-cart-list">
            {priced.map(({ line, item, key, unitPrice }) => {
              const limit = item ? foodMenuQuantityLimit(item) : 0;
              const totalMenuQuantity = quantityByMenu.get(line.menu_item_id) ?? line.quantity;
              const unavailable = !item || !foodMenuIsEffectivelyAvailable(item) || !foodCartLineOptionsValid(item, line) || limit <= 0 || totalMenuQuantity > limit;
              const optionText = foodCartLineOptionText(line, item);
              return (
                <article key={key} className={`wf-cart-row ${unavailable ? "is-off" : ""}`}>
                  <div className="wf-cart-copy">
                    <strong>{item?.name ?? "เมนูไม่พร้อมใช้งาน"}</strong>
                    {optionText ? <small>{optionText}</small> : null}
                    {line.note ? <small>หมายเหตุ · {line.note}</small> : null}
                    <b>{item ? foodMoney(unitPrice * line.quantity) : "—"}</b>
                    {unavailable ? <em>{limit <= 0 ? "เมนูนี้ขายครบสำหรับวันนี้แล้ว" : item && !foodCartLineOptionsValid(item, line) ? "ตัวเลือกเมนูเปลี่ยนแล้ว กรุณาเลือกใหม่" : "จำนวนหรือสถานะเมนูเปลี่ยนไป กรุณาปรับตะกร้า"}</em> : null}
                  </div>
                  <div className="wf-qty">
                    <button type="button" aria-label="ลดจำนวน" onClick={() => changeQuantity(key, -1)}>
                      {line.quantity === 1 ? <Trash2 size={15} /> : <Minus size={15} />}
                    </button>
                    <b>{line.quantity}</b>
                    <button type="button" aria-label="เพิ่มจำนวน" disabled={!item || totalMenuQuantity >= limit} onClick={() => changeQuantity(key, 1)}>
                      <Plus size={15} />
                    </button>
                  </div>
                </article>
              );
            })}
          </div>

          <div className="wf-summary">
            <div><span>ค่าอาหาร</span><b>{foodMoney(subtotal)}</b></div>
            {campaignDiscount > 0 ? <div className="is-discount"><span>{quote?.campaign_name ? "โปร · " + quote.campaign_name : "ส่วนลดแคมเปญ"}</span><b>−{foodMoney(campaignDiscount)}</b></div> : null}
            <div><span>ค่าส่ง</span><b>{foodMoney(delivery)}</b></div>
            {deliveryDiscount > 0 ? <div className="is-discount"><span>ส่วนลดค่าส่ง</span><b>−{foodMoney(deliveryDiscount)}</b></div> : null}
            <div className="is-total"><span>ยอดสุทธิ</span><b>{foodMoney(total)}</b></div>
          </div>
          {quote?.campaign_name ? <div className="wf-promo-applied"><strong>ใช้แคมเปญ {quote.campaign_name}</strong><small>WYNOS เลือกโปรที่ประหยัดที่สุดให้อัตโนมัติ</small></div> : null}

          {belowMinimum && store ? (
            <div className="wf-inline-warning">เพิ่มอีก {foodMoney(Math.max(0, minimum - subtotal))} เพื่อถึงยอดขั้นต่ำ {foodMoney(minimum)}</div>
          ) : null}
          {hasUnavailable ? <div className="wf-inline-warning">มีเมนูที่หมดหรือจำนวนเกินสต็อกวันนี้ กรุณาปรับตะกร้าก่อนชำระเงิน</div> : null}
          {store && !storeOpen ? <div className="wf-inline-warning">{foodStoreStatusText(store)}</div> : null}

          <button className="wf-primary wf-full" type="button" disabled={!canCheckout} onClick={onCheckout}>
            ไปชำระเงิน · {foodMoney(total)}
          </button>
        </>
      )}
    </>
  );
}

function OrdersPanel({
  orders,
  reviewedOrderIds,
  hasMore,
  loadingMore,
  onLoadMore,
  onOrder,
}: {
  orders: FoodCustomerOrder[];
  reviewedOrderIds: Set<string>;
  hasMore: boolean;
  loadingMore: boolean;
  onLoadMore: () => void;
  onOrder: (order: FoodCustomerOrder) => void;
}) {
  const active = orders.filter((order) => !["delivered", "cancelled"].includes(order.status));
  const history = orders.filter((order) => ["delivered", "cancelled"].includes(order.status));

  return (
    <>
      <div className="wf-page-title"><div><small>ติดตามและดูประวัติ</small><h1>คำสั่งซื้อ</h1></div></div>
      <div className="wf-section-title"><h2>กำลังดำเนินการ</h2><small>{active.length}</small></div>
      {active.length ? <div className="wf-order-list">{active.map((order) => <OrderCard key={order.id} order={order} onOpen={() => onOrder(order)} />)}</div> : (
        <div className="wf-empty wf-empty--compact"><PackageCheck size={36} strokeWidth={1.4} /><strong>ไม่มีออเดอร์ที่กำลังดำเนินการ</strong></div>
      )}
      <div className="wf-section-title wf-section-title--spaced"><h2>ประวัติ</h2><small>{history.length}</small></div>
      {history.length ? <div className="wf-order-list">{history.map((order) => <OrderCard key={order.id} order={order} reviewPending={order.status === "delivered" && !reviewedOrderIds.has(order.id)} onOpen={() => onOrder(order)} />)}</div> : null}
      {hasMore ? <button className="wf-secondary wf-full wf-load-more" type="button" disabled={loadingMore} onClick={onLoadMore}>{loadingMore ? "กำลังโหลด…" : "ดูคำสั่งซื้อเก่ากว่านี้"}</button> : null}
    </>
  );
}

function MessagesPanel() {
  return (
    <>
      <div className="wf-page-title">
        <div><small>WYNOS Food</small><h1>ข้อความ</h1></div>
      </div>
      <div className="wf-empty">
        <MessageCircle size={42} strokeWidth={1.35} />
        <strong>ยังไม่มีข้อความ</strong>
        <p>การสนทนากับร้านและผู้จัดส่งจะแสดงที่นี่</p>
        <p>แชท WYNOS Food แยกจากแชท WYNOS</p>
      </div>
    </>
  );
}

function OrderCard({ order, reviewPending = false, onOpen }: { order: FoodCustomerOrder; reviewPending?: boolean; onOpen: () => void }) {
  const count = order.food_order_items?.reduce((sum, item) => sum + item.quantity, 0) ?? 0;
  return (
    <button className="wf-order-card" type="button" onClick={onOpen}>
      <div className="wf-order-top">
        <span><strong>#{order.order_number}</strong><small>{formatDate(order.created_at)}</small></span>
        <b>{foodMoney(order.total)}</b>
      </div>
      <div className="wf-order-mid"><span>{count} รายการ</span><span className={`wf-order-status wf-order-status--${order.status}`}>{foodOrderStatusLabel(order.status)}</span></div>
      {order.scheduled_for ? <div className="wf-order-scheduled"><Clock3 size={14} /><span>นัดรับ/จัดส่ง</span><b>{formatDate(order.scheduled_for)}</b></div> : null}
      <div className="wf-order-bottom"><span className={reviewPending ? "wf-review-pending" : ""}>{reviewPending ? "ให้คะแนนร้าน" : foodPaymentStatusLabel(order.payment_status)}</span><ChevronRight size={18} /></div>
    </button>
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
}) {
  const primary = addresses.find((address) => address.is_default) ?? addresses[0] ?? null;
  const primaryLocation = addressLocation(primary);

  return (
    <>
      <div className="wf-page-title"><div><small>WYNOS Food</small><h1>โปรไฟล์</h1></div></div>

      <section className="wf-food-profile-card">
        <div className="wf-food-profile-head">
          <span><UserRound size={25} /></span>
          <div>
            <strong>โปรไฟล์ WYNOS Food</strong>
            <small>ข้อมูลสำหรับการสั่งและจัดส่งอาหารเท่านั้น</small>
          </div>
          <em>สำหรับ Food</em>
        </div>

        {primary ? (
          <>
            <div className="wf-food-profile-details">
              <div><span><UserRound size={17} /> ชื่อผู้รับ</span><strong>{primary.recipient_name}</strong></div>
              <div><span><Phone size={17} /> เบอร์โทร</span><strong>{primary.recipient_phone}</strong></div>
              <div><span><MapPin size={17} /> ที่อยู่หลัก</span><p>{primary.address}</p></div>
              <div><span><LocateFixed size={17} /> โลเคชั่น</span><strong className={primaryLocation ? "is-ready" : "is-missing"}>{primaryLocation ? "ปักหมุดแล้ว" : "ยังไม่ได้ปักหมุด"}</strong></div>
              {primary.delivery_note ? <div><span><Home size={17} /> รายละเอียดเพิ่มเติม</span><p>{primary.delivery_note}</p></div> : null}
            </div>
            <button className="wf-secondary wf-full" type="button" onClick={() => onEditAddress(primary)}>แก้ไขโปรไฟล์ WYNOS Food</button>
          </>
        ) : (
          <div className="wf-food-profile-empty">
            <MapPin size={32} strokeWidth={1.45} />
            <strong>ตั้งค่าโปรไฟล์ก่อนสั่งอาหาร</strong>
            <p>กรอกชื่อผู้รับ เบอร์โทร ที่อยู่ โลเคชั่น และรายละเอียดการจัดส่ง</p>
            <button className="wf-primary wf-full" type="button" onClick={onAddAddress}>ตั้งค่าโปรไฟล์ WYNOS Food</button>
          </div>
        )}
      </section>

      <div className="wf-section-title wf-section-title--spaced">
        <h2>ที่อยู่ของฉัน</h2>
        <button type="button" onClick={onAddAddress}><Plus size={15} /> เพิ่มที่อยู่</button>
      </div>
      {addresses.length ? (
        <div className="wf-address-list">
          {addresses.map((address) => (
            <article key={address.id} className="wf-address-row">
              <MapPin size={19} />
              <div>
                <strong>{address.label}{address.is_default ? " · ที่อยู่หลัก" : ""}</strong>
                <small>{address.recipient_name} · {address.recipient_phone}</small>
                <p>{address.address}</p>
                {[address.place_name, address.building_name, address.floor ? `ชั้น ${address.floor}` : null, address.room ? `ห้อง ${address.room}` : null, address.landmark].filter(Boolean).length ? (
                  <small>{[address.place_name, address.building_name, address.floor ? `ชั้น ${address.floor}` : null, address.room ? `ห้อง ${address.room}` : null, address.landmark].filter(Boolean).join(" · ")}</small>
                ) : null}
                <small className={addressLocation(address) ? "wf-location-ready" : "wf-location-missing"}>
                  {addressLocation(address) ? "ปักหมุดแล้ว" : "ยังไม่ได้ปักหมุดโลเคชั่น"}
                </small>
              </div>
              <button type="button" onClick={() => onEditAddress(address)}>แก้ไข</button>
              <button type="button" aria-label="ลบที่อยู่" onClick={() => onDeleteAddress(address.id)}><Trash2 size={17} /></button>
            </article>
          ))}
        </div>
      ) : null}

      <div className="wf-settings-list">
        <button type="button" onClick={onNotifications}>
          <span><Bell size={20} /><div><strong>การแจ้งเตือน WYNOS Food</strong><small>{notificationsEnabled ? "เปิดแล้วสำหรับอุปกรณ์นี้" : "แจ้งสถานะคำสั่งซื้อและการจัดส่ง"}</small></div></span>
          <ChevronRight size={18} />
        </button>
        {installPrompt ? (
          <button type="button" onClick={onInstall}>
            <span><Home size={20} /><div><strong>ติดตั้ง WYNOS Food</strong><small>เพิ่ม WYNOS Food ไว้บนหน้าจอหลัก</small></div></span>
            <ChevronRight size={18} />
          </button>
        ) : null}
        <a href="https://wynos.online/login">
          <span><ArrowLeft size={20} /><div><strong>เปิด WYNOS Social</strong><small>ใช้ WYNOS Account เดิม แล้วค่อยตั้งโปรไฟล์ Social เมื่อคุณต้องการ</small></div></span>
          <ChevronRight size={18} />
        </a>
        <button type="button" onClick={onSignOut}>
          <span><LogOut size={20} /><div><strong>ออกจากระบบ</strong><small>ออกจาก WYNOS Account บนอุปกรณ์นี้</small></div></span>
          <ChevronRight size={18} />
        </button>
      </div>
    </>
  );
}

function Sheet({
  title,
  onClose,
  children,
}: {
  title: string;
  onClose: () => void;
  children: React.ReactNode;
}) {
  return (
    <div className="wf-sheet-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}>
      <section className="wf-sheet" role="dialog" aria-modal="true" aria-label={title}>
        <header><button type="button" aria-label="ปิด" onClick={onClose}><X size={22} /></button><h2>{title}</h2><span /></header>
        <div className="wf-sheet-body">{children}</div>
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
        : `${existing ? "อัปเดตตะกร้า" : "เพิ่มลงตะกร้า"} · ${foodMoney(unitPrice * quantity)}`;

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
    <div
      className="wf-sheet-backdrop wf-item-sheet-backdrop"
      role="presentation"
      onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}
    >
      <section
        className={`wf-sheet wf-item-sheet${orderingDisabled ? " is-disabled" : ""}`}
        role="dialog"
        aria-modal="true"
        aria-label={item.name}
      >
        <button className="wf-item-close" type="button" aria-label="ปิด" onClick={onClose}><X size={24} /></button>

        <div className="wf-item-scroll">
          <div className="wf-item-photo">
            {image ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={image} alt="" />
            ) : <UtensilsCrossed size={44} strokeWidth={1.35} />}
          </div>

          <div className="wf-item-content">
            <div className="wf-item-title">
              <div>
                <h3>{item.name}</h3>
                {item.description ? <p>{item.description}</p> : null}
                {item.category ? <small className="wf-item-category">{item.category}</small> : null}
                {item.remaining_stock != null
                  ? <small className="wf-item-stock">เหลือ {Math.max(0, item.remaining_stock)} ชิ้นวันนี้</small>
                  : item.daily_stock_limit ? <small className="wf-item-stock">จำนวนจำกัด · สูงสุด {item.daily_stock_limit} ชิ้น/วัน</small> : null}
              </div>
              <strong>{foodMoney(unitPrice)}</strong>
            </div>

            {!storeOpen ? (
              <div className="wf-store-closed" role="status">
                <Clock3 size={18} />
                <strong>{storeStatus}</strong>
              </div>
            ) : null}
            {!itemAvailable ? <div className="wf-inline-warning">เมนูนี้หมดชั่วคราว</div> : null}
            {quantityLimit <= 0 ? <div className="wf-inline-warning">เมนูนี้ขายครบสำหรับวันนี้แล้ว</div> : null}

            {optionGroups.length ? (
              <div className="wf-option-groups">
                {optionGroups.map((group) => {
                  const maxSelect = Math.max(1, Math.min(20, Number(group.max_select ?? 1)));
                  const chosen = selected[group.id] ?? [];
                  return (
                    <section className="wf-option-group" key={group.id}>
                      <div className="wf-option-head">
                        <div>
                          <div className="wf-option-head-title">
                            <strong>{group.name}</strong>
                            {group.required ? <em>จำเป็น</em> : null}
                          </div>
                          <small>{maxSelect === 1 ? (group.required ? "เลือก 1 ข้อ" : "เลือกได้ 1 ข้อ") : `เลือกได้สูงสุด ${maxSelect} ข้อ`}</small>
                        </div>
                      </div>
                      <div className="wf-option-choices">
                        {group.choices.map((choice) => {
                          const active = chosen.includes(choice.id);
                          const extra = Math.max(0, Number(choice.price ?? 0));
                          return (
                            <button
                              key={choice.id}
                              type="button"
                              className={active ? "is-active" : ""}
                              aria-pressed={active}
                              disabled={orderingDisabled}
                              onClick={() => toggleOption(group.id, choice.id, maxSelect)}
                            >
                              <span className="wf-option-choice-copy">
                                <i className={`wf-option-control ${maxSelect === 1 ? "is-radio" : "is-checkbox"}${active ? " is-active" : ""}`} aria-hidden="true" />
                                <span>{choice.name}</span>
                              </span>
                              {extra > 0 ? <b>+{foodMoney(extra)}</b> : <b aria-hidden="true" />}
                            </button>
                          );
                        })}
                      </div>
                    </section>
                  );
                })}
              </div>
            ) : null}
            {!selectionValid ? <div className="wf-inline-warning">กรุณาเลือกตัวเลือกที่จำเป็นให้ครบ</div> : null}

            <label className="wf-field wf-item-note">
              <span className="wf-note-label">
                <span><strong>หมายเหตุถึงร้าน</strong> <em>(ไม่จำเป็น)</em></span>
                <small>{note.length}/200</small>
              </span>
              <textarea
                value={note}
                maxLength={200}
                disabled={orderingDisabled}
                onChange={(event) => setNote(event.target.value)}
                placeholder="เช่น ไม่ใส่ผัก, ไม่เผ็ด"
              />
            </label>
          </div>
        </div>

        <div className="wf-item-actions">
          <div className="wf-qty wf-qty--large">
            <button
              type="button"
              aria-label="ลดจำนวน"
              disabled={orderingDisabled || quantity <= 1}
              onClick={() => setQuantity((value) => Math.max(1, value - 1))}
            ><Minus size={17} /></button>
            <b>{quantity}</b>
            <button
              type="button"
              aria-label="เพิ่มจำนวน"
              disabled={orderingDisabled || quantity >= quantityLimit}
              onClick={() => setQuantity((value) => Math.min(quantityLimit, value + 1))}
            ><Plus size={17} /></button>
          </div>
          <button
            className="wf-primary"
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
  const complete = Boolean(form.recipientName.trim() && form.recipientPhone.trim() && form.address.trim() && form.location);
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
    <Sheet title={form.id ? "แก้ไขข้อมูลจัดส่ง" : "เพิ่มข้อมูลจัดส่ง"} onClose={onClose}>
      <div className="wf-form">
        <div className="wf-form-note">ข้อมูลนี้เป็นของ WYNOS Food เท่านั้น และไม่แก้ไขโปรไฟล์ WYNOS</div>
        <label>ชื่อที่อยู่ <small>เช่น บ้าน / หอพัก</small><input value={form.label} onChange={(event) => setForm({ ...form, label: event.target.value })} placeholder="ที่อยู่ของฉัน" /></label>
        <label>ชื่อผู้รับ <b>*</b><input value={form.recipientName} onChange={(event) => setForm({ ...form, recipientName: event.target.value })} placeholder="ชื่อผู้รับอาหาร" /></label>
        <label>เบอร์โทร <b>*</b><input inputMode="tel" autoComplete="tel" value={form.recipientPhone} onChange={(event) => setForm({ ...form, recipientPhone: event.target.value })} placeholder="เบอร์สำหรับติดต่อจัดส่ง" /></label>
        <label>ที่อยู่จัดส่ง <b>*</b><textarea value={form.address} onChange={(event) => setForm({ ...form, address: event.target.value })} placeholder="บ้านเลขที่ ถนน ซอย ตำบล/แขวง อำเภอ/เขต จังหวัด" /></label>
        {showPin || form.location ? <DeliveryPinPicker
          client={client}
          storeId={storeId}
          location={form.location}
          onChange={(location, place) => setForm((current) => ({
            ...current,
            location,
            placeId: location ? place?.placeId ?? null : null,
            placeName: location ? place?.name ?? "" : "",
            address: place ? [place.name, place.address].filter(Boolean).join(" ") : current.address,
          }))}
        /> : null}
        {form.placeName ? <div className="wf-form-note">WYNOS Place · {form.placeName}</div> : null}
        {storeId && form.location && deliveryMessage ? (
          <div className={availability?.can_deliver ? "wf-form-note" : "wf-inline-warning"}>{deliveryMessage}</div>
        ) : null}
        <label>ชื่ออาคาร / หมู่บ้าน<input value={form.buildingName} onChange={(event) => setForm({ ...form, buildingName: event.target.value })} placeholder="เช่น คอนโด A / หมู่บ้าน B" /></label>
        <label>ชั้น<input value={form.floor} onChange={(event) => setForm({ ...form, floor: event.target.value })} placeholder="เช่น 5" /></label>
        <label>ห้อง<input value={form.room} onChange={(event) => setForm({ ...form, room: event.target.value })} placeholder="เช่น 508" /></label>
        <label>จุดสังเกต<textarea value={form.landmark} onChange={(event) => setForm({ ...form, landmark: event.target.value })} placeholder="เช่น ทางเข้าอยู่ข้างร้านสะดวกซื้อ" /></label>
        <label>หมายเหตุถึงผู้จัดส่ง<textarea value={form.deliveryNote} onChange={(event) => setForm({ ...form, deliveryNote: event.target.value })} placeholder="เช่น โทรเมื่อถึง / ฝากไว้กับ รปภ." /></label>
        <label className="wf-check"><input type="checkbox" checked={form.isDefault} onChange={(event) => setForm({ ...form, isDefault: event.target.checked })} /><span><strong>ใช้เป็นที่อยู่หลัก</strong><small>WYNOS Food จะเลือกข้อมูลนี้ให้อัตโนมัติตอน Checkout</small></span></label>
        {!form.location ? <div className="wf-inline-warning">กรุณาปักหมุดโลเคชั่นก่อนบันทึก เพื่อให้ร้านและผู้จัดส่งหาได้ถูกต้อง</div> : null}
        <button className="wf-primary wf-full" type="button" disabled={busy || !complete} onClick={() => onSave(form)}>{busy ? "กำลังบันทึก…" : "บันทึกข้อมูล WYNOS Food"}</button>
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
  onSubmit: (address: FoodCustomerAddress, note: string, scheduledFor?: string | null) => void;
}) {
  const [addressId, setAddressId] = useState(addresses.find((address) => address.is_default)?.id ?? addresses[0]?.id ?? "");
  const [note, setNote] = useState("");
  const canSchedule = store.scheduled_orders_enabled === true;
  const minNotice = Math.max(15, Number(store.scheduled_min_notice_minutes ?? 30));
  const maxDays = Math.max(1, Number(store.scheduled_max_days ?? 7));
  const [scheduleMode, setScheduleMode] = useState<"asap" | "scheduled">("asap");
  const [scheduledLocal, setScheduledLocal] = useState("");
  const [scheduleError, setScheduleError] = useState("");
  const scheduledDate = scheduledLocal ? new Date(scheduledLocal) : null;
  const scheduledValid = scheduleMode === "asap" || (!!scheduledDate && !scheduleError);
  const chooseScheduledLocal = (value: string) => {
    setScheduledLocal(value);
    if (!value) {
      setScheduleError("กรุณาเลือกวันและเวลา");
      return;
    }
    const selectedDate = new Date(value);
    const selected = selectedDate.getTime();
    const now = Date.now();
    if (!Number.isFinite(selected) || selected < now + minNotice * 60_000 || selected > now + maxDays * 24 * 60 * 60_000) {
      setScheduleError("เวลาที่เลือกอยู่นอกช่วงที่ร้านรับออเดอร์ล่วงหน้า");
      return;
    }
    if (!foodStoreIsEffectivelyOpen(store, selectedDate)) {
      setScheduleError("ร้านปิดในวันหรือเวลาที่เลือก กรุณาเลือกเวลาใหม่");
      return;
    }
    setScheduleError("");
  };
  const address = addresses.find((row) => row.id === addressId) ?? null;
  const subtotal = cart.reduce((sum, line) => {
    const item = itemFor(menu, line.menu_item_id);
    return sum + (item ? foodCartLineUnitPrice(item, line) * line.quantity : 0);
  }, 0);
  // WYN-196: re-quote for the chosen address so the fee follows its distance.
  const zone = storeHasDeliveryZone(store);
  const location = addressLocation(address);
  const locationKey = location ? `${location.latitude},${location.longitude}` : "";
  const [addressQuote, setAddressQuote] = useState<{ key: string; quote: FoodOrderQuote | null; error: string } | null>(null);
  useEffect(() => {
    let live = true;
    const key = `${addressId}|${locationKey}`;
    const loc = zone && locationKey ? { latitude: Number(locationKey.split(",")[0]), longitude: Number(locationKey.split(",")[1]) } : null;
    if (!addressId || (zone && !loc)) return () => { live = false; };
    void quoteFoodCustomerOrder(client, store.id, cart, loc)
      .then((next) => { if (live) setAddressQuote({ key, quote: next, error: "" }); })
      .catch((error) => { if (live) setAddressQuote({ key, quote: null, error: foodCustomerError(error) }); });
    return () => { live = false; };
  }, [addressId, cart, client, locationKey, store.id, zone]);
  const current = addressQuote?.key === `${addressId}|${locationKey}` ? addressQuote : null;
  // Until the quote for this address arrives, the fee is unknown: no confirm.
  const quoteLoading = Boolean(address) && (!zone || Boolean(location)) && current === null;
  const effectiveQuote = current?.quote ?? quote;
  const checkoutQuantityByMenu = new Map<string, number>();
  for (const line of cart) checkoutQuantityByMenu.set(line.menu_item_id, (checkoutQuantityByMenu.get(line.menu_item_id) ?? 0) + line.quantity);
  const cartUnavailable = cart.some((line) => {
    const item = itemFor(menu, line.menu_item_id);
    if (!item || !foodMenuIsEffectivelyAvailable(item) || !foodCartLineOptionsValid(item, line)) return true;
    const limit = foodMenuQuantityLimit(item);
    return limit <= 0 || (checkoutQuantityByMenu.get(line.menu_item_id) ?? 0) > limit;
  });
  const serverSubtotal = Number(effectiveQuote?.subtotal ?? subtotal);
  const minimum = Number(store.minimum_order ?? 0);
  const minimumMissing = Math.max(0, minimum - serverSubtotal);
  const blockedReason = !address
    ? ""
    : zone && !location
      ? "ที่อยู่นี้ยังไม่ได้ปักหมุดตำแหน่ง แก้ไขที่อยู่เพื่อปักหมุดก่อนสั่ง"
      : cartUnavailable
        ? "มีเมนูที่หมดหรือจำนวนเกินสต็อกวันนี้ กรุณากลับไปปรับตะกร้า"
        : minimumMissing > 0
          ? `เพิ่มอีก ${foodMoney(minimumMissing)} เพื่อถึงยอดขั้นต่ำ ${foodMoney(minimum)}`
          : current?.error ?? "";
  const deliveryFee = Number(effectiveQuote?.delivery_fee ?? store.delivery_fee);
  const campaignDiscount = Number(effectiveQuote?.campaign_discount ?? 0);
  const deliveryDiscount = Number(effectiveQuote?.delivery_discount ?? 0);
  const total = effectiveQuote?.total ?? serverSubtotal + deliveryFee;
  const eta = foodEstimateDeliveryRange(store, effectiveQuote?.delivery_distance_km);

  return (
    <Sheet title="Checkout" onClose={onClose}>
      <div className="wf-checkout">
        <div className="wf-section-title"><h2>จัดส่งไปที่</h2><button type="button" onClick={onAddAddress}><Plus size={15} /> เพิ่มที่อยู่</button></div>
        {addresses.length ? (
          <div className="wf-address-choice">
            {addresses.map((row) => (
              <label key={row.id} className={addressId === row.id ? "is-active" : ""}>
                <input type="radio" name="food-address" checked={addressId === row.id} onChange={() => setAddressId(row.id)} />
                <span><strong>{row.label}</strong><small>{row.recipient_name} · {row.recipient_phone}</small><p>{row.address}</p>{row.building_name || row.floor || row.room ? <small>{[row.building_name, row.floor ? `ชั้น ${row.floor}` : null, row.room ? `ห้อง ${row.room}` : null].filter(Boolean).join(" · ")}</small> : null}</span>
              </label>
            ))}
          </div>
        ) : <div className="wf-inline-warning">เพิ่มที่อยู่จัดส่งก่อนสั่งอาหาร</div>}

        <label className="wf-field">หมายเหตุเพิ่มเติม<textarea value={note} onChange={(event) => setNote(event.target.value)} placeholder="เช่น โทรเมื่อถึง" /></label>
        {canSchedule ? <section className="wf-schedule-order">
          <div className="wf-section-title"><h2>เวลารับ/จัดส่ง</h2></div>
          <div className="wf-schedule-choice">
            <button className={scheduleMode === "asap" ? "is-active" : ""} type="button" onClick={() => setScheduleMode("asap")}><Clock3 size={17} /><span><strong>เร็วที่สุด</strong><small>ร้านเริ่มทำหลังรับออเดอร์</small></span></button>
            <button className={scheduleMode === "scheduled" ? "is-active" : ""} type="button" onClick={() => setScheduleMode("scheduled")}><CalendarDays size={17} /><span><strong>สั่งล่วงหน้า</strong><small>เลือกวันและเวลา</small></span></button>
          </div>
          {scheduleMode === "scheduled" ? <>
            <label className="wf-field">เลือกวันและเวลา<input type="datetime-local" value={scheduledLocal} onChange={(event) => chooseScheduledLocal(event.target.value)} /></label>
            <small className="wf-schedule-hint">ต้องล่วงหน้าอย่างน้อย {minNotice} นาที และไม่เกิน {maxDays} วัน</small>
            {scheduleMode === "scheduled" && scheduleError ? <div className="wf-inline-warning">{scheduleError}</div> : null}
          </> : null}
        </section> : null}

        <div className="wf-section-title wf-section-title--spaced"><h2>สรุปคำสั่งซื้อ</h2></div>
        <div className="wf-checkout-items">
          {cart.map((line) => {
            const item = itemFor(menu, line.menu_item_id);
            const optionText = foodCartLineOptionText(line, item);
            return <div key={foodCartLineKey(line)}><span>{line.quantity}× {item?.name ?? "เมนู"}{optionText ? <small>{optionText}</small> : null}</span><b>{item ? foodMoney(foodCartLineUnitPrice(item, line) * line.quantity) : "—"}</b></div>;
          })}
        </div>
        <div className="wf-summary">
          <div><span>ค่าอาหาร</span><b>{foodMoney(serverSubtotal)}</b></div>
          {campaignDiscount > 0 ? <div className="is-discount"><span>{effectiveQuote?.campaign_name ? "โปร · " + effectiveQuote.campaign_name : "ส่วนลดแคมเปญ"}</span><b>−{foodMoney(campaignDiscount)}</b></div> : null}
          <div><span>ค่าส่ง{current?.quote?.delivery_distance_km != null ? ` · ${current.quote.delivery_distance_km.toFixed(1)} กม.` : ""}</span><b>{foodMoney(deliveryFee)}</b></div>
          {deliveryDiscount > 0 ? <div className="is-discount"><span>ส่วนลดค่าส่ง</span><b>−{foodMoney(deliveryDiscount)}</b></div> : null}
          <div className="is-total"><span>ยอดสุทธิ</span><b>{foodMoney(total)}</b></div>
          <div><span>เวลาถึงโดยประมาณ</span><b>{eta.min}–{eta.max} นาที</b></div>
        </div>
        {blockedReason ? <div className="wf-inline-warning" role="alert">{blockedReason}</div> : null}
        {effectiveQuote?.campaign_name ? <div className="wf-promo-applied"><strong>แคมเปญ {effectiveQuote.campaign_name}</strong><small>ส่วนลดจะยืนยันอีกครั้งโดยระบบก่อนสร้างออเดอร์</small></div> : null}
        <p className="wf-server-note">ยอดจริงจะถูกตรวจและคำนวณจากระบบอีกครั้งก่อนสร้างออเดอร์</p>
        <button className="wf-primary wf-full" type="button" disabled={!address || busy || quoteLoading || Boolean(blockedReason) || !scheduledValid} onClick={() => { if (address) onSubmit(address, note, scheduleMode === "scheduled" && scheduledDate ? scheduledDate.toISOString() : null); }}>
          {busy ? "กำลังสร้างออเดอร์…" : quoteLoading ? "กำลังคำนวณค่าส่ง…" : `ยืนยันออเดอร์ · ${foodMoney(total)}`}
        </button>
      </div>
    </Sheet>
  );
}

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
    <Sheet title="รีวิวร้าน" onClose={onClose}>
      <div className="wf-review-form">
        <div className="wf-review-question">
          <span className="wf-review-big-star"><Star size={28} fill="currentColor" /></span>
          <div><h3>อาหารเป็นอย่างไรบ้าง?</h3><p>ให้คะแนนร้านจากออเดอร์ #{order.order_number}</p></div>
        </div>
        <div className="wf-review-picker" aria-label="ให้คะแนนร้าน">
          {[1, 2, 3, 4, 5].map((value) => (
            <button key={value} type="button" aria-label={`${value} ดาว`} onClick={() => setRating(value)}>
              <Star size={34} strokeWidth={1.7} fill={value <= rating ? "currentColor" : "none"} />
            </button>
          ))}
        </div>
        <div className="wf-review-tag-picker">
          {FOOD_REVIEW_TAGS.map((tag) => (
            <button key={tag} type="button" className={tags.includes(tag) ? "is-active" : ""} onClick={() => toggleTag(tag)}>{tag}</button>
          ))}
        </div>
        <label className="wf-field">เขียนรีวิวเพิ่มเติม
          <textarea maxLength={500} value={reviewText} onChange={(event) => setReviewText(event.target.value)} placeholder="เล่าประสบการณ์เกี่ยวกับอาหารและร้าน" />
        </label>
        <label className="wf-review-anonymous">
          <input type="checkbox" checked={anonymous} onChange={(event) => setAnonymous(event.target.checked)} />
          <span><strong>ไม่ระบุชื่อ</strong><small>ปกติจะแสดงชื่อแบบปกปิด เช่น ว**ล</small></span>
        </label>
        <div className="wf-review-identity"><span>ชื่อที่จะแสดง</span><strong>{reviewerLabel}</strong><small>ไม่แสดง @username รูปโปรไฟล์ หรือข้อมูล Social</small></div>
        <button className="wf-primary wf-full" type="button" disabled={!rating || submitting} onClick={() => void submit()}>
          {submitting ? "กำลังส่งรีวิว…" : "ส่งรีวิว"}
        </button>
        <p className="wf-server-note">รีวิวนี้มาจากออเดอร์ที่ส่งสำเร็จและจะแสดงป้าย “สั่งจริงกับ WYNOS Food”</p>
      </div>
    </Sheet>
  );
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
}) {
  const [slipFile, setSlipFile] = useState<File | null>(null);
  const [slipPreviewUrl, setSlipPreviewUrl] = useState<string | null>(null);
  const [proofUrl, setProofUrl] = useState<string | null>(null);
  const [dynamicPaymentQr, setDynamicPaymentQr] = useState<string | null>(null);
  const [working, setWorking] = useState(false);
  const slipInputRef = useRef<HTMLInputElement>(null);
  const slipPreviewUrlRef = useRef<string | null>(null);
  const proof = orderDeliveryProof(order);

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
      if (!store?.promptpay_id || !["pending", "issue"].includes(order.payment_status)) {
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
  }, [client, order.id, order.payment_status, store?.promptpay_id]);

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

  const submitSlip = async () => {
    if (!slipFile) {
      onMessage("กรุณาเลือกรูปสลิป");
      return;
    }
    setWorking(true);
    try {
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
  const canPay = !isCancelled && ["pending", "issue"].includes(order.payment_status);
  const canCancel = order.status === "pending_acceptance" && ["pending", "issue"].includes(order.payment_status);
  const paymentQr = dynamicPaymentQr ?? foodPublicUrl(client, store?.payment_qr_path);
  const combinedBusy = busy || working;

  return (
    <Sheet title={`ออเดอร์ #${order.order_number}`} onClose={onClose}>
      <div className="wf-order-detail">
        <div className="wf-order-detail-head">
          <div><span className={`wf-order-status wf-order-status--${order.status}`}>{foodOrderStatusLabel(order.status)}</span><small>{formatDate(order.created_at)}</small></div>
          <strong>{foodMoney(order.total)}</strong>
        </div>
        {order.scheduled_for ? <div className="wf-scheduled-banner"><Clock3 size={18} /><span><strong>ออเดอร์ล่วงหน้า</strong><small>{formatDate(order.scheduled_for)}</small></span></div> : null}

        {!isCancelled ? (
          <section className="wf-track">
            {TRACKING_STEPS.map((step, index) => {
              const done = currentIndex >= index;
              const current = currentIndex === index;
              return (
                <div key={step.status} className={`wf-track-step ${done ? "is-done" : ""} ${current ? "is-current" : ""}`}>
                  <span>{done ? <Check size={13} /> : null}</span>
                  <div><strong>{step.label}</strong>{current && order.eta_minutes && order.status === "preparing" ? <small>ประมาณ {order.eta_minutes} นาที</small> : null}</div>
                </div>
              );
            })}
          </section>
        ) : <div className="wf-cancelled"><X size={22} /><span><strong>ออเดอร์ถูกยกเลิก</strong><small>{order.cancelled_at ? formatDate(order.cancelled_at) : ""}</small></span></div>}

        <section className="wf-order-section">
          <div className="wf-section-title"><h2>รายการอาหาร</h2></div>
          <div className="wf-checkout-items">
            {(order.food_order_items ?? []).map((item) => (
              <div key={item.id}><span>{item.quantity}× {item.item_name}{foodCartLineOptionText({ selected_options: item.selected_options }) ? <small>{foodCartLineOptionText({ selected_options: item.selected_options })}</small> : null}{item.item_note ? <small>{item.item_note}</small> : null}</span><b>{foodMoney(Number(item.unit_price) * item.quantity)}</b></div>
            ))}
          </div>
          <div className="wf-summary">
            <div><span>ค่าอาหาร</span><b>{foodMoney(order.subtotal)}</b></div>
            {Number(order.campaign_discount ?? 0) > 0 ? <div className="is-discount"><span>{order.campaign_name ? "โปร · " + order.campaign_name : "ส่วนลดแคมเปญ"}</span><b>−{foodMoney(order.campaign_discount)}</b></div> : null}
            <div><span>ค่าส่ง</span><b>{foodMoney(order.delivery_fee)}</b></div>
            {Number(order.delivery_discount ?? 0) > 0 ? <div className="is-discount"><span>ส่วนลดค่าส่ง</span><b>−{foodMoney(order.delivery_discount)}</b></div> : null}
            <div className="is-total"><span>ยอดสุทธิ</span><b>{foodMoney(order.total)}</b></div>
          </div>
        </section>

        <section className="wf-order-section">
          <div className="wf-section-title"><h2>การชำระเงิน</h2><span className={`wf-payment-status wf-payment-status--${order.payment_status}`}>{foodPaymentStatusLabel(order.payment_status)}</span></div>
          {order.payment_note ? <div className="wf-inline-warning">{order.payment_note}</div> : null}
          {order.payment_verification_status === "auto_verified" ? <div className="wf-inline-warning">ตรวจสอบสลิปอัตโนมัติแล้ว</div> : null}
          {order.payment_verification_status === "manual_review" && order.payment_status === "submitted" ? <div className="wf-inline-warning">รอตรวจสอบโดยร้าน</div> : null}
          {canPay ? (
            <div className="wf-payment">
              <p>โอนเงินเข้าบัญชีร้านโดยตรง แล้วแนบสลิปเพื่อให้ระบบตรวจสอบ</p>
              {dynamicPaymentQr ? <div className="wf-inline-warning">{`QR นี้ตั้งยอด ${foodMoney(order.total)} ให้อัตโนมัติ`}</div> : null}
              {paymentQr ? (
                <div className="wf-payment-qr">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={paymentQr} alt="QR รับชำระเงินของร้าน" />
                </div>
              ) : null}
              <div className="wf-bank-info">
                {store?.promptpay_name || store?.promptpay_id ? <div><span>PromptPay</span><strong>{store.promptpay_name || "—"}</strong><b>{store.promptpay_id || "—"}</b></div> : null}
                {store?.bank_name || store?.bank_account_number ? <div><span>{store.bank_name || "บัญชีธนาคาร"}</span><strong>{store.bank_account_name || "—"}</strong><b>{store.bank_account_number || "—"}</b></div> : null}
              </div>
              {!paymentQr && !store?.promptpay_id && !store?.bank_account_number ? <div className="wf-inline-warning">ร้านยังไม่ได้ตั้งค่าช่องทางรับเงิน</div> : null}
              {slipFile ? (
                <div className="wf-slip-preview">
                  <div className="wf-slip-preview-image">
                    {slipPreviewUrl ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={slipPreviewUrl} alt="รูปตัวอย่างสลิปที่เลือก" />
                    ) : null}
                  </div>
                  <div className="wf-slip-preview-copy">
                    <div className="wf-slip-preview-status"><Check size={14} /><span>เพิ่มสลิปแล้ว</span></div>
                    <strong title={slipFile.name}>{slipFile.name}</strong>
                    <div className="wf-slip-preview-actions">
                      <label className={`wf-slip-preview-action${combinedBusy ? " is-disabled" : ""}`}>
                        <input
                          ref={slipInputRef}
                          type="file"
                          accept="image/jpeg,image/png,image/webp"
                          disabled={combinedBusy}
                          onChange={(event) => selectSlip(event.target.files?.[0] ?? null)}
                        />
                        <Upload size={15} /><span>เปลี่ยนรูป</span>
                      </label>
                      <button className="wf-slip-preview-action wf-slip-preview-remove" type="button" disabled={combinedBusy} onClick={clearSlip}>
                        <Trash2 size={15} /><span>ลบรูป</span>
                      </button>
                    </div>
                  </div>
                </div>
              ) : (
                <label className="wf-upload">
                  <input
                    ref={slipInputRef}
                    type="file"
                    accept="image/jpeg,image/png,image/webp"
                    disabled={combinedBusy}
                    onChange={(event) => selectSlip(event.target.files?.[0] ?? null)}
                  />
                  <Upload size={20} /><span>แนบรูปสลิป</span>
                </label>
              )}
              <button className="wf-primary wf-full" type="button" disabled={!slipFile || combinedBusy} onClick={() => void submitSlip()}>
                {combinedBusy ? "กำลังส่ง…" : "แจ้งชำระเงิน"}
              </button>
            </div>
          ) : null}
        </section>

        <section className="wf-order-section">
          <div className="wf-section-title"><h2>จัดส่งไปที่</h2></div>
          <div className="wf-delivery-address"><MapPin size={18} /><div><strong>{order.recipient_name}</strong><small>{order.recipient_phone}</small><p>{order.shipping_address}</p>{order.customer_note ? <em>{order.customer_note}</em> : null}</div></div>
          {store?.phone ? <a className="wf-secondary wf-full" href={`tel:${store.phone}`}><Phone size={17} /> โทรหาร้าน</a> : null}
        </section>

        {order.status === "delivered" ? (
          <section className="wf-delivery-proof">
            <PackageCheck size={27} />
            <div><strong>จัดส่งสำเร็จแล้ว</strong><small>{order.delivered_at ? formatDate(order.delivered_at) : ""}</small>{proof?.location_note ? <p>วางไว้: {proof.location_note}</p> : <p>{proof?.method === "direct" ? "ส่งให้ผู้รับโดยตรง" : ""}</p>}</div>
            {proofUrl ? <a href={proofUrl} target="_blank" rel="noreferrer">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={proofUrl} alt="หลักฐานการจัดส่ง" />
            </a> : null}
          </section>
        ) : null}

        {order.status === "delivered" ? (
          ownReview ? (
            <section className="wf-review-done">
              <div><strong>ขอบคุณที่รีวิวร้าน</strong><small>รีวิวจากออเดอร์จริงของคุณ</small></div>
              <ReviewStars rating={ownReview.rating} compact />
            </section>
          ) : (
            <button className="wf-review-cta" type="button" onClick={onReview}>
              <span><Star size={24} fill="currentColor" /></span>
              <div><strong>อาหารเป็นอย่างไรบ้าง?</strong><small>ให้คะแนนร้าน 1–5 ดาวจากออเดอร์นี้</small></div>
              <ChevronRight size={19} />
            </button>
          )
        ) : null}

        {canCancel ? <button className="wf-danger-link" type="button" disabled={combinedBusy} onClick={() => void cancel()}>ยกเลิกออเดอร์</button> : null}
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
  // WYN-211: Food is open to everyone, but only customers in Maha Sarakham
  // get past the introduction page (developers skip it, like the server).
  const [area, setArea] = useState<FoodAreaState>("checking");
  const resolveArea = useCallback(async (location: FoodLocation | null) => {
    try {
      const point = location ?? await currentFoodLocation();
      const inside = await checkFoodServiceArea(client, point);
      rememberFoodArea(userId, inside ? "inside" : "outside");
      setArea(inside ? "inside" : "outside");
    } catch {
      setArea("unknown");
    }
  }, [client, userId]);
  const checkArea = (location: FoodLocation | null) => {
    setArea("checking");
    void resolveArea(location);
  };
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
  const [cart, setCart] = useState<FoodCartLine[]>(() => {
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
  const [refreshing, setRefreshing] = useState(false);
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

  // A saved delivery pin answers without asking for GPS.
  const savedPin = snapshot?.addresses.find((address) => address.is_default && address.latitude != null && address.longitude != null)
    ?? snapshot?.addresses.find((address) => address.latitude != null && address.longitude != null);
  const savedPinKey = savedPin ? `${savedPin.latitude},${savedPin.longitude}` : "";
  const areaNeeded = Boolean(snapshot?.allowed && !snapshot.developer);
  useEffect(() => {
    if (!areaNeeded) return;
    let live = true;
    const [lat, lng] = savedPinKey.split(",").map(Number);
    const point = savedPinKey ? Promise.resolve({ latitude: lat, longitude: lng }) : currentFoodLocation();
    void point
      .then((location) => checkFoodServiceArea(client, location))
      .then((inside) => {
        // WYN-212: Home shows its Food banner only to people found inside.
        rememberFoodArea(userId, inside ? "inside" : "outside");
        if (live) setArea(inside ? "inside" : "outside");
      })
      .catch(() => { if (live) setArea("unknown"); });
    return () => { live = false; };
  }, [areaNeeded, client, savedPinKey, userId]);

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

  const createOrder = async (address: FoodCustomerAddress, note: string, scheduledFor?: string | null) => {
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
        scheduledFor: scheduledFor ?? null,
      });
      // Lets the store see orders that came from its shared link.
      if (hasShareRef(store.id)) void markFoodOrderFromShare(client, orderId).catch(() => undefined);
      setCart([]);
      setCheckoutOpen(false);
      const next = await load(true);
      const order = next?.orders.find((row) => row.id === orderId);
      if (order) setSelectedOrder(order);
      setTab("orders");
      setMessage(scheduledFor ? "สร้างออเดอร์ล่วงหน้าแล้ว กรุณาชำระเงินเข้าบัญชีร้าน" : "สร้างออเดอร์แล้ว กรุณาชำระเงินเข้าบัญชีร้าน");
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
  const pull = usePullToRefresh({ enabled: tab === "home" || tab === "orders", onRefresh: async () => { await load(true); } });

  if (!snapshot) return loadError ? <FoodLoadError message={loadError} onRetry={() => { setLoadError(""); void load(); }} /> : <FoodLoading />;
  if (!snapshot.allowed) return <FoodDenied />;
  if (!snapshot.developer && area !== "inside") {
    return (
      <FoodServiceAreaIntro
        client={client}
        state={area}
        onCheck={(location) => checkArea(location)}
        onUseLocation={() => checkArea(null)}
      />
    );
  }

  return (
    <main className={`wyn-food${tab === "home" && storefrontOpen ? " wf-storefront-open" : ""}${tab === "home" && storefrontOpen && cartCount > 0 ? " has-store-cart" : ""}`}>
      {tab === "home" && storefrontOpen ? null : (
        <FoodHeader
          cartCount={cartCount}
          showBack={tab !== "home"}
          homeLocationLabel={homeLocationLabel}
          onBack={() => setTab("home")}
          onCart={() => setTab("cart")}
          onLocation={() => setTab("account")}
          onFavorites={() => setFavoritesOpen(true)}
          onRefresh={() => void load(true)}
          refreshing={refreshing}
        />
      )}
      {message ? <div className="wf-toast" role="status"><span>{message}</span><button type="button" aria-label="ปิด" onClick={() => setMessage("")}><X size={16} /></button></div> : null}

      <PullToRefreshIndicator pull={pull} topOffset={tab === "home" && storefrontOpen ? "0px" : "58px"} refreshingLabel="กำลังอัปเดต WYNOS Food" />
      <section className="wf-content" onTouchStart={pull.onTouchStart} onTouchMove={pull.onTouchMove} onTouchEnd={pull.onTouchEnd} onTouchCancel={pull.onTouchCancel}>
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
            onMessage={setMessage}
          />
        ) : null}
        {tab === "orders" ? <OrdersPanel orders={orders} reviewedOrderIds={reviewedOrderIds} hasMore={snapshot.has_more_orders} loadingMore={loadingMoreOrders} onLoadMore={() => void loadMoreOrders()} onOrder={setSelectedOrder} /> : null}
        {tab === "messages" ? <MessagesPanel /> : null}
        {tab === "cart" ? <CartPanel store={store} menu={menu} cart={cart} quote={quote} onCart={setCart} onCheckout={() => setCheckoutOpen(true)} /> : null}
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
          />
        ) : null}
      </section>

      {tab === "home" && storefrontOpen && cartCount > 0 ? (
        <button className="wf-store-cart-bar" type="button" onClick={() => setTab("cart")}>
          <span><ShoppingBag size={19} />{cartCount} รายการ · {foodMoney(cartSubtotal)}</span>
          <b>ตะกร้า <ChevronRight size={18} /></b>
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
          onSubmit={(address, note, scheduledFor) => void createOrder(address, note, scheduledFor)}
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
        />
      ) : null}
    </main>
  );
}

export function WynosFoodDeveloperApp() {
  // A layout effect runs before the sign-in redirect (a passive effect in the
  // gate) leaves this page, so a signed-out customer who tapped a shared store
  // link still opens that store after signing in. It also runs before the
  // signed-in app clears the kept store once it has opened it.
  useLayoutEffect(() => {
    const shared = sharedFoodStoreId(window.location.search);
    if (shared) rememberSharedFoodStore(shared);
  }, []);
  return (
    <DeveloperRouteGate signedOutPath="/food/login" afterSignOutPath="/food/login">
      {({ client, userId, signOut }) => <FoodCustomerInner key={userId} client={client} userId={userId} signOut={signOut} />}
    </DeveloperRouteGate>
  );
}
