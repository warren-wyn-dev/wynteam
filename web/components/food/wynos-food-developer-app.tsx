"use client";

import {
  ArrowLeft,
  Bell,
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
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { FoodDeliveryMapPicker } from "@/components/food/food-delivery-map-picker";
import { PullToRefreshIndicator } from "@/components/ui/pull-to-refresh-indicator";
import { rememberFoodArea } from "@/lib/food-area-memory";
import {
  clearSharedFoodStore,
  foodStoreShareData,
  pendingSharedFoodStore,
  rememberSharedFoodStore,
  sharedFoodStoreId,
} from "@/lib/food-share";
import { shareOrCopyLink } from "@/lib/share";
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
  fetchFoodPromptPayQr,
  checkFoodServiceArea,
  checkFoodDeliveryAvailability,
  currentFoodLocation,
  foodCustomerError,
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
  return <FoodLoading />;
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
        <Link className="wf-area-home" href="/">กลับหน้าหลัก</Link>
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
  onBack,
  onCart,
  onRefresh,
  refreshing,
}: {
  cartCount: number;
  showBack: boolean;
  onBack: () => void;
  onCart: () => void;
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
      <div className="wf-brand">
        <span>WYNOS</span>
        <b>Food</b>
      </div>
      <div className="wf-header-actions">
        <button className="wf-icon-button wf-cart-button" type="button" aria-label={cartCount ? `ตะกร้า ${cartCount} รายการ` : "ตะกร้า"} onClick={onCart}>
          <ShoppingBag size={21} strokeWidth={1.9} />
          {cartCount ? <i>{cartCount > 9 ? "9+" : cartCount}</i> : null}
        </button>
        <button className="wf-icon-button" type="button" aria-label="อัปเดตข้อมูล" onClick={onRefresh}>
          {refreshing ? <i className="wf-mini-loader" /> : <Clock3 size={21} strokeWidth={1.8} />}
        </button>
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
        <img src={url} alt="" />
      ) : <UtensilsCrossed size={26} strokeWidth={1.45} />}
    </span>
  );
}

/**
 * WYN-207: store directory. Live paid ads come first as "ร้านแนะนำ" with a
 * "โฆษณา" label; search puts them on top too. Opening an ad tells the server,
 * which decides whether to charge (once per customer per store per day).
 */
function StoreDirectory({
  client,
  currentStoreId,
  onPick,
}: {
  client: SupabaseClient;
  currentStoreId: string | null;
  onPick: (store: FoodDirectoryStore, placement: "home" | "search") => void;
}) {
  const [query, setQuery] = useState("");
  const [stores, setStores] = useState<FoodDirectoryStore[] | null>(null);
  useEffect(() => {
    let live = true;
    const timer = window.setTimeout(() => {
      void fetchFoodStoreDirectory(client, query).then((next) => { if (live) setStores(next); });
    }, query ? 300 : 0);
    return () => { live = false; window.clearTimeout(timer); };
  }, [client, query]);
  // A Food home should remain a directory even when only one store is live.
  if (!stores) return null;
  const placement = query.trim() ? "search" : "home";
  const ads = stores.filter((store) => store.is_ad);
  const rest = stores.filter((store) => !store.is_ad);
  const card = (store: FoodDirectoryStore) => {
    const logo = foodPublicUrl(client, store.logo_path);
    const cover = foodPublicUrl(client, store.cover_path);
    return (
      <button
        key={store.id}
        type="button"
        className="wf-dir-store"
        aria-current={store.id === currentStoreId ? "true" : undefined}
        onClick={() => onPick(store, placement)}
      >
        <span className="wf-dir-cover">
          {cover ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={cover} alt="" />
          ) : <UtensilsCrossed size={34} strokeWidth={1.35} />}
          {store.is_ad ? <b className="wf-ad-label">โฆษณา</b> : null}
        </span>
        <span className="wf-dir-card-body">
          <span className="wf-dir-row">
            <span className="wf-dir-logo">{logo ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={logo} alt="" />
            ) : <Store size={20} strokeWidth={1.5} />}</span>
            <span className="wf-dir-copy">
              <strong>{store.name}</strong>
              <small>{store.is_open ? "เปิดรับออเดอร์" : "ปิดอยู่"}</small>
            </span>
            <ChevronRight size={18} strokeWidth={1.8} />
          </span>
          <span className="wf-dir-meta">
            {store.business_hours ? <span><Clock3 size={14} />{store.business_hours}</span> : null}
            <span><MapPin size={14} />ค่าส่ง {foodMoney(store.delivery_fee)}</span>
          </span>
        </span>
      </button>
    );
  };
  return (
    <section className="wf-directory">
      <label className="wf-search">
        <Search size={19} strokeWidth={1.7} />
        <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="ค้นหาร้าน" aria-label="ค้นหาร้าน" autoComplete="off" />
      </label>
      {ads.length ? (
        <>
          <h2 className="wf-dir-title">{placement === "search" ? "ร้านที่ตรงกับการค้นหา" : "ร้านแนะนำ"}</h2>
          <div className="wf-dir-list">{ads.map(card)}</div>
        </>
      ) : null}
      {rest.length ? (
        <>
          <h2 className="wf-dir-title">{ads.length ? "ร้านอื่นๆ" : "ร้านทั้งหมด"}</h2>
          <div className="wf-dir-list">{rest.map(card)}</div>
        </>
      ) : null}
      {!stores.length ? <p className="wf-dir-empty">ไม่พบร้านที่ค้นหา</p> : null}
    </section>
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
    () => menu.filter((item) => foodMenuIsEffectivelyAvailable(item)).slice(0, 4),
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
  storefrontOpen,
}: {
  client: SupabaseClient;
  userId: string;
  store: FoodCustomerStore | null;
  menu: FoodCustomerMenuItem[];
  onItem: (item: FoodCustomerMenuItem) => void;
  onPickStore: (store: FoodDirectoryStore, placement: "home" | "search") => void;
  onShareStore: () => void;
  storefrontOpen: boolean;
}) {
  const [category, setCategory] = useState("ทั้งหมด");
  const [searchOpen, setSearchOpen] = useState(false);
  const [storeSection, setStoreSection] = useState<"menu" | "reviews" | "info">("menu");
  const [campaigns, setCampaigns] = useState<string[]>([]);
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
        <StoreDirectory client={client} currentStoreId={store?.id ?? null} onPick={onPickStore} />
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
            <img src={cover} alt="" />
          ) : <Store size={46} strokeWidth={1.25} />}
        </div>
        <div className="wf-store-main">
          <span className="wf-store-logo">
            {logo ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={logo} alt="" />
            ) : <Store size={25} strokeWidth={1.45} />}
          </span>
          <div className="wf-store-copy">
            <div><h1>{store.name}</h1><FoodStatus store={store} /></div>
            {campaigns.length ? (
              <div className="wf-campaign-badges">{campaigns.map((name) => <span key={name}>{`แคมเปญ WYNOS · ${name}`}</span>)}</div>
            ) : null}
            {store.description ? <p>{store.description}</p> : null}
            <div className="wf-store-meta">
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
      <section className="wf-store-menu">
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
            const available = foodMenuIsEffectivelyAvailable(item);
            return (
            <button key={item.id} type="button" className={`wf-menu-row ${available ? "" : "is-off"}`} onClick={() => onItem(item)}>
              <MenuImage client={client} item={item} />
              <span className="wf-menu-copy">
                <strong>{item.name}</strong>
                {item.description ? <small>{item.description}</small> : <small>{item.category}</small>}
                {item.daily_stock_limit ? <small>จำนวนจำกัด · สูงสุด {item.daily_stock_limit} ชิ้น/วัน</small> : null}
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
  const priced = cart.map((line) => ({ line, item: itemFor(menu, line.menu_item_id) }));
  const subtotal = priced.reduce((sum, row) => sum + (row.item ? Number(row.item.price) * row.line.quantity : 0), 0);
  const delivery = Number(store?.delivery_fee ?? 0);
  const campaignDiscount = Number(quote?.campaign_discount ?? 0);
  const deliveryDiscount = Number(quote?.delivery_discount ?? 0);
  const total = quote?.total ?? subtotal + delivery;
  const hasUnavailable = priced.some((row) => !row.item || !foodMenuIsEffectivelyAvailable(row.item));
  const belowMinimum = subtotal < Number(store?.minimum_order ?? 0);
  const storeOpen = !!store && foodStoreIsEffectivelyOpen(store);
  const canCheckout = !!store && storeOpen && cart.length > 0 && !hasUnavailable && !belowMinimum;

  const changeQuantity = (id: string, delta: number) => {
    onCart(cart
      .map((line) => line.menu_item_id === id ? { ...line, quantity: line.quantity + delta } : line)
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
            {priced.map(({ line, item }) => (
              <article key={line.menu_item_id} className={`wf-cart-row ${item && foodMenuIsEffectivelyAvailable(item) ? "" : "is-off"}`}>
                <div className="wf-cart-copy">
                  <strong>{item?.name ?? "เมนูไม่พร้อมใช้งาน"}</strong>
                  {line.note ? <small>{line.note}</small> : null}
                  <b>{item ? foodMoney(Number(item.price) * line.quantity) : "—"}</b>
                  {!item || !foodMenuIsEffectivelyAvailable(item) ? <em>เมนูนี้หมดชั่วคราว กรุณานำออกจากตะกร้า</em> : null}
                </div>
                <div className="wf-qty">
                  <button type="button" aria-label="ลดจำนวน" onClick={() => changeQuantity(line.menu_item_id, -1)}>
                    {line.quantity === 1 ? <Trash2 size={15} /> : <Minus size={15} />}
                  </button>
                  <b>{line.quantity}</b>
                  <button type="button" aria-label="เพิ่มจำนวน" onClick={() => changeQuantity(line.menu_item_id, 1)}>
                    <Plus size={15} />
                  </button>
                </div>
              </article>
            ))}
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
            <div className="wf-inline-warning">ยอดขั้นต่ำของร้านคือ {foodMoney(store.minimum_order)}</div>
          ) : null}
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
  onOrder,
}: {
  orders: FoodCustomerOrder[];
  reviewedOrderIds: Set<string>;
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
  storeOpen,
  onClose,
  onAdd,
}: {
  client: SupabaseClient;
  item: FoodCustomerMenuItem;
  existing: FoodCartLine | null;
  storeOpen: boolean;
  onClose: () => void;
  onAdd: (line: FoodCartLine) => void;
}) {
  const [quantity, setQuantity] = useState(existing?.quantity ?? 1);
  const [note, setNote] = useState(existing?.note ?? "");
  const image = foodPublicUrl(client, item.image_path);
  const itemAvailable = foodMenuIsEffectivelyAvailable(item);
  const canAdd = itemAvailable && storeOpen;

  return (
    <Sheet title={item.name} onClose={onClose}>
      <div className="wf-item-detail">
        <div className="wf-item-photo">
          {image ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={image} alt="" />
          ) : <UtensilsCrossed size={40} strokeWidth={1.35} />}
        </div>
        <div className="wf-item-title"><div><h3>{item.name}</h3><p>{item.description || item.category}</p>{item.daily_stock_limit ? <small>จำนวนจำกัด · สูงสุด {item.daily_stock_limit} ชิ้น/วัน</small> : null}</div><strong>{foodMoney(item.price)}</strong></div>
        {!itemAvailable ? <div className="wf-inline-warning">เมนูนี้หมดชั่วคราว</div> : null}
        {!storeOpen ? <div className="wf-inline-warning">ร้านยังไม่เปิดรับออเดอร์</div> : null}
        <label className="wf-field">หมายเหตุถึงร้าน<textarea value={note} onChange={(event) => setNote(event.target.value)} placeholder="เช่น ไม่ใส่ผัก" /></label>
        <div className="wf-item-actions">
          <div className="wf-qty wf-qty--large">
            <button type="button" onClick={() => setQuantity((value) => Math.max(1, value - 1))}><Minus size={16} /></button>
            <b>{quantity}</b>
            <button type="button" onClick={() => setQuantity((value) => Math.min(99, value + 1))}><Plus size={16} /></button>
          </div>
          <button className="wf-primary" type="button" disabled={!canAdd} onClick={() => onAdd({ menu_item_id: item.id, quantity, note: note.trim() })}>
            {existing ? "อัปเดตตะกร้า" : "เพิ่มลงตะกร้า"} · {foodMoney(Number(item.price) * quantity)}
          </button>
        </div>
      </div>
    </Sheet>
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
  const scheduledDate = scheduledLocal ? new Date(scheduledLocal) : null;
  const scheduledMs = scheduledDate?.getTime() ?? Number.NaN;
  const minScheduledMs = Date.now() + minNotice * 60_000;
  const maxScheduledMs = Date.now() + maxDays * 24 * 60 * 60_000;
  const scheduledValid = scheduleMode === "asap"
    || (Number.isFinite(scheduledMs) && scheduledMs >= minScheduledMs && scheduledMs <= maxScheduledMs);
  const address = addresses.find((row) => row.id === addressId) ?? null;
  const subtotal = cart.reduce((sum, line) => {
    const item = itemFor(menu, line.menu_item_id);
    return sum + (item ? Number(item.price) * line.quantity : 0);
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
  const blockedReason = !address
    ? ""
    : zone && !location
      ? "ที่อยู่นี้ยังไม่ได้ปักหมุดตำแหน่ง แก้ไขที่อยู่เพื่อปักหมุดก่อนสั่ง"
      : current?.error ?? "";
  const deliveryFee = Number(effectiveQuote?.delivery_fee ?? store.delivery_fee);
  const campaignDiscount = Number(effectiveQuote?.campaign_discount ?? 0);
  const deliveryDiscount = Number(effectiveQuote?.delivery_discount ?? 0);
  const total = effectiveQuote?.total ?? subtotal + deliveryFee;
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

        {canSchedule ? (
          <section className="wf-schedule-order">
            <div className="wf-section-title"><h2>เวลารับ/จัดส่ง</h2></div>
            <div className="wf-schedule-choice">
              <button className={scheduleMode === "asap" ? "is-active" : ""} type="button" onClick={() => setScheduleMode("asap")}>
                <Clock3 size={17} /><span><strong>เร็วที่สุด</strong><small>ร้านเริ่มทำหลังรับออเดอร์</small></span>
              </button>
              <button className={scheduleMode === "scheduled" ? "is-active" : ""} type="button" onClick={() => setScheduleMode("scheduled")}>
                <CalendarDays size={17} /><span><strong>สั่งล่วงหน้า</strong><small>เลือกวันและเวลา</small></span>
              </button>
            </div>
            {scheduleMode === "scheduled" ? (
              <>
                <label className="wf-field">เลือกวันและเวลา<input type="datetime-local" value={scheduledLocal} onChange={(event) => setScheduledLocal(event.target.value)} /></label>
                <small className="wf-schedule-hint">ต้องล่วงหน้าอย่างน้อย {minNotice} นาที และไม่เกิน {maxDays} วัน</small>
                {scheduledLocal && !scheduledValid ? <div className="wf-inline-warning">เวลาที่เลือกอยู่นอกช่วงที่ร้านรับออเดอร์ล่วงหน้า</div> : null}
              </>
            ) : null}
          </section>
        ) : null}

        <div className="wf-section-title wf-section-title--spaced"><h2>สรุปคำสั่งซื้อ</h2></div>
        <div className="wf-checkout-items">
          {cart.map((line) => {
            const item = itemFor(menu, line.menu_item_id);
            return <div key={line.menu_item_id}><span>{line.quantity}× {item?.name ?? "เมนู"}</span><b>{item ? foodMoney(Number(item.price) * line.quantity) : "—"}</b></div>;
          })}
        </div>
        <div className="wf-summary">
          <div><span>ค่าอาหาร</span><b>{foodMoney(subtotal)}</b></div>
          {campaignDiscount > 0 ? <div className="is-discount"><span>{effectiveQuote?.campaign_name ? "โปร · " + effectiveQuote.campaign_name : "ส่วนลดแคมเปญ"}</span><b>−{foodMoney(campaignDiscount)}</b></div> : null}
          <div><span>ค่าส่ง{current?.quote?.delivery_distance_km != null ? ` · ${current.quote.delivery_distance_km.toFixed(1)} กม.` : ""}</span><b>{foodMoney(deliveryFee)}</b></div>
          {deliveryDiscount > 0 ? <div className="is-discount"><span>ส่วนลดค่าส่ง</span><b>−{foodMoney(deliveryDiscount)}</b></div> : null}
          <div className="is-total"><span>ยอดสุทธิ</span><b>{foodMoney(total)}</b></div>
          <div><span>เวลาถึงโดยประมาณ</span><b>{eta.min}–{eta.max} นาที</b></div>
        </div>
        {blockedReason ? <div className="wf-inline-warning" role="alert">{blockedReason}</div> : null}
        {effectiveQuote?.campaign_name ? <div className="wf-promo-applied"><strong>แคมเปญ {effectiveQuote.campaign_name}</strong><small>ส่วนลดจะยืนยันอีกครั้งโดยระบบก่อนสร้างออเดอร์</small></div> : null}
        <p className="wf-server-note">ยอดจริงจะถูกตรวจและคำนวณจากระบบอีกครั้งก่อนสร้างออเดอร์</p>
        <button className="wf-primary wf-full" type="button" disabled={!address || busy || quoteLoading || Boolean(blockedReason) || !scheduledValid} onClick={() => {
          if (!address) return;
          onSubmit(address, note, scheduleMode === "scheduled" && scheduledDate ? scheduledDate.toISOString() : null);
        }}>
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
        {order.scheduled_for ? (
          <div className="wf-scheduled-banner"><Clock3 size={18} /><span><strong>ออเดอร์ล่วงหน้า</strong><small>{formatDate(order.scheduled_for)}</small></span></div>
        ) : null}

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
              <div key={item.id}><span>{item.quantity}× {item.item_name}{item.item_note ? <small>{item.item_note}</small> : null}</span><b>{foodMoney(Number(item.unit_price) * item.quantity)}</b></div>
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
  const router = useRouter();
  const [snapshot, setSnapshot] = useState<FoodCustomerSnapshot | null>(null);
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
  const [reviewOrder, setReviewOrder] = useState<FoodCustomerOrder | null>(null);
  const [checkoutOpen, setCheckoutOpen] = useState(false);
  const [quote, setQuote] = useState<FoodOrderQuote | null>(null);
  const [addressDraft, setAddressDraft] = useState<FoodAddressDraft | null>(null);
  const [message, setMessage] = useState(() => opening.cartCleared ? "เปิดร้านจากลิงก์ที่แชร์ ตะกร้าเดิมถูกล้างแล้ว" : "");
  const [busy, setBusy] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [installPrompt, setInstallPrompt] = useState<InstallPromptEvent | null>(null);
  const [notificationsEnabled, setNotificationsEnabled] = useState(() => typeof window !== "undefined" && "Notification" in window && Notification.permission === "granted");
  const loadingRef = useRef(false);
  const previousOrdersRef = useRef<Map<string, string>>(new Map());

  const load = useCallback(async (quiet = false) => {
    if (loadingRef.current) return null;
    loadingRef.current = true;
    if (quiet) setRefreshing(true);
    try {
      const next = await fetchFoodCustomerSnapshot(client, userId, pickedStoreRef.current || null);
      if (!next.allowed) {
        router.replace("/");
        return null;
      }

      const previous = previousOrdersRef.current;
      for (const order of next.orders) {
        const prior = previous.get(order.id);
        if (prior && prior !== order.status) {
          setMessage(`ออเดอร์ #${order.order_number} · ${foodOrderStatusLabel(order.status)}`);
          if ("Notification" in window && Notification.permission === "granted") {
            const options = {
              body: `#${order.order_number} · ${foodOrderStatusLabel(order.status)}`,
              icon: "/icons/icon-192.png",
              badge: "/icons/icon-192.png",
              tag: `food-order-${order.id}`,
            };
            if ("serviceWorker" in navigator) {
              void navigator.serviceWorker.ready
                .then((registration) => registration.showNotification("WYNOS Food", options))
                .catch(() => undefined);
            }
          }
        }
      }
      previousOrdersRef.current = new Map(next.orders.map((order) => [order.id, order.status]));

      setSnapshot(next);
      setSelectedOrder((current) => current ? next.orders.find((order) => order.id === current.id) ?? null : null);
      return next;
    } catch (error) {
      setMessage(foodCustomerError(error, "โหลด WYNOS Food ไม่สำเร็จ"));
      return null;
    } finally {
      loadingRef.current = false;
      setRefreshing(false);
    }
  }, [client, router, userId]);

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
    localStorage.setItem(`wynos-food-cart-v1:${userId}`, JSON.stringify(cart));
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
    return sum + (item ? Number(item.price) * line.quantity : 0);
  }, 0);
  const activeCount = orders.filter((order) => !["delivered", "cancelled"].includes(order.status)).length;

  const addItem = (line: FoodCartLine) => {
    setCart((current) => {
      const exists = current.some((row) => row.menu_item_id === line.menu_item_id);
      return exists ? current.map((row) => row.menu_item_id === line.menu_item_id ? line : row) : [...current, line];
    });
    setSelectedItem(null);
    setTab("home");
    setStorefrontOpen(true);
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
    if (!("Notification" in window)) {
      setMessage("อุปกรณ์นี้ไม่รองรับการแจ้งเตือนผ่านเบราว์เซอร์");
      return;
    }
    const permission = await Notification.requestPermission();
    setNotificationsEnabled(permission === "granted");
    setMessage(permission === "granted" ? "เปิดการแจ้งเตือนแล้ว" : "ยังไม่ได้อนุญาตการแจ้งเตือน");
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

  if (!snapshot) return <FoodLoading />;
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
    <main className="wyn-food">
      <FoodHeader
        cartCount={cartCount}
        showBack={tab !== "home" || storefrontOpen}
        onBack={() => {
          if (tab === "home" && storefrontOpen) {
            setStorefrontOpen(false);
            window.scrollTo({ top: 0, behavior: "smooth" });
            return;
          }
          setTab("home");
        }}
        onCart={() => setTab("cart")}
        onRefresh={() => void load(true)}
        refreshing={refreshing}
      />
      {message ? <div className="wf-toast" role="status"><span>{message}</span><button type="button" aria-label="ปิด" onClick={() => setMessage("")}><X size={16} /></button></div> : null}

      <PullToRefreshIndicator pull={pull} topOffset="58px" refreshingLabel="กำลังอัปเดต WYNOS Food" />
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
            storefrontOpen={storefrontOpen}
          />
        ) : null}
        {tab === "orders" ? <OrdersPanel orders={orders} reviewedOrderIds={reviewedOrderIds} onOrder={setSelectedOrder} /> : null}
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

      {selectedItem && store ? (
        <ItemSheet
          client={client}
          item={selectedItem}
          existing={cart.find((line) => line.menu_item_id === selectedItem.id) ?? null}
          storeOpen={foodStoreIsEffectivelyOpen(store)}
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
