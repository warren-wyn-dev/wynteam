"use client";

import { ArrowLeft, ChevronRight, MapPin, Minus, Plus, Search, ShoppingBag, Store, UtensilsCrossed, X } from "lucide-react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { useEffect, useMemo, useState } from "react";

import { foodCartLineKey, foodCartLineOptionsValid, foodCartLineUnitPrice, foodMoney, foodPublicUrl, type FoodCartLine, type FoodMenuOptionGroup } from "@/lib/food-customer";
import { rememberSharedFoodStore, sharedFoodStoreId } from "@/lib/food-share";

export const GUEST_BASKET_KEY = "wynos-food-guest-basket-v1";

type GuestMenuItem = {
  id: string;
  store_id: string;
  category: string;
  name: string;
  description: string | null;
  price: number | string;
  image_path: string | null;
  options: FoodMenuOptionGroup[];
  sold_out_until: string | null;
  daily_stock_limit: number | null;
};

type GuestStore = {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  address: string | null;
  cover_path: string | null;
  logo_path: string | null;
  delivery_fee: number | string;
  is_open: boolean;
  menu: GuestMenuItem[];
};

export type GuestBasket = { storeId: string; lines: FoodCartLine[] };

export function readGuestFoodBasket(): GuestBasket | null {
  if (typeof window === "undefined") return null;
  let value: string | null = null;
  try { value = sessionStorage.getItem(GUEST_BASKET_KEY); } catch { /* private mode */ }
  if (!value) {
    try { value = localStorage.getItem(GUEST_BASKET_KEY); } catch { /* private mode */ }
  }
  if (!value) return null;
  try {
    const parsed: unknown = JSON.parse(value);
    if (!parsed || typeof parsed !== "object") return null;
    const basket = parsed as GuestBasket;
    if (!/^[0-9a-f-]{36}$/i.test(basket.storeId) || !Array.isArray(basket.lines)) return null;
    return {
      storeId: basket.storeId,
      lines: basket.lines.slice(0, 50).filter((line) => (
        line && typeof line.menu_item_id === "string"
        && Number.isSafeInteger(line.quantity) && line.quantity > 0 && line.quantity <= 99
        && typeof line.note === "string"
        && (!line.selected_options || Array.isArray(line.selected_options))
      )),
    };
  } catch {
    return null;
  }
}

export function clearGuestFoodBasket() {
  try { sessionStorage.removeItem(GUEST_BASKET_KEY); } catch { /* private mode */ }
  try { localStorage.removeItem(GUEST_BASKET_KEY); } catch { /* private mode */ }
}

function saveGuestFoodBasket(basket: GuestBasket) {
  const serialized = JSON.stringify(basket);
  try { sessionStorage.setItem(GUEST_BASKET_KEY, serialized); return; } catch { /* private mode */ }
  try { localStorage.setItem(GUEST_BASKET_KEY, serialized); } catch { /* private mode */ }
}

function available(item: GuestMenuItem) {
  if (item.daily_stock_limit != null && Number(item.daily_stock_limit) <= 0) return false;
  return !item.sold_out_until || Date.parse(item.sold_out_until) <= Date.now();
}

/** The only anonymous RPC reads published storefront/catalog fields.
 * Never use an anonymous session to call private order, quote, or payment endpoints.
 */
export function FoodGuestBrowse({ client }: { client: SupabaseClient }) {
  const [stores, setStores] = useState<GuestStore[] | null>(null);
  const [error, setError] = useState("");
  const [query, setQuery] = useState("");
  const [selectedId, setSelectedId] = useState<string | null>(() => {
    if (typeof window === "undefined") return null;
    return sharedFoodStoreId(window.location.search);
  });
  const [basket, setBasket] = useState<GuestBasket | null>(() => readGuestFoodBasket());
  const [selectedItem, setSelectedItem] = useState<GuestMenuItem | null>(null);
  const [chosen, setChosen] = useState<Record<string, string[]>>({});
  const [qty, setQty] = useState(1);
  const [note, setNote] = useState("");
  const [showBasket, setShowBasket] = useState(false);

  useEffect(() => {
    let live = true;
    void client.rpc("food_public_catalog").then(({ data, error: rpcError }) => {
      if (!live) return;
      if (rpcError || !Array.isArray(data)) {
        setError("โหลดร้านอาหารไม่สำเร็จ กรุณาลองอีกครั้ง");
        setStores([]);
        return;
      }
      setStores(data as GuestStore[]);
    }).catch(() => {
      if (!live) return;
      setError("โหลดร้านอาหารไม่สำเร็จ กรุณาลองอีกครั้ง");
      setStores([]);
    });
    return () => { live = false; };
  }, [client]);

  const store = stores?.find((entry) => entry.id === selectedId) ?? null;
  const filtered = useMemo(() => (stores ?? []).filter((entry) => (
    !query.trim()
    || entry.name.toLocaleLowerCase("th").includes(query.toLocaleLowerCase("th").trim())
    || entry.menu.some((item) => item.name.toLocaleLowerCase("th").includes(query.toLocaleLowerCase("th").trim()))
  )), [stores, query]);

  const basketStore = stores?.find((entry) => entry.id === basket?.storeId);
  const subtotal = basket?.lines.reduce((sum, line) => {
    const menu = basketStore?.menu.find((item) => item.id === line.menu_item_id);
    return sum + (menu ? foodCartLineUnitPrice(menu, line) * line.quantity : 0);
  }, 0) ?? 0;
  const cartCount = basket?.lines.reduce((sum, line) => sum + line.quantity, 0) ?? 0;

  const pickStore = (next: GuestStore) => {
    if (basket && basket.lines.length > 0 && basket.storeId !== next.id) {
      if (!window.confirm("เปลี่ยนร้านอาหารและล้างตะกร้าเดิม?")) return;
      setBasket(null);
      clearGuestFoodBasket();
    }
    setSelectedId(next.id);
    rememberSharedFoodStore(next.id);
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const showItem = (item: GuestMenuItem) => {
    if (!store || !available(item) || !store.is_open) return;
    setSelectedItem(item);
    setChosen({});
    setNote("");
    setQty(1);
  };

  const addItem = () => {
    if (!selectedItem || !store) return;
    const options = (selectedItem.options ?? []).flatMap((group) => (
      (chosen[group.id] ?? []).map((choiceId) => {
        const choice = group.choices.find((row) => row.id === choiceId);
        return {
          group_id: group.id,
          group_name: group.name,
          choice_id: choiceId,
          choice_name: choice?.name ?? "",
          price: choice?.price ?? 0,
        };
      })
    ));
    const line: FoodCartLine = { menu_item_id: selectedItem.id, quantity: qty, note: note.trim(), selected_options: options };
    if (!foodCartLineOptionsValid(selectedItem, line)) return;
    const existing = basket?.storeId === store.id ? basket.lines : [];
    const key = foodCartLineKey(line);
    const found = existing.findIndex((value) => foodCartLineKey(value) === key);
    const lines = [...existing];
    if (found >= 0) lines[found] = { ...lines[found], quantity: Math.min(99, lines[found].quantity + qty) };
    else lines.push(line);
    const next = { storeId: store.id, lines };
    setBasket(next);
    saveGuestFoodBasket(next);
    setSelectedItem(null);
  };

  const updateQty = (index: number, delta: number) => {
    if (!basket) return;
    const nextLines = basket.lines.map((line, i) => i === index ? { ...line, quantity: Math.max(0, Math.min(99, line.quantity + delta)) } : line).filter((line) => line.quantity > 0);
    const next = { ...basket, lines: nextLines };
    setBasket(nextLines.length ? next : null);
    if (nextLines.length) saveGuestFoodBasket(next);
    else clearGuestFoodBasket();
  };

  const signInForOrder = () => {
    if (basket?.storeId) {
      saveGuestFoodBasket(basket);
      rememberSharedFoodStore(basket.storeId);
    } else if (store?.id) {
      rememberSharedFoodStore(store.id);
    }
    // The Food login screen returns to /food, which imports this basket into
    // the authenticated user's existing order/cart state.
    window.location.assign("/food/login");
  };

  const toggleChoice = (group: FoodMenuOptionGroup, choiceId: string) => {
    setChosen((current) => {
      const before = current[group.id] ?? [];
      const chosenIds = before.includes(choiceId)
        ? before.filter((entry) => entry !== choiceId)
        : Number(group.max_select ?? 1) <= 1
          ? [choiceId]
          : before.length >= Math.min(20, Number(group.max_select ?? 1))
            ? before
            : [...before, choiceId];
      return { ...current, [group.id]: chosenIds };
    });
  };

  return (
    <main className="wyn-food wf-guest">
      <header className="wf-guest-header">
        <div className="wf-guest-brand"><UtensilsCrossed size={22} /><strong>WYNOS Food</strong></div>
        <a href="/food/login" className="wf-guest-login">เข้าสู่ระบบ</a>
      </header>

      <section className="wf-guest-intro">
        <span className="wf-guest-tag"><MapPin size={14} /> ให้บริการในพื้นที่มหาสารคาม</span>
        <h1>เลือกอาหารที่อยากกินได้เลย</h1>
        <p>ดูร้านและเมนูได้ทันที ไม่ต้องล็อกอินหรือเปิด GPS ตรวจสอบพื้นที่จัดส่งเมื่อสั่งซื้อจริง</p>
      </section>

      {store ? (
        <section className="wf-guest-shop">
          <button type="button" className="wf-guest-back" onClick={() => { setSelectedId(null); setShowBasket(false); }}>
            <ArrowLeft size={18} /> ดูร้านทั้งหมด
          </button>
          {store.cover_path && <div className="wf-guest-cover">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={foodPublicUrl(client, store.cover_path) ?? ""} alt="" />
          </div>}
          <div className="wf-guest-shop-head">
            <h2>{store.name}</h2>
            <span className={store.is_open ? "wf-guest-open" : "wf-guest-closed"}>{store.is_open ? "เปิดรับออเดอร์" : "ร้านปิดอยู่"}</span>
          </div>
          <p className="wf-guest-secondary">{store.description ?? ""}</p>
          <p className="wf-guest-secondary">ค่าจัดส่งเริ่มต้น {foodMoney(store.delivery_fee)} · ตรวจสอบพื้นที่ตอนสั่งซื้อ</p>
          {[...new Set(store.menu.map((item) => item.category))].map((category) => (
            <div key={category}>
              <h3 className="wf-guest-category">{category}</h3>
              <div className="wf-guest-items">
                {store.menu.filter((item) => item.category === category).map((item) => (
                  <button key={item.id} type="button" className="wf-guest-item" onClick={() => showItem(item)} disabled={!store.is_open || !available(item)}>
                    {item.image_path ? <span className="wf-guest-item-photo">
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img src={foodPublicUrl(client, item.image_path) ?? ""} alt="" loading="lazy" />
                    </span> : <span className="wf-guest-item-photo"><UtensilsCrossed size={25}/></span>}
                    <span className="wf-guest-item-info"><strong>{item.name}</strong>{item.description && <small>{item.description}</small>}<b>{foodMoney(item.price)}</b></span>
                    <span className="wf-guest-add">{store.is_open && available(item) ? <Plus size={17} /> : "หมด"}</span>
                  </button>
                ))}
              </div>
            </div>
          ))}
          {!store.menu.length && <p className="wf-guest-empty">ร้านนี้ยังไม่มีเมนูที่พร้อมขาย</p>}
        </section>
      ) : (
        <section className="wf-guest-shops">
          <div className="wf-guest-search"><Search size={19}/><input type="search" value={query} onChange={(e) => setQuery(e.target.value)} placeholder="ค้นหาร้านหรือชื่ออาหาร" aria-label="ค้นหาร้านหรือชื่ออาหาร"/></div>
          <h2>ร้านอาหารที่เปิดเผยแพร่</h2>
          {stores === null && <p className="wf-guest-empty">กำลังโหลดร้านอาหาร…</p>}
          {error && <p role="alert" className="wf-guest-empty">{error}</p>}
          {stores && !filtered.length && <p className="wf-guest-empty">ยังไม่พบร้านอาหารที่ตรงกับการค้นหา</p>}
          <div className="wf-guest-shop-list">
            {filtered.map((entry) => (
              <button type="button" className="wf-guest-shop-card" key={entry.id} onClick={() => pickStore(entry)}>
                {entry.cover_path ? <span className="wf-guest-shop-photo">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={foodPublicUrl(client, entry.cover_path) ?? ""} alt="" loading="lazy"/>
                </span> : <span className="wf-guest-shop-photo"><Store size={27}/></span>}
                <span className="wf-guest-shop-details"><strong>{entry.name}</strong><small>{entry.menu.length} เมนู · ค่าส่งเริ่มต้น {foodMoney(entry.delivery_fee)}</small><small>{entry.is_open ? "เปิดรับออเดอร์" : "ร้านปิดอยู่"}</small></span>
                <ChevronRight size={18}/>
              </button>
            ))}
          </div>
        </section>
      )}

      {cartCount > 0 && <div className="wf-guest-cartbar">
        <button type="button" onClick={() => setShowBasket(true)}><ShoppingBag size={19}/> ดูตะกร้า ({cartCount}) <b>{foodMoney(subtotal)}</b></button>
      </div>}

      {selectedItem && (
        <div className="wf-guest-overlay" role="presentation">
          <section className="wf-guest-sheet" role="dialog" aria-modal="true" aria-label={selectedItem.name}>
            <button type="button" className="wf-guest-close" aria-label="ปิด" onClick={() => setSelectedItem(null)}><X size={21}/></button>
            <h2>{selectedItem.name}</h2>
            <p>{selectedItem.description}</p>
            <strong>{foodMoney(selectedItem.price)}</strong>
            {(selectedItem.options ?? []).map((group) => (
              <fieldset key={group.id} className="wf-guest-options">
                <legend>{group.name} {group.required ? "(จำเป็น)" : "(ไม่จำเป็น)"}</legend>
                {group.choices.map((choice) => (
                  <label key={choice.id}>
                    <input type={group.max_select > 1 ? "checkbox" : "radio"} name={group.id} checked={(chosen[group.id] ?? []).includes(choice.id)} onChange={() => toggleChoice(group, choice.id)}/>
                    <span>{choice.name}</span>
                    <small>{Number(choice.price) > 0 ? `+${foodMoney(choice.price)}` : ""}</small>
                  </label>
                ))}
              </fieldset>
            ))}
            <label className="wf-guest-note">หมายเหตุเพิ่มเติม<textarea value={note} maxLength={250} onChange={(e) => setNote(e.target.value)} placeholder="เช่น ไม่ใส่ผัก"/></label>
            <div className="wf-guest-stepper">
              <button type="button" disabled={qty<=1} onClick={() => setQty(v => Math.max(1,v-1))} aria-label="ลดจำนวน"><Minus size={18}/></button>
              <b>{qty}</b>
              <button type="button" disabled={qty>=99} onClick={() => setQty(v => Math.min(99,v+1))} aria-label="เพิ่มจำนวน"><Plus size={18}/></button>
            </div>
            <button type="button" className="wf-guest-primary" disabled={!foodCartLineOptionsValid(selectedItem, { selected_options: (selectedItem.options ?? []).flatMap((group) => (chosen[group.id] ?? []).map((choiceId) => ({ group_id: group.id, choice_id: choiceId }))) })} onClick={addItem}>เพิ่มลงตะกร้า</button>
          </section>
        </div>
      )}

      {showBasket && (
        <div className="wf-guest-overlay" role="presentation">
          <section className="wf-guest-sheet" role="dialog" aria-modal="true" aria-label="ตะกร้าอาหาร">
            <button type="button" className="wf-guest-close" aria-label="ปิด" onClick={() => setShowBasket(false)}><X size={21}/></button>
            <h2>ตะกร้าอาหาร</h2>
            {basket?.lines.map((line, index) => {
              const item = basketStore?.menu.find((row) => row.id === line.menu_item_id);
              if (!item) return null;
              return <div className="wf-guest-basket-line" key={index}>
                <div><strong>{item.name}</strong><small>{line.selected_options?.map((x) => x.choice_name).filter(Boolean).join(" · ")}</small><b>{foodMoney(foodCartLineUnitPrice(item,line)*line.quantity)}</b></div>
                <span className="wf-guest-stepper"><button type="button" aria-label="ลดจำนวน" onClick={() => updateQty(index,-1)}><Minus size={16}/></button><b>{line.quantity}</b><button type="button" aria-label="เพิ่มจำนวน" disabled={line.quantity>=99} onClick={() => updateQty(index,1)}><Plus size={16}/></button></span>
              </div>;
            })}
            <p className="wf-guest-secondary">ยอดอาหารโดยประมาณ {foodMoney(subtotal)} · ยังไม่รวมค่าจัดส่งและส่วนลดที่ระบบคำนวณตอนสั่งจริง</p>
            <button type="button" className="wf-guest-primary" disabled={!cartCount} onClick={signInForOrder}>เข้าสู่ระบบเพื่อยืนยันคำสั่งซื้อ</button>
          </section>
        </div>
      )}
    </main>
  );
}
