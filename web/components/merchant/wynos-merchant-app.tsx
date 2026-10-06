/* eslint-disable @next/next/no-img-element */
"use client";

import {
  ArrowUpDown,
  Bell,
  Check,
  ChevronLeft,
  ChevronRight,
  ChevronUp,
  ChevronDown,
  CircleDollarSign,
  Clock3,
  ImagePlus,
  LayoutGrid,
  ListPlus,
  LogOut,
  GripVertical,
  Eye,
  CalendarDays,
  History,
  AlertTriangle,
  MapPin,
  Menu as MenuIcon,
  PackageCheck,
  Pencil,
  Printer,
  Phone,
  Plus,
  Search,
  Share2,
  ShoppingBag,
  Store,
  Tags,
  Truck,
  Upload,
  UtensilsCrossed,
  X,
} from "lucide-react";
import type { SupabaseClient } from "@supabase/supabase-js";
import dynamic from "next/dynamic";
import Link from "next/link";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { MerchantIcon3D } from "@/components/merchant/merchant-3d-icons";
import { MerchantNavIcon } from "@/components/merchant/merchant-nav-icons";
import { MerchantNotificationPrompt } from "@/components/merchant/merchant-notification-prompt";
import { clearRequestedOrder, foodStoreShareData, requestedOrderNumber } from "@/lib/food-share";
import { shareOrCopyLink } from "@/lib/share";
import { PullToRefreshIndicator } from "@/components/ui/pull-to-refresh-indicator";
import { NewOrderAlert, useMerchantSoundUnlock } from "@/components/merchant/merchant-order-alert";
import { MERCHANT_NOTIFICATION_TEST_RESULT_KEY, setMerchantStorePublished } from "@/lib/merchant-core";
import {
  completeFoodDelivery,
  deleteMenuItem,
  deleteStorePlace,
  fetchStorePlaces,
  fetchMerchantSnapshot,
  fetchMerchantMenu,
  fetchMerchantOrdersPage,
  fetchMerchantSalesReport,
  fetchMerchantStoreReadiness,
  fetchMerchantAuditHistory,
  checkMerchantLocationQuality,
  foodPrivateSignedUrl,
  foodPublicUrl,
  merchantError,
  money,
  paymentLabel,
  saveMenuItem,
  saveStorePlace,
  saveMenuSortOrder,
  saveMenuCategoryOrder,
  setMenuSoldOutToday,
  setFoodPaymentStatus,
  setMenuAvailability,
  statusLabel,
  subscribeMerchantOrders,
  transitionFoodOrder,
  updateFoodStore,
  uploadFoodPrivateImage,
  orderDeliveryProof,
  uploadFoodPublicImage,
  type FoodMenuItem,
  type FoodMenuOptionGroup,
  type FoodOrder,
  type FoodStore,
  type FoodStorePlace,
  type MerchantAuditEntry,
  type MerchantLocationQuality,
  type MerchantSalesReport,
  type MerchantStoreReadiness,
  type MenuDraft,
  MERCHANT_ORDER_PAGE_SIZE,
} from "@/lib/food-merchant";
import { usePullToRefresh } from "@/lib/use-pull-to-refresh";
import { checkFoodServiceArea, currentFoodLocation, foodDistanceKm, foodMapsHref, parseFoodLocation, type FoodLocation, type FoodPlace } from "@/lib/food-customer";
import {
  FOOD_DAY_KEYS,
  defaultFoodBusinessSchedule,
  foodMenuIsEffectivelyAvailable,
  foodStoreIsEffectivelyOpen,
  foodStoreStatusText,
  type FoodBusinessSchedule,
} from "@/lib/food-store-availability";

// WYN-204: four bottom tabs like LINE MAN Merchant. Reports, store settings
// and campaigns open from "เพิ่มเติม" (and the home shortcuts) as sub-pages.
// WYN-205: finance, ads, WYNOS campaigns and the store's own promotions.
type MerchantTab = "home" | "orders" | "menu" | "more" | "reports" | "store" | "finance" | "ads" | "campaigns" | "promotions" | "help" | "notifications";
const MORE_PAGES: ReadonlySet<MerchantTab> = new Set(["more", "reports", "store", "finance", "ads", "campaigns", "promotions", "help", "notifications"]);
const MERCHANT_STORE_KEY = "wynos-merchant-store-v1";
type OrderFilter = "new" | "cooking" | "delivery" | "done";

function MerchantChunkLoading() {
  return (
    <div className="wm-chunk-loading" aria-label="กำลังเปิด">
      <span className="wm-mini-loader" />
    </div>
  );
}

// Keep the launch bundle focused on Home / Orders / Menu. Secondary tools,
// maps, finance, QR and campaign code are fetched only when needed, then
// warmed during idle time below so subsequent taps still feel native-fast.
const FoodDeliveryMapPicker = dynamic(
  () => import("@/components/food/food-delivery-map-picker").then((mod) => mod.FoodDeliveryMapPicker),
  { loading: MerchantChunkLoading },
);
const FoodLocationMapPreview = dynamic(
  () => import("@/components/food/food-delivery-map-picker").then((mod) => mod.FoodLocationMapPreview),
  { loading: MerchantChunkLoading },
);
const MerchantCampaignCenter = dynamic(
  () => import("@/components/merchant/merchant-campaign-center").then((mod) => mod.MerchantCampaignCenter),
  { loading: MerchantChunkLoading },
);
const MerchantStoreTools = dynamic(
  () => import("@/components/merchant/merchant-core-panels").then((mod) => mod.MerchantStoreTools),
  { loading: MerchantChunkLoading },
);
const RefundControls = dynamic(
  () => import("@/components/merchant/merchant-core-panels").then((mod) => mod.RefundControls),
  { loading: MerchantChunkLoading },
);
const MerchantAds = dynamic(
  () => import("@/components/merchant/merchant-ads").then((mod) => mod.MerchantAds),
  { loading: MerchantChunkLoading },
);
const MerchantFinance = dynamic(
  () => import("@/components/merchant/merchant-finance").then((mod) => mod.MerchantFinance),
  { loading: MerchantChunkLoading },
);
const MerchantNotificationSettings = dynamic(
  () => import("@/components/merchant/merchant-notification-settings").then((mod) => mod.MerchantNotificationSettings),
  { loading: MerchantChunkLoading },
);
const MerchantPlatformCampaigns = dynamic(
  () => import("@/components/merchant/merchant-platform-campaigns").then((mod) => mod.MerchantPlatformCampaigns),
  { loading: MerchantChunkLoading },
);
const MerchantShareCard = dynamic(
  () => import("@/components/merchant/merchant-share-card").then((mod) => mod.MerchantShareCard),
  { loading: MerchantChunkLoading },
);

type InstallPromptEvent = Event & {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: "accepted" | "dismissed" }>;
};

const EMPTY_MENU_DRAFT: MenuDraft = {
  name: "",
  category: "อาหาร",
  description: "",
  price: "",
  image_path: null,
  options: [],
  is_available: true,
  daily_stock_limit: "",
};

function menuDraftFromItem(item: FoodMenuItem): MenuDraft {
  return {
    id: item.id,
    name: item.name,
    category: item.category,
    description: item.description ?? "",
    price: String(item.price),
    image_path: item.image_path,
    options: Array.isArray(item.options) ? item.options : [],
    is_available: item.is_available,
    sold_out_until: item.sold_out_until ?? null,
    daily_stock_limit: item.daily_stock_limit == null ? "" : String(item.daily_stock_limit),
  };
}

function menuOptionId(prefix: "group" | "choice") {
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

const FOOD_DAY_LABELS: Record<string, string> = {
  mon: "จันทร์", tue: "อังคาร", wed: "พุธ", thu: "พฤหัสบดี", fri: "ศุกร์", sat: "เสาร์", sun: "อาทิตย์",
};

function localDateTimeInput(value: string | null | undefined) {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  const offset = date.getTimezoneOffset();
  return new Date(date.getTime() - offset * 60000).toISOString().slice(0, 16);
}

function localFutureInput(minutes: number) {
  const date = new Date(Date.now() + minutes * 60000);
  const offset = date.getTimezoneOffset();
  return new Date(date.getTime() - offset * 60000).toISOString().slice(0, 16);
}

// WYN-198: four simple tabs, in the order the store works through them.
const ORDER_FILTERS: Array<{ key: OrderFilter; label: string }> = [
  { key: "new", label: "ใหม่" },
  { key: "cooking", label: "กำลังทำ" },
  { key: "delivery", label: "กำลังส่ง" },
  { key: "done", label: "เสร็จแล้ว" },
];

function orderInFilter(order: FoodOrder, filter: OrderFilter) {
  if (filter === "new") return order.status === "pending_acceptance";
  if (filter === "cooking") return order.status === "preparing" || order.status === "ready_for_delivery";
  if (filter === "delivery") return order.status === "out_for_delivery";
  return order.status === "delivered" || order.status === "cancelled";
}

/** An order the store can accept now: it is new and the customer has paid or sent a slip. */
function needsStoreNow(order: FoodOrder) {
  return order.status === "pending_acceptance" && (order.payment_status === "submitted" || order.payment_status === "paid");
}

/** A new slip (new storage path) alerts again; marking it paid does not. */
function alertKey(order: FoodOrder) {
  return `${order.id}:${order.payment_slip_path ?? "no-slip"}`;
}

type QuickStep = "check_slip" | "accept" | "ready" | "dispatch" | "deliver";

/**
 * WYN-198: the one main action for an order, shown on its card. Steps that
 * need a look (the slip) or a photo (delivery) open the order instead.
 */
function quickStep(order: FoodOrder): { step: QuickStep; label: string } | null {
  if (order.status === "pending_acceptance") {
    if (order.payment_status === "submitted") return { step: "check_slip", label: "ดูสลิป · รับออเดอร์" };
    if (order.payment_status === "paid") return { step: "accept", label: "รับออเดอร์" };
    return null;
  }
  if (order.status === "preparing") return { step: "ready", label: "อาหารพร้อมแล้ว" };
  if (order.status === "ready_for_delivery") return { step: "dispatch", label: "เริ่มจัดส่ง" };
  if (order.status === "out_for_delivery") return { step: "deliver", label: "ส่งถึงแล้ว · แนบรูป" };
  return null;
}

function waitingNote(order: FoodOrder) {
  if (order.status !== "pending_acceptance") return null;
  if (order.payment_status === "pending") return "รอลูกค้าโอนเงิน";
  if (order.payment_status === "issue") return "รอลูกค้าส่งสลิปใหม่";
  return null;
}

const MERCHANT_TIME_FORMATTER = new Intl.DateTimeFormat("th-TH", {
  hour: "2-digit",
  minute: "2-digit",
});
const MERCHANT_DATE_TIME_FORMATTER = new Intl.DateTimeFormat("th-TH", {
  dateStyle: "medium",
  timeStyle: "short",
});

function shortTime(value: string) {
  return MERCHANT_TIME_FORMATTER.format(new Date(value));
}

function OrderStatus({ order }: { order: FoodOrder }) {
  const tone = order.status === "pending_acceptance"
    ? "new"
    : order.status === "preparing"
      ? "preparing"
      : order.status === "ready_for_delivery"
        ? "ready"
        : order.status === "out_for_delivery"
          ? "delivery"
          : order.status === "delivered"
            ? "done"
            : "muted";
  return <span className={`wm-status wm-status--${tone}`}>{statusLabel(order.status)}</span>;
}

function PaymentStatus({ order }: { order: FoodOrder }) {
  const tone = order.payment_status === "paid"
    ? "done"
    : order.payment_status === "submitted"
      ? "new"
      : order.payment_status === "issue"
        ? "danger"
        : "muted";
  return <span className={`wm-status wm-status--${tone}`}>{paymentLabel(order.payment_status)}</span>;
}

function MerchantLoading() {
  return (
    <main className="wyn-merchant wm-loading-shell" aria-label="กำลังโหลด WYNOS Merchant" aria-busy="true">
      <header className="wm-header">
        <div className="wm-brand"><span>WYNOS</span><b>Merchant</b></div>
        <span className="wm-mini-loader" aria-hidden="true" />
      </header>
      <section className="wm-content">
        <section className="wm-hero wm-skeleton-hero" aria-hidden="true">
          <div className="wm-skeleton-line wm-skeleton-line--short" />
          <div className="wm-skeleton-line wm-skeleton-line--title" />
          <div className="wm-skeleton-block" />
          <div className="wm-skeleton-switch" />
        </section>
        <div className="wm-skeleton-actions" aria-hidden="true">
          <i /><i /><i /><i />
        </div>
        <section className="wm-section" aria-hidden="true">
          <div className="wm-skeleton-line wm-skeleton-line--medium" />
          <div className="wm-skeleton-order" />
          <div className="wm-skeleton-order" />
        </section>
      </section>
      <nav className="wm-nav wm-nav--loading" aria-hidden="true">
        <span><MerchantNavIcon name="home" active /><small>หน้าหลัก</small></span>
        <span><MerchantNavIcon name="orders" active={false} /><small>รับออเดอร์</small></span>
        <span><MerchantNavIcon name="menu" active={false} /><small>เมนู</small></span>
        <span><MerchantNavIcon name="more" active={false} /><small>เพิ่มเติม</small></span>
      </nav>
    </main>
  );
}

function MerchantBlocked({ signOut }: { signOut: () => Promise<void> }) {
  return (
    <main className="wm-blocked">
      <div className="wm-blocked-mark"><Store size={34} strokeWidth={1.7} /></div>
      <h1>WYNOS Merchant</h1>
      <p>บัญชีนี้ยังไม่ได้เปิดสิทธิ์ Merchant</p>
      <Link className="wm-primary wm-link-button" href="/merchant/signup">สมัคร WYNOS Merchant</Link>
      <button className="wm-auth-secondary" type="button" onClick={() => void signOut()}>ออกจากระบบ</button>
      <Link className="wm-secondary-link" href="/">กลับ WYNOS</Link>
    </main>
  );
}

function Metric({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <div className="wm-metric">
      <small>{label}</small>
      <strong>{value}</strong>
      {hint ? <span>{hint}</span> : null}
    </div>
  );
}

function OrderCard({
  order,
  onOpen,
  onAction,
  acting = false,
}: {
  order: FoodOrder;
  onOpen: () => void;
  onAction?: (order: FoodOrder) => void;
  acting?: boolean;
}) {
  const next = quickStep(order);
  const note = waitingNote(order);
  return (
    <article className={`wm-order-card ${needsStoreNow(order) ? "is-urgent" : ""}`}>
      {/* Opening is locked too while the card's step runs, so the sheet cannot repeat it. */}
      <button className="wm-order-card-open" type="button" disabled={acting} onClick={onOpen}>
      <div className="wm-order-card-top">
        <span>
          <strong>#{order.order_number}</strong>
          <small>{shortTime(order.created_at)} · {order.source === "manual" ? "ร้านสร้าง" : order.source === "social" ? "WYNOS Social" : "WYNOS Food"}</small>
        </span>
        <b>{money(order.total)}</b>
      </div>
      <div className="wm-order-card-customer">
        <span>{order.recipient_name}</span>
        <small>{order.food_order_items?.reduce((sum, item) => sum + item.quantity, 0) ?? 0} รายการ</small>
      </div>
      <div className="wm-order-card-footer">
        <OrderStatus order={order} />
        <PaymentStatus order={order} />
        <ChevronRight size={18} strokeWidth={1.8} />
      </div>
      </button>
      {next && onAction ? (
        <button className="wm-primary wm-full wm-card-action" type="button" disabled={acting} onClick={() => onAction(order)}>
          {acting ? "กำลังบันทึก…" : next.label}
        </button>
      ) : note ? <p className="wm-card-note">{note}</p> : null}
    </article>
  );
}

function MerchantInner({
  client,
  userId,
  signOut,
}: {
  client: SupabaseClient;
  userId: string;
  signOut: () => Promise<void>;
}) {
  const [tab, setTab] = useState<MerchantTab>("home");
  const [stores, setStores] = useState<FoodStore[]>([]);
  const [store, setStore] = useState<FoodStore | null>(null);
  const [menu, setMenu] = useState<FoodMenuItem[]>([]);
  const [orders, setOrders] = useState<FoodOrder[]>([]);
  const [ordersHasMore, setOrdersHasMore] = useState(false);
  const [salesReportState, setSalesReportState] = useState<{
    storeId: string;
    report: MerchantSalesReport | null;
    error: string;
  } | null>(null);
  const [salesReportRevision, setSalesReportRevision] = useState(0);
  const [loadingMoreOrders, setLoadingMoreOrders] = useState(false);
  const [selectedStoreId, setSelectedStoreId] = useState<string | null>(() => {
    if (typeof window === "undefined") return null;
    return window.localStorage.getItem(MERCHANT_STORE_KEY);
  });
  const [access, setAccess] = useState<boolean | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [message, setMessage] = useState("");
  const [selectedOrder, setSelectedOrder] = useState<FoodOrder | null>(null);
  // A tapped order notification (?order=WF0015) opens that order once loaded.
  const requestedOrderRef = useRef<string | null>(typeof window === "undefined" ? null : requestedOrderNumber(window.location.search));
  const [orderFilter, setOrderFilter] = useState<OrderFilter>("new");
  // WYN-198: one-tap card actions and the new-order alert.
  // Order id -> the status it had when the store pressed its card button. The
  // card stays busy until a reload shows a different status (or the call fails),
  // so a stale card can never send the same step twice.
  const [actedFrom, setActedFrom] = useState<ReadonlyMap<string, FoodOrder["status"]>>(() => new Map());
  const forgetAction = (orderId: string) => setActedFrom((current) => {
    const next = new Map(current);
    next.delete(orderId);
    return next;
  });
  const [seenAlerts, setSeenAlerts] = useState<Set<string>>(() => new Set());
  const soundReady = useMerchantSoundUnlock();
  // WYN-199: ask once when Merchant opens. The bell now opens the full notification center.
  const [notifyPrompt, setNotifyPrompt] = useState<"auto" | null>("auto");
  const [menuQuery, setMenuQuery] = useState("");
  const [menuDraft, setMenuDraft] = useState<MenuDraft | null>(null);
  const [menuAddOpen, setMenuAddOpen] = useState(false);
  const [menuToolMode, setMenuToolMode] = useState<"options" | "categories" | null>(null);
  const [storeEditing, setStoreEditing] = useState(false);
  const [installPrompt, setInstallPrompt] = useState<InstallPromptEvent | null>(null);
  const [notificationsEnabled, setNotificationsEnabled] = useState(() => typeof window !== "undefined" && "Notification" in window && Notification.permission === "granted");
  const loadingRef = useRef(false);
  // A refresh asked for while one is running runs once more afterwards, so
  // the last realtime event or action always shows its final state.
  const reloadQueuedRef = useRef(false);
  const paymentStatusRef = useRef<Map<string, FoodOrder["payment_status"]>>(new Map());
  const orderRefreshTimerRef = useRef<number | null>(null);

  const load = useCallback(async (quiet = false) => {
    if (loadingRef.current) {
      reloadQueuedRef.current = true;
      return;
    }
    loadingRef.current = true;
    if (!quiet) setLoading(true);
    else setRefreshing(true);
    if (!quiet) setMessage("");
    try {
      const next = await fetchMerchantSnapshot(client, selectedStoreId);
      setAccess(next.access);
      setStores(next.stores);
      setStore(next.store);
      setMenu(next.menu);
      setOrders(next.orders);
      setOrdersHasMore(next.has_more_orders);
      if (next.store && next.store.id !== selectedStoreId) setSelectedStoreId(next.store.id);
      paymentStatusRef.current = new Map(next.orders.map((order) => [order.id, order.payment_status]));
      const requested = requestedOrderRef.current;
      const requestedOrder = requested ? next.orders.find((order) => order.order_number === requested) ?? null : null;
      if (requested) {
        requestedOrderRef.current = null;
        clearRequestedOrder();
        setTab("orders");
      }
      if (requestedOrder) setSelectedOrder(requestedOrder);
      else setSelectedOrder((current) => current ? next.orders.find((order) => order.id === current.id) ?? null : null);
      return next;
    } catch (error) {
      setMessage(merchantError(error, "โหลดข้อมูลร้านไม่สำเร็จ"));
    } finally {
      loadingRef.current = false;
      setLoading(false);
      setRefreshing(false);
      if (reloadQueuedRef.current) {
        reloadQueuedRef.current = false;
        void loadRef.current?.(true);
      }
    }
  }, [client, selectedStoreId]);
  const loadRef = useRef<typeof load | null>(null);
  useEffect(() => { loadRef.current = load; }, [load]);

  // Order events are by far the hottest realtime path. Refresh only the order
  // window instead of re-reading Merchant access, stores and the full menu.
  const refreshOrders = useCallback(async () => {
    if (!store?.id) return;
    try {
      const page = await fetchMerchantOrdersPage(client, store.id, 0, MERCHANT_ORDER_PAGE_SIZE);
      paymentStatusRef.current = new Map(page.orders.map((order) => [order.id, order.payment_status]));
      setOrders((current) => {
        const freshIds = new Set(page.orders.map((order) => order.id));
        const older = current.filter((order) => !freshIds.has(order.id));
        return [...page.orders, ...older];
      });
      setOrdersHasMore((current) => current || page.hasMore);
      setSelectedOrder((current) => {
        if (!current) return null;
        return page.orders.find((order) => order.id === current.id) ?? current;
      });
    } catch (error) {
      setMessage(merchantError(error, "อัปเดตออเดอร์ไม่สำเร็จ"));
    }
  }, [client, store]);

  const scheduleOrderRefresh = useCallback(() => {
    if (typeof window === "undefined") return;
    if (orderRefreshTimerRef.current != null) window.clearTimeout(orderRefreshTimerRef.current);
    orderRefreshTimerRef.current = window.setTimeout(() => {
      orderRefreshTimerRef.current = null;
      void refreshOrders();
    }, 80);
  }, [refreshOrders]);

  const refreshMenu = useCallback(async () => {
    if (!store?.id) return;
    try {
      setMenu(await fetchMerchantMenu(client, store.id));
    } catch (error) {
      setMessage(merchantError(error, "อัปเดตเมนูไม่สำเร็จ"));
    }
  }, [client, store]);

  useEffect(() => {
    if (!selectedStoreId || typeof window === "undefined") return;
    window.localStorage.setItem(MERCHANT_STORE_KEY, selectedStoreId);
  }, [selectedStoreId]);

  useEffect(() => {
    const timer = window.setTimeout(() => void load(), 0);
    return () => window.clearTimeout(timer);
  }, [load]);

  useEffect(() => {
    if (!store?.id) return;
    let live = true;
    const storeId = store.id;
    void fetchMerchantSalesReport(client, storeId)
      .then((next) => {
        if (live) setSalesReportState({ storeId, report: next, error: "" });
      })
      .catch((reason) => {
        if (!live) return;
        const error = merchantError(reason, "โหลดรายงานไม่สำเร็จ กรุณาลองใหม่");
        setSalesReportState((current) => current?.storeId === storeId
          ? { ...current, error }
          : { storeId, report: null, error });
      });
    return () => { live = false; };
  }, [client, store?.id, salesReportRevision]);

  // Keep the last good numbers on screen while a fresh report loads, like a
  // native app's stale-while-revalidate cache. Store changes still isolate data.
  const currentSalesReport = store && salesReportState?.storeId === store.id
    ? salesReportState.report
    : null;
  const currentSalesReportError = store && salesReportState?.storeId === store.id
    ? salesReportState.error
    : "";

  useEffect(() => {
    if (typeof window === "undefined") return;
    const url = new URL(window.location.href);
    if (url.searchParams.get("notification-test") !== "1") return;

    try {
      const raw = JSON.parse(window.sessionStorage.getItem(MERCHANT_NOTIFICATION_TEST_RESULT_KEY) ?? "{}") as Record<string, unknown>;
      window.sessionStorage.setItem(MERCHANT_NOTIFICATION_TEST_RESULT_KEY, JSON.stringify({
        ...raw,
        deep_link: { status: "pass", detail: "Deep Link ผ่านแล้ว" },
      }));
    } catch {
      // Deep Link still worked even if private browsing blocks storage.
    }

    url.searchParams.delete("notification-test");
    const nextUrl = `${url.pathname}${url.search}${url.hash}`;
    window.history.replaceState(window.history.state, "", nextUrl);

    const timer = window.setTimeout(() => {
      setTab("store");
      setMessage("ทดสอบ Deep Link สำเร็จแล้ว");
      window.dispatchEvent(new Event("wynos:merchant-notification-test-deep-link"));
    }, 0);
    return () => window.clearTimeout(timer);
  }, []);

  useEffect(() => {
    if (!store?.id) return;
    const channel = subscribeMerchantOrders(client, store.id, (payload) => {
      const next = payload.new as Partial<FoodOrder>;
      if (payload.eventType === "INSERT") {
        if (typeof next.id === "string" && next.payment_status) paymentStatusRef.current.set(next.id, next.payment_status);
        if (typeof navigator !== "undefined" && "vibrate" in navigator) navigator.vibrate?.([180, 80, 180]);
        if (typeof window !== "undefined" && "Notification" in window && Notification.permission === "granted") {
          const options = {
            body: `#${String(next.order_number ?? "")} · ${money(next.total as number | string | undefined)}`,
            icon: "/icons/icon-192.png",
            badge: "/icons/icon-192.png",
            tag: String(next.id ?? "wynos-food-order"),
          };
          if ("serviceWorker" in navigator) {
            void navigator.serviceWorker.ready
              .then((registration) => registration.showNotification("WYNOS Merchant · ออเดอร์ใหม่", options))
              .catch(() => undefined);
          } else {
            try { new Notification("WYNOS Merchant · ออเดอร์ใหม่", options); } catch { /* best effort */ }
          }
        }
      } else if (payload.eventType === "UPDATE" && typeof next.id === "string" && next.payment_status) {
        const previousPayment = paymentStatusRef.current.get(next.id);
        paymentStatusRef.current.set(next.id, next.payment_status);
        if (previousPayment && previousPayment !== next.payment_status) {
          if (next.payment_status === "submitted") {
            setMessage(`ออเดอร์ #${String(next.order_number ?? "")} · ลูกค้าส่งสลิปแล้ว`);
            if (typeof navigator !== "undefined" && "vibrate" in navigator) navigator.vibrate?.([120, 70, 120]);
          } else if (next.payment_status === "paid") {
            setMessage(`ออเดอร์ #${String(next.order_number ?? "")} · ชำระเงินแล้ว`);
          } else if (next.payment_status === "issue") {
            setMessage(`ออเดอร์ #${String(next.order_number ?? "")} · การชำระเงินมีปัญหา`);
          }
        }
      }
      const previous = payload.old as Partial<FoodOrder>;
      if (next.status === "delivered" || previous.status === "delivered") {
        setSalesReportRevision((value) => value + 1);
      }
      scheduleOrderRefresh();
    });
    return () => {
      if (orderRefreshTimerRef.current != null) window.clearTimeout(orderRefreshTimerRef.current);
      orderRefreshTimerRef.current = null;
      void client.removeChannel(channel);
    };
  }, [client, scheduleOrderRefresh, store?.id]);

  useEffect(() => {
    if (typeof window === "undefined") return;
    const handler = (event: Event) => {
      event.preventDefault();
      setInstallPrompt(event as InstallPromptEvent);
    };
    window.addEventListener("beforeinstallprompt", handler);
    return () => window.removeEventListener("beforeinstallprompt", handler);
  }, []);


  useEffect(() => {
    if (loading || !store?.id || typeof window === "undefined") return;
    const hints = (navigator as Navigator & {
      connection?: { saveData?: boolean; effectiveType?: string };
    }).connection;
    if (!navigator.onLine || hints?.saveData || hints?.effectiveType === "slow-2g" || hints?.effectiveType === "2g") return;

    const warmSecondaryTools = () => {
      if (document.visibilityState !== "visible") return;
      void Promise.allSettled([
        import("@/components/merchant/merchant-finance"),
        import("@/components/merchant/merchant-notification-settings"),
        import("@/components/merchant/merchant-core-panels"),
        import("@/components/merchant/merchant-campaign-center"),
        import("@/components/merchant/merchant-platform-campaigns"),
        import("@/components/merchant/merchant-ads"),
        import("@/components/food/food-delivery-map-picker"),
      ]);
    };

    if (typeof window.requestIdleCallback === "function") {
      const handle = window.requestIdleCallback(warmSecondaryTools, { timeout: 1800 });
      return () => window.cancelIdleCallback(handle);
    }
    const timer = window.setTimeout(warmSecondaryTools, 900);
    return () => window.clearTimeout(timer);
  }, [loading, store]);

  const install = async () => {
    if (!installPrompt) return;
    await installPrompt.prompt();
    await installPrompt.userChoice;
    setInstallPrompt(null);
  };

  const chooseStore = (storeId: string) => {
    if (!storeId || storeId === store?.id) return;
    setSelectedOrder(null);
    setMenuDraft(null);
    setStoreEditing(false);
    setSeenAlerts(new Set<string>());
    setActedFrom(new Map<string, FoodOrder["status"]>());
    setOrderFilter("new");
    setTab("home");
    setSelectedStoreId(storeId);
  };

  const loadMoreOrders = async () => {
    if (!store || loadingMoreOrders || !ordersHasMore) return;
    setLoadingMoreOrders(true);
    try {
      const page = await fetchMerchantOrdersPage(client, store.id, orders.length, MERCHANT_ORDER_PAGE_SIZE);
      setOrders((current) => {
        const known = new Set(current.map((order) => order.id));
        return [...current, ...page.orders.filter((order) => !known.has(order.id))];
      });
      setOrdersHasMore(page.hasMore);
    } catch (error) {
      setMessage(merchantError(error, "โหลดออเดอร์เพิ่มเติมไม่สำเร็จ"));
    } finally {
      setLoadingMoreOrders(false);
    }
  };

  // Every unfinished order counts on the "รับออเดอร์" nav badge.
  const activeOrderCount = useMemo(
    () => orders.filter((order) => order.status !== "delivered" && order.status !== "cancelled").length,
    [orders],
  );
  const filteredOrders = useMemo(() => orders.filter((order) => orderInFilter(order, orderFilter)), [orderFilter, orders]);
  const alertQueue = useMemo(
    () => orders.filter((order) => needsStoreNow(order) && !seenAlerts.has(alertKey(order))),
    [orders, seenAlerts],
  );
  const alertOrder = alertQueue[0] ?? null;
  const markAlertSeen = (order: FoodOrder) => setSeenAlerts((current) => new Set(current).add(alertKey(order)));

  const applyLocalOrderStatus = (orderId: string, status: FoodOrder["status"]) => {
    const updatedAt = new Date().toISOString();
    setOrders((current) => current.map((item) => item.id === orderId ? { ...item, status, updated_at: updatedAt } : item));
    setSelectedOrder((current) => current?.id === orderId ? { ...current, status, updated_at: updatedAt } : current);
  };

  const quickAction = async (order: FoodOrder) => {
    const next = quickStep(order);
    if (!next) return;
    if (next.step === "check_slip" || next.step === "deliver") {
      setSelectedOrder(order);
      return;
    }
    if (actedFrom.get(order.id) === order.status) return;
    setActedFrom((current) => new Map(current).set(order.id, order.status));
    try {
      if (next.step === "accept") {
        await transitionFoodOrder(client, order.id, "preparing", order.eta_minutes ?? Number(store?.prep_time_max_minutes ?? 30));
        applyLocalOrderStatus(order.id, "preparing");
        setMessage(`รับออเดอร์ #${order.order_number} แล้ว`);
      } else if (next.step === "ready") {
        await transitionFoodOrder(client, order.id, "ready_for_delivery");
        applyLocalOrderStatus(order.id, "ready_for_delivery");
        setMessage(`ออเดอร์ #${order.order_number} อาหารพร้อมแล้ว`);
      } else {
        await transitionFoodOrder(client, order.id, "out_for_delivery");
        applyLocalOrderStatus(order.id, "out_for_delivery");
        setMessage(`ออเดอร์ #${order.order_number} เริ่มจัดส่งแล้ว`);
      }
    } catch (error) {
      setMessage(merchantError(error));
      forgetAction(order.id);
    } finally {
      // Reload on failure too: the order may have moved on elsewhere.
      // Keep the hot order flow lightweight: the realtime event usually wins,
      // and this debounced order-only refresh is the safety net if it does not.
      scheduleOrderRefresh();
    }
  };

  // WYN-201: pull down to refresh on the list tabs (forms and sheets are
  // excluded by the hook: dialogs and inputs never start a pull).
  const pull = usePullToRefresh({
    enabled: tab === "home" || tab === "orders" || tab === "menu" || tab === "reports" || tab === "finance",
    onRefresh: async () => {
      await load(true);
      setSalesReportRevision((value) => value + 1);
    },
  });

  if (loading && access === null) return <MerchantLoading />;
  if (access === false) return <MerchantBlocked signOut={signOut} />;

  return (
    <main className="wyn-merchant">
      <header className="wm-header">
        <div className="wm-brand-stack">
          <div className="wm-brand">
            <span>WYNOS</span>
            <b>Merchant</b>
          </div>
          {stores.length > 1 ? (
            <label className="wm-store-switcher">
              <Store size={13} strokeWidth={1.8} />
              <span className="sr-only">เลือกร้าน</span>
              <select value={selectedStoreId ?? store?.id ?? ""} onChange={(event) => chooseStore(event.target.value)}>
                {stores.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
              </select>
            </label>
          ) : null}
        </div>
        <div className="wm-header-actions">
          <button
            className={`wm-icon-button ${notificationsEnabled ? "is-active" : ""}`}
            type="button"
            aria-label="การแจ้งเตือน"
            onClick={() => setTab("notifications")}
          >
            <Bell size={21} strokeWidth={1.8} />
          </button>
          {refreshing ? <span className="wm-mini-loader" aria-label="กำลังอัปเดต" /> : (
            <button
              className="wm-icon-button"
              type="button"
              aria-label="อัปเดตข้อมูล"
              onClick={() => {
                void load(true);
                setSalesReportRevision((value) => value + 1);
              }}
            >
              <Clock3 size={21} strokeWidth={1.8} />
            </button>
          )}
        </div>
      </header>

      {message ? (
        <div className="wm-toast" role="status">
          <span>{message}</span>
          <button type="button" aria-label="ปิด" onClick={() => setMessage("")}><X size={16} /></button>
        </div>
      ) : null}

      <PullToRefreshIndicator pull={pull} topOffset="58px" refreshingLabel="กำลังอัปเดตข้อมูลร้าน" />
      <section className="wm-content" onTouchStart={pull.onTouchStart} onTouchMove={pull.onTouchMove} onTouchEnd={pull.onTouchEnd} onTouchCancel={pull.onTouchCancel}>
        {tab === "home" && store ? (
          <HomePanel
            client={client}
            store={store}
            menu={menu}
            todayOrderCount={currentSalesReport?.today_orders ?? null}
            todaySales={currentSalesReport?.today_sales ?? null}
            installPrompt={installPrompt}
            onInstall={() => void install()}
            onReload={() => void load(true)}
            onOpenTab={setTab}
            onEditStore={() => setStoreEditing(true)}
            onMessage={setMessage}
          />
        ) : null}

        {tab === "orders" && store ? (
          <OrdersPanel
            orders={filteredOrders}
            allOrders={orders}
            filter={orderFilter}
            onFilter={setOrderFilter}
            onOpen={setSelectedOrder}
            onAction={(order) => void quickAction(order)}
            actedFrom={actedFrom}
            hasMore={ordersHasMore}
            loadingMore={loadingMoreOrders}
            onLoadMore={() => void loadMoreOrders()}
          />
        ) : null}

        {tab === "menu" && store ? (
          <MenuPanel
            client={client}
            store={store}
            menu={menu}
            query={menuQuery}
            onQuery={setMenuQuery}
            onEdit={(item) => setMenuDraft(menuDraftFromItem(item))}
            onAdd={() => setMenuAddOpen(true)}
            onToggle={async (item) => {
              try {
                await setMenuAvailability(client, store.id, item.id, !item.is_available);
                await refreshMenu();
              } catch (error) { setMessage(merchantError(error)); }
            }}
            onSoldOut={async (item, soldOut) => {
              try {
                await setMenuSoldOutToday(client, store.id, item.id, soldOut);
                setMessage(soldOut ? "ตั้งเมนูหมดวันนี้แล้ว ระบบจะเปิดให้อัตโนมัติวันถัดไป" : "เปิดเมนูกลับแล้ว");
                await refreshMenu();
              } catch (error) { setMessage(merchantError(error)); }
            }}
            onReorder={async (ids) => {
              try { await saveMenuSortOrder(client, store.id, ids); await refreshMenu(); }
              catch (error) { setMessage(merchantError(error)); }
            }}
            onCategoryOrder={async (categories) => {
              try { await saveMenuCategoryOrder(client, store.id, categories); await load(true); }
              catch (error) { setMessage(merchantError(error)); }
            }}
          />
        ) : null}

        {MORE_PAGES.has(tab) && tab !== "more" ? (
          <button className="wm-back" type="button" onClick={() => setTab("more")}><ChevronLeft size={20} />เพิ่มเติม</button>
        ) : null}

        {tab === "more" && store ? (
          <MorePanel
            client={client}
            store={store}
            installPrompt={installPrompt}
            onInstall={() => void install()}
            onOpenTab={setTab}
            onSignOut={() => void signOut()}
          />
        ) : null}

        {tab === "reports" && store ? <ReportsPanel report={currentSalesReport} error={currentSalesReportError} /> : null}

        {tab === "notifications" && store ? (
          <MerchantNotificationSettings
            client={client}
            store={store}
            userId={userId}
            onMessage={setMessage}
            onPushChange={setNotificationsEnabled}
            onReload={async () => { await load(true); }}
          />
        ) : null}

        {tab === "help" && store ? <HelpPanel store={store} onMessage={setMessage} /> : null}

        {tab === "finance" && store ? <MerchantFinance client={client} store={store} refreshKey={orders} onEditStore={() => setStoreEditing(true)} onOpenTab={setTab} /> : null}

        {tab === "promotions" && store ? (
          <>
            <div className="wm-page-heading"><div><small>ส่วนลดที่ร้านตั้งเอง</small><h1>โปรโมชั่น</h1></div></div>
            <MerchantCampaignCenter client={client} store={store} menu={menu} onMessage={setMessage} />
          </>
        ) : null}

        {tab === "campaigns" && store ? (
          <>
            <div className="wm-page-heading"><div><small>จาก WYNOS</small><h1>แคมเปญ</h1></div></div>
            <MerchantPlatformCampaigns client={client} store={store} onMessage={setMessage} />
          </>
        ) : null}

        {tab === "ads" && store ? (
          <>
            <div className="wm-page-heading"><div><small>ดันร้านให้ลูกค้าเห็นก่อน</small><h1>โฆษณา</h1></div></div>
            <MerchantAds client={client} store={store} onMessage={setMessage} />
          </>
        ) : null}

        {tab === "store" && store ? (
          <StorePanel
            client={client}
            store={store}
            menu={menu}
            userId={userId}
            installPrompt={installPrompt}
            onInstall={() => void install()}
            onEdit={() => setStoreEditing(true)}
            onReload={() => void load(true)}
            onMessage={setMessage}
            onSignOut={() => void signOut()}
          />
        ) : null}

        {!store && access ? (
          <div className="wm-empty">
            <Store size={38} strokeWidth={1.5} />
            <strong>ยังไม่พบร้านค้า</strong>
            <p>ฐานข้อมูล Merchant ยังไม่มีร้านที่บัญชีนี้เข้าถึงได้</p>
          </div>
        ) : null}
      </section>

      <nav className="wm-nav" aria-label="WYNOS Merchant">
        <NavButton active={tab === "home"} label="หน้าหลัก" icon={<MerchantNavIcon name="home" active={tab === "home"} />} onClick={() => setTab("home")} />
        <NavButton active={tab === "orders"} label="รับออเดอร์" icon={<MerchantNavIcon name="orders" active={tab === "orders"} />} badge={activeOrderCount} onClick={() => setTab("orders")} />
        <NavButton active={tab === "menu"} label="เมนู" icon={<MerchantNavIcon name="menu" active={tab === "menu"} />} onClick={() => setTab("menu")} />
        <NavButton active={MORE_PAGES.has(tab)} label="เพิ่มเติม" icon={<MerchantNavIcon name="more" active={MORE_PAGES.has(tab)} />} onClick={() => setTab("more")} />
      </nav>

      {notifyPrompt && store && !alertOrder && !selectedOrder && !menuDraft && !menuAddOpen && !menuToolMode && !storeEditing ? (
        <MerchantNotificationPrompt
          key={notifyPrompt}
          client={client}
          userId={userId}
          forceOpen={false}
          onClose={() => setNotifyPrompt(null)}
          onEnabled={() => setNotificationsEnabled(true)}
        />
      ) : null}

      {alertOrder && !selectedOrder && !menuDraft && !menuAddOpen && !menuToolMode && !storeEditing ? (
        <NewOrderAlert
          key={alertKey(alertOrder)}
          order={alertOrder}
          count={alertQueue.length}
          soundReady={soundReady}
          onOpen={() => { markAlertSeen(alertOrder); setSelectedOrder(alertOrder); }}
        />
      ) : null}

      {selectedOrder && store ? (
        <OrderSheet
          client={client}
          store={store}
          order={selectedOrder}
          onClose={() => setSelectedOrder(null)}
          onReload={() => void load(true)}
          onMessage={setMessage}
        />
      ) : null}

      {menuAddOpen && store ? (
        <MenuAddHub
          onClose={() => setMenuAddOpen(false)}
          onNewMenu={() => {
            setMenuAddOpen(false);
            setMenuDraft({ ...EMPTY_MENU_DRAFT });
          }}
          onOptions={() => {
            setMenuAddOpen(false);
            setMenuToolMode("options");
          }}
          onCategories={() => {
            setMenuAddOpen(false);
            setMenuToolMode("categories");
          }}
        />
      ) : null}

      {menuToolMode === "options" && store ? (
        <MenuOptionPicker
          client={client}
          menu={menu}
          onClose={() => setMenuToolMode(null)}
          onPick={(item) => {
            setMenuToolMode(null);
            setMenuDraft(menuDraftFromItem(item));
          }}
        />
      ) : null}

      {menuToolMode === "categories" && store ? (
        <MenuCategoryManager
          client={client}
          store={store}
          menu={menu}
          onClose={() => setMenuToolMode(null)}
          onSaved={async () => {
            setMenuToolMode(null);
            await load(true);
          }}
          onMessage={setMessage}
        />
      ) : null}

      {menuDraft && store ? (
        <MenuEditor
          client={client}
          store={store}
          draft={menuDraft}
          onClose={() => setMenuDraft(null)}
          onSaved={async () => { setMenuDraft(null); await refreshMenu(); }}
          onMessage={setMessage}
        />
      ) : null}

      {storeEditing && store ? (
        <StoreEditor
          client={client}
          store={store}
          onClose={() => setStoreEditing(false)}
          onSaved={async () => { setStoreEditing(false); await load(true); }}
          onMessage={setMessage}
        />
      ) : null}
    </main>
  );
}

function NavButton({
  active,
  label,
  icon,
  badge,
  onClick,
}: {
  active: boolean;
  label: string;
  icon: React.ReactNode;
  badge?: number;
  onClick: () => void;
}) {
  return (
    <button className={active ? "is-active" : ""} type="button" onClick={onClick}>
      <span className="wm-nav-icon">{icon}{badge ? <i>{badge > 9 ? "9+" : badge}</i> : null}</span>
      <small>{label}</small>
    </button>
  );
}

function HomePanel({
  client,
  store,
  menu,
  todayOrderCount,
  todaySales,
  installPrompt,
  onInstall,
  onReload,
  onOpenTab,
  onEditStore,
  onMessage,
}: {
  client: SupabaseClient;
  store: FoodStore;
  menu: FoodMenuItem[];
  todayOrderCount: number | null;
  todaySales: number | null;
  installPrompt: InstallPromptEvent | null;
  onInstall: () => void;
  onReload: () => void;
  onOpenTab: (tab: MerchantTab) => void;
  onEditStore: () => void;
  onMessage: (message: string) => void;
}) {
  const [busy, setBusy] = useState(false);
  const [checklistOpen, setChecklistOpen] = useState(false);
  const toggleOpen = async () => {
    setBusy(true);
    try {
      await updateFoodStore(client, store.id, { is_open: !store.is_open });
      onReload();
    } catch (error) {
      onMessage(merchantError(error));
      // The store may have been suspended since this screen loaded.
      onReload();
    } finally { setBusy(false); }
  };
  const availableMenu = menu.filter((item) => item.is_available).length;
  // WYN-204: "เตรียมร้านให้พร้อม" uses the same rules as the publish check
  // (internal.food_store_readiness_missing), so a ticked list can publish.
  const filled = (value: string | null | undefined) => Boolean(value?.trim());
  const checklist = [
    { key: "info", label: "ใส่เบอร์ ที่อยู่ เวลาเปิด และพื้นที่ส่ง", done: filled(store.phone) && filled(store.address) && filled(store.business_hours) && filled(store.delivery_area), action: "แก้ไขร้าน", onGo: onEditStore },
    { key: "payment", label: "ตั้งช่องทางรับเงิน", done: (filled(store.promptpay_name) && filled(store.promptpay_id)) || (filled(store.bank_account_name) && filled(store.bank_account_number)) || filled(store.payment_qr_path), action: "ตั้งค่า", onGo: onEditStore },
    { key: "menu", label: "เปิดขายเมนูอย่างน้อย 1 รายการ", done: availableMenu > 0, action: "ไปที่เมนู", onGo: () => onOpenTab("menu") },
    { key: "publish", label: "เผยแพร่ร้านบน WYNOS Food", done: store.is_published, action: "เผยแพร่", onGo: () => onOpenTab("store") },
  ];
  const checklistDone = checklist.filter((item) => item.done).length;
  const readyPercent = Math.round((checklistDone / checklist.length) * 100);
  const nextStep = checklist.find((item) => !item.done);

  // WYN-204: Wynos home — one red "today" card (store, sales, open switch),
  // one row of 3D shortcuts, then the orders to handle.
  return (
    <>
      <section className="wm-hero">
        <div className="wm-hero-top">
          <div><small>ร้านของคุณ</small><h1>{store.name}</h1></div>
          <span className="wm-hero-actions">
            {/* Only a published store is visible to customers on WYNOS Food. */}
            {store.is_published && !store.admin_suspended_at ? (
              <button className="wm-hero-edit" type="button" aria-label="แชร์ลิงก์ร้านให้ลูกค้าสั่งอาหาร" onClick={() => void shareOrCopyLink(foodStoreShareData(store), onMessage)}><Share2 size={19} /></button>
            ) : null}
            <button className="wm-hero-edit" type="button" aria-label="แก้ไขร้าน" onClick={onEditStore}><Pencil size={19} /></button>
          </span>
        </div>
        <button className="wm-hero-sales" type="button" onClick={() => onOpenTab("reports")}>
          <small>ยอดขายวันนี้</small>
          <strong>{todaySales == null ? "–" : money(todaySales)}</strong>
          <span>{todayOrderCount == null ? "…" : todayOrderCount} ออเดอร์ <ChevronRight size={14} /></span>
        </button>
        <button
          className={`wm-open-switch ${store.is_open ? "is-open" : ""}`}
          type="button"
          role="switch"
          aria-checked={store.is_open}
          aria-label={store.is_open ? "เปิดร้านอยู่ กดเพื่อปิดรับออเดอร์" : "ปิดร้านอยู่ กดเพื่อเปิดรับออเดอร์"}
          disabled={busy || Boolean(store.admin_suspended_at)} onClick={() => void toggleOpen()}
        >
          <i className="wm-open-dot" />
          <span><b>{store.is_open ? "เปิดรับออเดอร์" : "ปิดร้านอยู่"}</b><small>{store.is_open ? "แตะเพื่อปิดร้าน" : "แตะเพื่อเปิดรับออเดอร์"}</small></span>
          <span className={`wm-switch ${store.is_open ? "is-on" : ""}`}><i /></span>
        </button>
      </section>

      {store.admin_suspended_at ? (
        <div className="wm-setup-banner wm-suspended-banner" role="alert">
          <Store size={22} strokeWidth={1.7} />
          <span><strong>ร้านถูกระงับโดยทีม WYNOS</strong><small>{store.admin_suspended_reason ? `เหตุผล: ${store.admin_suspended_reason}` : "ติดต่อทีม WYNOS เพื่อขอยกเลิกการระงับ"}</small></span>
        </div>
      ) : null}

      <nav className="wm-shortcuts" aria-label="ทางลัด">
        <button type="button" onClick={() => onOpenTab("finance")}><MerchantIcon3D name="finance" size={52} />การเงิน</button>
        <button type="button" onClick={() => onOpenTab("ads")}><MerchantIcon3D name="ads" size={52} />โฆษณา</button>
        <button type="button" onClick={() => onOpenTab("campaigns")}><MerchantIcon3D name="campaign" size={52} />แคมเปญ</button>
        <button type="button" onClick={() => onOpenTab("promotions")}><MerchantIcon3D name="promotion" size={52} />โปรโมชั่น</button>
      </nav>

      {/* Only a published store is visible to customers on WYNOS Food. */}
      {store.is_published && !store.admin_suspended_at ? <MerchantShareCard client={client} store={store} onMessage={onMessage} /> : null}


      {nextStep && !store.admin_suspended_at ? (
        <section className={`wm-ready ${checklistOpen ? "is-open" : ""}`}>
          <button className="wm-ready-bar" type="button" aria-expanded={checklistOpen} onClick={() => setChecklistOpen((open) => !open)}>
            <span className="wm-ready-head"><span>ร้านพร้อมขาย</span><b>{readyPercent}%</b></span>
            <span className="wm-ready-track" aria-hidden="true"><i style={{ width: `${readyPercent}%` }} /></span>
            <small>{`เหลือ ${checklist.length - checklistDone} ขั้น`} · {nextStep.label}</small>
          </button>
          {checklistOpen ? (
            <ul>
              {checklist.map((item) => (
                <li key={item.key} className={item.done ? "is-done" : ""}>
                  <span className="wm-check-mark">{item.done ? <Check size={14} /> : null}</span>
                  <span>{item.label}</span>
                  {item.done ? <small>เรียบร้อย</small> : <button type="button" onClick={item.onGo}>{item.action}</button>}
                </li>
              ))}
            </ul>
          ) : null}
        </section>
      ) : null}

      {installPrompt ? (
        <button className="wm-install-card" type="button" onClick={onInstall}>
          <span className="wm-install-icon"><Store size={22} /></span>
          <span><strong>ติดตั้ง WYNOS Merchant</strong><small>เปิดใช้งานเหมือนแอปแยกจาก WYNOS</small></span>
          <ChevronRight size={18} />
        </button>
      ) : null}
    </>
  );
}

/** WYN-204: "เพิ่มเติม" — everything that is not an order or a dish. */
function MorePanel({
  client,
  store,
  installPrompt,
  onInstall,
  onOpenTab,
  onSignOut,
}: {
  client: SupabaseClient;
  store: FoodStore;
  installPrompt: InstallPromptEvent | null;
  onInstall: () => void;
  onOpenTab: (tab: MerchantTab) => void;
  onSignOut: () => void;
}) {
  return (
    <>
      <div className="wm-page-heading"><div><small>Wynos Merchant</small><h1>เพิ่มเติม</h1></div></div>
      <button className="wm-store-card wm-store-card--link" type="button" onClick={() => onOpenTab("store")}>
        <span className="wm-store-avatar">{store.logo_path ? <img src={foodPublicUrl(client, store.logo_path) ?? ""} alt="" /> : <Store size={30} strokeWidth={1.6} />}</span>
        <span><strong>{store.name}</strong><small>{store.is_published ? "เผยแพร่บน WYNOS Food แล้ว" : "ร้านยังไม่เผยแพร่"}</small></span>
        <ChevronRight size={19} />
      </button>
      <section className="wm-section">
        <div className="wm-section-title"><h2>เครื่องมือร้าน</h2></div>
        <div className="wm-service-grid">
          <button type="button" onClick={() => onOpenTab("reports")}><span className="wm-tile-icon"><MerchantIcon3D name="reports" size={52} /></span>รายงานยอดขาย</button>
          <button type="button" onClick={() => onOpenTab("finance")}><span className="wm-tile-icon"><MerchantIcon3D name="finance" size={52} /></span>การเงิน</button>
          <button type="button" onClick={() => onOpenTab("promotions")}><span className="wm-tile-icon"><MerchantIcon3D name="promotion" size={52} /></span>โปรโมชั่น</button>
          <button type="button" onClick={() => onOpenTab("campaigns")}><span className="wm-tile-icon"><MerchantIcon3D name="campaign" size={52} /></span>แคมเปญ</button>
          <button type="button" onClick={() => onOpenTab("ads")}><span className="wm-tile-icon"><MerchantIcon3D name="ads" size={52} /></span>โฆษณา</button>
          <button type="button" onClick={() => onOpenTab("store")}><span className="wm-tile-icon"><MerchantIcon3D name="settings" size={52} /></span>ตั้งค่าร้าน</button>
          <button type="button" onClick={() => onOpenTab("help")}><span className="wm-tile-icon"><MerchantIcon3D name="help" size={52} /></span>ช่วยเหลือ</button>
          <button type="button" onClick={() => onOpenTab("notifications")}><span className="wm-tile-icon"><MerchantIcon3D name="bell" size={52} /></span>การแจ้งเตือน</button>
          {installPrompt ? <button type="button" onClick={onInstall}><span className="wm-tile-icon"><MerchantIcon3D name="install" size={52} /></span>ติดตั้งแอป</button> : null}
        </div>
      </section>
      {store.latitude != null && store.longitude != null ? (
        <section className="wm-store-location-card">
          <div className="wm-store-location-card-head">
            <span><strong>ตำแหน่งร้าน</strong><small>ตรวจสอบหมุดร้านบนแผนที่ก่อนเปิดรับออเดอร์</small></span>
            <button type="button" onClick={() => onOpenTab("store")}>แก้ไขตำแหน่ง</button>
          </div>
          <FoodLocationMapPreview
            location={{ latitude: Number(store.latitude), longitude: Number(store.longitude) }}
            label={store.name}
          />
          {store.pickup_latitude != null && store.pickup_longitude != null ? (
            <div className="wm-store-pickup-summary"><MapPin size={16} /><span><strong>มีจุดรับอาหารแยกจากหน้าร้าน</strong><small>{store.pickup_note || "ร้านกำหนดทางเข้าหรือจุดรับอาหารสำหรับไรเดอร์แล้ว"}</small></span></div>
          ) : null}
        </section>
      ) : (
        <section className="wm-store-location-missing">
          <MapPin size={20} /><span><strong>ยังไม่ได้ปักหมุดร้าน</strong><small>เพิ่มตำแหน่งเพื่อให้ร้านขึ้น WYNOS Maps และคำนวณระยะจัดส่ง</small></span><button type="button" onClick={() => onOpenTab("store")}>เพิ่มตำแหน่ง</button>
        </section>
      )}
      <section className="wm-settings-list">
        <button type="button" onClick={onSignOut}><span><strong>ออกจากระบบ</strong><small>ออกจากบัญชี WYNOS บนอุปกรณ์นี้</small></span><LogOut size={19} /></button>
      </section>
    </>
  );
}

function HelpPanel({ store, onMessage }: { store: FoodStore; onMessage: (message: string) => void }) {
  const copyDiagnostics = async () => {
    const detail = [
      "WYNOS Merchant",
      `ร้าน: ${store.name}`,
      `Store ID: ${store.id}`,
      `สถานะ: ${store.is_open ? "เปิดร้าน" : "ปิดร้าน"} / ${store.is_published ? "เผยแพร่แล้ว" : "ยังไม่เผยแพร่"}`,
      `เวลา: ${new Date().toISOString()}`,
      typeof navigator !== "undefined" ? `อุปกรณ์: ${navigator.userAgent}` : "",
    ].filter(Boolean).join("\n");
    try {
      await navigator.clipboard.writeText(detail);
      onMessage("คัดลอกข้อมูลสำหรับแจ้งปัญหาแล้ว");
    } catch {
      onMessage("คัดลอกไม่สำเร็จ กรุณาจด Store ID จากหน้านี้");
    }
  };
  return (
    <>
      <div className="wm-page-heading"><div><small>ศูนย์ช่วยเหลือร้านค้า</small><h1>ช่วยเหลือ</h1></div></div>
      <section className="wm-help-card">
        <strong>ต้องการความช่วยเหลือ?</strong>
        <p>ติดต่อบัญชี Official <b>@wynos_s</b> ใน WYNOS พร้อมส่งชื่อร้านและ Store ID เพื่อให้ทีมตรวจสอบได้เร็วขึ้น</p>
        <div className="wm-help-actions">
          <a className="wm-primary" href="https://wynos.online" target="_blank" rel="noreferrer">เปิด WYNOS</a>
          <button className="wm-secondary" type="button" onClick={() => void copyDiagnostics()}>คัดลอกข้อมูลร้าน</button>
        </div>
        <small>Store ID: {store.id}</small>
      </section>
      <section className="wm-settings-list wm-help-list">
        <div><span><strong>ออเดอร์ไม่ดัง</strong><small>ตรวจว่าเปิดการแจ้งเตือนของ WYNOS Merchant และมือถือไม่ได้ปิดเสียง</small></span></div>
        <div><span><strong>สลิปไม่ขึ้น</strong><small>ปิดออเดอร์แล้วเปิดใหม่ หากยังไม่ขึ้นให้คัดลอกข้อมูลร้านส่งทีม WYNOS</small></span></div>
        <div><span><strong>ร้านไม่ขึ้น WYNOS Food</strong><small>ตรวจความพร้อมร้าน ช่องทางรับเงิน เมนู ตำแหน่ง และสถานะเผยแพร่</small></span></div>
        <div><span><strong>ยอดขายหรือการเงินไม่ตรง</strong><small>ใช้หน้า “การเงิน” เลือกช่วงวันที่และดาวน์โหลด CSV เพื่อตรวจรายการ</small></span></div>
      </section>
    </>
  );
}

function OrdersPanel({
  orders,
  allOrders,
  filter,
  onFilter,
  onOpen,
  onAction,
  actedFrom,
  hasMore,
  loadingMore,
  onLoadMore,
}: {
  orders: FoodOrder[];
  allOrders: FoodOrder[];
  filter: OrderFilter;
  onFilter: (value: OrderFilter) => void;
  onOpen: (order: FoodOrder) => void;
  onAction: (order: FoodOrder) => void;
  actedFrom: ReadonlyMap<string, FoodOrder["status"]>;
  hasMore: boolean;
  loadingMore: boolean;
  onLoadMore: () => void;
}) {
  // "Done" keeps growing, so only the working tabs show a count.
  const counts: Record<OrderFilter, number> = {
    new: allOrders.filter((o) => orderInFilter(o, "new")).length,
    cooking: allOrders.filter((o) => orderInFilter(o, "cooking")).length,
    delivery: allOrders.filter((o) => orderInFilter(o, "delivery")).length,
    done: 0,
  };
  return (
    <>
      <div className="wm-filter-tabs wm-filter-tabs--simple" role="group" aria-label="สถานะออเดอร์">
        {ORDER_FILTERS.map((item) => (
          <button key={item.key} className={filter === item.key ? "is-active" : ""} type="button" aria-pressed={filter === item.key} onClick={() => onFilter(item.key)}>
            <span>{item.label}</span>{counts[item.key] ? <b>{counts[item.key]}</b> : null}
          </button>
        ))}
      </div>
      {orders.length ? <div className="wm-order-list wm-order-list--page">{orders.map((order) => <OrderCard key={order.id} order={order} onOpen={() => onOpen(order)} onAction={onAction} acting={actedFrom.get(order.id) === order.status} />)}</div> : (
        <div className="wm-empty"><ShoppingBag size={38} strokeWidth={1.5} /><strong>ไม่มีออเดอร์ในแท็บนี้</strong></div>
      )}
      {hasMore ? (
        <button className="wm-secondary wm-full wm-load-more" type="button" disabled={loadingMore} onClick={onLoadMore}>
          {loadingMore ? "กำลังโหลด…" : "โหลดออเดอร์เก่ากว่านี้"}
        </button>
      ) : allOrders.length >= MERCHANT_ORDER_PAGE_SIZE ? <p className="wm-list-end">แสดงออเดอร์ทั้งหมดที่โหลดได้แล้ว</p> : null}
    </>
  );
}
function MenuPanel({
  client,
  store,
  menu,
  query,
  onQuery,
  onEdit,
  onAdd,
  onToggle,
  onSoldOut,
  onReorder,
  onCategoryOrder,
}: {
  client: SupabaseClient;
  store: FoodStore;
  menu: FoodMenuItem[];
  query: string;
  onQuery: (value: string) => void;
  onEdit: (item: FoodMenuItem) => void;
  onAdd: () => void;
  onToggle: (item: FoodMenuItem) => void;
  onSoldOut: (item: FoodMenuItem, soldOut: boolean) => void;
  onReorder: (ids: string[]) => void;
  onCategoryOrder: (categories: string[]) => void;
}) {
  const [sortMode, setSortMode] = useState(false);
  const [categoryFilter, setCategoryFilter] = useState("all");
  const [openActionId, setOpenActionId] = useState<string | null>(null);
  const [collapsedCategories, setCollapsedCategories] = useState<Set<string>>(() => new Set());
  const q = query.trim().toLocaleLowerCase("th-TH");
  const presentCategories = Array.from(new Set(menu.map((item) => item.category.trim() || "อื่น ๆ")));
  const preferred = Array.isArray(store.menu_category_order) ? store.menu_category_order : [];
  const categoryOrder = [...preferred.filter((name) => presentCategories.includes(name)), ...presentCategories.filter((name) => !preferred.includes(name))];
  const visibleCategoryOrder = categoryFilter === "all" ? categoryOrder : categoryOrder.filter((name) => name === categoryFilter);
  const displayMenu = q
    ? menu.filter((item) => `${item.name} ${item.category} ${item.description ?? ""}`.toLocaleLowerCase("th-TH").includes(q))
    : menu;
  const categories = visibleCategoryOrder
    .map((category) => [category, displayMenu.filter((item) => (item.category.trim() || "อื่น ๆ") === category)] as const)
    .filter(([, items]) => items.length);

  const moveItem = (dragId: string, targetId: string) => {
    if (q || dragId === targetId) return;
    const ids = menu.map((item) => item.id);
    const from = ids.indexOf(dragId);
    const to = ids.indexOf(targetId);
    if (from < 0 || to < 0) return;
    const next = [...ids];
    next.splice(to, 0, next.splice(from, 1)[0]);
    onReorder(next);
  };

  const moveCategory = (dragCategory: string, targetCategory: string) => {
    if (q || dragCategory === targetCategory) return;
    const next = [...categoryOrder];
    const from = next.indexOf(dragCategory);
    const to = next.indexOf(targetCategory);
    if (from < 0 || to < 0) return;
    next.splice(to, 0, next.splice(from, 1)[0]);
    onCategoryOrder(next);
  };

  const shiftCategory = (category: string, delta: -1 | 1) => {
    const index = categoryOrder.indexOf(category);
    const target = index + delta;
    if (q || index < 0 || target < 0 || target >= categoryOrder.length) return;
    const next = [...categoryOrder];
    [next[index], next[target]] = [next[target], next[index]];
    onCategoryOrder(next);
  };

  const shiftItem = (items: FoodMenuItem[], itemId: string, delta: -1 | 1) => {
    const index = items.findIndex((item) => item.id === itemId);
    const target = index + delta;
    if (q || index < 0 || target < 0 || target >= items.length) return;
    moveItem(itemId, items[target].id);
  };

  const toggleCategory = (category: string) => {
    setCollapsedCategories((current) => {
      const next = new Set(current);
      if (next.has(category)) next.delete(category);
      else next.add(category);
      return next;
    });
  };

  return (
    <>
      <div className="wm-page-heading wm-page-heading--action wm-menu-page-heading">
        <div><h1>เมนูอาหาร</h1></div>
        <button className="wm-small-primary wm-menu-add" type="button" onClick={onAdd}><Plus size={18} /> เพิ่มเมนู</button>
      </div>

      <label className="wm-search wm-menu-search">
        <Search size={20} strokeWidth={1.7} />
        <input
          value={query}
          onChange={(event) => {
            onQuery(event.target.value);
            if (event.target.value) setSortMode(false);
          }}
          placeholder="ค้นหาเมนูหรือหมวดหมู่"
        />
      </label>

      {menu.length ? (
        <div className="wm-menu-toolbar" aria-label="เครื่องมือเมนู">
          <button
            className={`wm-menu-tool ${sortMode ? "is-active" : ""}`}
            type="button"
            aria-pressed={sortMode}
            disabled={Boolean(q) || categoryFilter !== "all"}
            onClick={() => {
              setSortMode((value) => !value);
              setOpenActionId(null);
            }}
          >
            <ArrowUpDown size={17} />
            <span>{sortMode ? "เสร็จสิ้น" : "จัดลำดับ"}</span>
            {sortMode ? <ChevronUp size={14} aria-hidden="true" /> : <ChevronDown size={14} aria-hidden="true" />}
          </button>
          <label className="wm-menu-tool wm-menu-category-filter">
            <LayoutGrid size={17} />
            <select
              aria-label="กรองตามหมวดหมู่"
              value={categoryFilter}
              onChange={(event) => {
                setCategoryFilter(event.target.value);
                setSortMode(false);
                setOpenActionId(null);
              }}
            >
              <option value="all">ทุกหมวดหมู่</option>
              {categoryOrder.map((category) => <option key={category} value={category}>{category}</option>)}
            </select>
            <ChevronDown size={15} aria-hidden="true" />
          </label>
        </div>
      ) : null}

      {sortMode ? (
        <div className="wm-menu-sort-hint"><GripVertical size={15} /> ลากหมวดหมู่หรือเมนูเพื่อจัดลำดับหน้าร้าน</div>
      ) : null}

      <div className="wm-menu-categories">
        {categories.map(([category, items]) => {
          const categoryIndex = categoryOrder.indexOf(category);
          const collapsed = collapsedCategories.has(category);
          return (
            <section
              className={`wm-menu-category ${collapsed ? "is-collapsed" : ""}`}
              key={category}
              draggable={sortMode && !q}
              onDragStart={(event) => event.dataTransfer.setData("text/wynos-category", category)}
              onDragOver={(event) => { if (sortMode && event.dataTransfer.types.includes("text/wynos-category")) event.preventDefault(); }}
              onDrop={(event) => {
                const source = event.dataTransfer.getData("text/wynos-category");
                if (sortMode && source) { event.preventDefault(); moveCategory(source, category); }
              }}
            >
              <div className="wm-menu-category-heading">
                <div className="wm-menu-category-title">
                  <span className={`wm-menu-category-drag ${sortMode ? "is-active" : ""}`} aria-hidden="true"><GripVertical size={17} /></span>
                  <span className={`wm-menu-category-mark is-tone-${categoryIndex % 3}`} aria-hidden="true"><UtensilsCrossed size={16} /></span>
                  <button type="button" onClick={() => toggleCategory(category)}><strong>{category}</strong></button>
                </div>
                <div className="wm-menu-category-meta">
                  <em>{items.length} เมนู</em>
                  {sortMode ? (
                    <span className="wm-sort-controls">
                      <button type="button" aria-label="เลื่อนหมวดหมู่ขึ้น" disabled={Boolean(q) || categoryIndex === 0} onClick={() => shiftCategory(category, -1)}><ChevronUp size={14} /></button>
                      <button type="button" aria-label="เลื่อนหมวดหมู่ลง" disabled={Boolean(q) || categoryIndex === categoryOrder.length - 1} onClick={() => shiftCategory(category, 1)}><ChevronDown size={14} /></button>
                    </span>
                  ) : null}
                  <button className={`wm-menu-collapse ${collapsed ? "is-collapsed" : ""}`} type="button" aria-label={collapsed ? "แสดงเมนูในหมวด" : "ซ่อนเมนูในหมวด"} aria-expanded={!collapsed} onClick={() => toggleCategory(category)}>
                    <ChevronDown size={17} />
                  </button>
                </div>
              </div>

              {!collapsed ? (
                <div className="wm-menu-list">
                  {items.map((item, itemIndex) => {
                    const image = foodPublicUrl(client, item.image_path);
                    const optionCount = Array.isArray(item.options)
                      ? item.options.reduce((sum, group) => sum + (Array.isArray(group.choices) ? group.choices.length : 0), 0)
                      : 0;
                    const available = foodMenuIsEffectivelyAvailable(item);
                    const soldOutToday = Boolean(item.sold_out_until && Date.parse(item.sold_out_until) > Date.now());
                    const actionOpen = openActionId === item.id;
                    return (
                      <article
                        className={`wm-menu-row ${available ? "" : "is-off"} ${soldOutToday ? "is-sold-out" : ""} ${sortMode ? "is-sorting" : ""}`}
                        key={item.id}
                        draggable={sortMode && !q}
                        onDragStart={(event) => event.dataTransfer.setData("text/wynos-menu", item.id)}
                        onDragOver={(event) => { if (sortMode && event.dataTransfer.types.includes("text/wynos-menu")) event.preventDefault(); }}
                        onDrop={(event) => {
                          const source = event.dataTransfer.getData("text/wynos-menu");
                          if (sortMode && source) { event.preventDefault(); moveItem(source, item.id); }
                        }}
                      >
                        {sortMode ? <span className="wm-menu-drag" aria-hidden="true"><GripVertical size={18} /></span> : null}
                        <button className="wm-menu-main" type="button" onClick={() => onEdit(item)}>
                          <span className="wm-menu-photo">{image ? <img src={image} alt="" loading="lazy" decoding="async" /> : <UtensilsCrossed size={24} strokeWidth={1.5} />}</span>
                          <span className="wm-menu-copy">
                            <strong>{item.name}</strong>
                            <small>{item.daily_stock_limit ? `จำกัด ${item.daily_stock_limit} ชิ้น/วัน` : optionCount ? `${optionCount} ตัวเลือกเสริม` : "ไม่มีตัวเลือกเสริม"}</small>
                            <b>{money(item.price)}</b>
                          </span>
                        </button>
                        <div className="wm-menu-row-actions">
                          {sortMode ? (
                            <span className="wm-sort-controls">
                              <button type="button" aria-label="เลื่อนเมนูขึ้น" disabled={Boolean(q) || itemIndex === 0} onClick={() => shiftItem(items, item.id, -1)}><ChevronUp size={13} /></button>
                              <button type="button" aria-label="เลื่อนเมนูลง" disabled={Boolean(q) || itemIndex === items.length - 1} onClick={() => shiftItem(items, item.id, 1)}><ChevronDown size={13} /></button>
                            </span>
                          ) : null}
                          {soldOutToday && !sortMode ? <span className="wm-menu-soldout-badge">หมดวันนี้</span> : null}
                          <button
                            className={`wm-switch ${available ? "is-on" : ""}`}
                            type="button"
                            aria-label={available ? "ปิดขาย" : "เปิดขาย"}
                            onClick={() => soldOutToday ? onSoldOut(item, false) : onToggle(item)}
                          ><i /></button>
                          {!sortMode ? (
                            <div className="wm-menu-overflow">
                              <button className="wm-menu-more" type="button" aria-label={`ตัวเลือกสำหรับ ${item.name}`} aria-expanded={actionOpen} onClick={() => setOpenActionId(actionOpen ? null : item.id)}>⋯</button>
                              {actionOpen ? (
                                <div className="wm-menu-action-popover" role="menu">
                                  <button type="button" role="menuitem" onClick={() => { setOpenActionId(null); onEdit(item); }}>แก้ไขเมนู</button>
                                  <button className={soldOutToday ? "is-active" : ""} type="button" role="menuitem" onClick={() => { setOpenActionId(null); onSoldOut(item, !soldOutToday); }}>{soldOutToday ? "ยกเลิกหมดวันนี้" : "หมดวันนี้"}</button>
                                </div>
                              ) : null}
                            </div>
                          ) : null}
                        </div>
                      </article>
                    );
                  })}
                </div>
              ) : null}
            </section>
          );
        })}
      </div>

      {menu.length && !categories.length ? <div className="wm-empty wm-empty--compact"><Search size={34} strokeWidth={1.5} /><strong>ไม่พบเมนูที่ค้นหา</strong><p>ลองเปลี่ยนคำค้นหาหรือเลือกหมวดหมู่อื่น</p></div> : null}
      {!menu.length ? <div className="wm-empty"><MenuIcon size={38} strokeWidth={1.5} /><strong>ยังไม่มีเมนู</strong><p>เพิ่มอาหารหรือเครื่องดื่มเพื่อเริ่มรับออเดอร์</p></div> : null}
    </>
  );
}

/** WYN-205: quick sales report, aggregated across the complete store history. */
function ReportsPanel({ report, error }: { report: MerchantSalesReport | null; error: string }) {
  return (
    <>
      <div className="wm-page-heading"><div><small>ภาพรวมร้าน</small><h1>รายงาน</h1></div></div>
      {error ? (
        <div className="wm-empty wm-empty--compact"><CircleDollarSign size={34} strokeWidth={1.5} /><strong>{error}</strong></div>
      ) : !report ? (
        <div className="wm-empty wm-empty--compact"><span className="wm-mini-loader" aria-label="กำลังโหลด" /></div>
      ) : (
        <>
          <div className="wm-report-hero"><small>ยอดขายวันนี้</small><strong>{money(report.today_sales)}</strong><span>{report.today_orders} ออเดอร์สำเร็จ</span></div>
          <div className="wm-metrics wm-metrics--reports">
            <Metric label="สัปดาห์นี้" value={money(report.week_sales)} hint={`${report.week_orders} ออเดอร์`} />
            <Metric label="เดือนนี้" value={money(report.month_sales)} hint={`${report.month_orders} ออเดอร์`} />
            <Metric label="เฉลี่ย/ออเดอร์" value={money(report.average_order)} />
            <Metric label="ออเดอร์ทั้งหมด" value={String(report.total_orders)} />
          </div>
          <section className="wm-section">
            <div className="wm-section-title"><h2>เมนูขายดี</h2></div>
            {report.best.length ? <div className="wm-ranking">{report.best.map((item, index) => <div key={item.name}><b>{index + 1}</b><span>{item.name}</span><strong>{item.quantity} ชิ้น</strong></div>)}</div> : (
              <div className="wm-empty wm-empty--compact"><CircleDollarSign size={34} strokeWidth={1.5} /><strong>ยังไม่มีข้อมูลยอดขาย</strong></div>
            )}
          </section>
        </>
      )}
    </>
  );
}

function StorePanel({
  client,
  store,
  menu,
  userId,
  installPrompt,
  onInstall,
  onEdit,
  onReload,
  onMessage,
  onSignOut,
}: {
  client: SupabaseClient;
  store: FoodStore;
  menu: FoodMenuItem[];
  userId: string;
  installPrompt: InstallPromptEvent | null;
  onInstall: () => void;
  onEdit: () => void;
  onReload: () => void;
  onMessage: (message: string) => void;
  onSignOut: () => void;
}) {
  const [busy, setBusy] = useState(false);
  const [readiness, setReadiness] = useState<MerchantStoreReadiness | null>(null);
  const [audit, setAudit] = useState<MerchantAuditEntry[]>([]);
  const [previewOpen, setPreviewOpen] = useState(false);

  useEffect(() => {
    let live = true;
    void Promise.all([
      fetchMerchantStoreReadiness(client, store.id),
      fetchMerchantAuditHistory(client, store.id),
    ]).then(([nextReadiness, nextAudit]) => {
      if (!live) return;
      setReadiness(nextReadiness);
      setAudit(nextAudit);
    }).catch(() => {
      if (live) { setReadiness(null); setAudit([]); }
    });
    return () => { live = false; };
  }, [client, store.id, store.updated_at, menu.length]);

  const checklistLabels: Record<string, string> = {
    name: "ชื่อร้าน",
    description: "รายละเอียดร้าน",
    phone: "เบอร์ติดต่อ",
    address: "ที่อยู่ร้าน",
    logo: "รูปโปรไฟล์",
    cover: "รูปปก",
    location: "ตำแหน่งร้าน",
    schedule: "เวลาเปิด–ปิด",
    prep_time: "เวลาเตรียมอาหาร",
    payment: "ข้อมูลรับชำระเงิน",
    menu: "เมนูอาหาร",
  };
  const entries = readiness ? Object.entries(readiness.checks) : [];
  const completed = entries.filter(([, ready]) => ready).length;
  const progress = entries.length ? Math.round((completed / entries.length) * 100) : 0;

  const togglePublished = async () => {
    if (!store.is_published && readiness && !readiness.ready) {
      onMessage("กรุณาตั้งค่าร้านให้ครบก่อนเผยแพร่");
      return;
    }
    setBusy(true);
    try {
      await setMerchantStorePublished(client, store.id, !store.is_published);
      onReload();
    } catch (error) { onMessage(merchantError(error)); onReload(); }
    finally { setBusy(false); }
  };

  return (
    <>
      <div className="wm-page-heading"><div><small>การตั้งค่า</small><h1>ร้านค้า</h1></div></div>

      <section className="wm-onboarding-card">
        <div className="wm-onboarding-head">
          <span><strong>ความพร้อมของร้าน</strong><small>{readiness?.ready ? "พร้อมเผยแพร่และรับออเดอร์" : "ตั้งค่าร้านให้ครบก่อนเปิดใช้งานจริง"}</small></span>
          <b>{progress}%</b>
        </div>
        <div className="wm-onboarding-progress"><i style={{ width: `${progress}%` }} /></div>
        <div className="wm-onboarding-checks">
          {entries.map(([key, ready]) => <span key={key} className={ready ? "is-ready" : ""}>{ready ? <Check size={13} /> : <AlertTriangle size={13} />}{checklistLabels[key] ?? key}</span>)}
        </div>
        {!readiness?.ready ? <button className="wm-secondary wm-full" type="button" onClick={onEdit}>ตั้งค่าร้านให้ครบ</button> : null}
      </section>

      <section className="wm-store-brand-card">
        <div className="wm-store-brand-card-cover">
          {store.cover_path ? <img src={foodPublicUrl(client, store.cover_path) ?? ""} alt="" /> : <Store size={40} strokeWidth={1.4} />}
        </div>
        <div className="wm-store-brand-card-main">
          <div className="wm-store-avatar">{store.logo_path ? <img src={foodPublicUrl(client, store.logo_path) ?? ""} alt="" /> : <Store size={30} strokeWidth={1.6} />}</div>
          <div><strong>{store.name}</strong><small>{foodStoreStatusText(store)} · {store.address || "ยังไม่ได้ใส่ที่อยู่ร้าน"}</small></div>
          <button type="button" onClick={onEdit}>แก้ไข</button>
        </div>
      </section>

      {store.latitude != null && store.longitude != null ? (
        <section className="wm-store-location-card">
          <div className="wm-store-location-card-head">
            <span><strong>ตำแหน่งร้าน</strong><small>ตรวจสอบหมุดร้านบนแผนที่ก่อนเปิดรับออเดอร์</small></span>
            <button type="button" onClick={onEdit}>แก้ไขตำแหน่ง</button>
          </div>
          <FoodLocationMapPreview
            location={{ latitude: Number(store.latitude), longitude: Number(store.longitude) }}
            label={store.name}
          />
          {store.pickup_latitude != null && store.pickup_longitude != null ? (
            <div className="wm-store-pickup-summary"><MapPin size={16} /><span><strong>มีจุดรับอาหารแยกจากหน้าร้าน</strong><small>{store.pickup_note || "ร้านกำหนดทางเข้าหรือจุดรับอาหารสำหรับไรเดอร์แล้ว"}</small></span></div>
          ) : null}
        </section>
      ) : (
        <section className="wm-store-location-missing">
          <MapPin size={20} /><span><strong>ยังไม่ได้ปักหมุดร้าน</strong><small>เพิ่มตำแหน่งเพื่อให้ร้านขึ้น WYNOS Maps และคำนวณระยะจัดส่ง</small></span><button type="button" onClick={onEdit}>เพิ่มตำแหน่ง</button>
        </section>
      )}

      <section className="wm-settings-list">
        <button type="button" onClick={() => void togglePublished()} disabled={busy || Boolean(store.admin_suspended_at) || (!store.is_published && readiness !== null && !readiness.ready)}>
          <span><strong>เผยแพร่ WYNOS Food</strong><small>{store.is_published ? "ลูกค้าเห็นร้านได้แล้ว" : readiness?.ready ? "พร้อมเปิดร้านให้ลูกค้าเห็น" : "ต้องตั้งค่าร้านให้ครบก่อน"}</small></span>
          <span className={`wm-switch ${store.is_published ? "is-on" : ""}`}><i /></span>
        </button>
        <button type="button" onClick={() => setPreviewOpen(true)}><span><strong>ดูแบบลูกค้า</strong><small>Preview หน้าร้านก่อนเผยแพร่จริง</small></span><Eye size={19} /></button>
        <button type="button" onClick={onEdit}><span><strong>ข้อมูลร้านและการจัดส่ง</strong><small>เวลาเปิด · ETA · ตำแหน่ง · ค่าส่ง</small></span><ChevronRight size={19} /></button>
        <button type="button" onClick={onEdit}><span><strong>รับชำระเงิน</strong><small>PromptPay · บัญชีธนาคาร · QR</small></span><ChevronRight size={19} /></button>
        {installPrompt ? <button type="button" onClick={onInstall}><span><strong>ติดตั้งเป็นแอป</strong><small>เพิ่ม WYNOS Merchant ไว้บนหน้าจอหลัก</small></span><ChevronRight size={19} /></button> : null}
        <button type="button" onClick={onSignOut}><span><strong>ออกจากระบบ</strong><small>ออกจากบัญชี WYNOS บนอุปกรณ์นี้</small></span><ChevronRight size={19} /></button>
      </section>

      <section className="wm-audit-card">
        <div className="wm-section-title"><h2><History size={18} /> ประวัติการแก้ไขร้าน</h2><small>{audit.length} รายการล่าสุด</small></div>
        {audit.length ? <div className="wm-audit-list">{audit.slice(0, 12).map((entry) => (
          <div key={entry.id}>
            <span><strong>{merchantAuditLabel(entry.event_type)}</strong><small>{entry.actor_username ? `โดย @${entry.actor_username}` : "โดยทีมร้าน"}</small></span>
            <time>{new Date(entry.created_at).toLocaleString("th-TH", { dateStyle: "short", timeStyle: "short" })}</time>
          </div>
        ))}</div> : <small>ยังไม่มีประวัติการแก้ไขในระบบใหม่</small>}
      </section>

      <MerchantStoreTools client={client} store={store} userId={userId} onMessage={onMessage} />

      {previewOpen ? <MerchantStorefrontPreview client={client} store={store} menu={menu} onClose={() => setPreviewOpen(false)} /> : null}
    </>
  );
}

function merchantAuditLabel(eventType: string) {
  if (eventType === "merchant_store_published") return "เผยแพร่ร้าน";
  if (eventType === "merchant_store_unpublished") return "ซ่อนร้าน";
  if (eventType === "merchant_menu_created") return "เพิ่มเมนู";
  if (eventType === "merchant_menu_deleted") return "ลบเมนู";
  if (eventType === "merchant_menu_reordered") return "จัดลำดับเมนู";
  if (eventType === "merchant_menu_updated") return "แก้ไขเมนู";
  return "แก้ไขข้อมูลร้าน";
}

function MerchantStorefrontPreview({
  client,
  store,
  menu,
  onClose,
}: {
  client: SupabaseClient;
  store: FoodStore;
  menu: FoodMenuItem[];
  onClose: () => void;
}) {
  const preferred = Array.isArray(store.menu_category_order) ? store.menu_category_order : [];
  const categories = Array.from(new Set(menu.map((item) => item.category)));
  categories.sort((a, b) => {
    const ai = preferred.indexOf(a);
    const bi = preferred.indexOf(b);
    if (ai < 0 && bi < 0) return 0;
    if (ai < 0) return 1;
    if (bi < 0) return -1;
    return ai - bi;
  });
  return (
    <Sheet title="Preview หน้าร้าน" onClose={onClose} wide>
      <div className="wm-customer-preview">
        <div className="wm-preview-cover">{store.cover_path ? <img src={foodPublicUrl(client, store.cover_path) ?? ""} alt="" /> : <Store size={42} />}</div>
        <div className="wm-preview-store">
          <span>{store.logo_path ? <img src={foodPublicUrl(client, store.logo_path) ?? ""} alt="" /> : <Store size={25} />}</span>
          <div><h3>{store.name}</h3><small className={foodStoreIsEffectivelyOpen(store) ? "is-open" : ""}>{foodStoreStatusText(store)}</small><p>{store.description || "ยังไม่มีรายละเอียดร้าน"}</p></div>
        </div>
        <div className="wm-preview-meta"><span>เตรียม {Number(store.prep_time_min_minutes ?? 15)}–{Number(store.prep_time_max_minutes ?? 30)} นาที</span><span>ค่าส่งเริ่มต้น {money(store.delivery_fee)}</span></div>
        {categories.map((category) => (
          <section key={category}>
            <h4>{category}</h4>
            {menu.filter((item) => item.category === category).map((item) => {
              const available = foodMenuIsEffectivelyAvailable(item);
              return <div className={`wm-preview-menu ${available ? "" : "is-off"}`} key={item.id}>
                <span>{item.image_path ? <img src={foodPublicUrl(client, item.image_path) ?? ""} alt="" loading="lazy" decoding="async" /> : <UtensilsCrossed size={22} />}</span>
                <div><strong>{item.name}</strong><small>{item.description || (available ? "พร้อมขาย" : "หมดชั่วคราว")}</small><b>{money(item.price)}</b></div>
              </div>;
            })}
          </section>
        ))}
      </div>
    </Sheet>
  );
}

function Sheet({
  title,
  onClose,
  children,
  wide = false,
  back = false,
  className = "",
}: {
  title: string;
  onClose: () => void;
  children: React.ReactNode;
  wide?: boolean;
  back?: boolean;
  className?: string;
}) {
  const sheetRef = useRef<HTMLElement>(null);
  // Move keyboard focus into the sheet when it opens (e.g. from the new-order
  // alert) and give it back to whatever opened the sheet when it closes.
  useEffect(() => {
    const opener = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    if (!sheetRef.current?.contains(document.activeElement)) sheetRef.current?.focus();
    return () => { if (opener?.isConnected) opener.focus(); };
  }, []);
  return (
    <div className="wm-sheet-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}>
      <section ref={sheetRef} tabIndex={-1} className={`wm-sheet ${wide ? "wm-sheet--wide" : ""} ${className}`} role="dialog" aria-modal="true" aria-label={title}>
        <header><button type="button" aria-label={back ? "ย้อนกลับ" : "ปิด"} onClick={onClose}>{back ? <ChevronLeft size={24} /> : <X size={22} />}</button><h2>{title}</h2><span /></header>
        <div className="wm-sheet-body">{children}</div>
      </section>
    </div>
  );
}

function OrderSheet({
  client,
  store,
  order,
  onClose,
  onReload,
  onMessage,
}: {
  client: SupabaseClient;
  store: FoodStore;
  order: FoodOrder;
  onClose: () => void;
  onReload: () => void;
  onMessage: (message: string) => void;
}) {
  const [busy, setBusy] = useState(false);
  const [eta, setEta] = useState(order.eta_minutes ?? 30);
  // The signed slip URL for a given slip path; null url = it failed to load.
  const [slip, setSlip] = useState<{ path: string | null; url: string | null } | null>(null);
  const [proofUrl, setProofUrl] = useState<string | null>(null);
  const [deliveryMethod, setDeliveryMethod] = useState<"direct" | "dropoff">("direct");
  const [locationNote, setLocationNote] = useState("");
  const [deliveryFile, setDeliveryFile] = useState<File | null>(null);

  const proof = orderDeliveryProof(order);
  const proofPath = proof?.image_path;
  useEffect(() => {
    let live = true;
    void foodPrivateSignedUrl(client, order.payment_slip_path).then((url) => { if (live) setSlip({ path: order.payment_slip_path, url }); });
    void foodPrivateSignedUrl(client, proofPath).then((url) => { if (live) setProofUrl(url); });
    return () => { live = false; };
  }, [client, order.id, order.payment_slip_path, proofPath]);

  const slipLoaded = slip !== null && slip.path === order.payment_slip_path;
  const slipUrl = slipLoaded ? slip.url : null;
  // The image itself must render, not just its signed URL, before the store
  // can confirm the payment.
  const [slipImage, setSlipImage] = useState<{ url: string; ok: boolean } | null>(null);
  const slipShown = slipUrl !== null && slipImage?.url === slipUrl && slipImage.ok;
  const slipImageFailed = slipUrl !== null && slipImage?.url === slipUrl && !slipImage.ok;

  // Every action here changes the order's status or payment status. Keep the
  // buttons locked after a success until the reloaded order shows that change,
  // so a tap on the old snapshot cannot repeat the action.
  // updated_at changes with every server update, so the lock cannot come back
  // when a status cycles (e.g. slip issue -> new slip -> submitted again).
  const stateKey = `${order.status}:${order.payment_status}:${order.updated_at}`;
  const [actedAt, setActedAt] = useState<string | null>(null);
  const locked = busy || actedAt === stateKey;

  const run = async (action: () => Promise<void>, success?: string) => {
    setBusy(true);
    setActedAt(stateKey);
    try {
      await action();
      if (success) onMessage(success);
    } catch (error) { onMessage(merchantError(error)); setActedAt(null); }
    finally {
      // Reload after failures too: a two-step action may have half succeeded.
      onReload();
      setBusy(false);
    }
  };

  const complete = async () => {
    await run(async () => {
      if (!deliveryFile) throw new Error("กรุณาแนบรูปยืนยันการจัดส่งจากคนส่ง");
      if (deliveryMethod === "dropoff" && !locationNote.trim()) throw new Error("กรุณาระบุว่าวางสินค้าไว้ที่ไหน");
      const path = await uploadFoodPrivateImage(client, deliveryFile, `delivery/${order.id}`);
      await completeFoodDelivery(client, order.id, deliveryMethod, deliveryMethod === "dropoff" ? locationNote : "", path);
    }, "ส่งออเดอร์สำเร็จแล้ว");
  };

  const mapHref = foodMapsHref(
    order.delivery_latitude != null && order.delivery_longitude != null
      ? { latitude: Number(order.delivery_latitude), longitude: Number(order.delivery_longitude) }
      : null,
    order.shipping_address,
  );
  const receiptLegalName = order.receipt_legal_name ?? (store.tax_invoice_enabled ? (store.tax_legal_name || store.name) : null);
  const receiptTaxId = order.receipt_tax_id ?? (store.tax_invoice_enabled ? store.tax_id ?? null : null);
  const receiptTaxBranch = order.receipt_tax_branch ?? (store.tax_invoice_enabled ? store.tax_branch ?? null : null);
  const receiptTaxAddress = order.receipt_tax_address ?? (store.tax_invoice_enabled ? store.tax_address ?? store.address : null);

  return (
    <Sheet title={`ออเดอร์ #${order.order_number}`} onClose={onClose} wide>
      <section className="wm-print-document" aria-hidden="true">
        <div className="wm-print-brand"><strong>{store.name}</strong><small>{receiptLegalName ? "ใบเสร็จรับเงิน / ข้อมูลภาษี" : "ใบออเดอร์ / ใบเสร็จอย่างย่อ"}</small></div>
        {receiptLegalName ? <div className="wm-print-tax"><b>{receiptLegalName}</b>{receiptTaxId ? <span>เลขประจำตัวผู้เสียภาษี {receiptTaxId}</span> : null}{receiptTaxBranch ? <span>สาขา {receiptTaxBranch}</span> : null}{receiptTaxAddress ? <span>{receiptTaxAddress}</span> : null}</div> : null}
        <div className="wm-print-meta"><span>ออเดอร์ #{order.order_number}</span><span>{MERCHANT_DATE_TIME_FORMATTER.format(new Date(order.created_at))}</span>{order.scheduled_for ? <span>นัดรับ/จัดส่ง {MERCHANT_DATE_TIME_FORMATTER.format(new Date(order.scheduled_for))}</span> : null}</div>
        <div className="wm-print-lines">{(order.food_order_items ?? []).map((item) => <div key={item.id}><span>{item.quantity}× {item.item_name}{item.item_note ? <small>{item.item_note}</small> : null}</span><b>{money(Number(item.unit_price) * item.quantity)}</b></div>)}</div>
        <div className="wm-print-totals">
          <div><span>ค่าอาหาร</span><b>{money(order.subtotal)}</b></div>
          {Number(order.campaign_discount ?? 0) > 0 ? <div><span>ส่วนลด</span><b>−{money(order.campaign_discount)}</b></div> : null}
          <div><span>ค่าส่ง</span><b>{money(order.delivery_fee)}</b></div>
          {Number(order.delivery_discount ?? 0) > 0 ? <div><span>ส่วนลดค่าส่ง</span><b>−{money(order.delivery_discount)}</b></div> : null}
          <div className="is-total"><span>ยอดสุทธิ</span><b>{money(order.total)}</b></div>
        </div>
        <div className="wm-print-customer"><strong>{order.recipient_name}</strong><span>{order.recipient_phone}</span><span>{order.shipping_address}</span></div>
        <small className="wm-print-foot">พิมพ์จาก WYNOS Merchant · โปรดตรวจสอบข้อมูลภาษีของร้านก่อนใช้เป็นเอกสารทางบัญชี</small>
      </section>
      <div className="wm-order-detail-head">
        <div><OrderStatus order={order} /><PaymentStatus order={order} /></div>
        <strong>{money(order.total)}</strong>
        <small>{MERCHANT_DATE_TIME_FORMATTER.format(new Date(order.created_at))}</small>
        <button className="wm-secondary wm-print-order" type="button" onClick={() => window.print()}><Printer size={17} /> พิมพ์ใบออเดอร์ / ใบเสร็จ</button>
      </div>
      {order.scheduled_for ? <div className="wm-scheduled-order-banner"><Clock3 size={18} /><span><strong>ออเดอร์ล่วงหน้า</strong><small>{MERCHANT_DATE_TIME_FORMATTER.format(new Date(order.scheduled_for))}</small></span></div> : null}

      {order.status === "pending_acceptance" ? (
        <section className="wm-detail-section wm-next-step">
          <h3>รับออเดอร์</h3>
          {order.payment_status === "submitted" ? (
            <>
              <p>ดูสลิปให้แน่ใจว่าเงินเข้าแล้ว จากนั้นกดปุ่มเดียวเพื่อยืนยันเงินและรับออเดอร์</p>
              {slipUrl && !slipImageFailed ? (
                <a className="wm-slip-preview" href={slipUrl} target="_blank" rel="noreferrer">
                  <img
                    src={slipUrl}
                    alt="สลิปชำระเงิน"
                    onLoad={() => setSlipImage({ url: slipUrl, ok: true })}
                    onError={() => setSlipImage({ url: slipUrl, ok: false })}
                  />
                </a>
              ) : null}
              {!slipShown ? (
                <p role="status">{slipImageFailed || (slipLoaded && !slipUrl) ? "โหลดสลิปไม่สำเร็จ ปิดแล้วเปิดออเดอร์ใหม่อีกครั้ง" : "กำลังโหลดสลิป…"}</p>
              ) : null}
            </>
          ) : null}
          {order.payment_status === "pending" ? <p>รอลูกค้าโอนเงิน ถ้าได้รับเงินช่องทางอื่นแล้ว กด “ทำเครื่องหมายว่าชำระแล้ว” ด้านล่าง</p> : null}
          {order.payment_status === "issue" ? <p>แจ้งลูกค้าแล้วว่าสลิปมีปัญหา รอลูกค้าส่งสลิปใหม่</p> : null}
          {order.payment_status === "submitted" || order.payment_status === "paid" ? (
            <>
              <label>เวลาทำโดยประมาณ<select value={eta} onChange={(e) => setEta(Number(e.target.value))}><option value={15}>15 นาที</option><option value={30}>30 นาที</option><option value={45}>45 นาที</option><option value={60}>60 นาที</option></select></label>
              {order.payment_status === "submitted" ? (
                <>
                  {/* WYN-198: one button confirms the payment and accepts the order. */}
                  {/* The store must see the slip before it can confirm the payment. */}
                  <button className="wm-primary wm-full" disabled={locked || !slipShown} type="button" onClick={() => void run(async () => {
                    await setFoodPaymentStatus(client, order.id, "paid");
                    await transitionFoodOrder(client, order.id, "preparing", eta);
                  }, "ยืนยันเงินเข้าและรับออเดอร์แล้ว")}>เงินเข้าแล้ว · รับออเดอร์</button>
                  <button className="wm-secondary wm-full" disabled={locked} type="button" onClick={() => void run(() => setFoodPaymentStatus(client, order.id, "issue", "กรุณาตรวจสอบหรือส่งสลิปใหม่"), "แจ้งลูกค้าว่าสลิปมีปัญหาแล้ว")}>สลิปมีปัญหา</button>
                </>
              ) : (
                <button className="wm-primary wm-full" disabled={locked} type="button" onClick={() => void run(() => transitionFoodOrder(client, order.id, "preparing", eta), "รับออเดอร์แล้ว")}>รับออเดอร์</button>
              )}
            </>
          ) : null}
        </section>
      ) : null}

      {order.status === "preparing" ? (
        <section className="wm-detail-section wm-next-step"><h3>กำลังเตรียม</h3><p>เมื่ออาหารพร้อม ให้เปลี่ยนสถานะเพื่อเข้าสู่ขั้นตอนจัดส่ง</p><button className="wm-primary wm-full" disabled={locked} type="button" onClick={() => void run(() => transitionFoodOrder(client, order.id, "ready_for_delivery"), "อาหารพร้อมจัดส่ง")}>อาหารพร้อมแล้ว</button></section>
      ) : null}

      {order.status === "ready_for_delivery" ? (
        <section className="wm-detail-section wm-next-step"><h3>พร้อมจัดส่ง</h3><p>ส่งอาหารให้คนส่งแล้วกดเริ่มจัดส่ง เมื่อส่งถึงแล้ว ขอรูปจากคนส่งมาแนบเพื่อยืนยันกับลูกค้า</p><button className="wm-primary wm-full" disabled={locked} type="button" onClick={() => void run(() => transitionFoodOrder(client, order.id, "out_for_delivery"), "เริ่มจัดส่งแล้ว")}><Truck size={18} /> เริ่มจัดส่ง</button></section>
      ) : null}

      {order.status === "out_for_delivery" ? (
        <section className="wm-detail-section wm-next-step">
          <h3>Delivery Mode</h3>
          <div className="wm-delivery-methods">
            <button className={deliveryMethod === "direct" ? "is-active" : ""} type="button" onClick={() => setDeliveryMethod("direct")}><PackageCheck size={20} /><span><strong>ส่งให้ลูกค้า</strong><small>ส่งถึงมือผู้รับ · ต้องมีรูป</small></span></button>
            <button className={deliveryMethod === "dropoff" ? "is-active" : ""} type="button" onClick={() => setDeliveryMethod("dropoff")}><ImagePlus size={20} /><span><strong>วางสินค้าไว้</strong><small>ต้องมีรูปและจุดที่วาง</small></span></button>
          </div>
          <div className="wm-proof-form">
            <label className="wm-upload">
              <input type="file" accept="image/jpeg,image/png,image/webp" onChange={(e) => setDeliveryFile(e.target.files?.[0] ?? null)} />
              <ImagePlus size={22} /><span>{deliveryFile ? deliveryFile.name : "แนบรูปยืนยันการจัดส่งจากคนส่ง (จำเป็น)"}</span>
            </label>
            {deliveryMethod === "dropoff" ? (
              <label>วางสินค้าไว้ที่ไหน?<textarea value={locationNote} onChange={(e) => setLocationNote(e.target.value)} placeholder="เช่น โต๊ะหน้าประตูด้านซ้าย" /></label>
            ) : null}
          </div>
          <button className="wm-primary wm-full" disabled={locked || !deliveryFile || (deliveryMethod === "dropoff" && !locationNote.trim())} type="button" onClick={() => void complete()}><Check size={18} /> ยืนยันส่งสำเร็จ</button>
        </section>
      ) : null}


      <section className="wm-detail-section">
        <h3>รายการอาหาร</h3>
        <div className="wm-line-items">
          {(order.food_order_items ?? []).map((item) => (
            <div key={item.id}><b>{item.quantity}×</b><span><strong>{item.item_name}</strong>{item.item_note ? <small>{item.item_note}</small> : null}</span><em>{money(Number(item.unit_price) * item.quantity)}</em></div>
          ))}
        </div>
        <div className="wm-totals">
          <div><span>ค่าอาหาร</span><b>{money(order.subtotal)}</b></div>
          {Number(order.campaign_discount ?? 0) > 0 ? <div className="is-discount"><span>{order.campaign_name ? `โปรโมชั่น · ${order.campaign_name}` : "ส่วนลดโปรโมชั่น"}</span><b>−{money(order.campaign_discount)}</b></div> : null}
          <div><span>ค่าส่ง{order.delivery_distance_km != null ? ` · ${Number(order.delivery_distance_km).toFixed(1)} กม.` : ""}</span><b>{money(order.delivery_fee)}</b></div>
          {Number(order.delivery_discount ?? 0) > 0 ? <div className="is-discount"><span>ส่วนลดค่าส่ง</span><b>−{money(order.delivery_discount)}</b></div> : null}
          <div className="is-total"><span>ยอดสุทธิ</span><b>{money(order.total)}</b></div>
        </div>
      </section>

      <section className="wm-detail-section">
        <h3>การชำระเงิน</h3>
        <div className="wm-payment-box">
          <PaymentStatus order={order} />
          {slipUrl && !(order.status === "pending_acceptance" && order.payment_status === "submitted") ? <a href={slipUrl} target="_blank" rel="noreferrer"><img src={slipUrl} alt="สลิปชำระเงิน" /></a> : null}
          {order.payment_note ? <p>{order.payment_note}</p> : null}
          {order.payment_verification_status === "auto_verified" ? <p>ตรวจสลิปอัตโนมัติแล้ว · ยอดและบัญชีผู้รับตรงร้าน</p> : null}
          {order.payment_verification_status === "manual_review" && order.payment_status === "submitted" ? <p>ระบบรับสลิปแล้ว · รอร้านตรวจสอบ</p> : null}
          {order.payment_verification_status === "manual_verified" ? <p>ร้านยืนยันการชำระเงินแล้ว</p> : null}
          {order.payment_verification_status === "rejected" && order.payment_verification_note ? <p>{order.payment_verification_note}</p> : null}
          {order.status === "pending_acceptance" ? (
            order.payment_status === "pending" ? (
              <button className="wm-secondary wm-full" disabled={locked} type="button" onClick={() => void run(() => setFoodPaymentStatus(client, order.id, "paid"), "บันทึกว่าชำระแล้ว")}>ทำเครื่องหมายว่าชำระแล้ว</button>
            ) : null
          ) : order.payment_status === "submitted" ? (
            <div className="wm-two-actions">
              <button className="wm-primary" disabled={locked} type="button" onClick={() => void run(() => setFoodPaymentStatus(client, order.id, "paid"), "ยืนยันเงินเข้าแล้ว")}>ยืนยันเงินเข้า</button>
              <button className="wm-secondary" disabled={locked} type="button" onClick={() => void run(() => setFoodPaymentStatus(client, order.id, "issue", "กรุณาตรวจสอบหรือส่งสลิปใหม่"))}>มีปัญหา</button>
            </div>
          ) : order.payment_status === "pending" ? (
            <button className="wm-secondary wm-full" disabled={locked} type="button" onClick={() => void run(() => setFoodPaymentStatus(client, order.id, "paid"), "บันทึกว่าชำระแล้ว")}>ทำเครื่องหมายว่าชำระแล้ว</button>
          ) : null}
        </div>
      </section>

      <RefundControls
        client={client}
        order={order}
        onMessage={onMessage}
        onReload={onReload}
      />

      <section className="wm-detail-section">
        <h3>ลูกค้าและที่อยู่</h3>
        <div className="wm-customer-box">
          <strong>{order.recipient_name}</strong>
          <a href={`tel:${order.recipient_phone}`}><Phone size={17} /> {order.recipient_phone}</a>
          <p><MapPin size={17} /> <span>{order.shipping_address}</span></p>
          {order.customer_note ? <small>หมายเหตุ: {order.customer_note}</small> : null}
          <div className="wm-two-actions">
            <a className="wm-secondary" href={mapHref} target="_blank" rel="noreferrer"><MapPin size={17} /> เปิดแผนที่</a>
            <a className="wm-secondary" href={`tel:${order.recipient_phone}`}><Phone size={17} /> โทร</a>
          </div>
        </div>
      </section>



      {order.status === "delivered" ? (
        <section className="wm-detail-section wm-delivered-box"><PackageCheck size={28} /><div><strong>จัดส่งสำเร็จแล้ว</strong><small>{order.delivered_at ? MERCHANT_DATE_TIME_FORMATTER.format(new Date(order.delivered_at)) : ""}</small>{proof?.location_note ? <p>วางไว้: {proof.location_note}</p> : null}</div>{proofUrl ? <a href={proofUrl} target="_blank" rel="noreferrer"><img src={proofUrl} alt="หลักฐานการจัดส่ง" /></a> : null}</section>
      ) : null}

      {!["delivered", "cancelled"].includes(order.status) ? (
        <button className="wm-danger-link" disabled={locked} type="button" onClick={() => {
          if (!window.confirm("ยืนยันยกเลิกออเดอร์นี้?")) return;
          void run(() => transitionFoodOrder(client, order.id, "cancelled"), "ยกเลิกออเดอร์แล้ว");
        }}>ยกเลิกออเดอร์</button>
      ) : null}
    </Sheet>
  );
}

function MenuAddHub({
  onClose,
  onNewMenu,
  onOptions,
  onCategories,
}: {
  onClose: () => void;
  onNewMenu: () => void;
  onOptions: () => void;
  onCategories: () => void;
}) {
  const rows = [
    {
      group: "เมนู",
      title: "เพิ่มเมนูใหม่",
      description: "เพิ่มอาหารหรือเครื่องดื่ม",
      icon: <UtensilsCrossed size={24} strokeWidth={1.8} />,
      onClick: onNewMenu,
    },
    {
      group: "ตัวเลือก",
      title: "เพิ่มตัวเลือกเสริม",
      description: "ขนาด · ความเผ็ด · ท็อปปิง · ของเสริม",
      icon: <ListPlus size={24} strokeWidth={1.8} />,
      onClick: onOptions,
    },
    {
      group: "หมวดหมู่",
      title: "จัดการหมวดหมู่",
      description: "เพิ่ม · แก้ไข · จัดลำดับหมวดหมู่",
      icon: <Tags size={24} strokeWidth={1.8} />,
      onClick: onCategories,
    },
  ];

  return (
    <Sheet title="เพิ่มเมนู" onClose={onClose} back className="wm-sheet--menu-flow">
      <div className="wm-menu-create-hub">
        {rows.map((row) => (
          <section key={row.group} className="wm-menu-create-group">
            <h3>{row.group}</h3>
            <button className="wm-menu-create-card" type="button" onClick={row.onClick}>
              <span className="wm-menu-create-icon">{row.icon}</span>
              <span className="wm-menu-create-copy"><strong>{row.title}</strong><small>{row.description}</small></span>
              <ChevronRight size={22} strokeWidth={1.8} />
            </button>
          </section>
        ))}
      </div>
    </Sheet>
  );
}

function MenuOptionPicker({
  client,
  menu,
  onClose,
  onPick,
}: {
  client: SupabaseClient;
  menu: FoodMenuItem[];
  onClose: () => void;
  onPick: (item: FoodMenuItem) => void;
}) {
  const [query, setQuery] = useState("");
  const q = query.trim().toLocaleLowerCase("th-TH");
  const visible = q
    ? menu.filter((item) => `${item.name} ${item.category}`.toLocaleLowerCase("th-TH").includes(q))
    : menu;

  return (
    <Sheet title="เพิ่มตัวเลือกเสริม" onClose={onClose} back className="wm-sheet--menu-flow">
      <div className="wm-menu-tool-page">
        <div className="wm-menu-tool-intro">
          <span className="wm-menu-tool-intro-icon"><ListPlus size={24} /></span>
          <span><strong>เลือกเมนูที่ต้องการ</strong><small>จากนั้นเพิ่มขนาด ความเผ็ด ท็อปปิง หรือของเสริมในเมนูนั้น</small></span>
        </div>
        <label className="wm-search wm-menu-tool-search"><Search size={19} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="ค้นหาเมนู" /></label>
        <div className="wm-menu-tool-list">
          {visible.map((item) => {
            const image = foodPublicUrl(client, item.image_path);
            const optionCount = Array.isArray(item.options)
              ? item.options.reduce((sum, group) => sum + (Array.isArray(group.choices) ? group.choices.length : 0), 0)
              : 0;
            return (
              <button type="button" key={item.id} onClick={() => onPick(item)}>
                <span className="wm-menu-tool-thumb">{image ? <img src={image} alt="" loading="lazy" decoding="async" /> : <UtensilsCrossed size={22} />}</span>
                <span><strong>{item.name}</strong><small>{item.category} · {optionCount ? `${optionCount} ตัวเลือกเสริม` : "ยังไม่มีตัวเลือกเสริม"}</small></span>
                <ChevronRight size={19} />
              </button>
            );
          })}
          {!visible.length ? <div className="wm-menu-tool-empty">ไม่พบเมนูที่ค้นหา</div> : null}
        </div>
      </div>
    </Sheet>
  );
}

type MenuCategoryRow = {
  key: string;
  original: string | null;
  name: string;
};

function MenuCategoryManager({
  client,
  store,
  menu,
  onClose,
  onSaved,
  onMessage,
}: {
  client: SupabaseClient;
  store: FoodStore;
  menu: FoodMenuItem[];
  onClose: () => void;
  onSaved: () => Promise<void>;
  onMessage: (message: string) => void;
}) {
  const initial = Array.from(new Set([
    ...(Array.isArray(store.menu_category_order) ? store.menu_category_order : []),
    ...menu.map((item) => item.category.trim()).filter(Boolean),
  ]));
  const [rows, setRows] = useState<MenuCategoryRow[]>(() => initial.map((name) => ({ key: `existing-${name}`, original: name, name })));
  const [newName, setNewName] = useState("");
  const [busy, setBusy] = useState(false);

  const move = (index: number, delta: -1 | 1) => {
    const target = index + delta;
    if (target < 0 || target >= rows.length) return;
    setRows((current) => {
      const next = [...current];
      [next[index], next[target]] = [next[target], next[index]];
      return next;
    });
  };

  const addCategory = () => {
    const name = newName.trim();
    if (!name) return;
    if (rows.some((row) => row.name.trim().toLocaleLowerCase("th-TH") === name.toLocaleLowerCase("th-TH"))) {
      onMessage("มีหมวดหมู่นี้อยู่แล้ว");
      return;
    }
    setRows((current) => [...current, { key: `new-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`, original: null, name }]);
    setNewName("");
  };

  const save = async () => {
    const names = rows.map((row) => row.name.trim()).filter(Boolean);
    const normalized = names.map((name) => name.toLocaleLowerCase("th-TH"));
    if (!names.length) {
      onMessage("กรุณามีอย่างน้อย 1 หมวดหมู่");
      return;
    }
    if (new Set(normalized).size !== normalized.length) {
      onMessage("ชื่อหมวดหมู่ซ้ำกัน");
      return;
    }
    setBusy(true);
    try {
      const renameMap = new Map<string, string>(
        rows
          .filter((row) => row.original && row.original !== row.name.trim())
          .map((row) => [row.original as string, row.name.trim()] as const),
      );
      const affected = menu.filter((item) => renameMap.has(item.category));
      for (const item of affected) {
        await saveMenuItem(client, store.id, { ...menuDraftFromItem(item), category: renameMap.get(item.category) ?? item.category });
      }
      await saveMenuCategoryOrder(client, store.id, names);
      onMessage("บันทึกหมวดหมู่แล้ว");
      await onSaved();
    } catch (error) {
      onMessage(merchantError(error));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Sheet title="จัดการหมวดหมู่" onClose={onClose} back className="wm-sheet--menu-flow">
      <div className="wm-menu-category-manager">
        <div className="wm-menu-tool-intro">
          <span className="wm-menu-tool-intro-icon"><Tags size={24} /></span>
          <span><strong>หมวดหมู่เมนู</strong><small>เพิ่ม แก้ไขชื่อ และจัดลำดับให้ลูกค้าหาเมนูได้ง่ายขึ้น</small></span>
        </div>
        <div className="wm-menu-category-add">
          <input value={newName} onChange={(event) => setNewName(event.target.value)} onKeyDown={(event) => { if (event.key === "Enter") { event.preventDefault(); addCategory(); } }} placeholder="ชื่อหมวดหมู่ใหม่" />
          <button type="button" onClick={addCategory} disabled={!newName.trim()}><Plus size={17} /> เพิ่ม</button>
        </div>
        <div className="wm-menu-category-edit-list">
          {rows.map((row, index) => (
            <div key={row.key} className="wm-menu-category-edit-row">
              <GripVertical size={17} aria-hidden="true" />
              <input value={row.name} onChange={(event) => setRows((current) => current.map((item) => item.key === row.key ? { ...item, name: event.target.value } : item))} aria-label="ชื่อหมวดหมู่" />
              <span className="wm-sort-controls">
                <button type="button" aria-label="เลื่อนหมวดหมู่ขึ้น" disabled={index === 0} onClick={() => move(index, -1)}><ChevronUp size={14} /></button>
                <button type="button" aria-label="เลื่อนหมวดหมู่ลง" disabled={index === rows.length - 1} onClick={() => move(index, 1)}><ChevronDown size={14} /></button>
              </span>
            </div>
          ))}
        </div>
        <button className="wm-primary wm-full" type="button" disabled={busy} onClick={() => void save()}>{busy ? "กำลังบันทึก…" : "บันทึกหมวดหมู่"}</button>
      </div>
    </Sheet>
  );
}

function MenuEditor({
  client,
  store,
  draft,
  onClose,
  onSaved,
  onMessage,
}: {
  client: SupabaseClient;
  store: FoodStore;
  draft: MenuDraft;
  onClose: () => void;
  onSaved: () => Promise<void>;
  onMessage: (message: string) => void;
}) {
  const [form, setForm] = useState(draft);
  const [file, setFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(() => foodPublicUrl(client, draft.image_path ?? null));
  const [imageState, setImageState] = useState<"idle" | "selected" | "uploading" | "uploaded" | "error">(draft.image_path ? "uploaded" : "idle");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    return () => {
      if (previewUrl?.startsWith("blob:")) URL.revokeObjectURL(previewUrl);
    };
  }, [previewUrl]);

  const chooseImage = (next: File | null) => {
    if (!next) return;
    setFile(next);
    setPreviewUrl(URL.createObjectURL(next));
    setImageState("selected");
  };

  const removeImage = () => {
    setFile(null);
    setPreviewUrl(null);
    setImageState("idle");
    setForm((current) => ({ ...current, image_path: null }));
  };

  const updateGroup = (groupId: string, patch: Partial<FoodMenuOptionGroup>) => {
    setForm((current) => ({
      ...current,
      options: current.options.map((group) => group.id === groupId ? { ...group, ...patch } : group),
    }));
  };

  const addGroup = () => {
    const group: FoodMenuOptionGroup = {
      id: menuOptionId("group"),
      name: "",
      required: false,
      max_select: 1,
      choices: [{ id: menuOptionId("choice"), name: "", price: 0 }],
    };
    setForm((current) => ({ ...current, options: [...current.options, group] }));
  };

  const addChoice = (groupId: string) => {
    setForm((current) => ({
      ...current,
      options: current.options.map((group) => group.id === groupId
        ? { ...group, choices: [...group.choices, { id: menuOptionId("choice"), name: "", price: 0 }] }
        : group),
    }));
  };

  const updateChoice = (groupId: string, choiceId: string, patch: { name?: string; price?: string | number }) => {
    setForm((current) => ({
      ...current,
      options: current.options.map((group) => group.id === groupId
        ? { ...group, choices: group.choices.map((choice) => choice.id === choiceId ? { ...choice, ...patch } : choice) }
        : group),
    }));
  };

  const removeChoice = (groupId: string, choiceId: string) => {
    setForm((current) => ({
      ...current,
      options: current.options.map((group) => group.id === groupId
        ? { ...group, choices: group.choices.filter((choice) => choice.id !== choiceId) }
        : group),
    }));
  };

  const save = async () => {
    setBusy(true);
    try {
      let imagePath = form.image_path ?? null;
      if (file) {
        setImageState("uploading");
        imagePath = await uploadFoodPublicImage(client, file, `stores/${store.id}/menu`);
        setImageState("uploaded");
      }
      await saveMenuItem(client, store.id, { ...form, image_path: imagePath });
      onMessage(form.id ? "บันทึกเมนูแล้ว" : "เพิ่มเมนูแล้ว");
      await onSaved();
    } catch (error) {
      if (file) setImageState("error");
      onMessage(merchantError(error));
    } finally { setBusy(false); }
  };

  const remove = async () => {
    if (!form.id || !window.confirm("ลบเมนูนี้?")) return;
    setBusy(true);
    try { await deleteMenuItem(client, store.id, form.id); onMessage("ลบเมนูแล้ว"); await onSaved(); }
    catch (error) { onMessage(merchantError(error)); }
    finally { setBusy(false); }
  };

  return (
    <Sheet title={form.id ? "แก้ไขเมนู" : "เพิ่มเมนู"} onClose={onClose}>
      <div className="wm-form">
        <label>ชื่อเมนู<input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="เช่น ข้าวกะเพรา" /></label>
        <div className="wm-form-grid">
          <label>หมวดหมู่
            <input list="wm-food-categories" value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })} placeholder="เลือกหรือพิมพ์หมวดหมู่" />
            <datalist id="wm-food-categories">
              {Array.from(new Set([
                ...(Array.isArray(store.menu_category_order) ? store.menu_category_order : []),
                "อาหารจานหลัก",
                "ของทานเล่น",
                "เครื่องดื่ม",
                "ของหวาน",
                "เมนูแนะนำ",
                "อื่น ๆ",
              ])).map((category) => <option key={category} value={category} />)}
            </datalist>
          </label>
          <label>ราคา<input type="number" min="0" step="1" inputMode="decimal" value={form.price} onChange={(e) => setForm({ ...form, price: e.target.value })} placeholder="0" /></label>
        </div>
        <label>รายละเอียด<textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} placeholder="รายละเอียดอาหาร" /></label>

        <section className="wm-menu-image-editor">
          <div className="wm-menu-image-heading"><strong>รูปเมนู</strong><small>เห็นสถานะก่อนบันทึกได้ทันที</small></div>
          {previewUrl ? <div className="wm-menu-image-preview"><img src={previewUrl} alt="ตัวอย่างรูปเมนู" decoding="async" /></div> : null}
          <label className="wm-upload">
            <input type="file" accept="image/jpeg,image/png,image/webp" onChange={(e) => chooseImage(e.target.files?.[0] ?? null)} />
            <Upload size={20} />
            <span>{file ? "เปลี่ยนรูปที่เลือก" : form.image_path ? "เปลี่ยนรูปเมนู" : "เลือกรูปเมนู"}</span>
          </label>
          <div className={`wm-upload-status is-${imageState}`}>
            {imageState === "selected" ? "เลือกภาพแล้ว · ยังไม่อัปโหลด (จะอัปโหลดเมื่อกดบันทึก)" : null}
            {imageState === "uploading" ? "กำลังอัปโหลดรูป…" : null}
            {imageState === "uploaded" ? "รูปอัปโหลดแล้ว ✓" : null}
            {imageState === "error" ? "อัปโหลดรูปไม่สำเร็จ · ลองใหม่อีกครั้ง" : null}
            {imageState === "idle" ? "ยังไม่มีรูปเมนู" : null}
          </div>
          {previewUrl ? <button className="wm-inline-danger" type="button" disabled={busy} onClick={removeImage}>ลบรูป</button> : null}
        </section>

        <section className="wm-menu-options-editor">
          <div className="wm-menu-options-heading">
            <span><strong>ตัวเลือกเสริม</strong><small>เช่น ขนาด ระดับความเผ็ด ท็อปปิง หรือของเสริม</small></span>
            <button type="button" onClick={addGroup}><Plus size={15} /> เพิ่มกลุ่ม</button>
          </div>
          {form.options.length ? form.options.map((group) => (
            <div className="wm-option-group" key={group.id}>
              <div className="wm-option-group-top">
                <input value={group.name} onChange={(e) => updateGroup(group.id, { name: e.target.value })} placeholder="ชื่อกลุ่ม เช่น ขนาด" />
                <button type="button" aria-label="ลบกลุ่มตัวเลือก" onClick={() => setForm((current) => ({ ...current, options: current.options.filter((row) => row.id !== group.id) }))}><X size={16} /></button>
              </div>
              <div className="wm-option-rules">
                <label><input type="checkbox" checked={group.required} onChange={(e) => updateGroup(group.id, { required: e.target.checked })} /> บังคับเลือก</label>
                <label>เลือกได้สูงสุด <input type="number" min="1" max="20" value={group.max_select} onChange={(e) => updateGroup(group.id, { max_select: Math.max(1, Number(e.target.value) || 1) })} /></label>
              </div>
              <div className="wm-option-choices">
                {group.choices.map((choice) => (
                  <div className="wm-option-choice" key={choice.id}>
                    <input value={choice.name} onChange={(e) => updateChoice(group.id, choice.id, { name: e.target.value })} placeholder="ตัวเลือก เช่น เพิ่มไข่ดาว" />
                    <label>+฿<input type="number" min="0" step="1" inputMode="decimal" value={choice.price} onChange={(e) => updateChoice(group.id, choice.id, { price: e.target.value })} /></label>
                    <button type="button" aria-label="ลบตัวเลือก" onClick={() => removeChoice(group.id, choice.id)}><X size={15} /></button>
                  </div>
                ))}
              </div>
              <button className="wm-option-add-choice" type="button" onClick={() => addChoice(group.id)}><Plus size={14} /> เพิ่มตัวเลือก</button>
            </div>
          )) : <div className="wm-option-empty">ยังไม่มีตัวเลือกเสริม กด “เพิ่มกลุ่ม” เพื่อเริ่มเพิ่มได้</div>}
        </section>

        <section className="wm-menu-stock-editor">
          <div><strong>จำนวนขายต่อวัน</strong><small>เว้นว่าง = ไม่จำกัด ระบบนับใหม่ทุกวันตามเวลาไทย</small></div>
          <label>สูงสุดต่อวัน<input type="number" min="1" max="9999" inputMode="numeric" value={form.daily_stock_limit ?? ""} onChange={(e) => setForm({ ...form, daily_stock_limit: e.target.value })} placeholder="ไม่จำกัด" /></label>
          <small>ถ้ายอดครบ ระบบจะไม่รับออเดอร์เพิ่มของเมนูนี้จนถึงวันถัดไป</small>
        </section>
        <label className="wm-check-row"><input type="checkbox" checked={form.is_available} onChange={(e) => setForm({ ...form, is_available: e.target.checked })} /><span><strong>เปิดขาย</strong><small>ปิดได้ทันทีเมื่อเมนูหมด</small></span></label>
        <button className="wm-primary wm-full" type="button" disabled={busy} onClick={() => void save()}>{busy ? "กำลังบันทึก…" : "บันทึกเมนู"}</button>
        {form.id ? <button className="wm-danger-link" type="button" disabled={busy} onClick={() => void remove()}>ลบเมนู</button> : null}
      </div>
    </Sheet>
  );
}

function StoreEditor({
  client,
  store,
  onClose,
  onSaved,
  onMessage,
}: {
  client: SupabaseClient;
  store: FoodStore;
  onClose: () => void;
  onSaved: () => Promise<void>;
  onMessage: (message: string) => void;
}) {
  const [form, setForm] = useState({
    name: store.name,
    description: store.description ?? "",
    phone: store.phone ?? "",
    address: store.address ?? "",
    business_hours: store.business_hours ?? "",
    temporary_closed_reason: store.temporary_closed_reason ?? "",
    prep_time_min_minutes: String(store.prep_time_min_minutes ?? 15),
    prep_time_max_minutes: String(store.prep_time_max_minutes ?? 30),
    delivery_area: store.delivery_area ?? "",
    delivery_fee: String(store.delivery_fee),
    minimum_order: String(store.minimum_order),
    delivery_radius_km: String(store.delivery_radius_km ?? 5),
    delivery_base_km: String(store.delivery_base_km ?? 2),
    delivery_fee_per_km: String(store.delivery_fee_per_km ?? 0),
    promptpay_name: store.promptpay_name ?? "",
    promptpay_id: store.promptpay_id ?? "",
    bank_name: store.bank_name ?? "",
    bank_account_name: store.bank_account_name ?? "",
    bank_account_number: store.bank_account_number ?? "",
    payment_qr_path: store.payment_qr_path,
    scheduled_orders_enabled: store.scheduled_orders_enabled === true,
    scheduled_min_notice_minutes: String(store.scheduled_min_notice_minutes ?? 30),
    scheduled_max_days: String(store.scheduled_max_days ?? 7),
    tax_invoice_enabled: store.tax_invoice_enabled === true,
    tax_legal_name: store.tax_legal_name ?? "",
    tax_id: store.tax_id ?? "",
    tax_branch: store.tax_branch ?? "",
    tax_address: store.tax_address ?? "",
    logo_path: store.logo_path,
    cover_path: store.cover_path,
    pickup_note: store.pickup_note ?? "",
  });
  const [logoFile, setLogoFile] = useState<File | null>(null);
  const [coverFile, setCoverFile] = useState<File | null>(null);
  const [logoPreview, setLogoPreview] = useState<string | null>(() => foodPublicUrl(client, store.logo_path));
  const [coverPreview, setCoverPreview] = useState<string | null>(() => foodPublicUrl(client, store.cover_path));
  const [logoState, setLogoState] = useState<"idle" | "selected" | "uploading" | "uploaded" | "error">(store.logo_path ? "uploaded" : "idle");
  const [coverState, setCoverState] = useState<"idle" | "selected" | "uploading" | "uploaded" | "error">(store.cover_path ? "uploaded" : "idle");
  const [qrFile, setQrFile] = useState<File | null>(null);
  const [busy, setBusy] = useState(false);
  const [schedule, setSchedule] = useState<FoodBusinessSchedule>(() => {
    const current = store.business_schedule as FoodBusinessSchedule | undefined;
    return current?.weekly ? current : defaultFoodBusinessSchedule();
  });
  const [specialClosedDates, setSpecialClosedDates] = useState<string[]>(() => Array.isArray(store.special_closed_dates) ? store.special_closed_dates : []);
  const [newClosedDate, setNewClosedDate] = useState("");
  const [temporaryClosedUntil, setTemporaryClosedUntil] = useState(() => localDateTimeInput(store.temporary_closed_until));
  // WYN-196: pinned store location for the delivery radius and per-km fee.
  const [pin, setPin] = useState<FoodLocation | null>(
    store.latitude != null && store.longitude != null ? { latitude: Number(store.latitude), longitude: Number(store.longitude) } : null,
  );
  const [pinStatus, setPinStatus] = useState("");
  const [pinPlace, setPinPlace] = useState<FoodPlace | null>(null);
  const [pickupPin, setPickupPin] = useState<FoodLocation | null>(
    store.pickup_latitude != null && store.pickup_longitude != null
      ? { latitude: Number(store.pickup_latitude), longitude: Number(store.pickup_longitude) }
      : null,
  );
  const [mapTarget, setMapTarget] = useState<"store" | "pickup" | null>(null);
  const [serviceAreaCheck, setServiceAreaCheck] = useState<{
    key: string;
    status: "inside" | "outside" | "error";
  } | null>(null);
  const serviceAreaKey = pin ? `${pin.latitude.toFixed(6)},${pin.longitude.toFixed(6)}` : "";
  const serviceAreaState: "idle" | "checking" | "inside" | "outside" | "error" =
    !pin ? "idle" : serviceAreaCheck?.key === serviceAreaKey ? serviceAreaCheck.status : "checking";
  const [locationQualityState, setLocationQualityState] = useState<{ key: string; value: MerchantLocationQuality | null } | null>(null);
  const locationQuality = locationQualityState?.key === serviceAreaKey ? locationQualityState.value : null;

  useEffect(() => {
    return () => {
      if (logoPreview?.startsWith("blob:")) URL.revokeObjectURL(logoPreview);
      if (coverPreview?.startsWith("blob:")) URL.revokeObjectURL(coverPreview);
    };
  }, [logoPreview, coverPreview]);

  useEffect(() => {
    if (!pin) return;
    let live = true;
    const key = `${pin.latitude.toFixed(6)},${pin.longitude.toFixed(6)}`;
    void checkFoodServiceArea(client, pin)
      .then((inside) => { if (live) setServiceAreaCheck({ key, status: inside ? "inside" : "outside" }); })
      .catch(() => { if (live) setServiceAreaCheck({ key, status: "error" }); });
    return () => { live = false; };
  }, [client, pin]);

  useEffect(() => {
    if (!pin) return;
    let live = true;
    const key = `${pin.latitude.toFixed(6)},${pin.longitude.toFixed(6)}`;
    void checkMerchantLocationQuality(client, store.id, pin.latitude, pin.longitude, form.name)
      .then((value) => { if (live) setLocationQualityState({ key, value }); })
      .catch(() => { if (live) setLocationQualityState({ key, value: null }); });
    return () => { live = false; };
  }, [client, form.name, pin, store.id]);

  const chooseBrandImage = (kind: "logo" | "cover", file: File | null) => {
    if (!file) return;
    const preview = URL.createObjectURL(file);
    if (kind === "logo") {
      setLogoFile(file);
      setLogoPreview(preview);
      setLogoState("selected");
    } else {
      setCoverFile(file);
      setCoverPreview(preview);
      setCoverState("selected");
    }
  };

  const removeBrandImage = (kind: "logo" | "cover") => {
    if (kind === "logo") {
      setLogoFile(null);
      setLogoPreview(null);
      setLogoState("idle");
      setForm((current) => ({ ...current, logo_path: null }));
    } else {
      setCoverFile(null);
      setCoverPreview(null);
      setCoverState("idle");
      setForm((current) => ({ ...current, cover_path: null }));
    }
  };

  const brandStatus = (state: "idle" | "selected" | "uploading" | "uploaded" | "error") => {
    if (state === "selected") return "เลือกภาพแล้ว · ยังไม่อัปโหลด (จะอัปโหลดเมื่อกดบันทึก)";
    if (state === "uploading") return "กำลังอัปโหลดรูป…";
    if (state === "uploaded") return "รูปอัปโหลดแล้ว ✓";
    if (state === "error") return "อัปโหลดรูปไม่สำเร็จ · ลองใหม่อีกครั้ง";
    return "ยังไม่มีรูป";
  };

  // The zone columns exist only once the WYN-196 migration is applied.
  const zoneReady = store.delivery_radius_km !== undefined;
  const pinStore = async () => {
    setPinStatus("กำลังหาตำแหน่ง…");
    try {
      setPin(await currentFoodLocation());
      setPinStatus("ปักหมุดตำแหน่งร้านแล้ว อย่าลืมกดบันทึก");
    } catch (error) {
      setPinStatus(error instanceof Error ? error.message : "หาตำแหน่งไม่สำเร็จ");
    }
  };

  const save = async () => {
    setBusy(true);
    let activeBrandUpload: "logo" | "cover" | null = null;
    try {
      let qr = form.payment_qr_path;
      let logo = form.logo_path;
      let cover = form.cover_path;
      if (logoFile) {
        activeBrandUpload = "logo";
        setLogoState("uploading");
        logo = await uploadFoodPublicImage(client, logoFile, `stores/${store.id}/profile`);
        setLogoState("uploaded");
        activeBrandUpload = null;
      }
      if (coverFile) {
        activeBrandUpload = "cover";
        setCoverState("uploading");
        cover = await uploadFoodPublicImage(client, coverFile, `stores/${store.id}/cover`);
        setCoverState("uploaded");
        activeBrandUpload = null;
      }
      if (qrFile) qr = await uploadFoodPublicImage(client, qrFile, `stores/${store.id}/payment`);
      await updateFoodStore(client, store.id, {
        name: form.name.trim(),
        description: form.description.trim() || null,
        phone: form.phone.trim() || null,
        address: form.address.trim() || null,
        business_hours: form.business_hours.trim() || null,
        business_schedule: schedule,
        special_closed_dates: specialClosedDates,
        temporary_closed_until: temporaryClosedUntil ? new Date(temporaryClosedUntil).toISOString() : null,
        temporary_closed_reason: form.temporary_closed_reason.trim() || null,
        prep_time_min_minutes: Number(form.prep_time_min_minutes || 15),
        prep_time_max_minutes: Number(form.prep_time_max_minutes || 30),
        delivery_area: form.delivery_area.trim() || null,
        delivery_fee: Number(form.delivery_fee || 0),
        minimum_order: Number(form.minimum_order || 0),
        ...(zoneReady ? {
          latitude: pin?.latitude ?? null,
          longitude: pin?.longitude ?? null,
          pickup_latitude: pickupPin?.latitude ?? null,
          pickup_longitude: pickupPin?.longitude ?? null,
          pickup_note: form.pickup_note.trim() || null,
          delivery_radius_km: Number(form.delivery_radius_km || 5),
          delivery_base_km: Number(form.delivery_base_km || 0),
          delivery_fee_per_km: Number(form.delivery_fee_per_km || 0),
        } : {}),
        promptpay_name: form.promptpay_name.trim() || null,
        promptpay_id: form.promptpay_id.trim() || null,
        bank_name: form.bank_name.trim() || null,
        bank_account_name: form.bank_account_name.trim() || null,
        bank_account_number: form.bank_account_number.trim() || null,
        payment_qr_path: qr,
        scheduled_orders_enabled: form.scheduled_orders_enabled,
        scheduled_min_notice_minutes: Math.max(15, Math.min(1440, Number(form.scheduled_min_notice_minutes || 30))),
        scheduled_max_days: Math.max(1, Math.min(30, Number(form.scheduled_max_days || 7))),
        tax_invoice_enabled: form.tax_invoice_enabled,
        tax_legal_name: form.tax_legal_name.trim() || null,
        tax_id: form.tax_id.trim() || null,
        tax_branch: form.tax_branch.trim() || null,
        tax_address: form.tax_address.trim() || null,
        logo_path: logo,
        cover_path: cover,
      });
      onMessage("บันทึกข้อมูลร้านแล้ว");
      await onSaved();
    } catch (error) {
      if (activeBrandUpload === "logo") setLogoState("error");
      if (activeBrandUpload === "cover") setCoverState("error");
      onMessage(merchantError(error));
    }
    finally { setBusy(false); }
  };

  return (
    <Sheet title="ตั้งค่าร้าน" onClose={onClose} wide>
      <div className="wm-form wm-store-settings-form">
        <nav className="wm-store-settings-nav" aria-label="หมวดการตั้งค่าร้าน">
          <button type="button" onClick={() => document.getElementById("wm-store-section-info")?.scrollIntoView({ behavior: "smooth", block: "start" })}><Store size={16} /> ข้อมูลร้าน</button>
          <button type="button" onClick={() => document.getElementById("wm-store-section-media")?.scrollIntoView({ behavior: "smooth", block: "start" })}><ImagePlus size={16} /> รูปภาพร้าน</button>
          <button type="button" onClick={() => document.getElementById("wm-store-section-hours")?.scrollIntoView({ behavior: "smooth", block: "start" })}><CalendarDays size={16} /> เวลาเปิด–ปิด</button>
          <button type="button" onClick={() => document.getElementById("wm-store-section-delivery")?.scrollIntoView({ behavior: "smooth", block: "start" })}><MapPin size={16} /> ตำแหน่งและจัดส่ง</button>
          <button type="button" onClick={() => document.getElementById("wm-store-section-payment")?.scrollIntoView({ behavior: "smooth", block: "start" })}><CircleDollarSign size={16} /> การชำระเงิน</button>
        </nav>

        <section className="wm-settings-category" id="wm-store-section-info">
          <div className="wm-settings-category-head">
            <span className="wm-settings-category-icon"><Store size={20} /></span>
            <span><strong>ข้อมูลร้าน</strong><small>ชื่อร้าน รายละเอียด และช่องทางติดต่อหลัก</small></span>
          </div>
          <div className="wm-settings-category-body">
            <label>ชื่อร้าน<input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></label>
            <label>รายละเอียด<textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} /></label>
            <label>เบอร์ร้าน<input value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} inputMode="tel" /></label>
          </div>
        </section>

        <section className="wm-settings-category" id="wm-store-section-media">
          <div className="wm-settings-category-head">
            <span className="wm-settings-category-icon"><ImagePlus size={20} /></span>
            <span><strong>รูปภาพร้าน</strong><small>รูปโปรไฟล์และรูปปกที่ลูกค้าจะเห็นบน WYNOS Food</small></span>
          </div>
          <div className="wm-settings-category-body">
            <section className="wm-store-brand-editor">
              <div className="wm-store-brand-heading">
                <span><strong>รูปโปรไฟล์และรูปปกร้าน</strong><small>ตรวจ Preview ให้เรียบร้อยก่อนกดบันทึก</small></span>
              </div>
              <div className="wm-store-brand-preview">
                <div className="wm-store-brand-cover">
                  {coverPreview ? <img src={coverPreview} alt="รูปปกร้านตัวอย่าง" /> : <span><Store size={34} /><small>รูปปกร้าน</small></span>}
                </div>
                <div className="wm-store-brand-logo">
                  {logoPreview ? <img src={logoPreview} alt="รูปโปรไฟล์ร้านตัวอย่าง" /> : <Store size={28} />}
                </div>
              </div>
              <div className="wm-store-brand-fields">
                <div className="wm-store-brand-field">
                  <div><strong>รูปโปรไฟล์ร้าน</strong><small>แนะนำรูปสี่เหลี่ยม 1:1</small></div>
                  <label className="wm-upload"><input type="file" accept="image/jpeg,image/png,image/webp" onChange={(e) => chooseBrandImage("logo", e.target.files?.[0] ?? null)} /><Upload size={18} /><span>{logoPreview ? "เปลี่ยนรูปโปรไฟล์ร้าน" : "เพิ่มรูปโปรไฟล์ร้าน"}</span></label>
                  <div className={`wm-upload-status is-${logoState}`}>{brandStatus(logoState)}</div>
                  {logoPreview ? <button className="wm-inline-danger" type="button" disabled={busy} onClick={() => removeBrandImage("logo")}>ลบรูปโปรไฟล์ร้าน</button> : null}
                </div>
                <div className="wm-store-brand-field">
                  <div><strong>รูปปกร้าน</strong><small>แนะนำรูปแนวนอน 16:9</small></div>
                  <label className="wm-upload"><input type="file" accept="image/jpeg,image/png,image/webp" onChange={(e) => chooseBrandImage("cover", e.target.files?.[0] ?? null)} /><Upload size={18} /><span>{coverPreview ? "เปลี่ยนรูปปกร้าน" : "เพิ่มรูปปกร้าน"}</span></label>
                  <div className={`wm-upload-status is-${coverState}`}>{brandStatus(coverState)}</div>
                  {coverPreview ? <button className="wm-inline-danger" type="button" disabled={busy} onClick={() => removeBrandImage("cover")}>ลบรูปปกร้าน</button> : null}
                </div>
              </div>
            </section>
          </div>
        </section>

        <section className="wm-settings-category" id="wm-store-section-hours">
          <div className="wm-settings-category-head">
            <span className="wm-settings-category-icon"><CalendarDays size={20} /></span>
            <span><strong>เวลาเปิด–ปิดและการเตรียมอาหาร</strong><small>กำหนดเวลารายวัน วันหยุด ปิดชั่วคราว และเวลาเตรียมออเดอร์</small></span>
          </div>
          <div className="wm-settings-category-body">
        <label>ข้อความสรุปเวลา <small>ไม่บังคับ</small><input value={form.business_hours} onChange={(e) => setForm({ ...form, business_hours: e.target.value })} placeholder="เช่น เปิดทุกวัน" /></label>
        <section className="wm-schedule-editor">
          <div className="wm-schedule-heading"><span><CalendarDays size={18} /><strong>เวลาเปิด–ปิดรายวัน</strong></span><small>ระบบจะเปิด/ปิดการรับออเดอร์ตามเวลาไทยอัตโนมัติ</small></div>
          <div className="wm-schedule-days">
            {FOOD_DAY_KEYS.map((key) => {
              const day = schedule.weekly[key] ?? { enabled: false, open: "09:00", close: "21:00" };
              return <div className="wm-schedule-day" key={key}>
                <label className="wm-check-row"><input type="checkbox" checked={day.enabled} onChange={(e) => setSchedule((current) => ({ ...current, weekly: { ...current.weekly, [key]: { ...day, enabled: e.target.checked } } }))} /><span><strong>{FOOD_DAY_LABELS[key]}</strong><small>{day.enabled ? "เปิด" : "ปิด"}</small></span></label>
                <input type="time" value={day.open} disabled={!day.enabled} onChange={(e) => setSchedule((current) => ({ ...current, weekly: { ...current.weekly, [key]: { ...day, open: e.target.value } } }))} />
                <span>–</span>
                <input type="time" value={day.close} disabled={!day.enabled} onChange={(e) => setSchedule((current) => ({ ...current, weekly: { ...current.weekly, [key]: { ...day, close: e.target.value } } }))} />
              </div>;
            })}
          </div>
          <div className="wm-special-days">
            <strong>วันหยุดพิเศษ</strong>
            <div className="wm-two-actions">
              <input type="date" value={newClosedDate} onChange={(e) => setNewClosedDate(e.target.value)} />
              <button className="wm-secondary" type="button" disabled={!newClosedDate || specialClosedDates.includes(newClosedDate)} onClick={() => { setSpecialClosedDates((rows) => [...rows, newClosedDate].sort()); setNewClosedDate(""); }}>เพิ่มวันหยุด</button>
            </div>
            {specialClosedDates.length ? <div className="wm-date-chips">{specialClosedDates.map((date) => <button type="button" key={date} onClick={() => setSpecialClosedDates((rows) => rows.filter((row) => row !== date))}>{date} <X size={13} /></button>)}</div> : <small>ยังไม่มีวันหยุดพิเศษ</small>}
          </div>
          <div className="wm-temporary-close">
            <strong>ปิดชั่วคราว</strong>
            <div className="wm-quick-close">
              <button type="button" onClick={() => setTemporaryClosedUntil(localFutureInput(30))}>30 นาที</button>
              <button type="button" onClick={() => setTemporaryClosedUntil(localFutureInput(60))}>1 ชั่วโมง</button>
              <button type="button" onClick={() => setTemporaryClosedUntil(localFutureInput(180))}>3 ชั่วโมง</button>
              <button type="button" onClick={() => setTemporaryClosedUntil("")}>ยกเลิก</button>
            </div>
            <label>ปิดถึง<input type="datetime-local" value={temporaryClosedUntil} onChange={(e) => setTemporaryClosedUntil(e.target.value)} /></label>
            <label>เหตุผล<input value={form.temporary_closed_reason} onChange={(e) => setForm({ ...form, temporary_closed_reason: e.target.value })} maxLength={200} placeholder="เช่น วัตถุดิบหมด / พักร้านชั่วคราว" /></label>
          </div>
          <div className="wm-form-grid">
            <label>เตรียมอาหารเร็วสุด (นาที)<input type="number" min="1" max="240" value={form.prep_time_min_minutes} onChange={(e) => setForm({ ...form, prep_time_min_minutes: e.target.value })} /></label>
            <label>เตรียมอาหารช้าสุด (นาที)<input type="number" min="1" max="240" value={form.prep_time_max_minutes} onChange={(e) => setForm({ ...form, prep_time_max_minutes: e.target.value })} /></label>
          </div>
          <div className="wm-scheduled-settings">
            <label className="wm-check-row"><input type="checkbox" checked={form.scheduled_orders_enabled} onChange={(e) => setForm({ ...form, scheduled_orders_enabled: e.target.checked })} /><span><strong>เปิดรับออเดอร์ล่วงหน้า</strong><small>ลูกค้าสามารถเลือกวันและเวลาจัดส่งได้ขณะร้านเปิดรับออเดอร์</small></span></label>
            {form.scheduled_orders_enabled ? <div className="wm-form-grid">
              <label>ต้องสั่งล่วงหน้าอย่างน้อย (นาที)<input type="number" min="15" max="1440" value={form.scheduled_min_notice_minutes} onChange={(e) => setForm({ ...form, scheduled_min_notice_minutes: e.target.value })} /></label>
              <label>รับล่วงหน้าได้สูงสุด (วัน)<input type="number" min="1" max="30" value={form.scheduled_max_days} onChange={(e) => setForm({ ...form, scheduled_max_days: e.target.value })} /></label>
            </div> : null}
          </div>
        </section>
          </div>
        </section>

        <section className="wm-settings-category" id="wm-store-section-delivery">
          <div className="wm-settings-category-head">
            <span className="wm-settings-category-icon"><MapPin size={20} /></span>
            <span><strong>ตำแหน่งและการจัดส่ง</strong><small>ที่อยู่ร้าน หมุดบนแผนที่ ระยะส่ง ค่าส่ง จุดรับอาหาร และพื้นที่ที่ส่งบ่อย</small></span>
          </div>
          <div className="wm-settings-category-body">
        <label>ที่อยู่ร้าน<textarea value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} placeholder="ที่อยู่ที่ลูกค้าและไรเดอร์ใช้ค้นหาร้าน" /></label>
        <label>พื้นที่จัดส่ง<textarea value={form.delivery_area} onChange={(e) => setForm({ ...form, delivery_area: e.target.value })} placeholder="เช่น รัศมี 5 กม. / เขตที่ให้บริการ" /></label>
        <div className="wm-form-grid"><label>ค่าส่งเริ่มต้น<input type="number" min="0" inputMode="decimal" value={form.delivery_fee} onChange={(e) => setForm({ ...form, delivery_fee: e.target.value })} /></label><label>ยอดขั้นต่ำ<input type="number" min="0" inputMode="decimal" value={form.minimum_order} onChange={(e) => setForm({ ...form, minimum_order: e.target.value })} /></label></div>
        {zoneReady ? <div className="wm-zone">
          <strong>ตำแหน่งร้านและระยะส่ง</strong>
          <small>{pin ? "ตำแหน่งร้านถูกปักหมุดแล้ว สามารถค้นหา เลื่อนแผนที่ และปรับหมุดให้ตรงจุดจริงได้" : "ยังไม่ปักหมุด: ร้านจะยังไม่ขึ้น WYNOS Maps"}</small>
          {pin ? <FoodLocationMapPreview location={pin} label={pinPlace?.name || store.name} /> : null}
          {pinPlace?.address ? <div className="wm-location-address"><MapPin size={15} /><span><strong>{pinPlace.name}</strong><small>{pinPlace.address}</small></span></div> : null}
          <div className="wm-two-actions">
            <button className="wm-secondary" type="button" onClick={() => setMapTarget("store")}><Search size={16} /> {pin ? "แก้ไขตำแหน่งบนแผนที่" : "ค้นหาและปักหมุดบนแผนที่"}</button>
            <button className="wm-secondary" type="button" onClick={() => void pinStore()}>ใช้ตำแหน่งปัจจุบัน</button>
          </div>
          {pin ? <button className="wm-inline-danger" type="button" onClick={() => { setPin(null); setPinPlace(null); setPinStatus("ล้างหมุดแล้ว อย่าลืมกดบันทึก"); }}>ล้างตำแหน่งร้าน</button> : null}
          {serviceAreaState !== "idle" ? (
            <div className={`wm-service-area-state is-${serviceAreaState}`} role="status">
              {serviceAreaState === "checking" ? "กำลังตรวจพื้นที่ให้บริการ…" : null}
              {serviceAreaState === "inside" ? "ตำแหน่งร้านอยู่ในพื้นที่ให้บริการ WYNOS Food ✓" : null}
              {serviceAreaState === "outside" ? "ร้านอยู่นอกพื้นที่ให้บริการปัจจุบัน — ยังบันทึกข้อมูลร้านได้ แต่การจัดส่งจะยังไม่เปิดให้ลูกค้า" : null}
              {serviceAreaState === "error" ? "ตรวจพื้นที่ให้บริการไม่สำเร็จ แต่ยังบันทึกตำแหน่งร้านได้" : null}
            </div>
          ) : null}
          {pinStatus ? <p role="status">{pinStatus}</p> : null}
          {pin && locationQuality ? <div className={`wm-location-quality ${locationQuality.warnings.length ? "has-warning" : "is-good"}`}>
            <span><strong>คุณภาพตำแหน่ง {locationQuality.score}/100</strong><small>{locationQuality.warnings.includes("possible_duplicate") ? "พบร้านชื่อเดียวกันใกล้จุดนี้ อาจเป็นร้านซ้ำ" : locationQuality.warnings.includes("very_close_to_another_store") ? "มีร้านอื่นอยู่ใกล้มาก โปรดตรวจหมุดให้ตรงหน้าร้าน" : locationQuality.warnings.includes("pickup_far_from_store") ? "จุดรับอาหารอยู่ห่างจากร้านมากผิดปกติ" : "ตำแหน่งดูปกติ ✓"}</small></span>
          </div> : null}

          <div className="wm-form-grid">
            <label>ส่งไกลสุด (กม.)<input type="number" min="0.5" max="50" step="0.5" inputMode="decimal" value={form.delivery_radius_km} onChange={(e) => setForm({ ...form, delivery_radius_km: e.target.value })} /></label>
            <label>รวมในค่าส่งเริ่มต้น (กม.)<input type="number" min="0" max="50" step="0.5" inputMode="decimal" value={form.delivery_base_km} onChange={(e) => setForm({ ...form, delivery_base_km: e.target.value })} /></label>
          </div>
          <label>บาทต่อ กม. ที่เกิน<input type="number" min="0" max="1000" inputMode="decimal" value={form.delivery_fee_per_km} onChange={(e) => setForm({ ...form, delivery_fee_per_km: e.target.value })} /></label>
          <small>{`ตัวอย่าง: ส่ง 4 กม. ค่าส่ง ${exampleFee(form.delivery_fee, form.delivery_base_km, form.delivery_fee_per_km)} บาท (ส่วนที่เกินคิดต่อ กม. ปัดขึ้นเป็นบาทเต็ม)`}</small>

          <div className="wm-pickup-zone">
            <strong>จุดรับอาหาร / ทางเข้าร้านสำหรับไรเดอร์</strong>
            <small>แยกจากตำแหน่งร้านหลัก เหมาะสำหรับร้านในห้าง อาคาร หรือร้านที่มีจุดรับของเฉพาะ</small>
            {pickupPin ? <FoodLocationMapPreview location={pickupPin} label="จุดรับอาหาร / ทางเข้า" /> : null}
            <label>รายละเอียดจุดรับอาหาร<textarea value={form.pickup_note} onChange={(e) => setForm({ ...form, pickup_note: e.target.value })} maxLength={500} placeholder="เช่น รับอาหารประตูหลัง ชั้น G ข้างจุดจอดไรเดอร์" /></label>
            <div className="wm-two-actions">
              <button className="wm-secondary" type="button" onClick={() => setMapTarget("pickup")}><MapPin size={16} /> {pickupPin ? "แก้ไขจุดรับอาหาร" : "เพิ่มจุดรับอาหาร"}</button>
              {pickupPin ? <button className="wm-secondary" type="button" onClick={() => setPickupPin(null)}>ล้างจุดรับอาหาร</button> : null}
            </div>
          </div>
        </div> : null}
        {zoneReady ? <StorePlacesEditor client={client} storeId={store.id} storePin={pin} radiusKm={Number(form.delivery_radius_km || 5)} /> : null}
          </div>
        </section>

        <section className="wm-settings-category" id="wm-store-section-payment">
          <div className="wm-settings-category-head">
            <span className="wm-settings-category-icon"><CircleDollarSign size={20} /></span>
            <span><strong>การรับชำระเงิน</strong><small>PromptPay บัญชีธนาคาร และ QR สำหรับรับเงินเข้าร้าน</small></span>
          </div>
          <div className="wm-settings-category-body">
        <div className="wm-form-grid"><label>ชื่อ PromptPay<input value={form.promptpay_name} onChange={(e) => setForm({ ...form, promptpay_name: e.target.value })} /></label><label>เบอร์/เลข PromptPay<input value={form.promptpay_id} onChange={(e) => setForm({ ...form, promptpay_id: e.target.value })} /></label></div>
        <label>ธนาคาร<input value={form.bank_name} onChange={(e) => setForm({ ...form, bank_name: e.target.value })} /></label>
        <label>ชื่อบัญชี<input value={form.bank_account_name} onChange={(e) => setForm({ ...form, bank_account_name: e.target.value })} /></label>
        <label>เลขบัญชี<input value={form.bank_account_number} onChange={(e) => setForm({ ...form, bank_account_number: e.target.value })} inputMode="numeric" /></label>
        <label className="wm-upload"><input type="file" accept="image/jpeg,image/png,image/webp" onChange={(e) => setQrFile(e.target.files?.[0] ?? null)} /><Upload size={20} /><span>{qrFile ? qrFile.name : "อัปโหลด QR รับเงิน"}</span></label>
        <div className="wm-tax-settings">
          <label className="wm-check-row"><input type="checkbox" checked={form.tax_invoice_enabled} onChange={(e) => setForm({ ...form, tax_invoice_enabled: e.target.checked })} /><span><strong>แสดงข้อมูลภาษีในใบเสร็จ</strong><small>ใช้สำหรับเอกสารที่พิมพ์จาก WYNOS Merchant</small></span></label>
          {form.tax_invoice_enabled ? (
            <>
              <label>ชื่อกิจการ / ชื่อนิติบุคคล<input value={form.tax_legal_name} onChange={(e) => setForm({ ...form, tax_legal_name: e.target.value })} maxLength={200} /></label>
              <div className="wm-form-grid">
                <label>เลขประจำตัวผู้เสียภาษี<input value={form.tax_id} onChange={(e) => setForm({ ...form, tax_id: e.target.value })} maxLength={40} inputMode="numeric" /></label>
                <label>สาขา<input value={form.tax_branch} onChange={(e) => setForm({ ...form, tax_branch: e.target.value })} maxLength={120} placeholder="เช่น สำนักงานใหญ่" /></label>
              </div>
              <label>ที่อยู่สำหรับเอกสารภาษี<textarea value={form.tax_address} onChange={(e) => setForm({ ...form, tax_address: e.target.value })} maxLength={800} /></label>
              <small className="wm-tax-note">กรุณาตรวจสอบข้อมูลให้ตรงกับเอกสารจดทะเบียนของร้านก่อนนำเอกสารไปใช้งาน</small>
            </>
          ) : null}
        </div>
          </div>
        </section>

        <div className="wm-settings-savebar">
          <span><strong>บันทึกการเปลี่ยนแปลง</strong><small>ข้อมูลทุกหมวดจะถูกบันทึกพร้อมกัน</small></span>
          <button className="wm-primary" type="button" disabled={busy} onClick={() => void save()}>{busy ? "กำลังบันทึก…" : "บันทึกการตั้งค่า"}</button>
        </div>
      </div>
      {mapTarget ? (
        <FoodDeliveryMapPicker
          client={client}
          storeId={null}
          initialLocation={mapTarget === "store" ? pin : pickupPin}
          title={mapTarget === "store" ? "ตำแหน่งร้าน" : "จุดรับอาหาร / ทางเข้าร้าน"}
          subtitle={mapTarget === "store" ? "ค้นหาแล้วเลื่อนหมุดให้ตรงหน้าร้านจริง" : "กำหนดจุดที่ไรเดอร์ควรมารับอาหาร"}
          confirmLabel={mapTarget === "store" ? "ใช้เป็นตำแหน่งร้าน" : "ใช้เป็นจุดรับอาหาร"}
          onClose={() => setMapTarget(null)}
          onConfirm={(location, place) => {
            if (mapTarget === "store") {
              setPin(location);
              setPinPlace(place ?? null);
              setPinStatus("เลือกตำแหน่งร้านแล้ว อย่าลืมกดบันทึก");
              if (!form.address.trim() && place?.address) setForm((current) => ({ ...current, address: place.address ?? current.address }));
            } else {
              setPickupPin(location);
            }
            setMapTarget(null);
          }}
        />
      ) : null}
    </Sheet>
  );
}

type StorePlaceForm = { id?: string; name: string; detail: string; coords: string; is_active: boolean };

/**
 * WYN-197: the store's own list of places (dorms, condos, villages) that
 * customers can pick in the Food place search. Free: no geocoding service.
 * Each change is saved right away, separately from the store settings form.
 */
function StorePlacesEditor({
  client,
  storeId,
  storePin,
  radiusKm,
}: {
  client: SupabaseClient;
  storeId: string;
  storePin: FoodLocation | null;
  radiusKm: number;
}) {
  // undefined = loading, null = not available yet (migration not applied).
  const [places, setPlaces] = useState<FoodStorePlace[] | null | undefined>(undefined);
  const [form, setForm] = useState<StorePlaceForm | null>(null);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState("");
  const [mapOpen, setMapOpen] = useState(false);

  const [version, setVersion] = useState(0);

  useEffect(() => {
    let active = true;
    fetchStorePlaces(client, storeId).then(
      (next) => { if (active) setPlaces(next); },
      (error) => { if (active) { setPlaces([]); setStatus(merchantError(error)); } },
    );
    return () => { active = false; };
  }, [client, storeId, version]);

  if (places === null) return null;

  const formPin = form ? parseFoodLocation(form.coords) : null;
  const distanceText = (location: FoodLocation) => {
    if (!storePin) return "";
    const km = foodDistanceKm(storePin, location);
    const away = `ห่างร้าน ${km.toFixed(1)} กม.`;
    return km > radiusKm ? `${away} · ${"นอกพื้นที่ส่ง"}` : away;
  };

  const pickCurrent = async () => {
    if (!form) return;
    setStatus("กำลังหาตำแหน่ง…");
    try {
      const here = await currentFoodLocation();
      setForm({ ...form, coords: `${here.latitude.toFixed(6)}, ${here.longitude.toFixed(6)}` });
      setStatus("");
    } catch (error) {
      setStatus(error instanceof Error ? error.message : "หาตำแหน่งไม่สำเร็จ");
    }
  };

  const run = async (work: () => Promise<void>, done: string) => {
    setBusy(true);
    try {
      await work();
      setStatus(done);
      setVersion((value) => value + 1);
    } catch (error) {
      setStatus(merchantError(error));
    } finally {
      setBusy(false);
    }
  };

  const save = () => {
    if (!form) return;
    if (!formPin) { setStatus("พิกัดไม่ถูกต้อง ใช้ปุ่มตำแหน่งปัจจุบันหรือวางพิกัดจากแผนที่"); return; }
    void run(async () => {
      await saveStorePlace(client, storeId, { ...form, latitude: formPin.latitude, longitude: formPin.longitude });
      setForm(null);
    }, "บันทึกสถานที่แล้ว");
  };

  const toggle = (place: FoodStorePlace) => void run(
    () => saveStorePlace(client, storeId, { ...place, detail: place.detail ?? "", is_active: !place.is_active }),
    place.is_active ? "ซ่อนสถานที่แล้ว" : "แสดงสถานที่แล้ว",
  );

  const remove = (place: FoodStorePlace) => {
    if (!window.confirm(`ลบ “${place.name}”?`)) return;
    void run(() => deleteStorePlace(client, storeId, place.id), "ลบสถานที่แล้ว");
  };

  return (
    <div className="wm-zone wm-places">
      <strong>สถานที่ที่ร้านส่งบ่อย</strong>
      <small>ลูกค้าค้นหาชื่อเหล่านี้ได้ตอนใส่ที่อยู่ ฟรี ไม่ต้องใช้บริการแผนที่</small>
      {places === undefined ? <small>กำลังโหลด…</small> : places.length ? (
        <ul className="wm-place-list">
          {places.map((place) => (
            <li key={place.id} className={place.is_active ? "" : "is-off"}>
              <span>
                <strong>{place.name}</strong>
                <small>{[place.detail, distanceText(place), place.is_active ? "" : "ซ่อนอยู่"].filter(Boolean).join(" · ")}</small>
              </span>
              <span className="wm-place-actions">
                <button type="button" disabled={busy} onClick={() => setForm({ id: place.id, name: place.name, detail: place.detail ?? "", coords: `${place.latitude}, ${place.longitude}`, is_active: place.is_active })}>แก้ไข</button>
                <button type="button" disabled={busy} onClick={() => toggle(place)}>{place.is_active ? "ซ่อน" : "แสดง"}</button>
                <button type="button" disabled={busy} onClick={() => remove(place)}>ลบ</button>
              </span>
            </li>
          ))}
        </ul>
      ) : <small>ยังไม่มีสถานที่ เพิ่มหอพัก คอนโด หรือหมู่บ้านที่ส่งบ่อยได้เลย</small>}
      {form ? (
        <div className="wm-place-form">
          <label>ชื่อสถานที่<input value={form.name} maxLength={120} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="เช่น หอพัก ABC" /></label>
          <label>รายละเอียด (ไม่บังคับ)<input value={form.detail} maxLength={200} onChange={(e) => setForm({ ...form, detail: e.target.value })} placeholder="เช่น ซอย 5 ตรงข้าม 7-Eleven" /></label>
          <label>พิกัด<input value={form.coords} inputMode="decimal" onChange={(e) => setForm({ ...form, coords: e.target.value })} placeholder="เช่น 13.75631, 100.50176" /></label>
          <small>{formPin ? distanceText(formPin) || "พิกัดถูกต้อง" : "กดปุ่มด้านล่างตอนอยู่ที่สถานที่ หรือกดค้างบน Google Maps แล้วคัดลอกพิกัดมาวาง"}</small>
          <div className="wm-two-actions">
            <button className="wm-secondary" type="button" disabled={busy} onClick={() => setMapOpen(true)}><Search size={16} /> ค้นหาและเลือกบนแผนที่</button>
            <button className="wm-secondary" type="button" disabled={busy} onClick={() => void pickCurrent()}><MapPin size={16} /> ใช้ตำแหน่งปัจจุบัน</button>
          </div>
          <button className="wm-inline-danger" type="button" disabled={busy} onClick={() => setForm(null)}>ยกเลิก</button>
          <button className="wm-primary wm-full" type="button" disabled={busy || !form.name.trim() || !formPin} onClick={save}>{busy ? "กำลังบันทึก…" : "บันทึกสถานที่"}</button>
        </div>
      ) : (
        <button className="wm-secondary" type="button" disabled={busy || places === undefined} onClick={() => setForm({ name: "", detail: "", coords: "", is_active: true })}><Plus size={16} /> เพิ่มสถานที่</button>
      )}
      {status ? <p role="status">{status}</p> : null}
      {form && mapOpen ? (
        <FoodDeliveryMapPicker
          client={client}
          storeId={null}
          initialLocation={formPin}
          title="สถานที่ที่ร้านส่งบ่อย"
          subtitle="ค้นหาและเลื่อนหมุดให้ตรงสถานที่จริง"
          confirmLabel="ใช้ตำแหน่งนี้"
          onClose={() => setMapOpen(false)}
          onConfirm={(location, place) => {
            setForm((current) => current ? {
              ...current,
              name: current.name.trim() ? current.name : (place?.name || current.name),
              detail: current.detail.trim() ? current.detail : (place?.address || current.detail),
              coords: `${location.latitude.toFixed(6)}, ${location.longitude.toFixed(6)}`,
            } : current);
            setMapOpen(false);
          }}
        />
      ) : null}
    </div>
  );
}

/** WYN-196: same formula as internal.food_delivery_fee on the server. */
function exampleFee(base: string, baseKm: string, perKm: string, distanceKm = 4) {
  const extra = Math.max(distanceKm - Number(baseKm || 0), 0) * Number(perKm || 0);
  return Number(base || 0) + Math.ceil(Math.round(extra * 100) / 100);
}

export function WynosMerchantApp() {
  return (
    <DeveloperRouteGate
      signedOutPath="/merchant/login"
      afterSignOutPath="/merchant/login"
      loadingFallback={<MerchantLoading />}
    >
      {({ client, userId, signOut }) => <MerchantInner client={client} userId={userId} signOut={signOut} />}
    </DeveloperRouteGate>
  );
}
