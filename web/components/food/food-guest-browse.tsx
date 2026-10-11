"use client";

import { ArrowLeft, Check, Clock3, Info, MapPin, Minus, Plus, Search, Store, Trash2, UtensilsCrossed, X } from "lucide-react";
import type { SupabaseClient } from "@supabase/supabase-js";
import Image from "next/image";
import Link from "next/link";
import { useRouter } from "next/navigation";
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
  const router = useRouter();
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
    void (async () => {
      try {
        const { data, error: rpcError } = await client.rpc("food_public_catalog");
        if (!live) return;
        if (rpcError || !Array.isArray(data)) throw rpcError ?? new Error("Invalid Food catalog response");
        setStores(data as GuestStore[]);
      } catch {
        if (!live) return;
        setError("โหลดร้านอาหารไม่สำเร็จ กรุณาลองอีกครั้ง");
        setStores([]);
      }
    })();
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
    router.push("/food/login");
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

  const itemSelection = selectedItem
    ? { selected_options: (selectedItem.options ?? []).flatMap((group) => (chosen[group.id] ?? []).map((choiceId) => ({ group_id: group.id, choice_id: choiceId }))) }
    : null;
  const itemValid = selectedItem && itemSelection ? foodCartLineOptionsValid(selectedItem, itemSelection) : false;
  const itemUnitPrice = selectedItem ? foodCartLineUnitPrice(selectedItem, { selected_options: (selectedItem.options ?? []).flatMap((group) => (chosen[group.id] ?? []).map((choiceId) => {
    const choice = group.choices.find((row) => row.id === choiceId);
    return { group_id: group.id, group_name: group.name, choice_id: choiceId, choice_name: choice?.name ?? "", price: choice?.price ?? 0 };
  })) }) : 0;
  const storeCover = store ? foodPublicUrl(client, store.cover_path) : null;

  return (
    <main className={`wyn-food fx-app fx-guest${cartCount > 0 && !showBasket ? " has-cart-bar" : ""}`}>
      {store ? (
        <>
          <section className={`fx-store-hero${store.is_open ? "" : " is-closed"}`}>
            <div className="fx-store-cover">
              {storeCover ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={storeCover} alt="" decoding="async" fetchPriority="high" />
              ) : <Store size={46} strokeWidth={1.25} />}
            </div>
            <div className="fx-store-hero-actions">
              <button className="fx-float-btn" type="button" aria-label="ดูร้านทั้งหมด" onClick={() => { setSelectedId(null); setShowBasket(false); }}>
                <ArrowLeft size={21} strokeWidth={2.3} />
              </button>
              <Link href="/food/login" className="fx-btn fx-btn--outline fx-btn--sm fx-guest-login">เข้าสู่ระบบ</Link>
            </div>
            {!store.is_open ? <span className="fx-store-closed-badge"><Clock3 size={16} strokeWidth={2.4} />ร้านปิดอยู่</span> : null}
          </section>

          <section className="fx-store-info">
            <h1>{store.name}</h1>
            <p className="fx-store-meta">{store.menu.length} เมนู · ค่าส่งเริ่มต้น {foodMoney(store.delivery_fee)}</p>
            {store.is_open ? (
              <p className="fx-store-open"><Clock3 size={14} strokeWidth={2.3} />เปิดรับออเดอร์</p>
            ) : (
              <div className="fx-store-closed-box" role="status">
                <strong>ปิดรับออเดอร์ชั่วคราว</strong>
                <span>ดูเมนูไว้ก่อนได้ สั่งได้เมื่อร้านเปิด</span>
              </div>
            )}
            {store.description ? <p className="fx-store-min">{store.description}</p> : null}
            {store.address ? <p className="fx-store-min"><MapPin size={14} /> {store.address}</p> : null}
          </section>

          <section className="fx-store-menu">
            {[...new Set(store.menu.map((item) => item.category))].map((category) => (
              <section className="fx-menu-section" key={category}>
                <h2>{category}</h2>
                <div className="fx-menu-list">
                  {store.menu.filter((item) => item.category === category).map((item) => {
                    const orderable = store.is_open && available(item);
                    const photo = foodPublicUrl(client, item.image_path);
                    return (
                      <button key={item.id} type="button" className={`fx-menu-row${available(item) ? "" : " is-off"}`} onClick={() => showItem(item)} disabled={!orderable} aria-label={`${item.name} ${foodMoney(item.price)}${available(item) ? "" : " สินค้าหมด"}`}>
                        <span className="fx-menu-row-photo">
                          <span className="fx-menu-image">
                            {photo ? (
                              // eslint-disable-next-line @next/next/no-img-element
                              <img src={photo} alt="" loading="lazy" decoding="async" />
                            ) : <UtensilsCrossed size={26} strokeWidth={1.45} />}
                          </span>
                          {!available(item) ? <span className="fx-soldout-tag">สินค้าหมด</span> : null}
                        </span>
                        <span className="fx-menu-row-copy">
                          <strong>{item.name}</strong>
                          {item.description ? <small>{item.description}</small> : null}
                          <b>{foodMoney(item.price)}</b>
                        </span>
                        {orderable ? <span className="fx-menu-row-add" aria-hidden="true"><Plus size={20} strokeWidth={2.8} /></span> : null}
                      </button>
                    );
                  })}
                </div>
              </section>
            ))}
            {!store.menu.length ? (
              <div className="fx-state" role="status">
                <span className="fx-state-icon"><UtensilsCrossed size={44} strokeWidth={1.6} /></span>
                <h2>ยังไม่มีเมนู</h2>
                <div className="fx-state-copy"><p>ร้านนี้ยังไม่มีเมนูที่พร้อมขาย</p></div>
              </div>
            ) : null}
          </section>
        </>
      ) : (
        <>
          <header className="fx-header">
            <div className="fx-header-top">
              <div className="fx-brand">
                <Image className="wf-brand-logo" src="/icons/food/icon-192-v12.png" width={32} height={32} alt="" />
                <span>WYNOS <b>Food</b></span>
              </div>
              <Link href="/food/login" className="fx-btn fx-btn--outline fx-btn--sm">เข้าสู่ระบบ</Link>
            </div>
          </header>

          <section className="fx-guest-hero">
            <span className="fx-guest-tag"><MapPin size={14} /> ให้บริการในพื้นที่มหาสารคาม</span>
            <h1>เลือกอาหารที่อยากกินได้เลย</h1>
            <p>ดูร้านและเมนูได้ทันที ไม่ต้องล็อกอินหรือเปิด GPS ตรวจสอบพื้นที่จัดส่งเมื่อสั่งซื้อจริง</p>
          </section>

          <label className="fx-search">
            <Search size={20} strokeWidth={2} />
            <input type="search" value={query} onChange={(e) => setQuery(e.target.value)} placeholder="ค้นหาร้านหรือชื่ออาหาร" aria-label="ค้นหาร้านหรือชื่ออาหาร" />
            {query ? <button type="button" className="fx-search-clear" aria-label="ล้างการค้นหา" onClick={() => setQuery("")}><X size={14} strokeWidth={3} /></button> : null}
          </label>

          <section className="fx-section fx-guest-stores">
            <div className="fx-section-head"><h2>ร้านอาหารที่เปิดเผยแพร่</h2></div>
            {stores === null ? <p className="fx-empty-line" role="status">กำลังโหลดร้านอาหาร…</p> : null}
            {error ? <div className="fx-note fx-note--danger" role="alert">{error}</div> : null}
            {stores && !error && !filtered.length ? (
              <div className="fx-state" role="status">
                <span className="fx-state-icon"><Search size={40} strokeWidth={1.6} /></span>
                <h2>ยังไม่พบร้านอาหารที่ตรงกับการค้นหา</h2>
                <div className="fx-state-copy"><p>ลองค้นด้วยชื่อร้าน ชื่อเมนู หรือคำที่สั้นลง</p></div>
              </div>
            ) : null}
            <div className="fx-store-grid">
              {filtered.map((entry) => {
                const cover = foodPublicUrl(client, entry.cover_path);
                return (
                  <button type="button" className={`fx-store-card${entry.is_open ? "" : " is-closed"}`} key={entry.id} onClick={() => pickStore(entry)}>
                    <span className="fx-store-card-photo">
                      {cover ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={cover} alt="" loading="lazy" decoding="async" />
                      ) : <Store size={30} strokeWidth={1.4} />}
                      {!entry.is_open ? <b className="fx-closed-label"><Clock3 size={12} strokeWidth={2.4} />ปิดอยู่</b> : null}
                    </span>
                    <span className="fx-store-card-name">{entry.name}</span>
                    <span className="fx-store-card-tags">
                      <span>{entry.menu.length} เมนู</span>
                      <span>ค่าส่ง {foodMoney(entry.delivery_fee)}</span>
                    </span>
                  </button>
                );
              })}
            </div>
          </section>
        </>
      )}

      {cartCount > 0 && !showBasket ? (
        <button className="fx-cart-bar" type="button" onClick={() => setShowBasket(true)} aria-label={`ดูตะกร้า ${cartCount} รายการ ${foodMoney(subtotal)}`}>
          <span className="fx-cart-bar-count">{cartCount > 99 ? "99+" : cartCount}</span>
          <span className="fx-cart-bar-label">ดูตะกร้า</span>
          <b>{foodMoney(subtotal)}</b>
        </button>
      ) : null}

      {selectedItem ? (
        <div className="fx-sheet-backdrop is-page fx-item-backdrop" role="presentation">
          <section className="fx-sheet is-page fx-item" role="dialog" aria-modal="true" aria-label={selectedItem.name}>
            <button className="fx-float-btn fx-item-close" type="button" aria-label="ปิด" onClick={() => setSelectedItem(null)}><X size={20} strokeWidth={2.4} /></button>
            <div className="fx-item-scroll">
              <div className="fx-item-photo">
                {foodPublicUrl(client, selectedItem.image_path) ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={foodPublicUrl(client, selectedItem.image_path) ?? ""} alt="" />
                ) : <UtensilsCrossed size={48} strokeWidth={1.35} />}
              </div>
              <div className="fx-item-head">
                <h3>{selectedItem.name}</h3>
                {selectedItem.description ? <p>{selectedItem.description}</p> : null}
                <strong>{foodMoney(itemUnitPrice)}</strong>
              </div>
              {(selectedItem.options ?? []).map((group) => {
                const maxSelect = Math.max(1, Math.min(20, Number(group.max_select ?? 1)));
                const picked = chosen[group.id] ?? [];
                return (
                  <section className="fx-option-group" key={group.id}>
                    <div className="fx-option-head">
                      <strong>{group.name}</strong>
                      {group.required ? (
                        <span className={`fx-required${picked.length ? " is-done" : ""}`}>{picked.length ? "เลือกแล้ว" : "ต้องเลือก"}</span>
                      ) : <small>{maxSelect === 1 ? "เลือกได้ 1 รายการ" : `เลือกได้สูงสุด ${maxSelect} รายการ`}</small>}
                    </div>
                    <div className="fx-option-choices">
                      {group.choices.map((choice) => {
                        const active = picked.includes(choice.id);
                        const extra = Math.max(0, Number(choice.price ?? 0));
                        return (
                          <button key={choice.id} type="button" className={active ? "is-active" : ""} role={maxSelect === 1 ? "radio" : "checkbox"} aria-checked={active} onClick={() => toggleChoice(group, choice.id)}>
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
              {!itemValid ? <div className="fx-note fx-note--warn fx-item-warn" role="status">กรุณาเลือกตัวเลือกที่จำเป็นให้ครบ</div> : null}
              <label className="fx-field fx-item-note">
                <span className="fx-field-label"><strong>หมายเหตุถึงร้าน</strong><small>{note.length}/250</small></span>
                <textarea value={note} maxLength={250} onChange={(e) => setNote(e.target.value)} placeholder="เช่น ไม่ใส่ผัก, แยกน้ำจิ้ม" />
              </label>
            </div>
            <div className="fx-item-actions">
              <div className="fx-stepper">
                <button type="button" disabled={qty <= 1} onClick={() => setQty((v) => Math.max(1, v - 1))} aria-label="ลดจำนวน"><Minus size={18} strokeWidth={2.6} /></button>
                <b aria-live="polite">{qty}</b>
                <button type="button" disabled={qty >= 99} onClick={() => setQty((v) => Math.min(99, v + 1))} aria-label="เพิ่มจำนวน"><Plus size={18} strokeWidth={2.6} /></button>
              </div>
              <button className="fx-btn fx-btn--primary fx-btn--grow" type="button" disabled={!itemValid} onClick={addItem}>
                {itemValid ? `เพิ่มลงตะกร้า · ${foodMoney(itemUnitPrice * qty)}` : "เลือกตัวเลือกที่จำเป็นก่อน"}
              </button>
            </div>
          </section>
        </div>
      ) : null}

      {showBasket ? (
        <div className="fx-sheet-backdrop is-page" role="presentation">
          <section className="fx-sheet is-page" role="dialog" aria-modal="true" aria-label="ตะกร้าอาหาร">
            <header className="fx-sheet-head">
              <button className="fx-icon-btn" type="button" aria-label="ย้อนกลับ" onClick={() => setShowBasket(false)}><ArrowLeft size={22} strokeWidth={2.1} /></button>
              <h2>ตะกร้าอาหาร</h2>
              <span />
            </header>
            <div className="fx-sheet-body">
              {basketStore ? <p className="fx-guest-basket-store"><Store size={18} /> {basketStore.name}</p> : null}
              <div className="fx-cart-lines">
                {basket?.lines.map((line, index) => {
                  const item = basketStore?.menu.find((row) => row.id === line.menu_item_id);
                  if (!item) return null;
                  const photo = foodPublicUrl(client, item.image_path);
                  const optionText = line.selected_options?.map((x) => x.choice_name).filter(Boolean).join(" · ");
                  return (
                    <article className="fx-cart-line" key={index}>
                      <span className="fx-menu-image fx-cart-thumb">
                        {photo ? (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img src={photo} alt="" loading="lazy" decoding="async" />
                        ) : <UtensilsCrossed size={22} />}
                      </span>
                      <div className="fx-cart-line-copy">
                        <strong>{item.name}</strong>
                        {optionText ? <small>{optionText}</small> : null}
                        {line.note ? <small>หมายเหตุ · {line.note}</small> : null}
                        <b>{foodMoney(foodCartLineUnitPrice(item, line) * line.quantity)}</b>
                      </div>
                      <div className="fx-cart-line-side">
                        <div className="fx-stepper fx-stepper--sm">
                          <button type="button" aria-label="ลดจำนวน" onClick={() => updateQty(index, -1)}>{line.quantity === 1 ? <Trash2 size={15} /> : <Minus size={15} strokeWidth={2.6} />}</button>
                          <b aria-live="polite">{line.quantity}</b>
                          <button type="button" aria-label="เพิ่มจำนวน" disabled={line.quantity >= 99} onClick={() => updateQty(index, 1)}><Plus size={15} strokeWidth={2.6} /></button>
                        </div>
                      </div>
                    </article>
                  );
                })}
              </div>
              <div className="fx-note fx-note--info" role="note">
                <Info size={18} />
                <span><strong>ยอดอาหารโดยประมาณ {foodMoney(subtotal)}</strong><small>ยังไม่รวมค่าจัดส่งและส่วนลดที่ระบบคำนวณตอนสั่งจริง</small></span>
              </div>
            </div>
            <footer className="fx-sheet-footer">
              <button type="button" className="fx-btn fx-btn--primary fx-btn--block" disabled={!cartCount} onClick={signInForOrder}>เข้าสู่ระบบเพื่อยืนยันคำสั่งซื้อ</button>
            </footer>
          </section>
        </div>
      ) : null}
    </main>
  );
}
