/// Thai UI strings (Thai-only like the web app; ZOKY-100 Q13 still open).
///
/// Kept in one place so they can move to gen-l10n ARB files if the Founder
/// approves more languages. Copy mirrors web/components/food/*.tsx with
/// "WYNOS Food" rebranded to "ZOKY" -- do not invent new copy here.
abstract final class ZokyStrings {
  static const String appName = 'ZOKY';

  // Bottom navigation (web: wynos-food-developer-app.tsx, nav items).
  static const String navHome = 'หน้าหลัก';
  static const String navOrders = 'ออเดอร์';
  static const String navMessages = 'ข้อความ';
  static const String navAccount = 'บัญชี';

  // Common.
  static const String cancel = 'ยกเลิก';
  static const String done = 'เสร็จ';
  static const String retry = 'ลองอีกครั้ง';
  static const String back = 'กลับ';
  static const String share = 'แชร์';
  static const String more = 'เพิ่มเติม';
  static const String close = 'ปิด';

  // Home.
  static const String deliverTo = 'ส่งถึง';
  // Header heart button + sheet title (web: aria-label / Sheet "ร้านโปรด").
  static const String favoriteStores = 'ร้านโปรด';
  // Placeholder until the favorite stores sheet ships (Home Phase 1 review).
  static const String comingSoon = 'เร็ว ๆ นี้';
  static const String searchHint = 'ค้นหาร้านหรือเมนูอาหาร';
  // Home Phase 2 hero card (copy from the Founder Home mockup, Phase 2).
  static const String heroFoodDelivery = 'FOOD DELIVERY';
  static const String heroTitle = 'อยากกินอะไรวันนี้?';
  // Same title with the mockup's line break (visual only; screen readers
  // get [heroTitle]).
  static const String heroTitleLines = 'อยากกินอะไร\nวันนี้?';
  static const String heroSubtitle = 'ของอร่อยใกล้คุณ เริ่มที่นี่';
  static const String heroSearchButton = 'ค้นหาของอร่อย';
  // Store search screen opened from the hero button. Empty-result copy is
  // a placeholder pending Founder review (not in the mockup or the web).
  static const String searchNoResultsTitle = 'ไม่พบร้านที่ค้นหา';
  static const String searchNoResultsBody = 'ลองค้นหาด้วยคำอื่น';
  static const String nearbyStores = 'ร้านใกล้คุณ';
  // Home Phase 3 "ดีลเด็ดวันนี้" (title and "ดูทั้งหมด" from the Founder
  // mockup). There is no backend yet, so every deal is sample data and the
  // UI must say so (Founder rule: no real promotions or discounts).
  static const String dealsTitle = 'ดีลเด็ดวันนี้';
  static const String seeAll = 'ดูทั้งหมด';
  static const String seeAllDeals = 'ดูทั้งหมด ดีลเด็ดวันนี้';
  static const String dealsDemoNote = 'ข้อมูลตัวอย่าง ยังไม่ใช่โปรโมชันจริง';
  static const String demoBadge = 'ตัวอย่าง';
  static const String demoDealPrefix = 'ตัวอย่างดีล';
  static const String demoDealDisclaimer = 'ตัวอย่าง — ยังไม่ใช่โปรโมชันจริง';
  // Home Phase 4 "ร้านอาหารแนะนำ" (title from the Founder mockup).
  static const String recommendedTitle = 'ร้านอาหารแนะนำ';
  static const String seeAllRecommended = 'ดูทั้งหมด ร้านอาหารแนะนำ';
  static const String allStoresTitle = 'ร้านอาหารทั้งหมด';
  static const String demoStorePrefix = 'ร้านตัวอย่าง';
  static const String saveFavoritePrefix = 'บันทึกร้านโปรด';
  static const String filterAll = 'ทั้งหมด';
  static const String filterFreeDelivery = 'ส่งฟรี';
  static const String filterPromo = 'มีโปรฯ';
  static const String filterNear = 'ใกล้ฉัน';
  static const String filterRating = 'เรตติ้ง 4.5+';
  static const String noStoresTitle = 'ยังไม่มีร้านในพื้นที่นี้';
  static const String noStoresBody =
      'ZOKY กำลังขยายพื้นที่ให้บริการ ลองเปลี่ยนที่อยู่จัดส่ง หรือกลับมาใหม่เร็วๆ นี้';
  static const String changeAddress = 'เปลี่ยนที่อยู่จัดส่ง';
  // Web: FoodLoadError (offline variant).
  static const String loadErrorTitle = 'โหลด ZOKY ไม่สำเร็จ';
  static const String offlineTitle = 'เชื่อมต่อไม่ได้';
  static const String offlineBody =
      'ตรวจสอบ Wi-Fi หรือเน็ตมือถือ แล้วลองอีกครั้ง ตะกร้าของคุณยังอยู่';

  // Store card / menu.
  static const String adLabel = 'โฆษณา';
  static const String closedLabel = 'ปิดอยู่';
  static const String newStore = 'ร้านใหม่';
  static const String soldOut = 'หมด';
  static const String deliveryFee = 'ค่าส่ง';
  static const String minutes = 'นาที';
  static const String viewCart = 'ดูตะกร้า';

  // Orders tab (web: OrdersPanel empty state).
  static const String ordersActive = 'กำลังดำเนินการ';
  static const String ordersHistory = 'ประวัติ';
  static const String noOrdersTitle = 'ยังไม่มีออเดอร์';
  static const String noOrdersBody =
      'ออเดอร์ที่กำลังทำจะแสดงที่นี่ ติดตามสถานะได้ตลอดจนถึงมือคุณ';
  static const String noHistoryTitle = 'ยังไม่มีประวัติการสั่ง';
  static const String noHistoryBody =
      'ออเดอร์ที่ส่งสำเร็จหรือยกเลิกจะแสดงที่นี่';
  static const String ordersPageTitle = 'ออเดอร์ของฉัน';
  static const String orderNow = 'สั่งอาหารเลย';

  // Messages tab (web: MessagesPanel placeholder, rebranded).
  static const String noMessagesTitle = 'ยังไม่มีข้อความ';
  static const String noMessagesBody1 =
      'การสนทนากับร้านและผู้จัดส่งจะแสดงที่นี่';
  static const String noMessagesBody2 = 'แชท ZOKY แยกจากแชท WYNOS';

  // Account tab.
  static const String profileSetupPrompt = 'ตั้งค่าโปรไฟล์ก่อนสั่งอาหาร';
  static const String orderHistory = 'ประวัติการสั่งอาหาร';
  static const String demoModeTitle = 'โหมดสาธิต';
  static const String demoModeBody =
      'ข้อมูลร้านและเมนูทั้งหมดเป็นข้อมูลตัวอย่าง ไม่ได้เชื่อมต่อระบบจริง';
  static const String openSourceLicenses = 'สัญญาอนุญาตโอเพนซอร์ส';

  // Demo-mode-only developer copy (not product copy; removed with demo
  // placeholders in ZOKY-105..107).
  static const String demoAddressLabel = 'ที่อยู่ตัวอย่าง (โหมดสาธิต)';
  static const String demoCartPending =
      'หน้าตะกร้าอยู่ระหว่างพัฒนา (โหมดสาธิต)';
}
