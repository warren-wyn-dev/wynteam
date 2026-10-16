import type { Store } from "./model";

// Synthetic fixtures only. These names, menus and prices are not live merchant offers.
// Native app must not infer production readiness from these values.
export const demoStores: Store[] = [
  {
    id: "demo-noodle",
    name: "ร้านก๋วยเตี๋ยวตัวอย่าง",
    description: "เมนูเส้นและอาหารจานเดียว (ข้อมูลจำลอง)",
    emoji: "🍜",
    deliveryFee: 15,
    open: true,
    menus: [
      {
        id: "demo-noodle-1", storeId: "demo-noodle", category: "ก๋วยเตี๋ยว",
        name: "ก๋วยเตี๋ยวน้ำใส", description: "เมนูสาธิต", price: 60, available: true,
        options: [
          { id: "spicy", name: "ระดับความเผ็ด", required: true, maxSelect: 1, choices: [
            { id: "none", name: "ไม่เผ็ด", price: 0 },
            { id: "mild", name: "เผ็ดน้อย", price: 0 },
            { id: "hot", name: "เผ็ดมาก", price: 0 }
          ] },
          { id: "extras", name: "เพิ่มของเสริม", required: false, maxSelect: 2, choices: [
            { id: "egg", name: "เพิ่มไข่", price: 10 },
            { id: "meat", name: "เพิ่มเนื้อ", price: 20 }
          ] }
        ]
      },
      {
        id: "demo-noodle-2", storeId: "demo-noodle", category: "ก๋วยเตี๋ยว",
        name: "ก๋วยเตี๋ยวต้มยำ", description: "สูตรทดลอง", price: 75, available: true,
        options: [{ id: "spicy", name: "ระดับความเผ็ด", required: true, maxSelect: 1, choices: [
          { id: "mild", name: "เผ็ดน้อย", price: 0 },
          { id: "medium", name: "เผ็ดกลาง", price: 0 },
          { id: "hot", name: "เผ็ดมาก", price: 0 }
        ] }]
      }
    ]
  },
  {
    id: "demo-chicken",
    name: "ร้านไก่ทอดตัวอย่าง",
    description: "เมนูไก่ทอดสำหรับทดสอบ UI",
    emoji: "🍗",
    deliveryFee: 20,
    open: true,
    menus: [
      { id: "demo-chicken-1", storeId: "demo-chicken", category: "ไก่ทอด",
        name: "ไก่ทอดกรอบ", description: "เมนูทดลอง", price: 89, available: true, options: [] },
      { id: "demo-chicken-2", storeId: "demo-chicken", category: "ของทานเล่น",
        name: "เฟรนช์ฟรายส์", description: "เมนูทดลอง", price: 49, available: true, options: [] }
    ]
  },
  {
    id: "demo-drinks",
    name: "ร้านเครื่องดื่มตัวอย่าง",
    description: "ชานมและเครื่องดื่ม (ข้อมูลจำลอง)",
    emoji: "🧋",
    deliveryFee: 12,
    open: false,
    menus: [
      { id: "demo-drinks-1", storeId: "demo-drinks", category: "เครื่องดื่ม",
        name: "ชานมไข่มุก", description: "เมนูทดลอง", price: 55, available: true, options: [
          { id: "size", name: "ขนาดแก้ว", required: true, maxSelect: 1, choices: [
            { id: "regular", name: "ปกติ", price: 0 },
            { id: "large", name: "ใหญ่", price: 15 }
          ] }
        ] }
    ]
  }
];
