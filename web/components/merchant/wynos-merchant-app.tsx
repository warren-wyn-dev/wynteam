/* eslint-disable @next/next/no-img-element */
"use client";

import {
  Bell,
  BellRing,
  Check,
  ChevronLeft,
  ChevronRight,
  CircleDollarSign,
  Clock3,
  ImagePlus,
  LogOut,
  MapPin,
  Menu as MenuIcon,
  PackageCheck,
  Pencil,
  Phone,
  Plus,
  Search,
  ShoppingBag,
  Store,
  Truck,
  Upload,
  UtensilsCrossed,
  X,
} from "lucide-react";
import type { SupabaseClient } from "@supabase/supabase-js";
import Link from "next/link";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { MerchantCampaignCenter } from "@/components/merchant/merchant-campaign-center";
import { MerchantStoreTools, RefundControls } from "@/components/merchant/merchant-core-panels";
import { MerchantIcon3D } from "@/components/merchant/merchant-3d-icons";
import { MerchantAds } from "@/components/merchant/merchant-ads";
import { MerchantFinance } from "@/components/merchant/merchant-finance";
import { MerchantNavIcon } from "@/components/merchant/merchant-nav-icons";
import { MerchantNotificationPrompt } from "@/components/merchant/merchant-notification-prompt";
import { MerchantPlatformCampaigns } from "@/components/merchant/merchant-platform-campaigns";
import { PullToRefreshIndicator } from "@/components/ui/pull-to-refresh-indicator";
import { NewOrderAlert, previewMerchantOrderSound, useMerchantSoundUnlock } from "@/components/merchant/merchant-order-alert";
import { MERCHANT_NOTIFICATION_TEST_RESULT_KEY, setMerchantStorePublished } from "@/lib/merchant-core";
import {
  completeFoodDelivery,
  deleteMenuItem,
  deleteStorePlace,
  fetchStorePlaces,
  fetchMerchantSnapshot,
  foodPrivateSignedUrl,
  foodPublicUrl,
  merchantError,
  money,
  paymentLabel,
  saveMenuItem,
  saveStorePlace,
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
  type MenuDraft,
} from "@/lib/food-merchant";
import { usePullToRefresh } from "@/lib/use-pull-to-refresh";
import { currentFoodLocation, foodDistanceKm, foodMapsHref, parseFoodLocation, type FoodLocation } from "@/lib/food-customer";

// WYN-204: four bottom tabs like LINE MAN Merchant. Reports, store settings
// and campaigns open from "เพิ่มเติม" (and the home shortcuts) as sub-pages.
// WYN-205: finance, ads, WYNOS campaigns and the store's own promotions.
type MerchantTab = "home" | "orders" | "menu" | "more" | "reports" | "store" | "finance" | "ads" | "campaigns" | "promotions";
const MORE_PAGES: ReadonlySet<MerchantTab> = new Set(["more", "reports", "store", "finance", "ads", "campaigns", "promotions"]);
type OrderFilter = "new" | "cooking" | "delivery" | "done";

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
};

function menuOptionId(prefix: "group" | "choice") {
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
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

function sameLocalDay(value: string, date = new Date()) {
  const stamp = new Date(value);
  return stamp.getFullYear() === date.getFullYear()
    && stamp.getMonth() === date.getMonth()
    && stamp.getDate() === date.getDate();
}

function startOfWeek() {
  const now = new Date();
  const day = (now.getDay() + 6) % 7;
  const start = new Date(now);
  start.setDate(now.getDate() - day);
  start.setHours(0, 0, 0, 0);
  return start;
}

function shortTime(value: string) {
  return new Intl.DateTimeFormat("th-TH", { hour: "2-digit", minute: "2-digit" }).format(new Date(value));
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
    <main className="wm-loading" aria-label="กำลังโหลด WYNOS Merchant">
      <div className="wm-loader" />
      <strong>WYNOS <b>Merchant</b></strong>
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
  const [store, setStore] = useState<FoodStore | null>(null);
  const [menu, setMenu] = useState<FoodMenuItem[]>([]);
  const [orders, setOrders] = useState<FoodOrder[]>([]);
  const [access, setAccess] = useState<boolean | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [message, setMessage] = useState("");
  const [selectedOrder, setSelectedOrder] = useState<FoodOrder | null>(null);
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
  // WYN-199: ask for notifications as soon as Merchant opens ("auto"), or
  // again from the bell button ("bell").
  const [notifyPrompt, setNotifyPrompt] = useState<"auto" | "bell" | null>("auto");
  const [menuQuery, setMenuQuery] = useState("");
  const [menuDraft, setMenuDraft] = useState<MenuDraft | null>(null);
  const [storeEditing, setStoreEditing] = useState(false);
  const [installPrompt, setInstallPrompt] = useState<InstallPromptEvent | null>(null);
  const [notificationsEnabled, setNotificationsEnabled] = useState(() => typeof window !== "undefined" && "Notification" in window && Notification.permission === "granted");
  const loadingRef = useRef(false);
  // A refresh asked for while one is running runs once more afterwards, so
  // the last realtime event or action always shows its final state.
  const reloadQueuedRef = useRef(false);
  const paymentStatusRef = useRef<Map<string, FoodOrder["payment_status"]>>(new Map());

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
      const next = await fetchMerchantSnapshot(client);
      setAccess(next.access);
      setStore(next.store);
      setMenu(next.menu);
      setOrders(next.orders);
      paymentStatusRef.current = new Map(next.orders.map((order) => [order.id, order.payment_status]));
      setSelectedOrder((current) => current ? next.orders.find((order) => order.id === current.id) ?? null : null);
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
  }, [client]);
  const loadRef = useRef<typeof load | null>(null);
  useEffect(() => { loadRef.current = load; }, [load]);

  useEffect(() => {
    const timer = window.setTimeout(() => void load(), 0);
    return () => window.clearTimeout(timer);
  }, [load]);

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
      void load(true);
    });
    return () => { void client.removeChannel(channel); };
  }, [client, load, store?.id]);

  useEffect(() => {
    if (typeof window === "undefined") return;
    const handler = (event: Event) => {
      event.preventDefault();
      setInstallPrompt(event as InstallPromptEvent);
    };
    window.addEventListener("beforeinstallprompt", handler);
    return () => window.removeEventListener("beforeinstallprompt", handler);
  }, []);


  const install = async () => {
    if (!installPrompt) return;
    await installPrompt.prompt();
    await installPrompt.userChoice;
    setInstallPrompt(null);
  };

  const todayOrders = useMemo(() => orders.filter((order) => sameLocalDay(order.created_at)), [orders]);
  const todayDelivered = useMemo(() => todayOrders.filter((order) => order.status === "delivered"), [todayOrders]);
  const todaySales = useMemo(() => todayDelivered.reduce((sum, order) => sum + Number(order.total), 0), [todayDelivered]);
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
        await transitionFoodOrder(client, order.id, "preparing", order.eta_minutes ?? 30);
        setMessage(`รับออเดอร์ #${order.order_number} แล้ว`);
      } else if (next.step === "ready") {
        await transitionFoodOrder(client, order.id, "ready_for_delivery");
        setMessage(`ออเดอร์ #${order.order_number} อาหารพร้อมแล้ว`);
      } else {
        await transitionFoodOrder(client, order.id, "out_for_delivery");
        setMessage(`ออเดอร์ #${order.order_number} เริ่มจัดส่งแล้ว`);
      }
    } catch (error) {
      setMessage(merchantError(error));
      forgetAction(order.id);
    } finally {
      // Reload on failure too: the order may have moved on elsewhere.
      void load(true);
    }
  };
  const visibleMenu = useMemo(() => {
    const q = menuQuery.trim().toLocaleLowerCase("th-TH");
    return q ? menu.filter((item) => `${item.name} ${item.category}`.toLocaleLowerCase("th-TH").includes(q)) : menu;
  }, [menu, menuQuery]);

  // WYN-201: pull down to refresh on the list tabs (forms and sheets are
  // excluded by the hook: dialogs and inputs never start a pull).
  const pull = usePullToRefresh({
    enabled: tab === "home" || tab === "orders" || tab === "menu" || tab === "reports" || tab === "finance",
    onRefresh: async () => { await load(true); },
  });

  if (loading && access === null) return <MerchantLoading />;
  if (access === false) return <MerchantBlocked signOut={signOut} />;

  return (
    <main className="wyn-merchant">
      <header className="wm-header">
        <div className="wm-brand">
          <span>WYNOS</span>
          <b>Merchant</b>
        </div>
        <div className="wm-header-actions">
          <button
            className={`wm-icon-button ${notificationsEnabled ? "is-active" : ""}`}
            type="button"
            aria-label="เปิดการแจ้งเตือน"
            onClick={() => setNotifyPrompt("bell")}
          >
            <Bell size={21} strokeWidth={1.8} />
          </button>
          {refreshing ? <span className="wm-mini-loader" aria-label="กำลังอัปเดต" /> : (
            <button className="wm-icon-button" type="button" aria-label="อัปเดตข้อมูล" onClick={() => void load(true)}>
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
            todayOrders={todayOrders}
            todaySales={todaySales}
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
          />
        ) : null}

        {tab === "menu" && store ? (
          <MenuPanel
            client={client}
            menu={visibleMenu}
            query={menuQuery}
            onQuery={setMenuQuery}
            onEdit={(item) => setMenuDraft({
              id: item.id,
              name: item.name,
              category: item.category,
              description: item.description ?? "",
              price: String(item.price),
              image_path: item.image_path,
              options: Array.isArray(item.options) ? item.options : [],
              is_available: item.is_available,
            })}
            onAdd={() => setMenuDraft({ ...EMPTY_MENU_DRAFT })}
            onToggle={async (item) => {
              try {
                await setMenuAvailability(client, store.id, item.id, !item.is_available);
                await load(true);
              } catch (error) { setMessage(merchantError(error)); }
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
            onNotifications={() => setNotifyPrompt("bell")}
            onMessage={setMessage}
            onSignOut={() => void signOut()}
          />
        ) : null}

        {tab === "reports" && store ? <ReportsPanel orders={orders} /> : null}

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

      {notifyPrompt && store && !alertOrder && !selectedOrder && !menuDraft && !storeEditing ? (
        <MerchantNotificationPrompt
          key={notifyPrompt}
          client={client}
          userId={userId}
          forceOpen={notifyPrompt === "bell"}
          onClose={() => setNotifyPrompt(null)}
          onEnabled={() => setNotificationsEnabled(true)}
        />
      ) : null}

      {alertOrder && !selectedOrder && !menuDraft && !storeEditing ? (
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
          order={selectedOrder}
          onClose={() => setSelectedOrder(null)}
          onReload={() => void load(true)}
          onMessage={setMessage}
        />
      ) : null}

      {menuDraft && store ? (
        <MenuEditor
          client={client}
          store={store}
          draft={menuDraft}
          onClose={() => setMenuDraft(null)}
          onSaved={async () => { setMenuDraft(null); await load(true); }}
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
  todayOrders,
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
  todayOrders: FoodOrder[];
  todaySales: number;
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
          <button className="wm-hero-edit" type="button" aria-label="แก้ไขร้าน" onClick={onEditStore}><Pencil size={19} /></button>
        </div>
        <button className="wm-hero-sales" type="button" onClick={() => onOpenTab("reports")}>
          <small>ยอดขายวันนี้</small>
          <strong>{money(todaySales)}</strong>
          <span>{todayOrders.length} ออเดอร์ <ChevronRight size={14} /></span>
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
  onNotifications,
  onMessage,
  onSignOut,
}: {
  client: SupabaseClient;
  store: FoodStore;
  installPrompt: InstallPromptEvent | null;
  onInstall: () => void;
  onOpenTab: (tab: MerchantTab) => void;
  onNotifications: () => void;
  onMessage: (message: string) => void;
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
          <button type="button" onClick={() => onOpenTab("store")}><span className="wm-tile-icon"><MerchantIcon3D name="store" size={52} /></span>ตั้งค่าร้าน</button>
          <button type="button" onClick={onNotifications}><span className="wm-tile-icon"><MerchantIcon3D name="bell" size={52} /></span>การแจ้งเตือน</button>
          <button type="button" onClick={() => void previewMerchantOrderSound().then((played) => { if (!played) onMessage("เปิดเสียงไม่ได้ ตรวจว่ามือถือไม่ได้ปิดเสียงอยู่"); })}><span className="wm-tile-icon"><MerchantIcon3D name="sound" size={52} /></span>ลองเสียงออเดอร์</button>
          {installPrompt ? <button type="button" onClick={onInstall}><span className="wm-tile-icon"><MerchantIcon3D name="install" size={52} /></span>ติดตั้งแอป</button> : null}
        </div>
      </section>
      <section className="wm-settings-list">
        <button type="button" onClick={onSignOut}><span><strong>ออกจากระบบ</strong><small>ออกจากบัญชี WYNOS บนอุปกรณ์นี้</small></span><LogOut size={19} /></button>
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
}: {
  orders: FoodOrder[];
  allOrders: FoodOrder[];
  filter: OrderFilter;
  onFilter: (value: OrderFilter) => void;
  onOpen: (order: FoodOrder) => void;
  onAction: (order: FoodOrder) => void;
  actedFrom: ReadonlyMap<string, FoodOrder["status"]>;
}) {
  const [showTools, setShowTools] = useState(false);
  const [query, setQuery] = useState("");
  const [paymentFilter, setPaymentFilter] = useState<"all" | FoodOrder["payment_status"]>("all");
  const [dateFilter, setDateFilter] = useState<"all" | "today" | "7d" | "30d">("all");
  // "Done" keeps growing, so only the working tabs show a count.
  const counts: Record<OrderFilter, number> = {
    new: allOrders.filter((o) => orderInFilter(o, "new")).length,
    cooking: allOrders.filter((o) => orderInFilter(o, "cooking")).length,
    delivery: allOrders.filter((o) => orderInFilter(o, "delivery")).length,
    done: 0,
  };
  const visibleOrders = useMemo(() => {
    const q = query.trim().toLocaleLowerCase("th-TH");
    const now = new Date().getTime();
    const day = 24 * 60 * 60 * 1000;
    return orders.filter((order) => {
      if (paymentFilter !== "all" && order.payment_status !== paymentFilter) return false;
      if (dateFilter === "today" && !sameLocalDay(order.created_at)) return false;
      if (dateFilter === "7d" && new Date(order.created_at).getTime() < now - 7 * day) return false;
      if (dateFilter === "30d" && new Date(order.created_at).getTime() < now - 30 * day) return false;
      if (!q) return true;
      const haystack = [
        order.order_number,
        order.recipient_name,
        order.recipient_phone,
        ...(order.food_order_items ?? []).map((item) => item.item_name),
      ].join(" ").toLocaleLowerCase("th-TH");
      return haystack.includes(q);
    });
  }, [dateFilter, orders, paymentFilter, query]);

  return (
    <>
      <div className="wm-page-heading">
        <div><small>ออเดอร์จาก WYNOS Food</small><h1>ออเดอร์</h1></div>
        <button className={`wm-icon-button ${showTools ? "is-active" : ""}`} type="button" aria-label="ค้นหาและตัวกรอง" aria-expanded={showTools} onClick={() => {
          // Closing the tools clears them, so no hidden filter is left on.
          if (showTools) { setQuery(""); setPaymentFilter("all"); setDateFilter("all"); }
          setShowTools(!showTools);
        }}>
          <Search size={21} strokeWidth={1.8} />
        </button>
      </div>
      <div className="wm-filter-tabs wm-filter-tabs--simple" role="group" aria-label="สถานะออเดอร์">
        {ORDER_FILTERS.map((item) => (
          <button key={item.key} className={filter === item.key ? "is-active" : ""} type="button" aria-pressed={filter === item.key} onClick={() => onFilter(item.key)}>
            <span>{item.label}</span>{counts[item.key] ? <b>{counts[item.key]}</b> : null}
          </button>
        ))}
      </div>
      {showTools ? <div className="wm-order-search-tools">
        <label className="wm-search"><Search size={19} strokeWidth={1.7} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="เลขออเดอร์ · ชื่อลูกค้า · เบอร์โทร · เมนู" /></label>
        <div className="wm-order-selects">
          <select value={paymentFilter} onChange={(event) => setPaymentFilter(event.target.value as "all" | FoodOrder["payment_status"])}>
            <option value="all">การชำระเงินทั้งหมด</option>
            <option value="pending">รอชำระเงิน</option>
            <option value="submitted">รอตรวจสลิป</option>
            <option value="paid">ชำระแล้ว</option>
            <option value="issue">มีปัญหา</option>
            <option value="refunded">คืนเงินแล้ว</option>
          </select>
          <select value={dateFilter} onChange={(event) => setDateFilter(event.target.value as "all" | "today" | "7d" | "30d")}>
            <option value="all">ทุกช่วงเวลา</option>
            <option value="today">วันนี้</option>
            <option value="7d">7 วันล่าสุด</option>
            <option value="30d">30 วันล่าสุด</option>
          </select>
        </div>
      </div> : null}
      {visibleOrders.length ? <div className="wm-order-list wm-order-list--page">{visibleOrders.map((order) => <OrderCard key={order.id} order={order} onOpen={() => onOpen(order)} onAction={onAction} acting={actedFrom.get(order.id) === order.status} />)}</div> : (
        <div className="wm-empty"><ShoppingBag size={38} strokeWidth={1.5} /><strong>{query || paymentFilter !== "all" || dateFilter !== "all" ? "ไม่พบออเดอร์ที่ตรงกับตัวกรอง" : "ไม่มีออเดอร์ในแท็บนี้"}</strong></div>
      )}
    </>
  );
}
function MenuPanel({
  client,
  menu,
  query,
  onQuery,
  onEdit,
  onAdd,
  onToggle,
}: {
  client: SupabaseClient;
  menu: FoodMenuItem[];
  query: string;
  onQuery: (value: string) => void;
  onEdit: (item: FoodMenuItem) => void;
  onAdd: () => void;
  onToggle: (item: FoodMenuItem) => void;
}) {
  const categories = Array.from(menu.reduce((groups, item) => {
    const category = item.category.trim() || "อื่น ๆ";
    const rows = groups.get(category) ?? [];
    rows.push(item);
    groups.set(category, rows);
    return groups;
  }, new Map<string, FoodMenuItem[]>()).entries());

  return (
    <>
      <div className="wm-page-heading wm-page-heading--action">
        <div><small>รายการขาย</small><h1>เมนูอาหาร</h1></div>
        <button className="wm-small-primary" type="button" onClick={onAdd}><Plus size={17} /> เพิ่มเมนู</button>
      </div>
      <label className="wm-search"><Search size={19} strokeWidth={1.7} /><input value={query} onChange={(e) => onQuery(e.target.value)} placeholder="ค้นหาเมนูหรือหมวดหมู่" /></label>
      <div className="wm-menu-categories">
        {categories.map(([category, items]) => (
          <section className="wm-menu-category" key={category}>
            <div className="wm-menu-category-heading">
              <strong>{category}</strong>
              <span>{items.length} เมนู</span>
            </div>
            <div className="wm-menu-list">
              {items.map((item) => {
                const image = foodPublicUrl(client, item.image_path);
                const optionCount = Array.isArray(item.options)
                  ? item.options.reduce((sum, group) => sum + (Array.isArray(group.choices) ? group.choices.length : 0), 0)
                  : 0;
                return (
                  <article className={`wm-menu-row ${item.is_available ? "" : "is-off"}`} key={item.id}>
                    <button className="wm-menu-main" type="button" onClick={() => onEdit(item)}>
                      <span className="wm-menu-photo">{image ? <img src={image} alt="" /> : <UtensilsCrossed size={24} strokeWidth={1.5} />}</span>
                      <span className="wm-menu-copy">
                        <strong>{item.name}</strong>
                        <small>{optionCount ? `${optionCount} ตัวเลือกเสริม` : "ไม่มีตัวเลือกเสริม"}</small>
                        <b>{money(item.price)}</b>
                      </span>
                    </button>
                    <button className={`wm-switch ${item.is_available ? "is-on" : ""}`} type="button" aria-label={item.is_available ? "ปิดขายชั่วคราว" : "เปิดขาย"} onClick={() => onToggle(item)}><i /></button>
                  </article>
                );
              })}
            </div>
          </section>
        ))}
      </div>
      {!menu.length ? <div className="wm-empty"><MenuIcon size={38} strokeWidth={1.5} /><strong>ยังไม่มีเมนู</strong><p>เพิ่มอาหารหรือเครื่องดื่มเพื่อเริ่มรับออเดอร์</p></div> : null}
    </>
  );
}

/** WYN-205: money in and out, from the orders already loaded in Merchant. */
function ReportsPanel({ orders }: { orders: FoodOrder[] }) {
  const delivered = orders.filter((order) => order.status === "delivered");
  const now = new Date();
  const week = startOfWeek();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const today = delivered.filter((order) => sameLocalDay(order.delivered_at ?? order.updated_at));
  const weekly = delivered.filter((order) => new Date(order.delivered_at ?? order.updated_at) >= week);
  const monthly = delivered.filter((order) => new Date(order.delivered_at ?? order.updated_at) >= monthStart);
  const sum = (rows: FoodOrder[]) => rows.reduce((total, row) => total + Number(row.total), 0);
  const itemCount = new Map<string, number>();
  delivered.forEach((order) => order.food_order_items?.forEach((item) => itemCount.set(item.item_name, (itemCount.get(item.item_name) ?? 0) + item.quantity)));
  const best = [...itemCount.entries()].sort((a, b) => b[1] - a[1]).slice(0, 5);
  const average = delivered.length ? sum(delivered) / delivered.length : 0;

  return (
    <>
      <div className="wm-page-heading"><div><small>ภาพรวมร้าน</small><h1>รายงาน</h1></div></div>
      <div className="wm-report-hero"><small>ยอดขายวันนี้</small><strong>{money(sum(today))}</strong><span>{today.length} ออเดอร์สำเร็จ</span></div>
      <div className="wm-metrics wm-metrics--reports">
        <Metric label="สัปดาห์นี้" value={money(sum(weekly))} hint={`${weekly.length} ออเดอร์`} />
        <Metric label="เดือนนี้" value={money(sum(monthly))} hint={`${monthly.length} ออเดอร์`} />
        <Metric label="เฉลี่ย/ออเดอร์" value={money(average)} />
        <Metric label="ออเดอร์ทั้งหมด" value={String(delivered.length)} />
      </div>
      <section className="wm-section">
        <div className="wm-section-title"><h2>เมนูขายดี</h2></div>
        {best.length ? <div className="wm-ranking">{best.map(([name, count], index) => <div key={name}><b>{index + 1}</b><span>{name}</span><strong>{count} ชิ้น</strong></div>)}</div> : (
          <div className="wm-empty wm-empty--compact"><CircleDollarSign size={34} strokeWidth={1.5} /><strong>ยังไม่มีข้อมูลยอดขาย</strong></div>
        )}
      </section>
    </>
  );
}

function StorePanel({
  client,
  store,
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
  userId: string;
  installPrompt: InstallPromptEvent | null;
  onInstall: () => void;
  onEdit: () => void;
  onReload: () => void;
  onMessage: (message: string) => void;
  onSignOut: () => void;
}) {
  const [busy, setBusy] = useState(false);
  const togglePublished = async () => {
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
      <section className="wm-store-brand-card">
        <div className="wm-store-brand-card-cover">
          {store.cover_path ? <img src={foodPublicUrl(client, store.cover_path) ?? ""} alt="" /> : <Store size={40} strokeWidth={1.4} />}
        </div>
        <div className="wm-store-brand-card-main">
          <div className="wm-store-avatar">{store.logo_path ? <img src={foodPublicUrl(client, store.logo_path) ?? ""} alt="" /> : <Store size={30} strokeWidth={1.6} />}</div>
          <div><strong>{store.name}</strong><small>{store.address || "ยังไม่ได้ใส่ที่อยู่ร้าน"}</small></div>
          <button type="button" onClick={onEdit}>แก้ไข</button>
        </div>
      </section>
      <section className="wm-settings-list">
        <button type="button" onClick={() => void togglePublished()} disabled={busy || Boolean(store.admin_suspended_at)}>
          <span><strong>เผยแพร่ WYNOS Food</strong><small>{store.is_published ? "ลูกค้าเห็นร้านได้แล้ว" : "ร้านยังซ่อนจากลูกค้า"}</small></span>
          <span className={`wm-switch ${store.is_published ? "is-on" : ""}`}><i /></span>
        </button>
        <button type="button" onClick={onEdit}><span><strong>ข้อมูลร้านและการจัดส่ง</strong><small>เวลาเปิด · พื้นที่ส่ง · ค่าส่ง · ยอดขั้นต่ำ</small></span><ChevronRight size={19} /></button>
        <button type="button" onClick={onEdit}><span><strong>รับชำระเงิน</strong><small>PromptPay · บัญชีธนาคาร · QR</small></span><ChevronRight size={19} /></button>
        <button type="button" onClick={() => void previewMerchantOrderSound().then((played) => { if (!played) onMessage("เปิดเสียงไม่ได้ ตรวจว่ามือถือไม่ได้ปิดเสียงอยู่"); })}><span><strong>เสียงแจ้งเตือนออเดอร์</strong><small>แตะเพื่อลองฟังเสียงของ Wynos Merchant</small></span><BellRing size={19} /></button>
        {installPrompt ? <button type="button" onClick={onInstall}><span><strong>ติดตั้งเป็นแอป</strong><small>เพิ่ม WYNOS Merchant ไว้บนหน้าจอหลัก</small></span><ChevronRight size={19} /></button> : null}
        <button type="button" onClick={onSignOut}><span><strong>ออกจากระบบ</strong><small>ออกจากบัญชี WYNOS บนอุปกรณ์นี้</small></span><ChevronRight size={19} /></button>
      </section>
      <MerchantStoreTools client={client} store={store} userId={userId} onMessage={onMessage} />
    </>
  );
}

function Sheet({ title, onClose, children, wide = false }: { title: string; onClose: () => void; children: React.ReactNode; wide?: boolean }) {
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
      <section ref={sheetRef} tabIndex={-1} className={`wm-sheet ${wide ? "wm-sheet--wide" : ""}`} role="dialog" aria-modal="true" aria-label={title}>
        <header><button type="button" aria-label="ปิด" onClick={onClose}><X size={22} /></button><h2>{title}</h2><span /></header>
        <div className="wm-sheet-body">{children}</div>
      </section>
    </div>
  );
}

function OrderSheet({
  client,
  order,
  onClose,
  onReload,
  onMessage,
}: {
  client: SupabaseClient;
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
  return (
    <Sheet title={`ออเดอร์ #${order.order_number}`} onClose={onClose} wide>
      <div className="wm-order-detail-head">
        <div><OrderStatus order={order} /><PaymentStatus order={order} /></div>
        <strong>{money(order.total)}</strong>
        <small>{new Intl.DateTimeFormat("th-TH", { dateStyle: "medium", timeStyle: "short" }).format(new Date(order.created_at))}</small>
      </div>

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
        <section className="wm-detail-section wm-delivered-box"><PackageCheck size={28} /><div><strong>จัดส่งสำเร็จแล้ว</strong><small>{order.delivered_at ? new Intl.DateTimeFormat("th-TH", { dateStyle: "medium", timeStyle: "short" }).format(new Date(order.delivered_at)) : ""}</small>{proof?.location_note ? <p>วางไว้: {proof.location_note}</p> : null}</div>{proofUrl ? <a href={proofUrl} target="_blank" rel="noreferrer"><img src={proofUrl} alt="หลักฐานการจัดส่ง" /></a> : null}</section>
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
              <option value="อาหารจานหลัก" />
              <option value="ของทานเล่น" />
              <option value="เครื่องดื่ม" />
              <option value="ของหวาน" />
              <option value="เมนูแนะนำ" />
              <option value="อื่น ๆ" />
            </datalist>
          </label>
          <label>ราคา<input type="number" min="0" step="1" inputMode="decimal" value={form.price} onChange={(e) => setForm({ ...form, price: e.target.value })} placeholder="0" /></label>
        </div>
        <label>รายละเอียด<textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} placeholder="รายละเอียดอาหาร" /></label>

        <section className="wm-menu-image-editor">
          <div className="wm-menu-image-heading"><strong>รูปเมนู</strong><small>เห็นสถานะก่อนบันทึกได้ทันที</small></div>
          {previewUrl ? <div className="wm-menu-image-preview"><img src={previewUrl} alt="ตัวอย่างรูปเมนู" /></div> : null}
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
    logo_path: store.logo_path,
    cover_path: store.cover_path,
  });
  const [logoFile, setLogoFile] = useState<File | null>(null);
  const [coverFile, setCoverFile] = useState<File | null>(null);
  const [logoPreview, setLogoPreview] = useState<string | null>(() => foodPublicUrl(client, store.logo_path));
  const [coverPreview, setCoverPreview] = useState<string | null>(() => foodPublicUrl(client, store.cover_path));
  const [logoState, setLogoState] = useState<"idle" | "selected" | "uploading" | "uploaded" | "error">(store.logo_path ? "uploaded" : "idle");
  const [coverState, setCoverState] = useState<"idle" | "selected" | "uploading" | "uploaded" | "error">(store.cover_path ? "uploaded" : "idle");
  const [qrFile, setQrFile] = useState<File | null>(null);
  const [busy, setBusy] = useState(false);
  // WYN-196: pinned store location for the delivery radius and per-km fee.
  const [pin, setPin] = useState<FoodLocation | null>(
    store.latitude != null && store.longitude != null ? { latitude: Number(store.latitude), longitude: Number(store.longitude) } : null,
  );
  const [pinStatus, setPinStatus] = useState("");

  useEffect(() => {
    return () => {
      if (logoPreview?.startsWith("blob:")) URL.revokeObjectURL(logoPreview);
      if (coverPreview?.startsWith("blob:")) URL.revokeObjectURL(coverPreview);
    };
  }, [logoPreview, coverPreview]);

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
    try {
      let qr = form.payment_qr_path;
      let logo = form.logo_path;
      let cover = form.cover_path;
      if (logoFile) {
        setLogoState("uploading");
        logo = await uploadFoodPublicImage(client, logoFile, `stores/${store.id}/profile`);
        setLogoState("uploaded");
      }
      if (coverFile) {
        setCoverState("uploading");
        cover = await uploadFoodPublicImage(client, coverFile, `stores/${store.id}/cover`);
        setCoverState("uploaded");
      }
      if (qrFile) qr = await uploadFoodPublicImage(client, qrFile, `stores/${store.id}/payment`);
      await updateFoodStore(client, store.id, {
        name: form.name.trim(),
        description: form.description.trim() || null,
        phone: form.phone.trim() || null,
        address: form.address.trim() || null,
        business_hours: form.business_hours.trim() || null,
        delivery_area: form.delivery_area.trim() || null,
        delivery_fee: Number(form.delivery_fee || 0),
        minimum_order: Number(form.minimum_order || 0),
        ...(zoneReady ? {
          latitude: pin?.latitude ?? null,
          longitude: pin?.longitude ?? null,
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
        logo_path: logo,
        cover_path: cover,
      });
      onMessage("บันทึกข้อมูลร้านแล้ว");
      await onSaved();
    } catch (error) {
      if (logoFile && logoState === "uploading") setLogoState("error");
      if (coverFile && coverState === "uploading") setCoverState("error");
      onMessage(merchantError(error));
    }
    finally { setBusy(false); }
  };

  return (
    <Sheet title="ตั้งค่าร้าน" onClose={onClose} wide>
      <div className="wm-form">
        <h3>ข้อมูลร้าน</h3>
        <section className="wm-store-brand-editor">
          <div className="wm-store-brand-heading">
            <span><strong>รูปโปรไฟล์และรูปปกร้าน</strong><small>รูปเหล่านี้จะแสดงบนหน้าร้านใน WYNOS Food</small></span>
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
        <label>ชื่อร้าน<input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></label>
        <label>รายละเอียด<textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} /></label>
        <label>เบอร์ร้าน<input value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} inputMode="tel" /></label>
        <label>ที่อยู่ร้าน<textarea value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} /></label>
        <label>เวลาเปิด–ปิด<input value={form.business_hours} onChange={(e) => setForm({ ...form, business_hours: e.target.value })} placeholder="เช่น ทุกวัน 10:00–20:00" /></label>
        <h3>การจัดส่ง</h3>
        <label>พื้นที่จัดส่ง<textarea value={form.delivery_area} onChange={(e) => setForm({ ...form, delivery_area: e.target.value })} placeholder="เช่น รัศมี 5 กม. / เขตที่ให้บริการ" /></label>
        <div className="wm-form-grid"><label>ค่าส่งเริ่มต้น<input type="number" min="0" inputMode="decimal" value={form.delivery_fee} onChange={(e) => setForm({ ...form, delivery_fee: e.target.value })} /></label><label>ยอดขั้นต่ำ<input type="number" min="0" inputMode="decimal" value={form.minimum_order} onChange={(e) => setForm({ ...form, minimum_order: e.target.value })} /></label></div>
        {zoneReady ? <div className="wm-zone">
          <strong>ตำแหน่งร้านและระยะส่ง</strong>
          <small>{pin ? `ปักหมุดแล้ว · ${pin.latitude.toFixed(5)}, ${pin.longitude.toFixed(5)}` : "ยังไม่ปักหมุด: ร้านจะยังไม่ขึ้น WYNOS Maps"}</small>
          <small>{pin
            ? (store.is_published
              ? "ร้านนี้ซิงก์ตำแหน่งไป WYNOS Maps อัตโนมัติเมื่อบันทึก"
              : "เมื่อร้านเผยแพร่ หมุดร้านสีแดงจะขึ้น WYNOS Maps อัตโนมัติ")
            : "ต้องปักหมุดร้านก่อนเผยแพร่และก่อนเปิดการจัดส่ง"}</small>
          <div className="wm-two-actions">
            <button className="wm-secondary" type="button" onClick={() => void pinStore()}>ใช้ตำแหน่งปัจจุบันเป็นร้าน</button>
            {pin ? <button className="wm-secondary" type="button" onClick={() => { setPin(null); setPinStatus("ล้างหมุดแล้ว อย่าลืมกดบันทึก"); }}>ล้างหมุด</button> : null}
          </div>
          {pinStatus ? <p role="status">{pinStatus}</p> : null}
          <div className="wm-form-grid">
            <label>ส่งไกลสุด (กม.)<input type="number" min="0.5" max="50" step="0.5" inputMode="decimal" value={form.delivery_radius_km} onChange={(e) => setForm({ ...form, delivery_radius_km: e.target.value })} /></label>
            <label>รวมในค่าส่งเริ่มต้น (กม.)<input type="number" min="0" max="50" step="0.5" inputMode="decimal" value={form.delivery_base_km} onChange={(e) => setForm({ ...form, delivery_base_km: e.target.value })} /></label>
          </div>
          <label>บาทต่อ กม. ที่เกิน<input type="number" min="0" max="1000" inputMode="decimal" value={form.delivery_fee_per_km} onChange={(e) => setForm({ ...form, delivery_fee_per_km: e.target.value })} /></label>
          <small>{`ตัวอย่าง: ส่ง 4 กม. ค่าส่ง ${exampleFee(form.delivery_fee, form.delivery_base_km, form.delivery_fee_per_km)} บาท (ส่วนที่เกินคิดต่อ กม. ปัดขึ้นเป็นบาทเต็ม)`}</small>
        </div> : null}
        {zoneReady ? <StorePlacesEditor client={client} storeId={store.id} storePin={pin} radiusKm={Number(form.delivery_radius_km || 5)} /> : null}
        <h3>รับชำระเงินเข้าร้าน</h3>
        <div className="wm-form-grid"><label>ชื่อ PromptPay<input value={form.promptpay_name} onChange={(e) => setForm({ ...form, promptpay_name: e.target.value })} /></label><label>เบอร์/เลข PromptPay<input value={form.promptpay_id} onChange={(e) => setForm({ ...form, promptpay_id: e.target.value })} /></label></div>
        <label>ธนาคาร<input value={form.bank_name} onChange={(e) => setForm({ ...form, bank_name: e.target.value })} /></label>
        <label>ชื่อบัญชี<input value={form.bank_account_name} onChange={(e) => setForm({ ...form, bank_account_name: e.target.value })} /></label>
        <label>เลขบัญชี<input value={form.bank_account_number} onChange={(e) => setForm({ ...form, bank_account_number: e.target.value })} inputMode="numeric" /></label>
        <label className="wm-upload"><input type="file" accept="image/jpeg,image/png,image/webp" onChange={(e) => setQrFile(e.target.files?.[0] ?? null)} /><Upload size={20} /><span>{qrFile ? qrFile.name : "อัปโหลด QR รับเงิน"}</span></label>
        <button className="wm-primary wm-full" type="button" disabled={busy} onClick={() => void save()}>{busy ? "กำลังบันทึก…" : "บันทึกการตั้งค่า"}</button>
      </div>
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
            <button className="wm-secondary" type="button" disabled={busy} onClick={() => void pickCurrent()}><MapPin size={16} /> ใช้ตำแหน่งปัจจุบัน</button>
            <button className="wm-secondary" type="button" disabled={busy} onClick={() => setForm(null)}>ยกเลิก</button>
          </div>
          <button className="wm-primary wm-full" type="button" disabled={busy || !form.name.trim() || !formPin} onClick={save}>{busy ? "กำลังบันทึก…" : "บันทึกสถานที่"}</button>
        </div>
      ) : (
        <button className="wm-secondary" type="button" disabled={busy || places === undefined} onClick={() => setForm({ name: "", detail: "", coords: "", is_active: true })}><Plus size={16} /> เพิ่มสถานที่</button>
      )}
      {status ? <p role="status">{status}</p> : null}
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
    <DeveloperRouteGate signedOutPath="/merchant/login" afterSignOutPath="/merchant/login">
      {({ client, userId, signOut }) => <MerchantInner client={client} userId={userId} signOut={signOut} />}
    </DeveloperRouteGate>
  );
}
