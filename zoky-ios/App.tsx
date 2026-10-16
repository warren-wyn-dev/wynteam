import React, { useMemo, useState } from "react";
import {
  Alert, Modal, Pressable, SafeAreaView, ScrollView, StatusBar,
  StyleSheet, Text, View
} from "react-native";
import { addLine, itemOptionError, lineKey, subtotal, unitPrice } from "./src/cart";
import { demoStores } from "./src/fixtures";
import type { CartLine, HomePage, MenuItem, SelectedOption, Store, Tab } from "./src/model";
import { baht, theme } from "./src/theme";
import { HomeDiscovery, BrowseDiscovery } from "./src/DiscoveryScreens";

function Button({ label, onPress, soft = false, disabled = false }: {
  label: string; onPress: () => void; soft?: boolean; disabled?: boolean;
}) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      disabled={disabled}
      onPress={onPress}
      style={[styles.button, soft && styles.softButton, disabled && styles.disabled]}
    >
      <Text style={[styles.buttonText, soft && styles.softButtonText]}>{label}</Text>
    </Pressable>
  );
}

function Heading({ title, hint }: { title: string; hint?: string }) {
  return (
    <View style={styles.sectionHeading}>
      <Text style={styles.h2}>{title}</Text>
      {hint ? <Text style={styles.subtle}>{hint}</Text> : null}
    </View>
  );
}

function OptionModal({ item, onClose, onAdd }: {
  item: MenuItem | null;
  onClose: () => void;
  onAdd: (item: MenuItem, options: SelectedOption[], quantity: number) => void;
}) {
  const [chosen, setChosen] = useState<Record<string, string[]>>({});
  const [quantity, setQuantity] = useState(1);

  if (!item) return null;

  const selected: SelectedOption[] = item.options.flatMap((group) =>
    (chosen[group.id] ?? []).flatMap((choiceId) => {
      const choice = group.choices.find((candidate) => candidate.id === choiceId);
      return choice ? [{
        groupId: group.id, groupName: group.name, choiceId: choice.id,
        choiceName: choice.name, price: choice.price
      }] : [];
    })
  );
  const toggle = (groupId: string, choiceId: string, max: number) => {
    setChosen((old) => {
      const current = old[groupId] ?? [];
      const next = max === 1
        ? [choiceId]
        : current.includes(choiceId)
          ? current.filter((id) => id !== choiceId)
          : current.length < max ? [...current, choiceId] : current;
      return { ...old, [groupId]: next };
    });
  };
  const submit = () => {
    const error = itemOptionError(item, selected);
    if (error) { Alert.alert("ยังเลือกไม่ครบ", error); return; }
    onAdd(item, selected, quantity);
    setChosen({});
    setQuantity(1);
  };

  return (
    <Modal transparent visible animationType="slide" onRequestClose={onClose}>
      <View style={styles.modalOverlay}>
        <View style={styles.sheet}>
          <ScrollView keyboardShouldPersistTaps="handled">
            <View style={styles.sheetTop}>
              <Text style={styles.h2}>{item.name}</Text>
              <Pressable accessibilityRole="button" accessibilityLabel="ปิด" onPress={onClose}>
                <Text style={styles.close}>✕</Text>
              </Pressable>
            </View>
            <Text style={styles.subtle}>ราคาเริ่มต้น {baht(item.price)} · ข้อมูลจำลอง</Text>
            {item.options.map((group) => (
              <View key={group.id} style={styles.optionGroup}>
                <Text style={styles.cardTitle}>
                  {group.name} {group.required ? "(จำเป็น)" : "(ไม่จำเป็น)"}
                </Text>
                <Text style={styles.subtle}>
                  {group.maxSelect === 1 ? "เลือกได้ 1 รายการ" : "เลือกได้สูงสุด " + group.maxSelect + " รายการ"}
                </Text>
                {group.choices.map((choice) => {
                  const checked = (chosen[group.id] ?? []).includes(choice.id);
                  return (
                    <Pressable
                      key={choice.id}
                      accessibilityRole={group.maxSelect === 1 ? "radio" : "checkbox"}
                      accessibilityState={{ checked }}
                      onPress={() => toggle(group.id, choice.id, group.maxSelect)}
                      style={styles.choiceRow}
                    >
                      <Text style={styles.choiceCircle}>{checked ? "🔘" : group.maxSelect === 1 ? "◯" : "☐"}</Text>
                      <Text style={styles.flex}>{choice.name}</Text>
                      <Text>{choice.price ? "+" + baht(choice.price) : "ฟรี"}</Text>
                    </Pressable>
                  );
                })}
              </View>
            ))}
            <View style={styles.stepperLine}>
              <Text style={styles.cardTitle}>จำนวน</Text>
              <Pressable accessibilityLabel="ลดจำนวน" accessibilityRole="button" onPress={() => setQuantity((v) => Math.max(1, v - 1))} style={styles.step}>
                <Text style={styles.stepText}>−</Text>
              </Pressable>
              <Text style={styles.qty}>{quantity}</Text>
              <Pressable accessibilityLabel="เพิ่มจำนวน" accessibilityRole="button" onPress={() => setQuantity((v) => Math.min(20, v + 1))} style={styles.step}>
                <Text style={styles.stepText}>+</Text>
              </Pressable>
            </View>
          </ScrollView>
          <Button label={"เพิ่มลงตะกร้า · " + baht(unitPrice(item.price, selected) * quantity)} onPress={submit} />
        </View>
      </View>
    </Modal>
  );
}

export default function App() {
  const [tab, setTab] = useState<Tab>("home");
  const [page, setPage] = useState<HomePage>("hub");
  const [storeId, setStoreId] = useState<string | null>(null);
  const [menuItem, setMenuItem] = useState<MenuItem | null>(null);
  const [search, setSearch] = useState("");
  const [category, setCategory] = useState("ทั้งหมด");
  const [cart, setCart] = useState<CartLine[]>([]);

  const store = demoStores.find((candidate) => candidate.id === storeId) ?? null;
  const cartStore = demoStores.find((candidate) => candidate.id === cart[0]?.storeId) ?? null;
  const cartCount = cart.reduce((sum, line) => sum + line.quantity, 0);
  const sum = subtotal(cart);
  const filtered = useMemo(() => demoStores.filter((entry) => {
    const term = search.trim().toLocaleLowerCase("th");
    const matchesText = !term || entry.name.toLocaleLowerCase("th").includes(term)
      || entry.menus.some((menu) => menu.name.toLocaleLowerCase("th").includes(term));
    const matchesCategory = category === "ทั้งหมด"
      || entry.menus.some((menu) => menu.category === category);
    return matchesText && matchesCategory;
  }), [search, category]);
  const categories = ["ทั้งหมด", ...Array.from(new Set(demoStores.flatMap((entry) =>
    entry.menus.map((menu) => menu.category)
  )))];

  const browse = () => { setTab("home"); setPage("browse"); setMenuItem(null); };
  const showStore = (next: Store) => {
    setTab("home"); setStoreId(next.id); setPage("store"); setMenuItem(null);
  };
  const addToCart = (item: MenuItem, options: SelectedOption[], quantity: number) => {
    if (!store || !store.open || !item.available) {
      Alert.alert("ไม่พร้อมให้เลือก", "รายการนี้ไม่พร้อมใช้งานในตัวอย่าง");
      return;
    }
    const next: CartLine = {
      key: lineKey(item.id, options), storeId: store.id,
      itemId: item.id, name: item.name, basePrice: item.price,
      options, quantity
    };
    const add = () => {
      setCart((old) => addLine(old.length && old[0].storeId !== store.id ? [] : old, next));
      setMenuItem(null);
      Alert.alert("เพิ่มลงตะกร้าแล้ว", "นี่เป็นรายการทดลอง ไม่มีการส่งคำสั่งซื้อ");
    };
    if (cart.length && cart[0].storeId !== store.id) {
      Alert.alert("ตะกร้าจากร้านอื่น", "เปลี่ยนร้านแล้วล้างตะกร้าเดิมหรือไม่?", [
        { text: "ยกเลิก", style: "cancel" },
        { text: "เปลี่ยนร้าน", style: "destructive", onPress: add }
      ]);
    } else add();
  };
  const updateQty = (key: string, delta: number) => {
    setCart((old) => old.flatMap((line) => {
      if (line.key !== key) return [line];
      const quantity = Math.min(99, line.quantity + delta);
      return quantity > 0 ? [{ ...line, quantity }] : [];
    }));
  };
  const switchTab = (next: Tab) => {
    setTab(next); setPage("hub"); setMenuItem(null);
  };

  return (
    <SafeAreaView style={styles.root}>
      <StatusBar barStyle="dark-content" />
      <View style={styles.header}>
        <View>
          <Text style={styles.logo}>หน้าหลัก</Text>
          <Text style={styles.subtle}>iOS Design Preview 2 · ไม่มีธุรกรรมจริง</Text>
        </View>
        <Pressable accessibilityRole="button" accessibilityLabel={"ตะกร้า " + cartCount + " รายการ"} onPress={() => { setTab("home"); setPage("cart"); }} style={styles.cartPill}>
          <Text style={styles.cartPillText}>🛒  {cartCount}</Text>
        </Pressable>
      </View>
      <ScrollView
        key={tab + ":" + page + ":" + (storeId ?? "")}
        style={styles.scroller}
        contentContainerStyle={styles.content}
        keyboardShouldPersistTaps="handled"
      >
        {tab === "home" && page === "hub" && (
          <HomeDiscovery
            stores={demoStores}
            categories={categories}
            onBrowse={browse}
            onStore={showStore}
            onCategory={(value) => { setCategory(value); browse(); }}
          />
        )}
        {tab === "home" && page === "browse" && (
          <BrowseDiscovery
            stores={filtered}
            categories={categories}
            query={search}
            onQuery={setSearch}
            category={category}
            onCategory={setCategory}
            onStore={showStore}
            onBack={() => setPage("hub")}
          />
        )}
        {tab === "home" && page === "store" && store && (
          <>
            <Button label="← ร้านอาหารทั้งหมด" onPress={browse} soft />
            <View style={styles.storeHero}>
              <Text style={styles.storeEmoji}>{store.emoji}</Text>
              <Text style={styles.h2}>{store.name}</Text>
              <Text style={styles.subtle}>{store.description}</Text>
              <Text style={styles.meta}>{store.open ? "เปิด (ตัวอย่าง)" : "ปิด (ตัวอย่าง)"} · ค่าส่ง {baht(store.deliveryFee)} (ประมาณการ)</Text>
            </View>
            <Heading title="เมนูอาหาร" hint="ราคาทดลอง ไม่ใช่ราคาขายจริง" />
            {store.menus.map((item) => (
              <View key={item.id} style={styles.menuCard}>
                <View style={styles.flex}>
                  <Text style={styles.categoryText}>{item.category}</Text>
                  <Text style={styles.cardTitle}>{item.name}</Text>
                  <Text style={styles.subtle}>{item.description}</Text>
                  <Text style={styles.price}>{baht(item.price)}</Text>
                </View>
                <View style={styles.addButton}>
                  <Button label="เลือก +" disabled={!item.available || !store.open} onPress={() => setMenuItem(item)} />
                </View>
              </View>
            ))}
            <Button label={"ดูตะกร้า (" + cartCount + ")"} onPress={() => setPage("cart")} />
          </>
        )}
        {tab === "home" && page === "cart" && (
          <>
            <Heading title="ตะกร้าทดลอง" hint="ไม่สามารถสร้างออเดอร์หรือจ่ายเงินจริง" />
            {cart.length === 0 ? (
              <View style={styles.card}>
                <Text style={styles.empty}>🛒 ยังไม่มีสินค้าในตะกร้า</Text>
                <Button label="เลือกอาหาร" onPress={browse} />
              </View>
            ) : (
              <>
                <Text style={styles.meta}>{cartStore?.name ?? "ร้านตัวอย่าง"}</Text>
                {cart.map((line) => (
                  <View style={styles.menuCard} key={line.key}>
                    <View style={styles.flex}>
                      <Text style={styles.cardTitle}>{line.name}</Text>
                      <Text style={styles.subtle}>{line.options.map((option) => option.choiceName).join(", ") || "ไม่มีตัวเลือกเสริม"}</Text>
                      <Text style={styles.price}>{baht(unitPrice(line.basePrice, line.options) * line.quantity)}</Text>
                      <View style={styles.stepperLine}>
                        <Pressable accessibilityRole="button" accessibilityLabel={"ลดจำนวน " + line.name} onPress={() => updateQty(line.key, -1)} style={styles.step}><Text style={styles.stepText}>−</Text></Pressable>
                        <Text style={styles.qty}>{line.quantity}</Text>
                        <Pressable accessibilityRole="button" accessibilityLabel={"เพิ่มจำนวน " + line.name} onPress={() => updateQty(line.key, 1)} style={styles.step}><Text style={styles.stepText}>+</Text></Pressable>
                        <Pressable accessibilityRole="button" accessibilityLabel={"ลบ " + line.name} onPress={() => setCart((old) => old.filter((value) => value.key !== line.key))}>
                          <Text style={styles.deleteText}>ลบ</Text>
                        </Pressable>
                      </View>
                    </View>
                  </View>
                ))}
                <View style={styles.card}>
                  <View style={styles.totalRow}><Text>ค่าอาหารตัวอย่าง</Text><Text>{baht(sum)}</Text></View>
                  <View style={styles.totalRow}><Text>ค่าจัดส่งตัวอย่าง</Text><Text>{baht(cartStore?.deliveryFee ?? 0)}</Text></View>
                  <View style={styles.totalRow}><Text style={styles.cardTitle}>รวมโดยประมาณ</Text><Text style={styles.price}>{baht(sum + (cartStore?.deliveryFee ?? 0))}</Text></View>
                  <Text style={styles.subtle}>ยอดนี้ไม่ใช่ราคาจาก Server Quote และยังไม่รวมกฎโปรโมชัน/ค่าธรรมเนียมจริง</Text>
                  <Button label="ทดลองไปหน้าชำระเงิน (ยังไม่เปิด)" disabled onPress={() => {}} />
                  <Button label="ล้างตะกร้า" soft onPress={() => Alert.alert("ล้างตะกร้า?", "ลบรายการตัวอย่างทั้งหมด", [
                    { text: "ยกเลิก", style: "cancel" },
                    { text: "ล้าง", style: "destructive", onPress: () => setCart([]) }
                  ])} />
                </View>
                <Button label="เลือกอาหารต่อ" onPress={browse} soft />
              </>
            )}
          </>
        )}
        {tab === "orders" && (
          <View style={styles.card}><Heading title="คำสั่งซื้อ" hint="ยังไม่เชื่อมข้อมูลคำสั่งซื้อจริง" /><Text style={styles.empty}>ยังไม่มีคำสั่งซื้อใน Preview</Text><Button label="สำรวจร้านอาหาร" onPress={browse} /></View>
        )}
        {tab === "messages" && (
          <View style={styles.card}><Heading title="ข้อความ" hint="รอบนี้ยังไม่เปิดแชตหรือแจ้งเตือน" /><Text style={styles.empty}>ไม่มีข้อความใน Preview</Text></View>
        )}
        {tab === "account" && (
          <View style={styles.card}><Heading title="บัญชีของฉัน" hint="ยังไม่เชื่อมบัญชีจริง" /><Text style={styles.empty}>การเข้าสู่ระบบจะพัฒนาในขั้นถัดไป หลังผ่านการทดสอบความปลอดภัย</Text></View>
        )}
      </ScrollView>
      <View style={styles.tabs}>
        {([
          ["home", "⌂", "หน้าหลัก"],
          ["orders", "▤", "ออเดอร์"],
          ["messages", "◌", "ข้อความ"],
          ["account", "♙", "บัญชี"]
        ] as const).map(([value, glyph, label]) => (
          <Pressable key={value} onPress={() => switchTab(value)} accessibilityRole="tab" accessibilityState={{ selected: tab === value }} accessibilityLabel={label} style={styles.tab}>
            <Text style={[styles.tabIcon, tab === value && styles.tabActive]}>{glyph}</Text>
            <Text style={[styles.tabLabel, tab === value && styles.tabActive]}>{label}</Text>
          </Pressable>
        ))}
      </View>
      <OptionModal key={menuItem?.id ?? "closed"} item={menuItem} onClose={() => setMenuItem(null)} onAdd={addToCart} />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: theme.white },
  header: { backgroundColor: theme.white, paddingHorizontal: 20, paddingTop: 8, paddingBottom: 12,
    borderBottomColor: theme.border, borderBottomWidth: 1, flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  logo: { color: theme.pink, fontSize: 32, fontWeight: "900", letterSpacing: -1 },
  subtle: { color: theme.muted, fontSize: 13, lineHeight: 19 },
  meta: { color: theme.pinkDark, fontSize: 12, fontWeight: "600", marginTop: 7 },
  scroller: { flex: 1, backgroundColor: theme.pinkSoft },
  content: { padding: 16, paddingBottom: 30 },
  hero: { borderRadius: 24, backgroundColor: theme.pink, padding: 20, marginBottom: 20 },
  heroEyebrow: { color: "#FFEAF3", fontSize: 13, fontWeight: "700" },
  heroTitle: { color: theme.white, fontSize: 29, fontWeight: "900", marginTop: 7, lineHeight: 36 },
  heroCopy: { color: theme.white, marginTop: 7, marginBottom: 8, fontSize: 13 },
  sectionHeading: { marginTop: 6, marginBottom: 12 },
  h2: { color: theme.ink, fontSize: 22, fontWeight: "800", marginBottom: 3 },
  card: { backgroundColor: theme.white, borderRadius: 18, padding: 15, marginBottom: 12, borderWidth: 1, borderColor: theme.border },
  cardRow: { flexDirection: "row", alignItems: "center", gap: 12 },
  illustration: { width: 60, height: 60, borderRadius: 15, backgroundColor: theme.pinkLight, alignItems: "center", justifyContent: "center" },
  bigEmoji: { fontSize: 31 },
  flex: { flex: 1 },
  cardTitle: { color: theme.ink, fontSize: 16, fontWeight: "700", marginBottom: 5 },
  arrow: { color: theme.pink, fontSize: 29 },
  serviceCard: { backgroundColor: theme.white, borderRadius: 18, padding: 15, marginBottom: 12, flexDirection: "row",
    alignItems: "center", gap: 12, borderWidth: 1, borderColor: theme.border },
  button: { borderRadius: 12, backgroundColor: theme.pink, paddingVertical: 12, paddingHorizontal: 16, alignItems: "center", justifyContent: "center" },
  buttonText: { fontSize: 14, color: theme.white, fontWeight: "700" },
  softButton: { backgroundColor: theme.pinkLight },
  softButtonText: { color: theme.pinkDark },
  disabled: { opacity: 0.45 },
  cartPill: { backgroundColor: theme.pinkLight, borderRadius: 24, paddingVertical: 10, paddingHorizontal: 14 },
  cartPillText: { fontWeight: "700", color: theme.pinkDark },
  search: { borderRadius: 13, padding: 14, backgroundColor: theme.white, borderColor: theme.border,
    borderWidth: 1, marginBottom: 12, fontSize: 15, color: theme.ink },
  chips: { marginBottom: 14 },
  chip: { backgroundColor: theme.white, borderRadius: 22, paddingHorizontal: 14, paddingVertical: 9,
    marginRight: 8, borderColor: theme.border, borderWidth: 1 },
  chipActive: { backgroundColor: theme.pink, borderColor: theme.pink },
  chipText: { color: theme.ink, fontWeight: "600", fontSize: 12 },
  chipTextActive: { color: theme.white },
  empty: { color: theme.muted, fontSize: 15, paddingVertical: 20 },
  storeHero: { backgroundColor: theme.white, borderRadius: 20, alignItems: "center", padding: 22, marginTop: 12, marginBottom: 16 },
  storeEmoji: { fontSize: 53, marginBottom: 9 },
  menuCard: { backgroundColor: theme.white, borderRadius: 16, padding: 15, marginBottom: 10,
    flexDirection: "row", alignItems: "center", gap: 12 },
  categoryText: { color: theme.muted, fontSize: 12, marginBottom: 5 },
  price: { color: theme.pinkDark, fontSize: 17, fontWeight: "800", marginTop: 8 },
  addButton: { minWidth: 92 },
  totalRow: { flexDirection: "row", justifyContent: "space-between", paddingVertical: 9 },
  stepperLine: { flexDirection: "row", alignItems: "center", gap: 12, marginTop: 15 },
  step: { backgroundColor: theme.pinkLight, borderRadius: 10, padding: 8, minWidth: 38, alignItems: "center" },
  stepText: { color: theme.pinkDark, fontSize: 19, fontWeight: "700" },
  qty: { fontWeight: "700", fontSize: 16, color: theme.ink },
  deleteText: { color: theme.pinkDark, marginLeft: 10, fontWeight: "700" },
  tabs: { flexDirection: "row", backgroundColor: theme.white, borderTopWidth: 1, borderColor: theme.border, paddingTop: 9, paddingBottom: 4 },
  tab: { flex: 1, alignItems: "center", paddingVertical: 3 },
  tabIcon: { fontSize: 23, fontWeight: "600", color: "#99919B" },
  tabLabel: { fontSize: 11, color: theme.muted, marginTop: 2 },
  tabActive: { color: theme.pinkDark, fontWeight: "800" },
  modalOverlay: { flex: 1, justifyContent: "flex-end", backgroundColor: "rgba(0,0,0,0.35)" },
  sheet: { borderTopLeftRadius: 24, borderTopRightRadius: 24, backgroundColor: theme.white,
    padding: 19, maxHeight: "85%", paddingBottom: 28 },
  sheetTop: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  close: { fontSize: 23, color: theme.muted, padding: 8 },
  optionGroup: { marginVertical: 14, paddingBottom: 8, borderBottomColor: theme.border, borderBottomWidth: 1 },
  choiceRow: { paddingVertical: 13, flexDirection: "row", alignItems: "center", gap: 12 },
  choiceCircle: { width: 27, fontSize: 19, color: theme.pinkDark }
});
