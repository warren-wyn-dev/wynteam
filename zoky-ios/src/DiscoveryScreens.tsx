import React from "react";
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import type { Store } from "./model";
import { baht, theme } from "./theme";

type CommonProps = {
  stores: Store[];
  onStore: (store: Store) => void;
};
type HomeProps = CommonProps & {
  categories: string[];
  onBrowse: () => void;
  onCategory: (category: string) => void;
};
type BrowseProps = CommonProps & {
  categories: string[];
  query: string;
  onQuery: (value: string) => void;
  category: string;
  onCategory: (value: string) => void;
  onBack: () => void;
};

const emojiForCategory = (name: string): string => {
  if (name.includes("ก๋วยเตี๋ยว")) return "🍜";
  if (name.includes("ไก่")) return "🍗";
  if (name.includes("ทานเล่น")) return "🍟";
  if (name.includes("เครื่องดื่ม")) return "🧋";
  return "🍴";
};

function Eyebrow({ children }: { children: React.ReactNode }) {
  return <Text style={styles.eyebrow}>{children}</Text>;
}

function SectionHeader({ title, subtitle, action, onAction }: {
  title: string;
  subtitle?: string;
  action?: string;
  onAction?: () => void;
}) {
  return (
    <View style={styles.sectionHeader}>
      <View style={styles.flex}>
        <Text style={styles.sectionTitle}>{title}</Text>
        {subtitle ? <Text style={styles.caption}>{subtitle}</Text> : null}
      </View>
      {action && onAction ? (
        <Pressable onPress={onAction} accessibilityRole="button" accessibilityLabel={action}>
          <Text style={styles.sectionAction}>{action} ›</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

export function DiscoveryStoreCard({ store, onPress }: { store: Store; onPress: () => void }) {
  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      accessibilityLabel={"ดูร้าน " + store.name + (store.open ? "" : " ร้านปิดอยู่")}
      style={styles.storeCard}
    >
      <View style={styles.storeArtwork}>
        <Text style={styles.storeEmoji}>{store.emoji}</Text>
        <Text style={styles.artworkFoot}>FOOD</Text>
      </View>
      <View style={styles.flex}>
        <Text numberOfLines={1} style={styles.storeName}>{store.name}</Text>
        <Text numberOfLines={2} style={styles.caption}>{store.description}</Text>
        <View style={styles.storeStatusRow}>
          <View style={[styles.statusPill, !store.open && styles.statusClosed]}>
            <Text style={[styles.statusText, !store.open && styles.statusTextClosed]}>
              {store.open ? "เปิด • ตัวอย่าง" : "ปิด • ตัวอย่าง"}
            </Text>
          </View>
        </View>
        <Text style={styles.fee}>ค่าจัดส่งจำลอง {baht(store.deliveryFee)}</Text>
      </View>
      <Text style={styles.chevron}>›</Text>
    </Pressable>
  );
}

function CategoryStrip({ categories, selected, onCategory }: {
  categories: string[];
  selected?: string;
  onCategory: (category: string) => void;
}) {
  return (
    <ScrollView
      horizontal
      showsHorizontalScrollIndicator={false}
      contentContainerStyle={styles.categories}
      accessibilityLabel="หมวดหมู่อาหาร"
    >
      {categories.map((category) => {
        const active = selected === category;
        return (
          <Pressable
            key={category}
            onPress={() => onCategory(category)}
            accessibilityRole="button"
            accessibilityLabel={"เลือกหมวด " + category}
            accessibilityState={{ selected: active }}
            style={[styles.category, active && styles.categorySelected]}
          >
            <Text style={styles.categoryEmoji}>{category === "ทั้งหมด" ? "✨" : emojiForCategory(category)}</Text>
            <Text style={[styles.categoryLabel, active && styles.categoryLabelSelected]}>{category}</Text>
          </Pressable>
        );
      })}
    </ScrollView>
  );
}

export function HomeDiscovery({ stores, categories, onBrowse, onStore, onCategory }: HomeProps) {
  return (
    <View>
      <View style={styles.deliveryHint}>
        <Text style={styles.deliveryIcon}>⌖</Text>
        <View style={styles.flex}>
          <Text style={styles.deliveryLabel}>พื้นที่จัดส่ง</Text>
          <Text style={styles.deliveryValue}>ยังไม่ได้ตั้งที่อยู่ · โหมดทดลอง</Text>
        </View>
        <View style={styles.previewPill}><Text style={styles.previewPillText}>PREVIEW</Text></View>
      </View>

      <View style={styles.hero}>
        <View style={styles.heroTag}><Text style={styles.heroTagText}>✦  FOOD DELIVERY</Text></View>
        <View style={styles.heroRow}>
          <View style={styles.flex}>
            <Text style={styles.heroTitle}>อยากกินอะไร{"\n"}วันนี้?</Text>
            <Text style={styles.heroSubtitle}>ของอร่อยใกล้คุณ เริ่มที่นี่</Text>
          </View>
          <View style={styles.heroIllustration}><Text style={styles.heroEmoji}>🍱</Text></View>
        </View>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="ค้นหาร้านอาหาร"
          onPress={onBrowse}
          style={styles.heroButton}
        >
          <Text style={styles.heroButtonText}>ค้นหาของอร่อย</Text>
          <Text style={styles.heroButtonArrow}>→</Text>
        </Pressable>
      </View>

      <Pressable
        accessibilityRole="button"
        accessibilityLabel="แตะเพื่อค้นหาร้านอาหารและเมนู"
        onPress={onBrowse}
        style={styles.searchShortcut}
      >
        <Text style={styles.searchIcon}>⌕</Text>
        <Text style={styles.searchPlaceholder}>ค้นหาร้านอาหาร หรือชื่อเมนู</Text>
        <Text style={styles.searchArrow}>›</Text>
      </Pressable>

      <SectionHeader title="บริการของเรา" subtitle="ครบในที่เดียว เริ่มจากบริการอาหาร" />
      <View style={styles.servicesRow}>
        <Pressable
          onPress={onBrowse}
          accessibilityRole="button"
          accessibilityLabel="สั่งอาหาร"
          style={[styles.serviceTile, styles.foodTile]}
        >
          <View style={styles.serviceIconPink}><Text style={styles.serviceEmoji}>🍜</Text></View>
          <Text style={styles.serviceTitle}>สั่งอาหาร</Text>
          <Text style={styles.serviceDescription}>เลือกร้านและเมนู</Text>
          <Text style={styles.serviceAction}>ดูร้านอาหาร →</Text>
        </Pressable>
        <View style={[styles.serviceTile, styles.rideTile]}>
          <View style={styles.serviceIconGrey}><Text style={styles.serviceEmoji}>🚗</Text></View>
          <Text style={styles.serviceTitle}>เรียกรถ</Text>
          <Text style={styles.serviceDescription}>เดินทางสะดวก</Text>
          <Text style={styles.soon}>เร็ว ๆ นี้</Text>
        </View>
      </View>

      <SectionHeader
        title="เลือกหมวดหมู่"
        subtitle="แตะเพื่อดูรายการอาหารตัวอย่าง"
        action="ดูทั้งหมด"
        onAction={onBrowse}
      />
      <CategoryStrip categories={categories} onCategory={onCategory} />

      <View style={styles.promoCard}>
        <View style={styles.flex}>
          <Eyebrow>DESIGNED FOR YOU</Eyebrow>
          <Text style={styles.promoTitle}>เรียบง่ายในทุกมื้อ</Text>
          <Text style={styles.promoCopy}>ค้นหาร้าน เลือกเมนู และจัดตะกร้าได้ในไม่กี่ขั้นตอน</Text>
        </View>
        <Text style={styles.promoEmoji}>💗</Text>
      </View>

      <SectionHeader
        title="ร้านที่น่าสนใจ"
        subtitle="ข้อมูลร้านและราคาเป็นตัวอย่าง"
        action="ดูร้านทั้งหมด"
        onAction={onBrowse}
      />
      {stores.slice(0, 3).map((store) => (
        <DiscoveryStoreCard key={store.id} store={store} onPress={() => onStore(store)} />
      ))}
      <Text style={styles.disclaimer}>นี่เป็นต้นแบบแอป iOS ไม่มีการสั่งซื้อหรือชำระเงินจริง</Text>
    </View>
  );
}

export function BrowseDiscovery({
  stores, categories, query, onQuery, category, onCategory, onStore, onBack
}: BrowseProps) {
  return (
    <View>
      <Pressable onPress={onBack} accessibilityRole="button" accessibilityLabel="กลับหน้าแรก" style={styles.back}>
        <Text style={styles.backText}>‹  หน้าหลัก</Text>
      </Pressable>
      <Eyebrow>DISCOVER FOOD</Eyebrow>
      <Text style={styles.browseTitle}>ค้นหาของอร่อย</Text>
      <Text style={styles.browseDescription}>ร้านและเมนูตัวอย่างสำหรับทดลองบน iPhone</Text>
      <View style={styles.searchContainer}>
        <Text style={styles.searchIcon}>⌕</Text>
        <TextInput
          style={styles.searchInput}
          accessibilityLabel="ค้นหาร้านอาหารหรือชื่อเมนู"
          placeholder="ค้นหาร้านอาหาร หรือชื่อเมนู"
          placeholderTextColor={theme.muted}
          returnKeyType="search"
          value={query}
          onChangeText={onQuery}
        />
        {query ? (
          <Pressable accessibilityRole="button" accessibilityLabel="ล้างคำค้นหา" onPress={() => onQuery("")}>
            <Text style={styles.clearSearch}>✕</Text>
          </Pressable>
        ) : null}
      </View>
      <SectionHeader title="หมวดหมู่" subtitle="เลือกหมวดที่ต้องการ" />
      <CategoryStrip categories={categories} selected={category} onCategory={onCategory} />
      <SectionHeader
        title="ร้านอาหาร"
        subtitle={stores.length + " ร้านจากข้อมูลจำลอง"}
      />
      {stores.length ? stores.map((store) => (
        <DiscoveryStoreCard key={store.id} store={store} onPress={() => onStore(store)} />
      )) : (
        <View style={styles.emptyCard}>
          <Text style={styles.emptyEmoji}>🔍</Text>
          <Text style={styles.emptyTitle}>ไม่พบร้านที่ค้นหา</Text>
          <Text style={styles.caption}>ลองเปลี่ยนชื่อร้านหรือเลือกหมวดอื่น</Text>
          <Pressable
            onPress={() => { onQuery(""); onCategory("ทั้งหมด"); }}
            accessibilityRole="button"
            style={styles.resetButton}
          ><Text style={styles.resetText}>ล้างตัวกรอง</Text></Pressable>
        </View>
      )}
      <Text style={styles.disclaimer}>ข้อมูลนี้มีไว้เพื่อพัฒนา UI เท่านั้น ไม่ใช่รายการร้านค้าที่เปิดบริการจริง</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  eyebrow: { color: theme.pinkDark, fontSize: 10, letterSpacing: 1.5, fontWeight: "900" },
  sectionHeader: { flexDirection: "row", alignItems: "center", marginTop: 20, marginBottom: 12, gap: 8 },
  sectionTitle: { color: theme.ink, fontSize: 21, fontWeight: "800" },
  sectionAction: { color: theme.pink, fontWeight: "800", fontSize: 12 },
  caption: { color: theme.muted, fontSize: 12, lineHeight: 19, marginTop: 3 },
  deliveryHint: { flexDirection: "row", alignItems: "center", gap: 10, paddingBottom: 15 },
  deliveryIcon: { color: theme.pink, fontSize: 26, fontWeight: "700" },
  deliveryLabel: { fontSize: 11, color: theme.muted },
  deliveryValue: { color: theme.ink, fontWeight: "700", fontSize: 12, marginTop: 2 },
  previewPill: { borderRadius: 20, backgroundColor: theme.pinkLight, paddingHorizontal: 10, paddingVertical: 6 },
  previewPillText: { fontSize: 9, color: theme.pinkDark, fontWeight: "900", letterSpacing: 0.5 },
  hero: { borderRadius: 25, backgroundColor: theme.pink, padding: 21, overflow: "hidden" },
  heroTag: { borderWidth: 1, borderColor: "#FFB9D4", borderRadius: 30, paddingHorizontal: 11, paddingVertical: 6, alignSelf: "flex-start" },
  heroTagText: { color: theme.white, fontSize: 10, fontWeight: "900", letterSpacing: 1.2 },
  heroRow: { flexDirection: "row", alignItems: "center", minHeight: 145, gap: 8 },
  heroTitle: { color: theme.white, fontWeight: "900", fontSize: 29, lineHeight: 36, marginTop: 15 },
  heroSubtitle: { color: "#FFE8F2", marginTop: 8, fontSize: 12, lineHeight: 18 },
  heroIllustration: { width: 94, height: 94, borderRadius: 47, backgroundColor: "#FF5797",
    alignItems: "center", justifyContent: "center", borderWidth: 3, borderColor: "#FF82B1" },
  heroEmoji: { fontSize: 48 },
  heroButton: { borderRadius: 13, backgroundColor: theme.white, padding: 14, flexDirection: "row",
    alignItems: "center", justifyContent: "space-between" },
  heroButtonText: { color: theme.pinkDark, fontSize: 14, fontWeight: "800" },
  heroButtonArrow: { color: theme.pinkDark, fontSize: 22, lineHeight: 24 },
  searchShortcut: { backgroundColor: theme.white, borderRadius: 16, padding: 14, borderWidth: 1,
    borderColor: theme.border, marginTop: 16, flexDirection: "row", alignItems: "center", gap: 8 },
  searchIcon: { fontSize: 23, color: theme.pink, fontWeight: "600", lineHeight: 26 },
  searchPlaceholder: { flex: 1, fontSize: 13, color: theme.muted },
  searchArrow: { fontSize: 22, color: theme.muted },
  servicesRow: { flexDirection: "row", gap: 11 },
  serviceTile: { flex: 1, minHeight: 169, borderRadius: 19, padding: 14, borderWidth: 1, borderColor: theme.border },
  foodTile: { backgroundColor: theme.white },
  rideTile: { backgroundColor: "#F7F7FA" },
  serviceIconPink: { width: 47, height: 47, backgroundColor: theme.pinkLight, borderRadius: 14,
    alignItems: "center", justifyContent: "center", marginBottom: 9 },
  serviceIconGrey: { width: 47, height: 47, backgroundColor: "#EDECF0", borderRadius: 14,
    alignItems: "center", justifyContent: "center", marginBottom: 9 },
  serviceEmoji: { fontSize: 25 },
  serviceTitle: { fontSize: 16, fontWeight: "800", color: theme.ink },
  serviceDescription: { fontSize: 11, marginTop: 4, color: theme.muted },
  serviceAction: { fontSize: 11, fontWeight: "800", color: theme.pinkDark, marginTop: 15 },
  soon: { alignSelf: "flex-start", fontSize: 11, fontWeight: "700", color: theme.muted,
    backgroundColor: "#EAE9EF", borderRadius: 20, paddingHorizontal: 9, paddingVertical: 5, marginTop: 12 },
  categories: { paddingBottom: 4, gap: 9 },
  category: { borderRadius: 16, backgroundColor: theme.white, paddingHorizontal: 14, paddingVertical: 10,
    borderWidth: 1, borderColor: theme.border, alignItems: "center", minWidth: 84 },
  categorySelected: { backgroundColor: theme.pinkLight, borderColor: "#FDB9D3" },
  categoryEmoji: { fontSize: 25, marginBottom: 7 },
  categoryLabel: { color: theme.ink, fontSize: 11, fontWeight: "700" },
  categoryLabelSelected: { color: theme.pinkDark },
  promoCard: { backgroundColor: "#FFF0F5", borderColor: "#FDD2E2", borderWidth: 1, borderRadius: 18,
    padding: 16, marginTop: 20, flexDirection: "row", alignItems: "center", gap: 12 },
  promoTitle: { color: theme.ink, fontSize: 17, fontWeight: "800", marginTop: 4 },
  promoCopy: { fontSize: 11, color: theme.muted, lineHeight: 17, marginTop: 4 },
  promoEmoji: { fontSize: 41 },
  storeCard: { backgroundColor: theme.white, borderRadius: 18, padding: 12, flexDirection: "row",
    gap: 12, alignItems: "center", marginBottom: 11, borderWidth: 1, borderColor: theme.border },
  storeArtwork: { backgroundColor: theme.pinkLight, width: 94, height: 94, borderRadius: 15,
    alignItems: "center", justifyContent: "center" },
  storeEmoji: { fontSize: 40 },
  artworkFoot: { color: theme.pinkDark, fontSize: 8, fontWeight: "900", letterSpacing: 0.9, marginTop: 7 },
  storeName: { fontSize: 15, fontWeight: "800", color: theme.ink },
  storeStatusRow: { marginTop: 6, flexDirection: "row" },
  statusPill: { borderRadius: 20, backgroundColor: "#E9F8EF", paddingHorizontal: 8, paddingVertical: 4 },
  statusClosed: { backgroundColor: "#F2F0F3" },
  statusText: { fontSize: 10, fontWeight: "700", color: "#226D42" },
  statusTextClosed: { color: theme.muted },
  fee: { fontSize: 11, color: theme.muted, marginTop: 7, fontWeight: "600" },
  chevron: { color: theme.pink, fontSize: 22 },
  disclaimer: { fontSize: 11, lineHeight: 17, color: theme.muted, textAlign: "center", marginTop: 14, marginBottom: 6 },
  back: { alignSelf: "flex-start", paddingVertical: 9, marginBottom: 13 },
  backText: { color: theme.pinkDark, fontWeight: "800" },
  browseTitle: { color: theme.ink, fontSize: 27, fontWeight: "900", marginTop: 5 },
  browseDescription: { color: theme.muted, marginTop: 5, marginBottom: 18, fontSize: 13 },
  searchContainer: { backgroundColor: theme.white, borderWidth: 1, borderColor: theme.border, borderRadius: 14,
    paddingHorizontal: 14, flexDirection: "row", alignItems: "center", gap: 8, minHeight: 49 },
  searchInput: { flex: 1, color: theme.ink, fontSize: 13, paddingVertical: 11 },
  clearSearch: { color: theme.muted, fontSize: 17, paddingHorizontal: 4 },
  emptyCard: { backgroundColor: theme.white, borderRadius: 19, padding: 25, alignItems: "center" },
  emptyEmoji: { fontSize: 42, marginBottom: 10 },
  emptyTitle: { color: theme.ink, fontSize: 16, fontWeight: "800" },
  resetButton: { backgroundColor: theme.pinkLight, borderRadius: 10, paddingVertical: 10,
    paddingHorizontal: 15, marginTop: 13 },
  resetText: { color: theme.pinkDark, fontSize: 12, fontWeight: "800" }
});
