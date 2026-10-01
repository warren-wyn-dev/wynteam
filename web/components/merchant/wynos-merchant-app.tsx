"use client";

import {
  Bell,
  Check,
  ChevronRight,
  CircleDollarSign,
  Clock3,
  Home,
  ImagePlus,
  LayoutGrid,
  MapPin,
  Menu as MenuIcon,
  PackageCheck,
  Phone,
  Plus,
  ReceiptText,
  Search,
  Settings,
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
import {
  completeFoodDelivery,
  createManualFoodOrder,
  deleteMenuItem,
  fetchMerchantSnapshot,
  foodPrivateSignedUrl,
  foodPublicUrl,
  merchantError,
  money,
  paymentLabel,
  saveMenuItem,
  setFoodPaymentStatus,
  setMenuAvailability,
  statusLabel,
  subscribeMerchantOrders,
  transitionFoodOrder,
  updateFoodStore,
  uploadFoodPrivateImage,
  uploadFoodPublicImage,
  type FoodMenuItem,
  type FoodOrder,
  type FoodStore,
  type ManualOrderDraft,
  type MenuDraft,
} from "@/lib/food-merchant";

type MerchantTab = "home" | "orders" | "menu" | "reports" | "store";
type OrderFilter = "active" | "new" | "preparing" | "ready" | "delivery" | "done";

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
  is_available: true,
};

const ORDER_FILTERS: Array<{ key: OrderFilter; label: string }> = [
  { key: "active", label: "ทั้งหมด" },
  { key: "new", label: "ใหม่" },
  { key: "preparing", label: "กำลังทำ" },
  { key: "ready", label: "พร้อมส่ง" },
  { key: "delivery", label: "กำลังส่ง" },
  { key: "done", label: "เสร็จสิ้น" },
];

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
      <p>บัญชีนี้ยังไม่มีสิทธิ์จัดการร้าน</p>
      <button className="wm-primary" type="button" onClick={() => void signOut()}>ออกจากระบบ</button>
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

function OrderCard({ order, onOpen }: { order: FoodOrder; onOpen: () => void }) {
  return (
    <button className="wm-order-card" type="button" onClick={onOpen}>
      <div className="wm-order-card-top">
        <span>
          <strong>#{order.order_number}</strong>
          <small>{shortTime(order.created_at)} · {order.source === "manual" ? "ร้านสร้าง" : "WYNOS Food"}</small>
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
  const [orderFilter, setOrderFilter] = useState<OrderFilter>("active");
  const [menuQuery, setMenuQuery] = useState("");
  const [menuDraft, setMenuDraft] = useState<MenuDraft | null>(null);
  const [manualOpen, setManualOpen] = useState(false);
  const [storeEditing, setStoreEditing] = useState(false);
  const [installPrompt, setInstallPrompt] = useState<InstallPromptEvent | null>(null);
  const [notificationsEnabled, setNotificationsEnabled] = useState(() => typeof window !== "undefined" && "Notification" in window && Notification.permission === "granted");
  const loadingRef = useRef(false);

  const load = useCallback(async (quiet = false) => {
    if (loadingRef.current) return;
    loadingRef.current = true;
    if (!quiet) setLoading(true);
    else setRefreshing(true);
    setMessage("");
    try {
      const next = await fetchMerchantSnapshot(client);
      setAccess(next.access);
      setStore(next.store);
      setMenu(next.menu);
      setOrders(next.orders);
      setSelectedOrder((current) => current ? next.orders.find((order) => order.id === current.id) ?? null : null);
    } catch (error) {
      setMessage(merchantError(error, "โหลดข้อมูลร้านไม่สำเร็จ"));
    } finally {
      loadingRef.current = false;
      setLoading(false);
      setRefreshing(false);
    }
  }, [client]);

  useEffect(() => {
    const timer = window.setTimeout(() => void load(), 0);
    return () => window.clearTimeout(timer);
  }, [load]);

  useEffect(() => {
    if (!store?.id) return;
    const channel = subscribeMerchantOrders(client, store.id, (payload) => {
      const next = payload.new as Partial<FoodOrder>;
      if (payload.eventType === "INSERT") {
        if (typeof navigator !== "undefined" && "vibrate" in navigator) navigator.vibrate?.([180, 80, 180]);
        if (typeof window !== "undefined" && "Notification" in window && Notification.permission === "granted") {
          new Notification("WYNOS Merchant · ออเดอร์ใหม่", {
            body: `#${String(next.order_number ?? "")} · ${money(next.total as number | string | undefined)}`,
            icon: "/icons/icon-192.png",
            tag: String(next.id ?? "wynos-food-order"),
          });
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
    setNotificationsEnabled("Notification" in window && Notification.permission === "granted");
    return () => window.removeEventListener("beforeinstallprompt", handler);
  }, []);

  const requestNotifications = async () => {
    if (!("Notification" in window)) {
      setMessage("อุปกรณ์นี้ไม่รองรับการแจ้งเตือนผ่านเบราว์เซอร์");
      return;
    }
    const permission = await Notification.requestPermission();
    setNotificationsEnabled(permission === "granted");
    if (permission !== "granted") setMessage("ยังไม่ได้อนุญาตการแจ้งเตือน");
  };

  const install = async () => {
    if (!installPrompt) return;
    await installPrompt.prompt();
    await installPrompt.userChoice;
    setInstallPrompt(null);
  };

  const todayOrders = useMemo(() => orders.filter((order) => sameLocalDay(order.created_at)), [orders]);
  const todayDelivered = useMemo(() => todayOrders.filter((order) => order.status === "delivered"), [todayOrders]);
  const todaySales = useMemo(() => todayDelivered.reduce((sum, order) => sum + Number(order.total), 0), [todayDelivered]);
  const attentionOrders = useMemo(
    () => orders.filter((order) => order.status !== "delivered" && order.status !== "cancelled").slice(0, 8),
    [orders],
  );
  const filteredOrders = useMemo(() => orders.filter((order) => {
    if (orderFilter === "new") return order.status === "pending_acceptance";
    if (orderFilter === "preparing") return order.status === "preparing";
    if (orderFilter === "ready") return order.status === "ready_for_delivery";
    if (orderFilter === "delivery") return order.status === "out_for_delivery";
    if (orderFilter === "done") return order.status === "delivered" || order.status === "cancelled";
    return order.status !== "delivered" && order.status !== "cancelled";
  }), [orderFilter, orders]);
  const visibleMenu = useMemo(() => {
    const q = menuQuery.trim().toLocaleLowerCase("th-TH");
    return q ? menu.filter((item) => `${item.name} ${item.category}`.toLocaleLowerCase("th-TH").includes(q)) : menu;
  }, [menu, menuQuery]);

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
            onClick={() => void requestNotifications()}
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

      <section className="wm-content">
        {tab === "home" && store ? (
          <HomePanel
            client={client}
            store={store}
            orders={orders}
            todayOrders={todayOrders}
            todaySales={todaySales}
            attentionOrders={attentionOrders}
            installPrompt={installPrompt}
            onInstall={() => void install()}
            onReload={() => void load(true)}
            onOrder={setSelectedOrder}
            onOpenOrders={() => setTab("orders")}
          />
        ) : null}

        {tab === "orders" && store ? (
          <OrdersPanel
            orders={filteredOrders}
            allOrders={orders}
            filter={orderFilter}
            onFilter={setOrderFilter}
            onOpen={setSelectedOrder}
            onManual={() => setManualOpen(true)}
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

        {tab === "reports" && store ? <ReportsPanel orders={orders} /> : null}

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
        <NavButton active={tab === "home"} label="หน้าหลัก" icon={<Home />} onClick={() => setTab("home")} />
        <NavButton active={tab === "orders"} label="ออเดอร์" icon={<ReceiptText />} badge={attentionOrders.length} onClick={() => setTab("orders")} />
        <NavButton active={tab === "menu"} label="เมนู" icon={<UtensilsCrossed />} onClick={() => setTab("menu")} />
        <NavButton active={tab === "reports"} label="รายงาน" icon={<LayoutGrid />} onClick={() => setTab("reports")} />
        <NavButton active={tab === "store"} label="ร้านค้า" icon={<Store />} onClick={() => setTab("store")} />
      </nav>

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

      {manualOpen && store ? (
        <ManualOrderSheet
          client={client}
          store={store}
          menu={menu}
          onClose={() => setManualOpen(false)}
          onSaved={async (orderId) => {
            setManualOpen(false);
            await load(true);
            const next = orders.find((order) => order.id === orderId);
            if (next) setSelectedOrder(next);
          }}
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
  orders,
  todayOrders,
  todaySales,
  attentionOrders,
  installPrompt,
  onInstall,
  onReload,
  onOrder,
  onOpenOrders,
}: {
  client: SupabaseClient;
  store: FoodStore;
  orders: FoodOrder[];
  todayOrders: FoodOrder[];
  todaySales: number;
  attentionOrders: FoodOrder[];
  installPrompt: InstallPromptEvent | null;
  onInstall: () => void;
  onReload: () => void;
  onOrder: (order: FoodOrder) => void;
  onOpenOrders: () => void;
}) {
  const [busy, setBusy] = useState(false);
  const toggleOpen = async () => {
    setBusy(true);
    try {
      await updateFoodStore(client, store.id, { is_open: !store.is_open });
      onReload();
    } finally { setBusy(false); }
  };
  const waitingPayment = orders.filter((order) => order.payment_status === "submitted").length;
  const preparing = orders.filter((order) => order.status === "preparing").length;
  const delivery = orders.filter((order) => order.status === "out_for_delivery").length;

  return (
    <>
      <div className="wm-page-heading">
        <div>
          <small>ร้านของคุณ</small>
          <h1>{store.name}</h1>
        </div>
        <span className={`wm-live ${store.is_open ? "is-open" : ""}`}>
          <i />{store.is_open ? "เปิดรับออเดอร์" : "ปิดรับออเดอร์"}
        </span>
      </div>

      <button className={`wm-open-toggle ${store.is_open ? "is-open" : ""}`} type="button" disabled={busy} onClick={() => void toggleOpen()}>
        <span>
          <strong>{store.is_open ? "กำลังเปิดรับออเดอร์" : "หยุดรับออเดอร์อยู่"}</strong>
          <small>{store.is_open ? "ลูกค้าสามารถสั่งอาหารได้" : "กดเพื่อเปิดร้านเมื่อพร้อม"}</small>
        </span>
        <i><b /></i>
      </button>

      {!store.is_published ? (
        <div className="wm-setup-banner">
          <Store size={22} strokeWidth={1.7} />
          <span><strong>ร้านยังไม่เผยแพร่</strong><small>ตั้งค่าข้อมูลร้านและช่องทางรับเงินก่อนเปิดให้ลูกค้าสั่ง</small></span>
        </div>
      ) : null}

      <section className="wm-section">
        <div className="wm-section-title"><h2>วันนี้</h2><small>{todayOrders.length} ออเดอร์</small></div>
        <div className="wm-metrics">
          <Metric label="ยอดขาย" value={money(todaySales)} />
          <Metric label="รอตรวจเงิน" value={String(waitingPayment)} />
          <Metric label="กำลังทำ" value={String(preparing)} />
          <Metric label="กำลังส่ง" value={String(delivery)} />
        </div>
      </section>

      <section className="wm-section">
        <div className="wm-section-title">
          <h2>ต้องจัดการตอนนี้</h2>
          <button type="button" onClick={onOpenOrders}>ดูทั้งหมด <ChevronRight size={15} /></button>
        </div>
        {attentionOrders.length ? (
          <div className="wm-order-list">{attentionOrders.map((order) => <OrderCard key={order.id} order={order} onOpen={() => onOrder(order)} />)}</div>
        ) : (
          <div className="wm-empty wm-empty--compact"><PackageCheck size={34} strokeWidth={1.5} /><strong>จัดการครบแล้ว</strong><p>ยังไม่มีออเดอร์ที่ต้องดำเนินการ</p></div>
        )}
      </section>

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

function OrdersPanel({
  orders,
  allOrders,
  filter,
  onFilter,
  onOpen,
  onManual,
}: {
  orders: FoodOrder[];
  allOrders: FoodOrder[];
  filter: OrderFilter;
  onFilter: (value: OrderFilter) => void;
  onOpen: (order: FoodOrder) => void;
  onManual: () => void;
}) {
  const counts: Record<OrderFilter, number> = {
    active: allOrders.filter((o) => !["delivered", "cancelled"].includes(o.status)).length,
    new: allOrders.filter((o) => o.status === "pending_acceptance").length,
    preparing: allOrders.filter((o) => o.status === "preparing").length,
    ready: allOrders.filter((o) => o.status === "ready_for_delivery").length,
    delivery: allOrders.filter((o) => o.status === "out_for_delivery").length,
    done: allOrders.filter((o) => ["delivered", "cancelled"].includes(o.status)).length,
  };
  return (
    <>
      <div className="wm-page-heading wm-page-heading--action">
        <div><small>จัดการงานร้าน</small><h1>ออเดอร์</h1></div>
        <button className="wm-small-primary" type="button" onClick={onManual}><Plus size={17} /> สร้างออเดอร์</button>
      </div>
      <div className="wm-filter-tabs">
        {ORDER_FILTERS.map((item) => (
          <button key={item.key} className={filter === item.key ? "is-active" : ""} type="button" onClick={() => onFilter(item.key)}>
            {item.label}{counts[item.key] ? <b>{counts[item.key]}</b> : null}
          </button>
        ))}
      </div>
      {orders.length ? <div className="wm-order-list wm-order-list--page">{orders.map((order) => <OrderCard key={order.id} order={order} onOpen={() => onOpen(order)} />)}</div> : (
        <div className="wm-empty"><ShoppingBag size={38} strokeWidth={1.5} /><strong>ไม่มีออเดอร์ในหมวดนี้</strong></div>
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
  return (
    <>
      <div className="wm-page-heading wm-page-heading--action">
        <div><small>รายการขาย</small><h1>เมนูอาหาร</h1></div>
        <button className="wm-small-primary" type="button" onClick={onAdd}><Plus size={17} /> เพิ่มเมนู</button>
      </div>
      <label className="wm-search"><Search size={19} strokeWidth={1.7} /><input value={query} onChange={(e) => onQuery(e.target.value)} placeholder="ค้นหาเมนู" /></label>
      <div className="wm-menu-list">
        {menu.map((item) => {
          const image = foodPublicUrl(client, item.image_path);
          return (
            <article className={`wm-menu-row ${item.is_available ? "" : "is-off"}`} key={item.id}>
              <button className="wm-menu-main" type="button" onClick={() => onEdit(item)}>
                <span className="wm-menu-photo">{image ? <img src={image} alt="" /> : <UtensilsCrossed size={24} strokeWidth={1.5} />}</span>
                <span className="wm-menu-copy"><strong>{item.name}</strong><small>{item.category}</small><b>{money(item.price)}</b></span>
              </button>
              <button className={`wm-switch ${item.is_available ? "is-on" : ""}`} type="button" aria-label={item.is_available ? "ปิดขายชั่วคราว" : "เปิดขาย"} onClick={() => onToggle(item)}><i /></button>
            </article>
          );
        })}
      </div>
      {!menu.length ? <div className="wm-empty"><MenuIcon size={38} strokeWidth={1.5} /><strong>ยังไม่มีเมนู</strong><p>เพิ่มอาหารหรือเครื่องดื่มเพื่อเริ่มรับออเดอร์</p></div> : null}
    </>
  );
}

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
      await updateFoodStore(client, store.id, { is_published: !store.is_published });
      onReload();
    } catch (error) { onMessage(merchantError(error)); }
    finally { setBusy(false); }
  };
  return (
    <>
      <div className="wm-page-heading"><div><small>การตั้งค่า</small><h1>ร้านค้า</h1></div></div>
      <section className="wm-store-card">
        <div className="wm-store-avatar">{store.logo_path ? <img src={foodPublicUrl(client, store.logo_path) ?? ""} alt="" /> : <Store size={30} strokeWidth={1.6} />}</div>
        <div><strong>{store.name}</strong><small>{store.address || "ยังไม่ได้ใส่ที่อยู่ร้าน"}</small></div>
        <button type="button" onClick={onEdit}>แก้ไข</button>
      </section>
      <section className="wm-settings-list">
        <button type="button" onClick={() => void togglePublished()} disabled={busy}>
          <span><strong>เผยแพร่ WYNOS Food</strong><small>{store.is_published ? "ลูกค้าเห็นร้านได้แล้ว" : "ร้านยังซ่อนจากลูกค้า"}</small></span>
          <span className={`wm-switch ${store.is_published ? "is-on" : ""}`}><i /></span>
        </button>
        <button type="button" onClick={onEdit}><span><strong>ข้อมูลร้านและการจัดส่ง</strong><small>เวลาเปิด · พื้นที่ส่ง · ค่าส่ง · ยอดขั้นต่ำ</small></span><ChevronRight size={19} /></button>
        <button type="button" onClick={onEdit}><span><strong>รับชำระเงิน</strong><small>PromptPay · บัญชีธนาคาร · QR</small></span><ChevronRight size={19} /></button>
        {installPrompt ? <button type="button" onClick={onInstall}><span><strong>ติดตั้งเป็นแอป</strong><small>เพิ่ม WYNOS Merchant ไว้บนหน้าจอหลัก</small></span><ChevronRight size={19} /></button> : null}
        <button type="button" onClick={onSignOut}><span><strong>ออกจากระบบ</strong><small>ออกจากบัญชี WYNOS บนอุปกรณ์นี้</small></span><ChevronRight size={19} /></button>
      </section>
    </>
  );
}

function Sheet({ title, onClose, children, wide = false }: { title: string; onClose: () => void; children: React.ReactNode; wide?: boolean }) {
  return (
    <div className="wm-sheet-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}>
      <section className={`wm-sheet ${wide ? "wm-sheet--wide" : ""}`} role="dialog" aria-modal="true" aria-label={title}>
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
  const [slipUrl, setSlipUrl] = useState<string | null>(null);
  const [proofUrl, setProofUrl] = useState<string | null>(null);
  const [deliveryMethod, setDeliveryMethod] = useState<"direct" | "dropoff">("direct");
  const [locationNote, setLocationNote] = useState("");
  const [deliveryFile, setDeliveryFile] = useState<File | null>(null);

  useEffect(() => {
    let live = true;
    void foodPrivateSignedUrl(client, order.payment_slip_path).then((url) => { if (live) setSlipUrl(url); });
    const proofPath = order.food_delivery_proofs?.[0]?.image_path;
    void foodPrivateSignedUrl(client, proofPath).then((url) => { if (live) setProofUrl(url); });
    return () => { live = false; };
  }, [client, order.id, order.payment_slip_path, order.food_delivery_proofs]);

  const run = async (action: () => Promise<void>, success?: string) => {
    setBusy(true);
    try {
      await action();
      if (success) onMessage(success);
      onReload();
    } catch (error) { onMessage(merchantError(error)); }
    finally { setBusy(false); }
  };

  const complete = async () => {
    await run(async () => {
      let path: string | null = null;
      if (deliveryMethod === "dropoff") {
        if (!deliveryFile) throw new Error("กรุณาถ่ายรูปจุดที่วางสินค้า");
        if (!locationNote.trim()) throw new Error("กรุณาระบุว่าวางสินค้าไว้ที่ไหน");
        path = await uploadFoodPrivateImage(client, deliveryFile, `delivery/${order.id}`);
      }
      await completeFoodDelivery(client, order.id, deliveryMethod, locationNote, path);
    }, "ส่งออเดอร์สำเร็จแล้ว");
  };

  const mapHref = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(order.shipping_address)}`;
  return (
    <Sheet title={`ออเดอร์ #${order.order_number}`} onClose={onClose} wide>
      <div className="wm-order-detail-head">
        <div><OrderStatus order={order} /><PaymentStatus order={order} /></div>
        <strong>{money(order.total)}</strong>
        <small>{new Intl.DateTimeFormat("th-TH", { dateStyle: "medium", timeStyle: "short" }).format(new Date(order.created_at))}</small>
      </div>

      <section className="wm-detail-section">
        <h3>รายการอาหาร</h3>
        <div className="wm-line-items">
          {(order.food_order_items ?? []).map((item) => (
            <div key={item.id}><b>{item.quantity}×</b><span><strong>{item.item_name}</strong>{item.item_note ? <small>{item.item_note}</small> : null}</span><em>{money(Number(item.unit_price) * item.quantity)}</em></div>
          ))}
        </div>
        <div className="wm-totals">
          <div><span>ค่าอาหาร</span><b>{money(order.subtotal)}</b></div>
          <div><span>ค่าส่ง</span><b>{money(order.delivery_fee)}</b></div>
          <div className="is-total"><span>ยอดสุทธิ</span><b>{money(order.total)}</b></div>
        </div>
      </section>

      <section className="wm-detail-section">
        <h3>การชำระเงิน</h3>
        <div className="wm-payment-box">
          <PaymentStatus order={order} />
          {slipUrl ? <a href={slipUrl} target="_blank" rel="noreferrer"><img src={slipUrl} alt="สลิปชำระเงิน" /></a> : null}
          {order.payment_note ? <p>{order.payment_note}</p> : null}
          {order.payment_status === "submitted" ? (
            <div className="wm-two-actions">
              <button className="wm-primary" disabled={busy} type="button" onClick={() => void run(() => setFoodPaymentStatus(client, order.id, "paid"), "ยืนยันเงินเข้าแล้ว")}>ยืนยันเงินเข้า</button>
              <button className="wm-secondary" disabled={busy} type="button" onClick={() => void run(() => setFoodPaymentStatus(client, order.id, "issue", "กรุณาตรวจสอบหรือส่งสลิปใหม่"))}>มีปัญหา</button>
            </div>
          ) : order.payment_status === "pending" ? (
            <button className="wm-secondary wm-full" disabled={busy} type="button" onClick={() => void run(() => setFoodPaymentStatus(client, order.id, "paid"), "บันทึกว่าชำระแล้ว")}>ทำเครื่องหมายว่าชำระแล้ว</button>
          ) : null}
        </div>
      </section>

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

      {order.status === "pending_acceptance" ? (
        <section className="wm-detail-section wm-next-step">
          <h3>รับออเดอร์</h3>
          <label>เวลาทำโดยประมาณ<select value={eta} onChange={(e) => setEta(Number(e.target.value))}><option value={15}>15 นาที</option><option value={30}>30 นาที</option><option value={45}>45 นาที</option><option value={60}>60 นาที</option></select></label>
          <button className="wm-primary wm-full" disabled={busy || order.payment_status !== "paid"} type="button" onClick={() => void run(() => transitionFoodOrder(client, order.id, "preparing", eta), "รับออเดอร์แล้ว")}>รับออเดอร์</button>
          {order.payment_status !== "paid" ? <small>ยืนยันการชำระเงินก่อนรับออเดอร์</small> : null}
        </section>
      ) : null}

      {order.status === "preparing" ? (
        <section className="wm-detail-section wm-next-step"><h3>กำลังเตรียม</h3><p>เมื่ออาหารพร้อม ให้เปลี่ยนสถานะเพื่อเข้าสู่ขั้นตอนจัดส่ง</p><button className="wm-primary wm-full" disabled={busy} type="button" onClick={() => void run(() => transitionFoodOrder(client, order.id, "ready_for_delivery"), "อาหารพร้อมจัดส่ง")}>อาหารพร้อมแล้ว</button></section>
      ) : null}

      {order.status === "ready_for_delivery" ? (
        <section className="wm-detail-section wm-next-step"><h3>พร้อมจัดส่ง</h3><p>คุณเป็นผู้จัดส่งเอง ระบบจะเข้าสู่ Delivery Mode หลังเริ่มงาน</p><button className="wm-primary wm-full" disabled={busy} type="button" onClick={() => void run(() => transitionFoodOrder(client, order.id, "out_for_delivery"), "เริ่มจัดส่งแล้ว")}><Truck size={18} /> เริ่มจัดส่ง</button></section>
      ) : null}

      {order.status === "out_for_delivery" ? (
        <section className="wm-detail-section wm-next-step">
          <h3>Delivery Mode</h3>
          <div className="wm-delivery-methods">
            <button className={deliveryMethod === "direct" ? "is-active" : ""} type="button" onClick={() => setDeliveryMethod("direct")}><PackageCheck size={20} /><span><strong>ส่งให้ลูกค้า</strong><small>ส่งถึงมือผู้รับแล้ว</small></span></button>
            <button className={deliveryMethod === "dropoff" ? "is-active" : ""} type="button" onClick={() => setDeliveryMethod("dropoff")}><ImagePlus size={20} /><span><strong>วางสินค้าไว้</strong><small>ต้องมีรูปและจุดที่วาง</small></span></button>
          </div>
          {deliveryMethod === "dropoff" ? (
            <div className="wm-proof-form">
              <label className="wm-upload">
                <input type="file" accept="image/jpeg,image/png,image/webp" capture="environment" onChange={(e) => setDeliveryFile(e.target.files?.[0] ?? null)} />
                <ImagePlus size={22} /><span>{deliveryFile ? deliveryFile.name : "ถ่ายรูปหลักฐานการจัดส่ง"}</span>
              </label>
              <label>วางไว้ที่ไหน?<textarea value={locationNote} onChange={(e) => setLocationNote(e.target.value)} placeholder="เช่น โต๊ะหน้าประตูด้านซ้าย" /></label>
            </div>
          ) : null}
          <button className="wm-primary wm-full" disabled={busy} type="button" onClick={() => void complete()}><Check size={18} /> ยืนยันส่งสำเร็จ</button>
        </section>
      ) : null}

      {order.status === "delivered" ? (
        <section className="wm-detail-section wm-delivered-box"><PackageCheck size={28} /><div><strong>จัดส่งสำเร็จแล้ว</strong><small>{order.delivered_at ? new Intl.DateTimeFormat("th-TH", { dateStyle: "medium", timeStyle: "short" }).format(new Date(order.delivered_at)) : ""}</small>{order.food_delivery_proofs?.[0]?.location_note ? <p>วางไว้: {order.food_delivery_proofs[0].location_note}</p> : null}</div>{proofUrl ? <a href={proofUrl} target="_blank" rel="noreferrer"><img src={proofUrl} alt="หลักฐานการจัดส่ง" /></a> : null}</section>
      ) : null}

      {!["delivered", "cancelled"].includes(order.status) ? (
        <button className="wm-danger-link" disabled={busy} type="button" onClick={() => {
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
  const [busy, setBusy] = useState(false);
  const save = async () => {
    setBusy(true);
    try {
      let imagePath = form.image_path ?? null;
      if (file) imagePath = await uploadFoodPublicImage(client, file, `stores/${store.id}/menu`);
      await saveMenuItem(client, store.id, { ...form, image_path: imagePath });
      onMessage(form.id ? "บันทึกเมนูแล้ว" : "เพิ่มเมนูแล้ว");
      await onSaved();
    } catch (error) { onMessage(merchantError(error)); }
    finally { setBusy(false); }
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
        <div className="wm-form-grid"><label>หมวด<input value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })} /></label><label>ราคา<input type="number" min="0" step="1" inputMode="decimal" value={form.price} onChange={(e) => setForm({ ...form, price: e.target.value })} placeholder="0" /></label></div>
        <label>รายละเอียด<textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} placeholder="รายละเอียดอาหาร" /></label>
        <label className="wm-upload"><input type="file" accept="image/jpeg,image/png,image/webp" onChange={(e) => setFile(e.target.files?.[0] ?? null)} /><Upload size={20} /><span>{file ? file.name : "อัปโหลดรูปเมนู"}</span></label>
        <label className="wm-check-row"><input type="checkbox" checked={form.is_available} onChange={(e) => setForm({ ...form, is_available: e.target.checked })} /><span><strong>เปิดขาย</strong><small>ปิดได้ทันทีเมื่อเมนูหมด</small></span></label>
        <button className="wm-primary wm-full" type="button" disabled={busy} onClick={() => void save()}>{busy ? "กำลังบันทึก…" : "บันทึกเมนู"}</button>
        {form.id ? <button className="wm-danger-link" type="button" disabled={busy} onClick={() => void remove()}>ลบเมนู</button> : null}
      </div>
    </Sheet>
  );
}

function ManualOrderSheet({
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
  onSaved: (orderId: string) => Promise<void>;
  onMessage: (message: string) => void;
}) {
  const [recipientName, setRecipientName] = useState("");
  const [recipientPhone, setRecipientPhone] = useState("");
  const [shippingAddress, setShippingAddress] = useState("");
  const [customerNote, setCustomerNote] = useState("");
  const [paid, setPaid] = useState(true);
  const [quantities, setQuantities] = useState<Record<string, number>>({});
  const [busy, setBusy] = useState(false);
  const selected = menu.filter((item) => (quantities[item.id] ?? 0) > 0);
  const subtotal = selected.reduce((sum, item) => sum + Number(item.price) * (quantities[item.id] ?? 0), 0);
  const total = subtotal + Number(store.delivery_fee);

  const create = async () => {
    setBusy(true);
    try {
      const draft: ManualOrderDraft = {
        recipientName,
        recipientPhone,
        shippingAddress,
        customerNote,
        paymentStatus: paid ? "paid" : "pending",
        items: selected.map((item) => ({ menu_item_id: item.id, quantity: quantities[item.id] })),
      };
      const id = await createManualFoodOrder(client, store.id, draft);
      onMessage("สร้างออเดอร์แล้ว");
      await onSaved(id);
    } catch (error) { onMessage(merchantError(error)); }
    finally { setBusy(false); }
  };

  return (
    <Sheet title="สร้างออเดอร์" onClose={onClose} wide>
      <div className="wm-form">
        <div className="wm-manual-menu">
          <h3>เลือกเมนู</h3>
          {menu.filter((item) => item.is_available).map((item) => (
            <div key={item.id}><span><strong>{item.name}</strong><small>{money(item.price)}</small></span><div className="wm-qty"><button type="button" onClick={() => setQuantities({ ...quantities, [item.id]: Math.max(0, (quantities[item.id] ?? 0) - 1) })}>−</button><b>{quantities[item.id] ?? 0}</b><button type="button" onClick={() => setQuantities({ ...quantities, [item.id]: (quantities[item.id] ?? 0) + 1 })}>+</button></div></div>
          ))}
        </div>
        <label>ชื่อลูกค้า<input value={recipientName} onChange={(e) => setRecipientName(e.target.value)} /></label>
        <label>เบอร์โทร<input value={recipientPhone} onChange={(e) => setRecipientPhone(e.target.value)} inputMode="tel" /></label>
        <label>ที่อยู่จัดส่ง<textarea value={shippingAddress} onChange={(e) => setShippingAddress(e.target.value)} /></label>
        <label>หมายเหตุ<textarea value={customerNote} onChange={(e) => setCustomerNote(e.target.value)} placeholder="ไม่ใส่ผัก / โทรเมื่อถึง" /></label>
        <label className="wm-check-row"><input type="checkbox" checked={paid} onChange={(e) => setPaid(e.target.checked)} /><span><strong>ชำระเงินแล้ว</strong><small>เงินเข้าบัญชีร้านแล้ว</small></span></label>
        <div className="wm-manual-total"><span>ยอดรวม</span><strong>{money(total)}</strong></div>
        <button className="wm-primary wm-full" type="button" disabled={busy || !selected.length} onClick={() => void create()}>{busy ? "กำลังสร้าง…" : "สร้างออเดอร์"}</button>
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
    promptpay_name: store.promptpay_name ?? "",
    promptpay_id: store.promptpay_id ?? "",
    bank_name: store.bank_name ?? "",
    bank_account_name: store.bank_account_name ?? "",
    bank_account_number: store.bank_account_number ?? "",
    payment_qr_path: store.payment_qr_path,
  });
  const [qrFile, setQrFile] = useState<File | null>(null);
  const [busy, setBusy] = useState(false);

  const save = async () => {
    setBusy(true);
    try {
      let qr = form.payment_qr_path;
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
        promptpay_name: form.promptpay_name.trim() || null,
        promptpay_id: form.promptpay_id.trim() || null,
        bank_name: form.bank_name.trim() || null,
        bank_account_name: form.bank_account_name.trim() || null,
        bank_account_number: form.bank_account_number.trim() || null,
        payment_qr_path: qr,
      });
      onMessage("บันทึกข้อมูลร้านแล้ว");
      await onSaved();
    } catch (error) { onMessage(merchantError(error)); }
    finally { setBusy(false); }
  };

  return (
    <Sheet title="ตั้งค่าร้าน" onClose={onClose} wide>
      <div className="wm-form">
        <h3>ข้อมูลร้าน</h3>
        <label>ชื่อร้าน<input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></label>
        <label>รายละเอียด<textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} /></label>
        <label>เบอร์ร้าน<input value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} inputMode="tel" /></label>
        <label>ที่อยู่ร้าน<textarea value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} /></label>
        <label>เวลาเปิด–ปิด<input value={form.business_hours} onChange={(e) => setForm({ ...form, business_hours: e.target.value })} placeholder="เช่น ทุกวัน 10:00–20:00" /></label>
        <h3>การจัดส่ง</h3>
        <label>พื้นที่จัดส่ง<textarea value={form.delivery_area} onChange={(e) => setForm({ ...form, delivery_area: e.target.value })} placeholder="เช่น รัศมี 5 กม. / เขตที่ให้บริการ" /></label>
        <div className="wm-form-grid"><label>ค่าส่ง<input type="number" min="0" inputMode="decimal" value={form.delivery_fee} onChange={(e) => setForm({ ...form, delivery_fee: e.target.value })} /></label><label>ยอดขั้นต่ำ<input type="number" min="0" inputMode="decimal" value={form.minimum_order} onChange={(e) => setForm({ ...form, minimum_order: e.target.value })} /></label></div>
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

export function WynosMerchantApp() {
  return (
    <DeveloperRouteGate>
      {({ client, userId, signOut }) => <MerchantInner client={client} userId={userId} signOut={signOut} />}
    </DeveloperRouteGate>
  );
}
