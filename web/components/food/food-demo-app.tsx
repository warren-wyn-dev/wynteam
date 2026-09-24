"use client";

import {
  ArrowLeft, ArrowRight, Bell, Check, ChevronDown, ChevronRight, Clock3, CreditCard,
  Heart, HelpCircle, Home, MapPin, MessageCircle, Minus, Plus, Search, Share2,
  ShoppingBag, SlidersHorizontal, Star, Store, TicketPercent, Trash2,
  UtensilsCrossed, UserRound, X,
} from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import {
  FOOD_ADDONS, FOOD_ADDRESSES, FOOD_CATEGORIES, FOOD_MENU, FOOD_RESTAURANTS,
  formatFoodBaht, menuFor, restaurantFor,
  type FoodCartLine, type FoodDemoOrder, type FoodMenuItem, type FoodRestaurant,
} from "@/components/food/food-demo-data";

type Screen =
  | "home" | "search" | "restaurant" | "item" | "cart" | "checkout"
  | "tracking" | "orders" | "reviews" | "profile" | "favorites"
  | "addresses" | "coupons";
type RestaurantTab = "menu" | "reviews" | "info";
type OrderFilter = "all" | "active" | "delivered";
const SPICE = ["ไม่เผ็ด", "เผ็ดน้อย", "เผ็ดกลาง", "เผ็ดมาก"];
const TRACK_STEPS = ["รอร้านรับออเดอร์", "กำลังทำอาหาร", "พร้อมจัดส่ง", "กำลังจัดส่ง", "ส่งสำเร็จ"];
const exampleOrders: FoodDemoOrder[] = [
  { id: "WF-000123", label: "ตำแซ่บเดโม่", menuIds: ["tam-pa", "tam-thai"], total: 229, date: "วันนี้ · 12:05", step: 3 },
  { id: "WF-000122", label: "ไก่ทอดเดโม่", menuIds: ["fried"], total: 69, date: "เมื่อวาน · 18:30", step: 4 },
  { id: "WF-000121", label: "ครัวเดโม่", menuIds: ["krapao", "rice"], total: 145, date: "12 ก.ย. · 12:10", step: 4 },
];
const demoCart: FoodCartLine[] = [
  { id: "sample-tam", itemId: "tam-pa", quantity: 1, spice: "เผ็ดกลาง", extras: ["pork"], note: "" },
  { id: "sample-fried", itemId: "fried", quantity: 1, spice: "", extras: [], note: "" },
];
const itemUnitPrice = (line: FoodCartLine) =>
  menuFor(line.itemId).price + line.extras.reduce((sum, id) => sum + (FOOD_ADDONS.find((addon) => addon.id === id)?.price ?? 0), 0);

function Photo({ src, emoji, alt, className = "" }: { src: string; emoji: string; alt: string; className?: string }) {
  return (
    <div className={"wfd-image-holder " + className}>
      <span className="wfd-image-fallback" aria-hidden="true">{emoji}</span>
      {/* Placeholder photography only. Live launch requires merchant-owned images. */}
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img className="wfd-photo" src={src} alt={alt} loading="lazy" onError={(event) => { event.currentTarget.style.display = "none"; }} />
    </div>
  );
}
function Rating({ value, count }: { value: number; count?: number }) {
  return <span className="wfd-rating"><Star size={12} aria-hidden="true" />{value}{count != null ? " (" + count + ")" : null}</span>;
}
function BackBar({ title, onBack, right }: { title: string; onBack: () => void; right?: React.ReactNode }) {
  return (
    <header className="wfd-topbar">
      <button type="button" className="wfd-ico" aria-label="ย้อนกลับ" onClick={onBack}><ArrowLeft size={22} /></button>
      <h1>{title}</h1>
      {right ?? <span style={{ width: 40 }} />}
    </header>
  );
}
function Summary({ subtotal, delivery, discount = 0 }: { subtotal: number; delivery: number; discount?: number }) {
  return (
    <div className="wfd-summary">
      <div className="wfd-summary-row"><span>ค่าอาหาร</span><span>{formatFoodBaht(subtotal)}</span></div>
      <div className="wfd-summary-row"><span>ค่าจัดส่ง</span><span>{formatFoodBaht(delivery)}</span></div>
      {discount > 0 ? <div className="wfd-summary-row" style={{ color: "#178054" }}><span>ส่วนลด</span><span>−{formatFoodBaht(discount)}</span></div> : null}
      <div className="wfd-summary-row wfd-summary-row--total"><span>ยอดรวม</span><b>{formatFoodBaht(Math.max(0, subtotal + delivery - discount))}</b></div>
    </div>
  );
}
export function FoodDemoApp() {
  const router = useRouter();
  const [screen, setScreen] = useState<Screen>("home");
  const [restaurantId, setRestaurantId] = useState("somtam");
  const [menuId, setMenuId] = useState("tam-pa");
  const [restaurantTab, setRestaurantTab] = useState<RestaurantTab>("menu");
  const [query, setQuery] = useState("");
  const [storeQuery, setStoreQuery] = useState("");
  const [searchType, setSearchType] = useState<"all" | "restaurants" | "menus">("all");
  const [onlyOpen, setOnlyOpen] = useState(false);
  const [sort, setSort] = useState<"nearby" | "rating" | "delivery">("nearby");
  const [spice, setSpice] = useState("เผ็ดกลาง");
  const [extras, setExtras] = useState<string[]>([]);
  const [note, setNote] = useState("");
  const [quantity, setQuantity] = useState(1);
  const [cart, setCart] = useState<FoodCartLine[]>(demoCart);
  const [favorites, setFavorites] = useState<string[]>(["somtam"]);
  const [addressId, setAddressId] = useState("dorm");
  const [returnFromAddress, setReturnFromAddress] = useState<Screen>("home");
  const [payment, setPayment] = useState<"promptpay" | "cash">("promptpay");
  const [coupon, setCoupon] = useState("");
  const [couponDraft, setCouponDraft] = useState("");
  const [orders, setOrders] = useState<FoodDemoOrder[]>(exampleOrders);
  const [activeOrderId, setActiveOrderId] = useState("WF-000123");
  const [orderFilter, setOrderFilter] = useState<OrderFilter>("all");
  const [reviewStars, setReviewStars] = useState(5);
  const [reviewNote, setReviewNote] = useState("");
  const [localReviews, setLocalReviews] = useState<{ restaurantId: string; stars: number; note: string }[]>([]);
  const [notice, setNotice] = useState("");

  const restaurant = restaurantFor(restaurantId);
  const selectedItem = menuFor(menuId);
  const address = FOOD_ADDRESSES.find((a) => a.id === addressId) ?? FOOD_ADDRESSES[0];
  const activeOrder = orders.find((order) => order.id === activeOrderId) ?? orders[0];
  const cartCount = cart.reduce((sum, line) => sum + line.quantity, 0);
  const subtotal = cart.reduce((sum, line) => sum + itemUnitPrice(line) * line.quantity, 0);
  const cartStores = FOOD_RESTAURANTS.filter((store) => cart.some((line) => menuFor(line.itemId).restaurantId === store.id));
  const delivery = cartStores.reduce((sum, store) => sum + store.deliveryFee, 0);
  const discount = coupon === "DEMO20" ? Math.min(subtotal, 20) : 0;
  const total = Math.max(0, subtotal + delivery - discount);
  const selectedExtrasPrice = extras.reduce((sum, id) => sum + (FOOD_ADDONS.find((a) => a.id === id)?.price ?? 0), 0);
  const favoritesList = FOOD_RESTAURANTS.filter((store) => favorites.includes(store.id));

  useEffect(() => {
    window.scrollTo({ top: 0, behavior: "auto" });
  }, [screen, restaurantId, menuId]);

  const results = useMemo(() => {
    const q = query.trim().toLocaleLowerCase("th-TH");
    let stores = FOOD_RESTAURANTS.filter((store) =>
      (!onlyOpen || store.open) &&
      (!q || (store.name + " " + store.category + " " + store.subtitle).toLocaleLowerCase("th-TH").includes(q))
    );
    if (sort === "rating") stores = [...stores].sort((a, b) => b.rating - a.rating);
    if (sort === "delivery") stores = [...stores].sort((a, b) => a.deliveryFee - b.deliveryFee);
    const menus = FOOD_MENU.filter((item) => (!onlyOpen || restaurantFor(item.restaurantId).open) &&
      (!q || (item.name + " " + item.description).toLocaleLowerCase("th-TH").includes(q)));
    return { stores, menus };
  }, [query, onlyOpen, sort]);

  const go = (next: Screen) => { setNotice(""); setScreen(next); };
  const openRestaurant = (id: string) => { setRestaurantId(id); setRestaurantTab("menu"); setStoreQuery(""); go("restaurant"); };
  const openItem = (id: string) => {
    setMenuId(id);
    setSpice("เผ็ดกลาง");
    setExtras([]);
    setNote("");
    setQuantity(1);
    go("item");
  };
  const openAddresses = (from: Screen) => { setReturnFromAddress(from); go("addresses"); };
  const toggleFavorite = (id: string) =>
    setFavorites((current) => current.includes(id) ? current.filter((value) => value !== id) : [...current, id]);
  const addToCart = () => {
    const itemExtras = [...extras].sort();
    const key = selectedItem.id + "|" + spice + "|" + itemExtras.join(",") + "|" + note.trim();
    setCart((current) => {
      const match = current.find((line) => line.itemId + "|" + line.spice + "|" + [...line.extras].sort().join(",") + "|" + line.note === key);
      if (match) return current.map((line) => line.id === match.id ? { ...line, quantity: line.quantity + quantity } : line);
      return [...current, { id: "demo-" + Date.now() + "-" + current.length, itemId: selectedItem.id, quantity, spice, extras: itemExtras, note: note.trim() }];
    });
    go("cart");
  };
  const changeCartQuantity = (id: string, delta: number) =>
    setCart((current) => current.map((line) => line.id === id ? { ...line, quantity: line.quantity + delta } : line).filter((line) => line.quantity > 0));
  const applyCoupon = () => {
    if (couponDraft.trim().toUpperCase() === "DEMO20") {
      setCoupon("DEMO20");
      setNotice("ใช้คูปองตัวอย่าง DEMO20 ลด ฿20 แล้ว");
    } else {
      setNotice("โหมดทดลองรองรับรหัสตัวอย่าง DEMO20 เท่านั้น");
    }
  };
  const simulateOrder = () => {
    if (!cart.length) return;
    const id = "WF-DEMO-" + Date.now().toString().slice(-6);
    const first = restaurantFor(menuFor(cart[0].itemId).restaurantId);
    const created: FoodDemoOrder = {
      id, label: cartStores.length > 1 ? first.name + " +" + (cartStores.length - 1) + " ร้าน" : first.name,
      menuIds: cart.flatMap((line) => Array(line.quantity).fill(line.itemId) as string[]),
      total, date: "เพิ่งจำลอง", step: 0,
    };
    setOrders((current) => [created, ...current]);
    setActiveOrderId(id);
    setCart([]);
    setCoupon("");
    setNotice("");
    go("tracking");
  };
  const reorder = (order: FoodDemoOrder) => {
    setCart((current) => [...current, ...order.menuIds.map((id, idx) => ({
      id: "reorder-" + Date.now() + "-" + idx,
      itemId: id, quantity: 1, spice: "เผ็ดกลาง", extras: [], note: "",
    }))]);
    go("cart");
  };
  const advanceDemo = () => setOrders((current) => current.map((order) =>
    order.id === activeOrderId ? { ...order, step: Math.min(4, order.step + 1) } : order));
  const shareRestaurant = async () => {
    const link = window.location.origin + "/food";
    try {
      if (navigator.share) await navigator.share({ title: restaurant.name + " • WYNOS Food (Demo)", url: link });
      else if (navigator.clipboard) { await navigator.clipboard.writeText(link); setNotice("คัดลอกลิงก์ตัวอย่างแล้ว"); }
      else setNotice("ระบบแชร์ยังไม่พร้อมในเบราว์เซอร์นี้");
    } catch { /* User cancelled the share sheet; no action needed. */ }
  };
  const favoriteButton = (store: FoodRestaurant) => (
    <button type="button" className="wfd-ico wfd-ico--soft"
      aria-label={favorites.includes(store.id) ? "ลบร้านออกจากร้านโปรด" : "บันทึกร้านโปรด"}
      onClick={() => toggleFavorite(store.id)}>
      <Heart size={20} fill={favorites.includes(store.id) ? "#e8293d" : "none"} color={favorites.includes(store.id) ? "#e8293d" : "currentColor"} />
    </button>
  );
  const restaurantCard = (store: FoodRestaurant) => (
    <button type="button" key={store.id} className="wfd-card" onClick={() => openRestaurant(store.id)}>
      <Photo className="wfd-card-image" src={store.image} emoji={store.emoji} alt={"ภาพตัวอย่าง " + store.name} />
      <span className="wfd-card-body">
        <strong>{store.name}</strong>
        <small>{store.category}</small>
        <span className="wfd-listing-stats"><Rating value={store.rating} count={store.reviewCount} /><small>· {store.deliveryMins} นาที</small></span>
        <small>ค่าส่ง {formatFoodBaht(store.deliveryFee)} · ขั้นต่ำ {formatFoodBaht(store.minimum)}</small>
        <span className={"wfd-open " + (!store.open ? "wfd-closed" : "")}>{store.open ? "เปิดอยู่" : "ปิดอยู่"}</span>
      </span>
    </button>
  );
  const listing = (store: FoodRestaurant) => (
    <button type="button" key={store.id} className="wfd-listing" onClick={() => openRestaurant(store.id)}>
      <Photo className="wfd-listing-image" src={store.image} emoji={store.emoji} alt={"ภาพตัวอย่าง " + store.name} />
      <span className="wfd-listing-copy">
        <strong>{store.name}</strong>
        <small>{store.category}</small>
        <span className="wfd-listing-stats"><Rating value={store.rating} count={store.reviewCount} /><small>{store.deliveryMins} นาที</small></span>
        <small>ค่าส่ง {formatFoodBaht(store.deliveryFee)} · ขั้นต่ำ {formatFoodBaht(store.minimum)}</small>
        <span className={"wfd-open " + (!store.open ? "wfd-closed" : "")}>{store.open ? "เปิดอยู่" : "ปิดอยู่"}</span>
      </span>
    </button>
  );
  const menuLine = (item: FoodMenuItem) => (
    <div className="wfd-menu-line" key={item.id}>
      <div className="wfd-menu-line-copy">
        <strong>{item.name}</strong>
        <p>{item.description}</p>
        <div className="wfd-menu-line-footer"><b>{formatFoodBaht(item.price)}</b>
          <button type="button" aria-label={"ดูรายละเอียด " + item.name} onClick={() => openItem(item.id)}><Plus size={17} /></button>
        </div>
      </div>
      <button type="button" style={{ flex: "0 0 auto", padding: 0, border: 0, background: "transparent" }} onClick={() => openItem(item.id)} aria-label={"เลือก " + item.name}>
        <Photo className="wfd-menu-line-image" src={item.image} emoji={item.emoji} alt={"ภาพตัวอย่าง " + item.name} />
      </button>
    </div>
  );
  const topCart = (
    <button className="wfd-ico" type="button" onClick={() => go("cart")} aria-label={"ตะกร้าสินค้า " + cartCount + " รายการ"}>
      <ShoppingBag size={22} />{cartCount > 0 ? <span className="wfd-notification-dot">{cartCount > 9 ? "9+" : cartCount}</span> : null}
    </button>
  );
  const navScreens: Screen[] = ["home", "search", "favorites", "orders", "profile"];
  const showNav = navScreens.includes(screen);
  const floatingCart = cart.length > 0 && ["home", "search", "restaurant", "favorites"].includes(screen);

  return (
    <div className="wfd" data-testid="wynos-food-customer-demo">
      <div className="wfd-demo-flag" role="status">● DEVELOPER PREVIEW · ข้อมูลตัวอย่าง · ยังไม่รับออเดอร์จริง</div>
      {notice ? <div role="status" style={{ margin: "8px 14px 0", padding: 11, background: "#fff4ed", borderRadius: 11, display: "flex", gap: 10, alignItems: "center", fontSize: 12, color: "#8b4724" }}><span style={{ flex: 1 }}>{notice}</span><button type="button" className="wfd-ico" onClick={() => setNotice("")} aria-label="ปิดข้อความ"><X size={16} /></button></div> : null}

      {screen === "home" ? (
        <div className="wfd-page">
          <div className="wfd-topbar wfd-topbar--between">
            <div className="wfd-brand">WYNOS <b>Food</b></div>
            <div style={{ display: "flex", alignItems: "center" }}>
              {topCart}
              <button className="wfd-ico" type="button" aria-label="คำสั่งซื้อ" onClick={() => go("orders")}><Bell size={22} /></button>
            </div>
          </div>
          <button type="button" className="wfd-location" onClick={() => openAddresses("home")}>
            <MapPin size={18} /><span>จัดส่งไปที่ <b>{address.title}</b></span><ChevronDown size={15} />
          </button>
          <button type="button" className="wfd-search wfd-search--press" onClick={() => go("search")}><Search size={18} />ค้นหาร้านอาหาร เมนู หรือเครื่องดื่ม</button>
          <div className="wfd-hero">
            <div className="wfd-hero-copy">
              <span className="wfd-hero-badge">WYNOS FOOD</span>
              <strong>อร่อยใกล้คุณ</strong>
              <small>ค้นพบร้านอร่อย ทั้งของคาวและของหวาน</small>
              <button type="button" onClick={() => go("search")} style={{ marginTop: 4, color: "#bd1734", background: "white", border: 0, borderRadius: 20, padding: "6px 12px", fontSize: 11, fontWeight: 800 }}>เลือกร้านเลย ›</button>
            </div>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={FOOD_RESTAURANTS[0].image} alt="" onError={(event) => { event.currentTarget.style.display = "none"; }} />
          </div>
          <div className="wfd-section"><h2>อยากกินอะไร?</h2><button className="wfd-link" type="button" onClick={() => go("search")}>ดูทั้งหมด ›</button></div>
          <div className="wfd-categories">
            {FOOD_CATEGORIES.map((category) => (
              <button key={category.id} type="button" className="wfd-category" onClick={() => {
                setQuery(category.id === "all" ? "" : category.id === "dessert" ? "หวาน" : category.id === "healthy" ? "ผัก" : category.id === "kitchen" ? "ข้าว" : category.label);
                setSearchType("all");
                go("search");
              }}>
                <span className="wfd-category-icon" aria-hidden="true">{category.emoji}</span><span>{category.label}</span>
              </button>
            ))}
          </div>
          <div className="wfd-section"><h2>ร้านใกล้คุณ</h2><button type="button" className="wfd-link" onClick={() => { setQuery(""); go("search"); }}>ดูทั้งหมด ›</button></div>
          <div className="wfd-featured">{FOOD_RESTAURANTS.filter((store) => store.featured).map(restaurantCard)}</div>
          <div className="wfd-section"><h2>ร้านแนะนำ</h2><span className="wfd-muted">ร้านตัวอย่าง</span></div>
          {FOOD_RESTAURANTS.filter((store) => !store.featured).map(listing)}
        </div>
      ) : null}

      {screen === "search" ? (
        <div className="wfd-page">
          <BackBar title="ค้นหาและตัวกรอง" onBack={() => go("home")} right={topCart} />
          <div className="wfd-search" style={{ marginTop: 8 }}><Search size={18} /><input aria-label="ค้นหาร้านอาหารหรือเมนู" autoFocus value={query} onChange={(event) => setQuery(event.target.value)} placeholder="ค้นหาร้านอาหารหรือเมนู..." />{query ? <button type="button" className="wfd-ico" aria-label="ล้างคำค้นหา" onClick={() => setQuery("")}><X size={17} /></button> : null}</div>
          <div className="wfd-search-controls" role="group" aria-label="ประเภทการค้นหา">
            {[["all","ทั้งหมด"],["restaurants","ร้านอาหาร"],["menus","เมนู"]].map(([value,label]) => (
              <button type="button" key={value} className={"wfd-chip " + (searchType === value ? "is-active" : "")} onClick={() => setSearchType(value as typeof searchType)}>{label}</button>
            ))}
          </div>
          <div className="wfd-search-controls" style={{ paddingTop: 0 }}>
            <button type="button" className={"wfd-chip wfd-chip--border " + (onlyOpen ? "is-active" : "")} onClick={() => setOnlyOpen(!onlyOpen)}>เปิดอยู่</button>
            <button type="button" className={"wfd-chip wfd-chip--border " + (sort === "nearby" ? "is-active" : "")} onClick={() => setSort("nearby")}>ใกล้ฉัน</button>
            <button type="button" className={"wfd-chip wfd-chip--border " + (sort === "delivery" ? "is-active" : "")} onClick={() => setSort("delivery")}>ค่าส่งน้อย</button>
            <button type="button" className={"wfd-chip wfd-chip--border " + (sort === "rating" ? "is-active" : "")} onClick={() => setSort("rating")}>คะแนนสูง</button>
            <SlidersHorizontal size={16} style={{ flex: "0 0 auto", alignSelf: "center", color: "#8c8c94" }} />
          </div>
          {searchType !== "menus" && results.stores.length > 0 ? <><div className="wfd-section" style={{ marginTop: 7 }}><h2>ร้านอาหาร ({results.stores.length})</h2></div>{results.stores.map(listing)}</> : null}
          {searchType !== "restaurants" && results.menus.length > 0 ? <><div className="wfd-section"><h2>เมนูอาหาร ({results.menus.length})</h2></div>{results.menus.map((item) => (
            <button key={item.id} type="button" className="wfd-listing" onClick={() => openItem(item.id)}>
              <Photo className="wfd-listing-image" src={item.image} emoji={item.emoji} alt={"ภาพตัวอย่าง " + item.name} />
              <span className="wfd-listing-copy"><strong>{item.name}</strong><small>{restaurantFor(item.restaurantId).name}</small><small>{item.description}</small><b style={{ color: "#e8293d", fontSize: 14 }}>{formatFoodBaht(item.price)}</b></span>
            </button>
          ))}</> : null}
          {(searchType === "restaurants" ? results.stores.length === 0 : searchType === "menus" ? results.menus.length === 0 : results.stores.length === 0 && results.menus.length === 0) ?
            <div className="wfd-empty"><Search size={44} /><strong>ไม่พบผลการค้นหา</strong><p>ลองใช้คำค้นอื่น หรือปิดตัวกรองร้านที่เปิดอยู่</p><button type="button" className="wfd-primary wfd-primary--soft" onClick={() => { setQuery(""); setOnlyOpen(false); }}>ล้างตัวกรอง</button></div> : null}
        </div>
      ) : null}

      {screen === "restaurant" ? (
        <div className="wfd-page wfd-page--flush">
          <div className="wfd-cover">
            <Photo src={restaurant.image} emoji={restaurant.emoji} alt={"ภาพตัวอย่าง " + restaurant.name} />
            <div className="wfd-cover-controls"><button type="button" className="wfd-ico" aria-label="ย้อนกลับ" onClick={() => go("search")}><ArrowLeft size={21} /></button><div className="wfd-cover-controls-group"><button type="button" className="wfd-ico" aria-label="แชร์ร้าน" onClick={() => void shareRestaurant()}><Share2 size={19} /></button>{favoriteButton(restaurant)}</div></div>
          </div>
          <div className="wfd-restaurant-sheet">
            <h1>{restaurant.name}</h1>
            <p className="wfd-muted" style={{ marginTop: 6 }}>{restaurant.category} · {restaurant.subtitle}</p>
            <div className="wfd-metadata"><Rating value={restaurant.rating} count={restaurant.reviewCount} /><span><Clock3 size={14} />{restaurant.deliveryMins} นาที</span><span>ค่าส่ง {formatFoodBaht(restaurant.deliveryFee)}</span><span className={"wfd-open " + (!restaurant.open ? "wfd-closed" : "")}>{restaurant.open ? "เปิดอยู่" : "ปิดอยู่"}</span></div>
            <div className="wfd-store-tabs" role="tablist" aria-label="ข้อมูลร้าน">
              {[["menu","เมนู"],["reviews","รีวิว"],["info","ข้อมูลร้าน"]].map(([value,label]) => <button key={value} role="tab" aria-selected={restaurantTab === value} type="button" className={restaurantTab === value ? "is-active" : ""} onClick={() => setRestaurantTab(value as RestaurantTab)}>{label}</button>)}
            </div>
            {restaurantTab === "menu" ? <>
              <label className="wfd-search" style={{ marginTop: 17 }}><Search size={16} /><input aria-label={"ค้นหาเมนูใน " + restaurant.name} placeholder="ค้นหาเมนูในร้านนี้" value={storeQuery} onChange={(event) => setStoreQuery(event.target.value)} /></label>
              <div className="wfd-section"><h2>เมนูแนะนำ</h2></div>
              <div className="wfd-menu-scroll">{FOOD_MENU.filter((item) => item.restaurantId === restaurantId && item.popular && item.name.includes(storeQuery.trim())).map((item) => (
                <button type="button" className="wfd-menu-tile" key={item.id} onClick={() => openItem(item.id)}>
                  <Photo src={item.image} emoji={item.emoji} alt={"ภาพตัวอย่าง " + item.name} />
                  <span className="wfd-menu-tile-copy"><strong>{item.name}</strong><span>{formatFoodBaht(item.price)} <Plus size={18} /></span></span>
                </button>
              ))}</div>
              <div className="wfd-section"><h2>เมนูทั้งหมด</h2></div>
              {FOOD_MENU.filter((item) => item.restaurantId === restaurantId && item.name.includes(storeQuery.trim())).map(menuLine)}
              {FOOD_MENU.filter((item) => item.restaurantId === restaurantId && item.name.includes(storeQuery.trim())).length === 0 ? <div className="wfd-empty"><Search size={34} /><strong>ไม่พบเมนูในร้านนี้</strong><button type="button" className="wfd-primary wfd-primary--soft" onClick={() => setStoreQuery("")}>ล้างคำค้น</button></div> : null}
            </> : null}
            {restaurantTab === "reviews" ? <div style={{ paddingTop: 20 }}><p style={{ fontSize: 14, marginBottom: 12 }}>คะแนนร้าน <Rating value={restaurant.rating} count={restaurant.reviewCount} /></p><button type="button" className="wfd-outline-red" onClick={() => go("reviews")}>ดูรีวิวและเขียนรีวิวตัวอย่าง <ChevronRight size={14} style={{ display: "inline" }} /></button></div> : null}
            {restaurantTab === "info" ? <div style={{ paddingTop: 20, display: "grid", gap: 12, fontSize: 13 }}><p>ประเภทอาหาร: {restaurant.category}</p><p>เวลาจัดส่งประมาณ: {restaurant.deliveryMins} นาที</p><p>ค่าส่งตัวอย่าง: {formatFoodBaht(restaurant.deliveryFee)}</p><p>ยอดขั้นต่ำ: {formatFoodBaht(restaurant.minimum)}</p><p className="wfd-muted">ข้อมูลร้านตัวอย่าง ยังไม่ใช่ร้านที่เปิดให้บริการจริง</p></div> : null}
          </div>
        </div>
      ) : null}

      {screen === "item" ? (
        <div className="wfd-page wfd-page--flush" style={{ paddingBottom: 0 }}>
          <div className="wfd-cover" style={{ height: 275 }}>
            <Photo src={selectedItem.image} emoji={selectedItem.emoji} alt={"ภาพตัวอย่าง " + selectedItem.name} />
            <div className="wfd-cover-controls"><button type="button" className="wfd-ico" aria-label="ย้อนกลับ" onClick={() => openRestaurant(selectedItem.restaurantId)}><ArrowLeft size={21} /></button></div>
          </div>
          <div className="wfd-detail-desc"><div style={{ display: "flex", alignItems: "start", justifyContent: "space-between", gap: 12 }}><h1>{selectedItem.name}</h1><b style={{ color: "#e8293d", fontSize: 21 }}>{formatFoodBaht(selectedItem.price)}</b></div><p>{selectedItem.description}</p><p>จาก {restaurantFor(selectedItem.restaurantId).name}</p></div>
          <div className="wfd-detail-form">
            {selectedItem.restaurantId !== "tea" ? <><label className="wfd-form-label">ระดับความเผ็ด <span className="wfd-muted">(เลือก 1 อย่าง)</span></label><div className="wfd-radio-list">{SPICE.map((level) => (
              <label className={"wfd-radio-row " + (spice === level ? "is-selected" : "")} key={level}><input type="radio" name="spice" checked={spice === level} onChange={() => setSpice(level)} /><span>{level}</span></label>
            ))}</div></> : null}
            <label className="wfd-form-label">เพิ่มเติม <span className="wfd-muted">(เลือกได้หลายอย่าง)</span></label>
            <div className="wfd-radio-list">{FOOD_ADDONS.map((addon) => (
              <label className={"wfd-radio-row " + (extras.includes(addon.id) ? "is-selected" : "")} key={addon.id}><input type="checkbox" checked={extras.includes(addon.id)} onChange={() => setExtras((old) => old.includes(addon.id) ? old.filter((id) => id !== addon.id) : [...old, addon.id])} /><span>{addon.label}</span><b style={{ fontSize: 12 }}>+{formatFoodBaht(addon.price)}</b></label>
            ))}</div>
            <label htmlFor="wfd-item-note" className="wfd-form-label">หมายเหตุถึงร้าน</label>
            <textarea id="wfd-item-note" className="wfd-form-note" maxLength={250} value={note} onChange={(event) => setNote(event.target.value)} placeholder="เช่น ไม่ใส่ถั่ว เพิ่มผัก..." />
          </div>
          <div className="wfd-bottom-cta">
            <div className="wfd-qty"><button type="button" aria-label="ลดจำนวน" disabled={quantity <= 1} onClick={() => setQuantity(Math.max(1, quantity - 1))}><Minus size={17} /></button>{quantity}<button type="button" aria-label="เพิ่มจำนวน" disabled={quantity >= 20} onClick={() => setQuantity(Math.min(20, quantity + 1))}><Plus size={17} /></button></div>
            <button type="button" className="wfd-primary" onClick={addToCart}>เพิ่มลงตะกร้า · {formatFoodBaht((selectedItem.price + selectedExtrasPrice) * quantity)}</button>
          </div>
        </div>
      ) : null}

      {screen === "cart" ? (
        <div className="wfd-page">
          <BackBar title={"ตะกร้าสินค้า (" + cartStores.length + " ร้าน)"} onBack={() => go("home")} right={<button type="button" className="wfd-ico" aria-label="ล้างตะกร้า" onClick={() => setCart([])} disabled={!cart.length}><Trash2 size={19} /></button>} />
          {!cart.length ? <div className="wfd-empty"><ShoppingBag size={45} /><strong>ตะกร้ายังว่างอยู่</strong><p>ลองเลือกร้านและเพิ่มเมนูที่ชอบ</p><button type="button" className="wfd-primary" onClick={() => go("home")}>เลือกร้านอาหาร</button></div> :
            <>
              {cartStores.map((store) => {
                const lines = cart.filter((line) => menuFor(line.itemId).restaurantId === store.id);
                const storeSubtotal = lines.reduce((sum, line) => sum + line.quantity * itemUnitPrice(line), 0);
                return <section key={store.id} className="wfd-cart-group">
                  <h2><Store size={17} color="#e8293d" />{store.name}</h2>
                  {lines.map((line) => {
                    const item = menuFor(line.itemId);
                    return <div key={line.id} className="wfd-cart-row">
                      <Photo className="wfd-cart-row-img" src={item.image} emoji={item.emoji} alt={"ภาพตัวอย่าง " + item.name} />
                      <div className="wfd-cart-copy"><strong>{item.name}</strong><small>{[line.spice, ...line.extras.map((id) => FOOD_ADDONS.find((addon) => addon.id === id)?.label ?? "")].filter(Boolean).join(" · ") || "สูตรปกติ"}</small><small>{line.note}</small><div className="wfd-cart-actions"><b style={{ fontSize: 14 }}>{formatFoodBaht(itemUnitPrice(line) * line.quantity)}</b><div className="wfd-qty"><button type="button" aria-label={"ลด " + item.name} onClick={() => changeCartQuantity(line.id, -1)}><Minus size={14} /></button>{line.quantity}<button type="button" aria-label={"เพิ่ม " + item.name} onClick={() => changeCartQuantity(line.id, 1)}><Plus size={14} /></button></div></div></div>
                    </div>;
                  })}
                  <button type="button" className="wfd-link" onClick={() => openRestaurant(store.id)}>+ เพิ่มเมนูจากร้านนี้</button>
                  <div className="wfd-summary-row" style={{ borderTop: "1px solid #eee", paddingTop: 11 }}><span>ยอดร้านนี้</span><b>{formatFoodBaht(storeSubtotal)}</b></div>
                </section>;
              })}
              <Summary subtotal={subtotal} delivery={delivery} />
              <p className="wfd-muted" style={{ margin: "12px 0" }}>ตะกร้าหลายร้านเป็นตัวอย่าง UX เท่านั้น ยังไม่มีการส่งคำสั่งซื้อจริง</p>
              <button type="button" className="wfd-primary wfd-primary--wide" onClick={() => go("checkout")}>ไปชำระเงิน · {formatFoodBaht(subtotal + delivery)}</button>
            </>}
        </div>
      ) : null}

      {screen === "checkout" ? (
        <div className="wfd-page">
          <BackBar title="ชำระเงิน (ทดลอง)" onBack={() => go("cart")} />
          <section className="wfd-checkout-box">
            <h2>ที่อยู่จัดส่ง <button type="button" className="wfd-link" onClick={() => openAddresses("checkout")}>แก้ไข</button></h2>
            <p style={{ fontWeight: 800, color: "#282a2f", marginBottom: 6 }}><MapPin size={15} style={{ display: "inline", color: "#e8293d" }} /> {address.title}</p>
            <p>{address.detail}</p>
          </section>
          <section className="wfd-checkout-box"><h2>วิธีชำระเงิน</h2>
            <label className={"wfd-radio-row " + (payment === "promptpay" ? "is-selected" : "")}><input type="radio" checked={payment === "promptpay"} onChange={() => setPayment("promptpay")} /><span>PromptPay (ตัวอย่าง QR เท่านั้น)</span><CreditCard size={19} color="#2266c6" /></label>
            <label className={"wfd-radio-row " + (payment === "cash" ? "is-selected" : "")}><input type="radio" checked={payment === "cash"} onChange={() => setPayment("cash")} /><span>เงินสด (จำลอง)</span></label>
            <label className="wfd-radio-row" style={{ opacity: .5 }}><input type="radio" disabled /><span>บัตรเครดิต (ยังไม่เชื่อมต่อ)</span></label>
          </section>
          <section className="wfd-checkout-box"><h2>คูปองส่วนลด <TicketPercent size={20} color="#e8293d" /></h2>
            <div style={{ display: "flex", gap: 8 }}><input className="wfd-text-field" aria-label="รหัสคูปอง" value={couponDraft} onChange={(event) => setCouponDraft(event.target.value)} placeholder="ลองใส่ DEMO20" /><button type="button" className="wfd-outline-red" onClick={applyCoupon}>ใช้</button></div>
            {coupon ? <p style={{ color: "#16814b", marginTop: 8 }}>ใช้คูปอง {coupon} แล้ว</p> : null}
          </section>
          <section className="wfd-checkout-box"><h2>สรุปคำสั่งซื้อ</h2>
            {cartStores.map((store) => <p key={store.id} style={{ padding: "6px 0" }}><b>{store.name}</b> · {cart.filter((line) => menuFor(line.itemId).restaurantId === store.id).reduce((sum, line) => sum + line.quantity, 0)} รายการ</p>)}
            <Summary subtotal={subtotal} delivery={delivery} discount={discount} />
          </section>
          <p className="wfd-muted" style={{ margin: "16px 0" }}>การกดปุ่มจะสร้างข้อมูลคำสั่งซื้อจำลองในเบราว์เซอร์นี้เท่านั้น ไม่เรียก API ร้านค้าและไม่เก็บเงินจริง</p>
          <button className="wfd-primary wfd-primary--wide" type="button" disabled={!cart.length} onClick={simulateOrder}>จำลองการสั่งซื้อ · {formatFoodBaht(total)}</button>
        </div>
      ) : null}

      {screen === "tracking" ? (
        <div className="wfd-page">
          <BackBar title={"คำสั่งซื้อ #" + activeOrder.id} onBack={() => go("orders")} />
          <div className="wfd-checkout-box" style={{ display: "flex", alignItems: "center", gap: 11 }}>
            <Photo className="wfd-cart-row-img" src={FOOD_RESTAURANTS[0].image} emoji="🥗" alt="ภาพตัวอย่างคำสั่งซื้อ" />
            <div><strong>{activeOrder.label}</strong><p style={{ marginTop: 6 }}>ประมาณ 25–35 นาที (ข้อมูลตัวอย่าง)</p></div>
          </div>
          <div className="wfd-section"><h2>สถานะคำสั่งซื้อ</h2><span className="wfd-inline-demo">จำลอง</span></div>
          <div className="wfd-tracking">{TRACK_STEPS.map((label, index) => <div className={"wfd-track-step " + (index <= activeOrder.step ? "is-done" : "")} key={label}><span className="wfd-track-dot">{index <= activeOrder.step ? <Check size={13} /> : null}</span><span className="wfd-track-copy">{label}<small>{index === activeOrder.step ? "สถานะล่าสุด (จำลอง)" : index < activeOrder.step ? "เสร็จสิ้น (จำลอง)" : "ยังไม่ถึงขั้นตอนนี้"}</small></span></div>)}</div>
          <div className="wfd-map" role="img" aria-label="ภาพจำลองเส้นทางจัดส่ง ไม่ใช่ GPS จริง"><span className="wfd-map-pin wfd-map-pin--a">🏪 ร้านอาหาร</span><span className="wfd-map-pin wfd-map-pin--b">📍 จุดจัดส่ง</span></div>
          <p className="wfd-muted">แผนที่และสถานะข้างบนเป็นตัวอย่าง ยังไม่มีการติดตามไรเดอร์แบบเรียลไทม์</p>
          <button type="button" style={{ marginTop: 15 }} className="wfd-primary wfd-primary--wide" disabled={activeOrder.step === 4} onClick={advanceDemo}>จำลองสถานะถัดไป <ArrowRight size={17} style={{ display: "inline" }} /></button>
          <button type="button" style={{ marginTop: 12 }} className="wfd-primary wfd-primary--soft wfd-primary--wide" onClick={() => router.push("/chat")}><MessageCircle size={17} style={{ display: "inline" }} /> ไปยังแชท WYNOS</button>
        </div>
      ) : null}

      {screen === "orders" ? (
        <div className="wfd-page">
          <BackBar title="ประวัติการสั่งซื้อ" onBack={() => go("home")} />
          <div className="wfd-search-controls" role="group" aria-label="กรองคำสั่งซื้อ">
            {[["all","ทั้งหมด"],["active","กำลังดำเนินการ"],["delivered","สำเร็จ"]].map(([value,label]) => <button type="button" key={value} className={"wfd-chip " + (orderFilter === value ? "is-active" : "")} onClick={() => setOrderFilter(value as OrderFilter)}>{label}</button>)}
          </div>
          {orders.filter((order) => orderFilter === "all" || (orderFilter === "active" ? order.step < 4 : order.step === 4)).map((order) => (
            <div className="wfd-order-card" key={order.id}>
              <div className="wfd-order-card-top"><Photo src={menuFor(order.menuIds[0]).image} emoji={menuFor(order.menuIds[0]).emoji} alt="ภาพอาหารตัวอย่าง" /><div><strong>#{order.id}</strong><small>{order.label}</small><small>{order.date}</small></div><span className={"wfd-open " + (order.step === 4 ? "" : "wfd-closed")}>{order.step === 4 ? "ส่งสำเร็จ" : "กำลังดำเนินการ"}</span></div>
              <div className="wfd-order-card-footer"><b>{formatFoodBaht(order.total)}</b><div style={{ display: "flex", gap: 7 }}><button type="button" className="wfd-outline-red" onClick={() => reorder(order)}>สั่งอีกครั้ง</button><button type="button" className="wfd-outline-red" onClick={() => { setActiveOrderId(order.id); go("tracking"); }}>ดูสถานะ</button></div></div>
            </div>
          ))}
          {orders.filter((order) => orderFilter === "all" || (orderFilter === "active" ? order.step < 4 : order.step === 4)).length === 0 ? <div className="wfd-empty"><ShoppingBag size={42} /><strong>ไม่มีคำสั่งซื้อในหมวดนี้</strong></div> : null}
        </div>
      ) : null}

      {screen === "reviews" ? (
        <div className="wfd-page wfd-page--flush">
          <div className="wfd-cover" style={{ height: 197 }}><Photo src={restaurant.image} emoji={restaurant.emoji} alt={"ภาพร้านตัวอย่าง " + restaurant.name} /><div className="wfd-cover-controls"><button type="button" className="wfd-ico" aria-label="ย้อนกลับ" onClick={() => openRestaurant(restaurantId)}><ArrowLeft size={21} /></button></div></div>
          <div style={{ padding: "18px" }}><h1 className="wfd-page-title">{restaurant.name}</h1><p className="wfd-muted" style={{ marginTop: 5 }}>รีวิวและคะแนน (ข้อมูลตัวอย่าง)</p>
            <div style={{ display: "flex", gap: 20, marginTop: 21, alignItems: "center" }}><div><strong className="wfd-review-score">{restaurant.rating}</strong><div className="wfd-stars">★★★★★</div><small className="wfd-muted">{restaurant.reviewCount} รีวิวตัวอย่าง</small></div><div style={{ flex: 1 }}>{[70,20,7,2,1].map((width,index) => <div className="wfd-rating-bar" key={index}><span>{5-index}</span><div><i style={{ width: width + "%" }} /></div><span>{width}%</span></div>)}</div></div>
            <div className="wfd-section"><h2>เขียนรีวิวตัวอย่าง</h2></div>
            <div className="wfd-stars">{[1,2,3,4,5].map((stars) => <button key={stars} type="button" aria-label={"ให้ " + stars + " ดาว"} onClick={() => setReviewStars(stars)}><Star fill={stars <= reviewStars ? "#f4a721" : "none"} color="#f4a721" size={25} /></button>)}</div>
            <textarea className="wfd-form-note" aria-label="เขียนรีวิว" style={{ marginTop: 9 }} maxLength={300} value={reviewNote} onChange={(event) => setReviewNote(event.target.value)} placeholder="เมนูนี้เป็นอย่างไรบ้าง..." />
            <button type="button" className="wfd-primary wfd-primary--soft" style={{ marginTop: 10 }} disabled={!reviewNote.trim()} onClick={() => { setLocalReviews((current) => [{restaurantId,stars:reviewStars,note:reviewNote.trim()},...current]);setReviewNote("");setNotice("บันทึกรีวิวตัวอย่างในเบราว์เซอร์แล้ว"); }}>ส่งรีวิวตัวอย่าง</button>
            <div className="wfd-section"><h2>รีวิวจากลูกค้า</h2></div>
            {localReviews.filter((review) => review.restaurantId === restaurantId).map((review,index) => <div className="wfd-review-card" key={index}><b>นักพัฒนา (ตัวอย่าง)</b><p style={{ color: "#f3aa20", margin: "6px 0" }}>{"★".repeat(review.stars)}</p><p>{review.note}</p></div>)}
            {[{name:"Natcha",rating:5,note:"อร่อยมาก ส่งไว คุ้มราคา"},{name:"WYNOS User",rating:4,note:"อาหารรสชาติดี แพ็กเกจเรียบร้อย"}].map((review) => <div className="wfd-review-card" key={review.name}><b>{review.name}</b><p style={{ color: "#f3aa20", margin: "6px 0" }}>{"★".repeat(review.rating)}</p><p>{review.note}</p><small>รีวิวจำลอง</small></div>)}
          </div>
        </div>
      ) : null}

      {screen === "favorites" ? (
        <div className="wfd-page"><BackBar title="ร้านโปรด" onBack={() => go("home")} /><p className="wfd-muted" style={{ margin: "9px 0 17px" }}>บันทึกร้านที่ชอบไว้ในโหมดทดลอง</p>
          {favoritesList.length ? favoritesList.map(listing) : <div className="wfd-empty"><Heart size={44} /><strong>ยังไม่มีร้านโปรด</strong><p>กดรูปหัวใจบนหน้าร้านเพื่อบันทึก</p><button className="wfd-primary" type="button" onClick={() => go("home")}>ค้นหาร้านอาหาร</button></div>}
        </div>
      ) : null}

      {screen === "addresses" ? (
        <div className="wfd-page"><BackBar title="ที่อยู่จัดส่ง" onBack={() => go(returnFromAddress)} /><p className="wfd-muted" style={{ margin: "9px 0 19px" }}>ตัวเลือกตัวอย่าง ยังไม่มีการคำนวณระยะทาง GPS จริง</p><div className="wfd-radio-list">{FOOD_ADDRESSES.map((entry) => <label key={entry.id} className={"wfd-radio-row " + (addressId === entry.id ? "is-selected" : "")} style={{ padding: 15 }}><input type="radio" name="delivery-address" checked={addressId === entry.id} onChange={() => { setAddressId(entry.id); go(returnFromAddress); }} /><span><b>{entry.title}</b><small style={{ display: "block", marginTop: 5, color: "#7b808a", fontSize: 11 }}>{entry.detail}</small></span></label>)}</div></div>
      ) : null}

      {screen === "coupons" ? (
        <div className="wfd-page"><BackBar title="คูปองส่วนลด" onBack={() => go("profile")} /><div className="wfd-checkout-box" style={{ borderColor: "#efbbc2", background: "#fff4f5" }}><div style={{ display: "flex", gap: 12, alignItems: "center" }}><TicketPercent size={36} color="#e8293d" /><div><b>ทดลองลด ฿20</b><p style={{ marginTop: 6 }}>ใช้ได้กับตะกร้าตัวอย่าง รหัส DEMO20</p></div></div><button type="button" className="wfd-primary wfd-primary--wide" style={{ marginTop: 14 }} onClick={() => { setCouponDraft("DEMO20"); setCoupon("DEMO20"); go("cart"); }}>เก็บคูปองและไปตะกร้า</button></div></div>
      ) : null}

      {screen === "profile" ? (
        <div className="wfd-page"><BackBar title="โปรไฟล์และตั้งค่า" onBack={() => go("home")} />
          <div className="wfd-profile-avatar" aria-hidden="true">👤</div><h2 className="wfd-profile-name">ผู้ใช้ WYNOS</h2><p className="wfd-profile-sub">เชื่อมกับบัญชี WYNOS Social · โหมดทดลอง</p>
          {[
            { title: "ที่อยู่จัดส่ง",icon:MapPin,action:() => openAddresses("profile"),detail:address.title },
            { title: "ร้านโปรด",icon:Heart,action:() => go("favorites"),detail:favorites.length + " ร้าน" },
            { title: "เมนูโปรด",icon:UtensilsCrossed,action:() => go("favorites"),detail:"ดูร้านโปรด" },
            { title: "คูปองของฉัน",icon:TicketPercent,action:() => go("coupons"),detail:"1 ใบตัวอย่าง" },
            { title: "ประวัติการสั่งซื้อ",icon:ShoppingBag,action:() => go("orders"),detail:orders.length + " รายการ" },
            { title: "วิธีการชำระเงิน",icon:CreditCard,action:() => setNotice("วิธีชำระเงินจริงจะเปิดเมื่อระบบ Food พร้อมให้บริการ"),detail:"กำลังพัฒนา" },
            { title: "การแจ้งเตือน",icon:Bell,action:() => setNotice("การแจ้งเตือน Food จริงยังไม่เปิดใช้งาน"),detail:"กำลังพัฒนา" },
            { title: "ศูนย์ช่วยเหลือ",icon:HelpCircle,action:() => setNotice("ศูนย์ช่วยเหลือ Food จะพัฒนาภายหลัง"),detail:"กำลังพัฒนา" },
          ].map((row) => <button key={row.title} type="button" className="wfd-profile-row" onClick={row.action}><row.icon size={19}/><span>{row.title}</span><small>{row.detail}</small><ChevronRight size={18}/></button>)}
          <button type="button" className="wfd-primary wfd-primary--soft wfd-primary--wide" style={{ marginTop: 21 }} onClick={() => router.push("/")}>กลับไปยัง WYNOS Social <ArrowRight size={17} style={{ display: "inline" }} /></button>
        </div>
      ) : null}

      {floatingCart ? <button type="button" className="wfd-floating-cart" aria-label={"เปิดตะกร้าสินค้า " + cartCount + " รายการ"} onClick={() => go("cart")}><ShoppingBag size={19}/><span>ดูตะกร้า ({cartCount})</span><b>{formatFoodBaht(subtotal + delivery)}</b><ChevronRight size={18}/></button> : null}
      {showNav ? <nav className="wfd-nav" aria-label="เมนู WYNOS Food">
        <button type="button" className={screen === "home" ? "is-active" : ""} onClick={() => go("home")}><Home size={22} fill={screen === "home" ? "#e8293d" : "none"}/>หน้าหลัก</button>
        <button type="button" className={screen === "favorites" ? "is-active" : ""} onClick={() => go("favorites")}><Heart size={22} fill={screen === "favorites" ? "#e8293d" : "none"}/>ร้านโปรด</button>
        <button type="button" className="wfd-nav-center" onClick={() => go("home")}><span><UtensilsCrossed size={21}/></span>Food</button>
        <button type="button" onClick={() => router.push("/chat")}><MessageCircle size={22}/>แชท</button>
        <button type="button" className={screen === "profile" ? "is-active" : ""} onClick={() => go("profile")}><UserRound size={22} fill={screen === "profile" ? "#e8293d" : "none"}/>โปรไฟล์</button>
      </nav> : null}
    </div>
  );
}
