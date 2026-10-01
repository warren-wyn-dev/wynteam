"use client";

import {
  ArrowLeft,
  Bell,
  Check,
  ChevronRight,
  Clock3,
  Home,
  MapPin,
  Minus,
  PackageCheck,
  Phone,
  Plus,
  ReceiptText,
  Search,
  ShoppingBag,
  Store,
  Trash2,
  Upload,
  UserRound,
  UtensilsCrossed,
  X,
} from "lucide-react";
import type { SupabaseClient } from "@supabase/supabase-js";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import {
  cancelFoodCustomerOrder,
  createFoodCustomerOrder,
  deleteFoodCustomerAddress,
  fetchFoodCustomerSnapshot,
  foodCustomerError,
  foodMoney,
  foodOrderStatusLabel,
  foodPaymentStatusLabel,
  foodPrivateSignedUrl,
  foodPublicUrl,
  saveFoodCustomerAddress,
  submitFoodPayment,
  subscribeFoodCustomerOrders,
  uploadFoodPaymentSlip,
  type FoodAddressDraft,
  type FoodCartLine,
  type FoodCustomerAddress,
  type FoodCustomerMenuItem,
  type FoodCustomerOrder,
  type FoodCustomerSnapshot,
  type FoodCustomerStore,
} from "@/lib/food-customer";

type FoodTab = "home" | "orders" | "cart" | "account";

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
  isDefault: true,
};

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
      <small>Developer Preview</small>
    </main>
  );
}

function FoodDenied() {
  return <FoodLoading />;
}

function FoodHeader({
  onRefresh,
  refreshing,
}: {
  onRefresh: () => void;
  refreshing: boolean;
}) {
  return (
    <header className="wf-header">
      <div className="wf-brand">
        <span>WYNOS</span>
        <b>Food</b>
        <small>Developer Preview</small>
      </div>
      <button className="wf-icon-button" type="button" aria-label="อัปเดตข้อมูล" onClick={onRefresh}>
        {refreshing ? <i className="wf-mini-loader" /> : <Clock3 size={21} strokeWidth={1.8} />}
      </button>
    </header>
  );
}

function FoodNav({
  tab,
  cartCount,
  activeCount,
  onTab,
}: {
  tab: FoodTab;
  cartCount: number;
  activeCount: number;
  onTab: (tab: FoodTab) => void;
}) {
  return (
    <nav className="wf-nav" aria-label="WYNOS Food">
      <button type="button" className={tab === "home" ? "is-active" : ""} onClick={() => onTab("home")}>
        <span><Home /></span><small>หน้าหลัก</small>
      </button>
      <button type="button" className={tab === "orders" ? "is-active" : ""} onClick={() => onTab("orders")}>
        <span><ReceiptText />{activeCount ? <i>{activeCount > 9 ? "9+" : activeCount}</i> : null}</span><small>ออเดอร์</small>
      </button>
      <button type="button" className={tab === "cart" ? "is-active" : ""} onClick={() => onTab("cart")}>
        <span><ShoppingBag />{cartCount ? <i>{cartCount > 9 ? "9+" : cartCount}</i> : null}</span><small>ตะกร้า</small>
      </button>
      <button type="button" className={tab === "account" ? "is-active" : ""} onClick={() => onTab("account")}>
        <span><UserRound /></span><small>บัญชี</small>
      </button>
    </nav>
  );
}

function FoodStatus({ store }: { store: FoodCustomerStore }) {
  return (
    <span className={`wf-store-status ${store.is_open ? "is-open" : ""}`}>
      <i />{store.is_open ? "เปิดรับออเดอร์" : "ปิดรับออเดอร์"}
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

function HomePanel({
  client,
  store,
  menu,
  onItem,
}: {
  client: SupabaseClient;
  store: FoodCustomerStore | null;
  menu: FoodCustomerMenuItem[];
  onItem: (item: FoodCustomerMenuItem) => void;
}) {
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState("ทั้งหมด");
  const categories = useMemo(() => ["ทั้งหมด", ...new Set(menu.map((item) => item.category))], [menu]);
  const visible = useMemo(() => {
    const q = query.trim().toLocaleLowerCase("th-TH");
    return menu.filter((item) => {
      if (category !== "ทั้งหมด" && item.category !== category) return false;
      if (!q) return true;
      return `${item.name} ${item.category} ${item.description ?? ""}`.toLocaleLowerCase("th-TH").includes(q);
    });
  }, [category, menu, query]);

  if (!store) {
    return (
      <div className="wf-empty">
        <Store size={40} strokeWidth={1.4} />
        <strong>ยังไม่มีร้านสำหรับ WYNOS Food</strong>
        <p>สร้างและตั้งค่าร้านจาก WYNOS Merchant ก่อนเริ่มทดสอบฝั่งลูกค้า</p>
      </div>
    );
  }

  const cover = foodPublicUrl(client, store.cover_path);
  const logo = foodPublicUrl(client, store.logo_path);

  return (
    <>
      <div className="wf-preview-banner">
        <span>DEV</span>
        <div><strong>Developer Preview เท่านั้น</strong><small>ร้านนี้ยังไม่เปิดให้ผู้ใช้ทั่วไปและไม่ถูกแสดงใน WYNOS</small></div>
      </div>

      <section className="wf-store-hero">
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
            {store.description ? <p>{store.description}</p> : null}
            <div className="wf-store-meta">
              {store.business_hours ? <span><Clock3 size={14} />{store.business_hours}</span> : null}
              <span><MapPin size={14} />ค่าส่ง {foodMoney(store.delivery_fee)}</span>
              {Number(store.minimum_order) > 0 ? <span>ขั้นต่ำ {foodMoney(store.minimum_order)}</span> : null}
            </div>
          </div>
        </div>
      </section>

      <label className="wf-search">
        <Search size={19} strokeWidth={1.7} />
        <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="ค้นหาเมนูอาหาร" />
      </label>

      <div className="wf-category-tabs">
        {categories.map((name) => (
          <button key={name} type="button" className={category === name ? "is-active" : ""} onClick={() => setCategory(name)}>
            {name}
          </button>
        ))}
      </div>

      <div className="wf-section-title">
        <h2>{category === "ทั้งหมด" ? "เมนูทั้งหมด" : category}</h2>
        <small>{visible.length} เมนู</small>
      </div>

      {visible.length ? (
        <div className="wf-menu-list">
          {visible.map((item) => (
            <button key={item.id} type="button" className={`wf-menu-row ${item.is_available ? "" : "is-off"}`} onClick={() => onItem(item)}>
              <MenuImage client={client} item={item} />
              <span className="wf-menu-copy">
                <strong>{item.name}</strong>
                {item.description ? <small>{item.description}</small> : <small>{item.category}</small>}
                <b>{foodMoney(item.price)}</b>
              </span>
              <span className={item.is_available ? "wf-add" : "wf-soldout"}>
                {item.is_available ? <Plus size={18} /> : "หมดชั่วคราว"}
              </span>
            </button>
          ))}
        </div>
      ) : (
        <div className="wf-empty wf-empty--compact">
          <Search size={35} strokeWidth={1.4} />
          <strong>ไม่พบเมนู</strong>
        </div>
      )}
    </>
  );
}

function CartPanel({
  store,
  menu,
  cart,
  onCart,
  onCheckout,
}: {
  store: FoodCustomerStore | null;
  menu: FoodCustomerMenuItem[];
  cart: FoodCartLine[];
  onCart: (cart: FoodCartLine[]) => void;
  onCheckout: () => void;
}) {
  const priced = cart.map((line) => ({ line, item: itemFor(menu, line.menu_item_id) }));
  const subtotal = priced.reduce((sum, row) => sum + (row.item ? Number(row.item.price) * row.line.quantity : 0), 0);
  const delivery = Number(store?.delivery_fee ?? 0);
  const total = subtotal + delivery;
  const hasUnavailable = priced.some((row) => !row.item?.is_available);
  const belowMinimum = subtotal < Number(store?.minimum_order ?? 0);
  const canCheckout = !!store && store.is_open && cart.length > 0 && !hasUnavailable && !belowMinimum;

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
              <article key={line.menu_item_id} className={`wf-cart-row ${item?.is_available ? "" : "is-off"}`}>
                <div className="wf-cart-copy">
                  <strong>{item?.name ?? "เมนูไม่พร้อมใช้งาน"}</strong>
                  {line.note ? <small>{line.note}</small> : null}
                  <b>{item ? foodMoney(Number(item.price) * line.quantity) : "—"}</b>
                  {!item?.is_available ? <em>เมนูนี้หมดชั่วคราว กรุณานำออกจากตะกร้า</em> : null}
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
            <div><span>ค่าส่ง</span><b>{foodMoney(delivery)}</b></div>
            <div className="is-total"><span>ยอดสุทธิ</span><b>{foodMoney(total)}</b></div>
          </div>

          {belowMinimum && store ? (
            <div className="wf-inline-warning">ยอดขั้นต่ำของร้านคือ {foodMoney(store.minimum_order)}</div>
          ) : null}
          {!store?.is_open ? <div className="wf-inline-warning">ร้านยังไม่เปิดรับออเดอร์</div> : null}

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
  onOrder,
}: {
  orders: FoodCustomerOrder[];
  onOrder: (order: FoodCustomerOrder) => void;
}) {
  const active = orders.filter((order) => !["delivered", "cancelled"].includes(order.status));
  const history = orders.filter((order) => ["delivered", "cancelled"].includes(order.status));

  return (
    <>
      <div className="wf-page-title"><div><small>ติดตามและดูประวัติ</small><h1>ออเดอร์</h1></div></div>
      <div className="wf-section-title"><h2>กำลังดำเนินการ</h2><small>{active.length}</small></div>
      {active.length ? <div className="wf-order-list">{active.map((order) => <OrderCard key={order.id} order={order} onOpen={() => onOrder(order)} />)}</div> : (
        <div className="wf-empty wf-empty--compact"><PackageCheck size={36} strokeWidth={1.4} /><strong>ไม่มีออเดอร์ที่กำลังดำเนินการ</strong></div>
      )}
      <div className="wf-section-title wf-section-title--spaced"><h2>ประวัติ</h2><small>{history.length}</small></div>
      {history.length ? <div className="wf-order-list">{history.map((order) => <OrderCard key={order.id} order={order} onOpen={() => onOrder(order)} />)}</div> : null}
    </>
  );
}

function OrderCard({ order, onOpen }: { order: FoodCustomerOrder; onOpen: () => void }) {
  const count = order.food_order_items?.reduce((sum, item) => sum + item.quantity, 0) ?? 0;
  return (
    <button className="wf-order-card" type="button" onClick={onOpen}>
      <div className="wf-order-top">
        <span><strong>#{order.order_number}</strong><small>{formatDate(order.created_at)}</small></span>
        <b>{foodMoney(order.total)}</b>
      </div>
      <div className="wf-order-mid"><span>{count} รายการ</span><span className={`wf-order-status wf-order-status--${order.status}`}>{foodOrderStatusLabel(order.status)}</span></div>
      <div className="wf-order-bottom"><span>{foodPaymentStatusLabel(order.payment_status)}</span><ChevronRight size={18} /></div>
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
}: {
  addresses: FoodCustomerAddress[];
  installPrompt: InstallPromptEvent | null;
  notificationsEnabled: boolean;
  onAddAddress: () => void;
  onEditAddress: (address: FoodCustomerAddress) => void;
  onDeleteAddress: (id: string) => void;
  onInstall: () => void;
  onNotifications: () => void;
}) {
  return (
    <>
      <div className="wf-page-title"><div><small>Developer Preview</small><h1>บัญชี</h1></div></div>
      <section className="wf-account-card">
        <span><UserRound size={26} /></span>
        <div><strong>บัญชีนักพัฒนา WYNOS</strong><small>WYNOS Food ถูกซ่อนจากผู้ใช้ทั่วไป</small></div>
      </section>

      <div className="wf-section-title wf-section-title--spaced">
        <h2>ที่อยู่จัดส่ง</h2>
        <button type="button" onClick={onAddAddress}><Plus size={15} /> เพิ่ม</button>
      </div>
      {addresses.length ? (
        <div className="wf-address-list">
          {addresses.map((address) => (
            <article key={address.id} className="wf-address-row">
              <MapPin size={19} />
              <div><strong>{address.label}{address.is_default ? " · ค่าเริ่มต้น" : ""}</strong><small>{address.recipient_name} · {address.recipient_phone}</small><p>{address.address}</p></div>
              <button type="button" onClick={() => onEditAddress(address)}>แก้ไข</button>
              <button type="button" aria-label="ลบที่อยู่" onClick={() => onDeleteAddress(address.id)}><Trash2 size={17} /></button>
            </article>
          ))}
        </div>
      ) : <div className="wf-empty wf-empty--compact"><MapPin size={34} strokeWidth={1.4} /><strong>ยังไม่มีที่อยู่จัดส่ง</strong></div>}

      <div className="wf-settings-list">
        <button type="button" onClick={onNotifications}>
          <span><Bell size={20} /><div><strong>การแจ้งเตือน</strong><small>{notificationsEnabled ? "เปิดแล้วสำหรับอุปกรณ์นี้" : "เปิดแจ้งเตือนสถานะออเดอร์ขณะทดสอบ"}</small></div></span>
          <ChevronRight size={18} />
        </button>
        {installPrompt ? (
          <button type="button" onClick={onInstall}>
            <span><Home size={20} /><div><strong>ติดตั้ง WYNOS Food</strong><small>เพิ่ม Developer Preview ไว้บนหน้าจอหลัก</small></div></span>
            <ChevronRight size={18} />
          </button>
        ) : null}
        <Link href="/">
          <span><ArrowLeft size={20} /><div><strong>กลับไป WYNOS</strong><small>ออกจาก WYNOS Food Developer Preview</small></div></span>
          <ChevronRight size={18} />
        </Link>
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
  const canAdd = item.is_available && storeOpen;

  return (
    <Sheet title={item.name} onClose={onClose}>
      <div className="wf-item-detail">
        <div className="wf-item-photo">
          {image ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={image} alt="" />
          ) : <UtensilsCrossed size={40} strokeWidth={1.35} />}
        </div>
        <div className="wf-item-title"><div><h3>{item.name}</h3><p>{item.description || item.category}</p></div><strong>{foodMoney(item.price)}</strong></div>
        {!item.is_available ? <div className="wf-inline-warning">เมนูนี้หมดชั่วคราว</div> : null}
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

function AddressEditor({
  draft,
  onClose,
  onSave,
  busy,
}: {
  draft: FoodAddressDraft;
  onClose: () => void;
  onSave: (draft: FoodAddressDraft) => void;
  busy: boolean;
}) {
  const [form, setForm] = useState(draft);
  return (
    <Sheet title={form.id ? "แก้ไขที่อยู่" : "เพิ่มที่อยู่"} onClose={onClose}>
      <div className="wf-form">
        <label>ชื่อที่อยู่<input value={form.label} onChange={(event) => setForm({ ...form, label: event.target.value })} placeholder="เช่น บ้าน / หอพัก" /></label>
        <label>ชื่อผู้รับ<input value={form.recipientName} onChange={(event) => setForm({ ...form, recipientName: event.target.value })} /></label>
        <label>เบอร์โทร<input inputMode="tel" value={form.recipientPhone} onChange={(event) => setForm({ ...form, recipientPhone: event.target.value })} /></label>
        <label>ที่อยู่จัดส่ง<textarea value={form.address} onChange={(event) => setForm({ ...form, address: event.target.value })} /></label>
        <label>หมายเหตุการจัดส่ง<textarea value={form.deliveryNote} onChange={(event) => setForm({ ...form, deliveryNote: event.target.value })} placeholder="เช่น โทรเมื่อถึง / ประตูสีขาว" /></label>
        <label className="wf-check"><input type="checkbox" checked={form.isDefault} onChange={(event) => setForm({ ...form, isDefault: event.target.checked })} /><span><strong>ใช้เป็นที่อยู่เริ่มต้น</strong><small>เลือกให้อัตโนมัติตอน Checkout</small></span></label>
        <button className="wf-primary wf-full" type="button" disabled={busy} onClick={() => onSave(form)}>{busy ? "กำลังบันทึก…" : "บันทึกที่อยู่"}</button>
      </div>
    </Sheet>
  );
}

function CheckoutSheet({
  store,
  menu,
  cart,
  addresses,
  busy,
  onClose,
  onAddAddress,
  onSubmit,
}: {
  store: FoodCustomerStore;
  menu: FoodCustomerMenuItem[];
  cart: FoodCartLine[];
  addresses: FoodCustomerAddress[];
  busy: boolean;
  onClose: () => void;
  onAddAddress: () => void;
  onSubmit: (address: FoodCustomerAddress, note: string) => void;
}) {
  const [addressId, setAddressId] = useState(addresses.find((address) => address.is_default)?.id ?? addresses[0]?.id ?? "");
  const [note, setNote] = useState("");
  const address = addresses.find((row) => row.id === addressId) ?? null;
  const subtotal = cart.reduce((sum, line) => {
    const item = itemFor(menu, line.menu_item_id);
    return sum + (item ? Number(item.price) * line.quantity : 0);
  }, 0);
  const total = subtotal + Number(store.delivery_fee);

  return (
    <Sheet title="Checkout" onClose={onClose}>
      <div className="wf-checkout">
        <div className="wf-section-title"><h2>จัดส่งไปที่</h2><button type="button" onClick={onAddAddress}><Plus size={15} /> เพิ่มที่อยู่</button></div>
        {addresses.length ? (
          <div className="wf-address-choice">
            {addresses.map((row) => (
              <label key={row.id} className={addressId === row.id ? "is-active" : ""}>
                <input type="radio" name="food-address" checked={addressId === row.id} onChange={() => setAddressId(row.id)} />
                <span><strong>{row.label}</strong><small>{row.recipient_name} · {row.recipient_phone}</small><p>{row.address}</p></span>
              </label>
            ))}
          </div>
        ) : <div className="wf-inline-warning">เพิ่มที่อยู่จัดส่งก่อนสั่งอาหาร</div>}

        <label className="wf-field">หมายเหตุเพิ่มเติม<textarea value={note} onChange={(event) => setNote(event.target.value)} placeholder="เช่น โทรเมื่อถึง" /></label>

        <div className="wf-section-title wf-section-title--spaced"><h2>สรุปคำสั่งซื้อ</h2></div>
        <div className="wf-checkout-items">
          {cart.map((line) => {
            const item = itemFor(menu, line.menu_item_id);
            return <div key={line.menu_item_id}><span>{line.quantity}× {item?.name ?? "เมนู"}</span><b>{item ? foodMoney(Number(item.price) * line.quantity) : "—"}</b></div>;
          })}
        </div>
        <div className="wf-summary">
          <div><span>ค่าอาหาร</span><b>{foodMoney(subtotal)}</b></div>
          <div><span>ค่าส่ง</span><b>{foodMoney(store.delivery_fee)}</b></div>
          <div className="is-total"><span>ยอดสุทธิ</span><b>{foodMoney(total)}</b></div>
        </div>
        <p className="wf-server-note">ยอดจริงจะถูกตรวจและคำนวณจากระบบอีกครั้งก่อนสร้างออเดอร์</p>
        <button className="wf-primary wf-full" type="button" disabled={!address || busy} onClick={() => { if (address) onSubmit(address, note); }}>
          {busy ? "กำลังสร้างออเดอร์…" : `ยืนยันออเดอร์ · ${foodMoney(total)}`}
        </button>
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
  onClose,
  onReload,
  onMessage,
}: {
  client: SupabaseClient;
  userId: string;
  store: FoodCustomerStore | null;
  order: FoodCustomerOrder;
  busy: boolean;
  onClose: () => void;
  onReload: () => Promise<void>;
  onMessage: (message: string) => void;
}) {
  const [slipFile, setSlipFile] = useState<File | null>(null);
  const [proofUrl, setProofUrl] = useState<string | null>(null);
  const [working, setWorking] = useState(false);
  const proof = order.food_delivery_proofs?.[0];

  useEffect(() => {
    let live = true;
    void foodPrivateSignedUrl(client, proof?.image_path).then((url) => { if (live) setProofUrl(url); });
    return () => { live = false; };
  }, [client, order.id, proof?.image_path]);

  const submitSlip = async () => {
    if (!slipFile) {
      onMessage("กรุณาเลือกรูปสลิป");
      return;
    }
    setWorking(true);
    try {
      const path = await uploadFoodPaymentSlip(client, userId, order.id, slipFile);
      await submitFoodPayment(client, order.id, path);
      onMessage("ส่งสลิปให้ร้านตรวจสอบแล้ว");
      setSlipFile(null);
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
  const paymentQr = foodPublicUrl(client, store?.payment_qr_path);
  const combinedBusy = busy || working;

  return (
    <Sheet title={`ออเดอร์ #${order.order_number}`} onClose={onClose}>
      <div className="wf-order-detail">
        <div className="wf-order-detail-head">
          <div><span className={`wf-order-status wf-order-status--${order.status}`}>{foodOrderStatusLabel(order.status)}</span><small>{formatDate(order.created_at)}</small></div>
          <strong>{foodMoney(order.total)}</strong>
        </div>

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
            <div><span>ค่าส่ง</span><b>{foodMoney(order.delivery_fee)}</b></div>
            <div className="is-total"><span>ยอดสุทธิ</span><b>{foodMoney(order.total)}</b></div>
          </div>
        </section>

        <section className="wf-order-section">
          <div className="wf-section-title"><h2>การชำระเงิน</h2><span className={`wf-payment-status wf-payment-status--${order.payment_status}`}>{foodPaymentStatusLabel(order.payment_status)}</span></div>
          {order.payment_note ? <div className="wf-inline-warning">{order.payment_note}</div> : null}
          {canPay ? (
            <div className="wf-payment">
              <p>โอนเงินเข้าบัญชีร้านโดยตรง แล้วแนบสลิปเพื่อให้ร้านยืนยัน</p>
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
              <label className="wf-upload">
                <input type="file" accept="image/jpeg,image/png,image/webp" onChange={(event) => setSlipFile(event.target.files?.[0] ?? null)} />
                <Upload size={20} /><span>{slipFile ? slipFile.name : "แนบรูปสลิป"}</span>
              </label>
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

        {canCancel ? <button className="wf-danger-link" type="button" disabled={combinedBusy} onClick={() => void cancel()}>ยกเลิกออเดอร์</button> : null}
      </div>
    </Sheet>
  );
}

function FoodCustomerInner({
  client,
  userId,
}: {
  client: SupabaseClient;
  userId: string;
}) {
  const router = useRouter();
  const [snapshot, setSnapshot] = useState<FoodCustomerSnapshot | null>(null);
  const [tab, setTab] = useState<FoodTab>("home");
  const [cart, setCart] = useState<FoodCartLine[]>(() => {
    if (typeof window === "undefined") return [];
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
  const [checkoutOpen, setCheckoutOpen] = useState(false);
  const [addressDraft, setAddressDraft] = useState<FoodAddressDraft | null>(null);
  const [message, setMessage] = useState("");
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
      const next = await fetchFoodCustomerSnapshot(client, userId);
      if (!next.developer) {
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
    localStorage.setItem(`wynos-food-cart-v1:${userId}`, JSON.stringify(cart));
  }, [cart, userId]);

  useEffect(() => {
    if (!snapshot?.developer) return;
    const channel = subscribeFoodCustomerOrders(client, userId, () => void load(true));
    return () => { void client.removeChannel(channel); };
  }, [client, load, snapshot?.developer, userId]);

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
  const store = snapshot?.store ?? null;
  const cartCount = cart.reduce((sum, line) => sum + line.quantity, 0);
  const activeCount = orders.filter((order) => !["delivered", "cancelled"].includes(order.status)).length;

  const addItem = (line: FoodCartLine) => {
    setCart((current) => {
      const exists = current.some((row) => row.menu_item_id === line.menu_item_id);
      return exists ? current.map((row) => row.menu_item_id === line.menu_item_id ? line : row) : [...current, line];
    });
    setSelectedItem(null);
    setTab("cart");
  };

  const saveAddress = async (draft: FoodAddressDraft) => {
    setBusy(true);
    try {
      await saveFoodCustomerAddress(client, draft);
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

  const createOrder = async (address: FoodCustomerAddress, note: string) => {
    if (!store) return;
    setBusy(true);
    try {
      const combinedNote = [address.delivery_note, note.trim()].filter(Boolean).join(" · ");
      const orderId = await createFoodCustomerOrder(client, store.id, {
        recipientName: address.recipient_name,
        recipientPhone: address.recipient_phone,
        shippingAddress: address.address,
        customerNote: combinedNote,
        items: cart,
      });
      setCart([]);
      setCheckoutOpen(false);
      const next = await load(true);
      const order = next?.orders.find((row) => row.id === orderId);
      if (order) setSelectedOrder(order);
      setTab("orders");
      setMessage("สร้างออเดอร์แล้ว กรุณาชำระเงินเข้าบัญชีร้าน");
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

  if (!snapshot) return <FoodLoading />;
  if (!snapshot.developer) return <FoodDenied />;

  return (
    <main className="wyn-food">
      <FoodHeader onRefresh={() => void load(true)} refreshing={refreshing} />
      {message ? <div className="wf-toast" role="status"><span>{message}</span><button type="button" aria-label="ปิด" onClick={() => setMessage("")}><X size={16} /></button></div> : null}

      <section className="wf-content">
        {tab === "home" ? <HomePanel client={client} store={store} menu={menu} onItem={setSelectedItem} /> : null}
        {tab === "orders" ? <OrdersPanel orders={orders} onOrder={setSelectedOrder} /> : null}
        {tab === "cart" ? <CartPanel store={store} menu={menu} cart={cart} onCart={setCart} onCheckout={() => setCheckoutOpen(true)} /> : null}
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
              isDefault: address.is_default,
            })}
            onDeleteAddress={(id) => void deleteAddress(id)}
            onInstall={() => void install()}
            onNotifications={() => void requestNotifications()}
          />
        ) : null}
      </section>

      <FoodNav tab={tab} cartCount={cartCount} activeCount={activeCount} onTab={setTab} />

      {selectedItem && store ? (
        <ItemSheet
          client={client}
          item={selectedItem}
          existing={cart.find((line) => line.menu_item_id === selectedItem.id) ?? null}
          storeOpen={store.is_open}
          onClose={() => setSelectedItem(null)}
          onAdd={addItem}
        />
      ) : null}

      {checkoutOpen && store ? (
        <CheckoutSheet
          store={store}
          menu={menu}
          cart={cart}
          addresses={addresses}
          busy={busy}
          onClose={() => setCheckoutOpen(false)}
          onAddAddress={() => setAddressDraft({ ...EMPTY_ADDRESS, isDefault: addresses.length === 0 })}
          onSubmit={(address, note) => void createOrder(address, note)}
        />
      ) : null}

      {addressDraft ? (
        <AddressEditor draft={addressDraft} busy={busy} onClose={() => setAddressDraft(null)} onSave={(draft) => void saveAddress(draft)} />
      ) : null}

      {selectedOrder ? (
        <OrderDetailSheet
          client={client}
          userId={userId}
          store={store}
          order={selectedOrder}
          busy={busy}
          onClose={() => setSelectedOrder(null)}
          onReload={async () => { await load(true); }}
          onMessage={setMessage}
        />
      ) : null}
    </main>
  );
}

export function WynosFoodDeveloperApp() {
  return (
    <DeveloperRouteGate>
      {({ client, userId }) => <FoodCustomerInner key={userId} client={client} userId={userId} />}
    </DeveloperRouteGate>
  );
}
