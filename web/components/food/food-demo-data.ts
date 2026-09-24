/* Sample-only content for the developer UI preview.
   Before public launch, replace these records with merchant-owned data and
   properly licensed merchant photography from the Food backend. */
export type FoodRestaurant = {
  id: string;
  name: string;
  category: string;
  subtitle: string;
  rating: number;
  reviewCount: number;
  deliveryMins: string;
  deliveryFee: number;
  minimum: number;
  image: string;
  emoji: string;
  open: boolean;
  featured?: boolean;
};
export type FoodMenuItem = {
  id: string;
  restaurantId: string;
  name: string;
  description: string;
  price: number;
  image: string;
  emoji: string;
  popular?: boolean;
};
export type FoodCartLine = {
  id: string;
  itemId: string;
  quantity: number;
  spice: string;
  extras: string[];
  note: string;
};
export type FoodDemoOrder = {
  id: string;
  label: string;
  menuIds: string[];
  total: number;
  date: string;
  step: number;
};

const photo = (id: string, width = 850) =>
  "https://images.unsplash.com/" + id + "?auto=format&fit=crop&w=" + width + "&q=78";

export const FOOD_RESTAURANTS: FoodRestaurant[] = [
  { id: "somtam", name: "ตำแซ่บเดโม่", category: "ส้มตำ · อาหารอีสาน", subtitle: "รสจัดจ้าน แซ่บถึงใจ", rating: 4.8, reviewCount: 320, deliveryMins: "25–35", deliveryFee: 15, minimum: 80, image: photo("photo-1547592180-85f173990554"), emoji: "🥗", open: true, featured: true },
  { id: "chicken", name: "ไก่ทอดเดโม่", category: "ไก่ทอด · อาหารจานด่วน", subtitle: "กรอบนอกนุ่มใน ทอดใหม่ทุกวัน", rating: 4.7, reviewCount: 86, deliveryMins: "20–30", deliveryFee: 10, minimum: 50, image: photo("photo-1626082927389-6cd097cdc6ec"), emoji: "🍗", open: true, featured: true },
  { id: "kitchen", name: "ครัวเดโม่", category: "อาหารตามสั่ง · ข้าว", subtitle: "อิ่มอร่อยง่าย ๆ ได้ทุกวัน", rating: 4.6, reviewCount: 148, deliveryMins: "30–40", deliveryFee: 20, minimum: 70, image: photo("photo-1569718212165-3a8278d5f624"), emoji: "🍜", open: true },
  { id: "tea", name: "ชานมเดโม่", category: "เครื่องดื่ม · ของหวาน", subtitle: "เติมความสดชื่นระหว่างวัน", rating: 4.9, reviewCount: 74, deliveryMins: "15–25", deliveryFee: 10, minimum: 45, image: photo("photo-1544145945-f90425340c7e"), emoji: "🧋", open: true },
  { id: "noodles", name: "ก๋วยเตี๋ยวเดโม่", category: "เส้น · ก๋วยเตี๋ยว", subtitle: "ซุปหอม เครื่องแน่น", rating: 4.5, reviewCount: 68, deliveryMins: "25–40", deliveryFee: 15, minimum: 65, image: photo("photo-1569718212165-3a8278d5f624"), emoji: "🍜", open: false },
];

export const FOOD_MENU: FoodMenuItem[] = [
  { id: "tam-pa", restaurantId: "somtam", name: "ตำป่า", description: "เส้นมะละกอ ผักสด เครื่องแน่น เผ็ดจัดจ้าน", price: 75, image: photo("photo-1547592180-85f173990554"), emoji: "🥗", popular: true },
  { id: "tam-thai", restaurantId: "somtam", name: "ตำไทย", description: "สามรสกลมกล่อม ถั่วลิสง กุ้งแห้ง", price: 60, image: photo("photo-1512621776951-a57141f2eefd"), emoji: "🥗", popular: true },
  { id: "tam-pu", restaurantId: "somtam", name: "ตำปูปลาร้า", description: "ปลาร้าหอม น้ำยำรสเข้มข้น", price: 65, image: photo("photo-1547592180-85f173990554"), emoji: "🥗" },
  { id: "fried", restaurantId: "chicken", name: "ไก่ทอดกรอบ", description: "ไก่ทอดชิ้นใหญ่ กรอบนอกฉ่ำใน", price: 59, image: photo("photo-1626082927389-6cd097cdc6ec"), emoji: "🍗", popular: true },
  { id: "wings", restaurantId: "chicken", name: "ปีกไก่ทอด", description: "ปีกไก่ทอดหมักเครื่องเทศ", price: 69, image: photo("photo-1626082927389-6cd097cdc6ec"), emoji: "🍗" },
  { id: "sticky", restaurantId: "chicken", name: "ข้าวเหนียว", description: "ข้าวเหนียวนุ่มร้อน ๆ", price: 15, image: photo("photo-1512058564366-18510be2db19"), emoji: "🍚" },
  { id: "krapao", restaurantId: "kitchen", name: "ข้าวกะเพราไข่ดาว", description: "ผัดกะเพรารสจัด เสิร์ฟกับไข่ดาว", price: 65, image: photo("photo-1569718212165-3a8278d5f624"), emoji: "🍳", popular: true },
  { id: "rice", restaurantId: "kitchen", name: "ข้าวผัด", description: "ข้าวผัดหอมกระทะ เสิร์ฟร้อน ๆ", price: 60, image: photo("photo-1512058564366-18510be2db19"), emoji: "🍛" },
  { id: "milk-tea", restaurantId: "tea", name: "ชานมไข่มุก", description: "ชานมเข้มข้น ไข่มุกเคี้ยวหนึบ", price: 55, image: photo("photo-1544145945-f90425340c7e"), emoji: "🧋", popular: true },
  { id: "matcha", restaurantId: "tea", name: "มัทฉะลาเต้", description: "มัทฉะหอมละมุน หวานกำลังดี", price: 65, image: photo("photo-1515823064-d6e0c04616a7"), emoji: "🍵" },
  { id: "noodles", restaurantId: "noodles", name: "ก๋วยเตี๋ยวน้ำ", description: "น้ำซุปกลมกล่อม เครื่องแน่น", price: 60, image: photo("photo-1569718212165-3a8278d5f624"), emoji: "🍜" },
];
export const FOOD_CATEGORIES = [
  { id: "all", label: "ทั้งหมด", emoji: "🍴" },
  { id: "somtam", label: "ส้มตำ", emoji: "🥗" },
  { id: "chicken", label: "ไก่ทอด", emoji: "🍗" },
  { id: "kitchen", label: "อาหารจานเดียว", emoji: "🍳" },
  { id: "noodles", label: "ก๋วยเตี๋ยว", emoji: "🍜" },
  { id: "tea", label: "เครื่องดื่ม", emoji: "🧋" },
  { id: "dessert", label: "ของหวาน", emoji: "🧁" },
  { id: "healthy", label: "อาหารสุขภาพ", emoji: "🥬" },
];
export const FOOD_ADDONS = [
  { id: "rice", label: "ขนมจีน", price: 10 },
  { id: "pork", label: "แคบหมู", price: 10 },
  { id: "egg", label: "ไข่ต้ม", price: 15 },
  { id: "noodle", label: "เส้นเพิ่ม", price: 10 },
];
export const FOOD_ADDRESSES = [
  { id: "dorm", title: "หอพักของฉัน", detail: "123 ถ.ในเมือง อ.เมือง จ.มหาสารคาม 44000" },
  { id: "home", title: "บ้าน", detail: "45 ถ.ตัวอย่าง อ.เมือง จ.มหาสารคาม 44000" },
  { id: "university", title: "มหาวิทยาลัย", detail: "บริเวณประตู 1 มหาวิทยาลัยมหาสารคาม" },
];
export const formatFoodBaht = (amount: number) => "฿" + amount.toLocaleString("th-TH");
export const restaurantFor = (id: string) => FOOD_RESTAURANTS.find((r) => r.id === id) ?? FOOD_RESTAURANTS[0];
export const menuFor = (id: string) => FOOD_MENU.find((item) => item.id === id) ?? FOOD_MENU[0];
