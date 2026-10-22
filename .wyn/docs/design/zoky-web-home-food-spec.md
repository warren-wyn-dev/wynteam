
## Storefront header update (Founder, 2026-10-22, after staging review)
- Header: `ชื่อร้าน · ที่อยู่ร้าน` on one line (address ellipsised).
- Removed: menu count, delivery fee, "เปิดรับออเดอร์"/"เปิดอยู่" line. The closed badge and closed box remain.
- Meta: `⭐ rating (count)` (real reviews only; "ร้านใหม่" when none) · ZOKY scooter icon + distance (customer default address → store pin, straight line) · delivery minutes = store prep time + ride time (~22 km/h + 5 min). Minutes are shown only when the store set prep times and a distance is known.
- Signed-out storefront: name · address only, because the public catalog has no ratings, prep times or customer location. Adding them would need a DB change and a separate approval.
- Scooter icon: inline SVG `ZokyScooterIcon` (pink body, gold box), with no network request.
