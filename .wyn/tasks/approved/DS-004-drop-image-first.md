# Product Task — DS-004

Status: approved (QA — PASS, 2026-08-16, audit-only — ไม่มีการแก้โค้ด) — 4th ของ 8 เฟส (DS-001 → DS-002 → DS-003 → **DS-004** → DS-005 → ... → DS-008)
Owner: AI Product Manager → AI Design (audit) → AI QA & Security (PASS)

Feature: Drop — image-first

Goal: ตรวจสอบว่าประสบการณ์ Drop (grid เรียกดู + create + detail) เป็น "image-first" จริงตามที่ DS-001's Recommendation ตั้งชื่อ task นี้ไว้ — ถ้ามีช่องว่างให้แก้ ถ้าไม่มีให้บันทึกผล audit ไว้แทนการแก้โค้ดที่ไม่จำเป็น

Target User: ผู้ใช้ WYN ทุกกลุ่ม (Drop เป็น 1 ใน 4 แท็บ Bottom Nav หลัก)

## Audit ผล (สำคัญ — เปลี่ยนขอบเขตงานนี้เหมือน DS-003)

อ่านทั้ง 4 ไฟล์ presentation ของ Drop (`drop_feed_screen.dart`, `widgets/drop_grid_tile.dart`, `drop_detail_screen.dart`, `create_drop_screen.dart`) แล้วพบว่า **feature นี้เป็น image-first อยู่แล้วทุกจุด ไม่มีช่องว่างที่ต้องแก้**:

| จุดตรวจ | ผล |
|---|---|
| Grid (DropFeedScreen) | 3-column grid, `crossAxisSpacing`/`mainAxisSpacing` แค่ 2px — เกือบไร้ช่องว่าง ภาพชิดกันแบบ image-first ที่แท้จริง ไม่มี border/card ล้อมแต่ละ tile |
| Grid tile (DropGridTile) | แค่ `Image.network` + scrim ไล่ระดับโปร่งแสงด้านล่างสำหรับตัวเลขไลค์ ไม่มี card/border/shadow เลย |
| Detail (DropDetailScreen) | รูป 1:1 full-bleed อยู่บนสุดของหน้าจอ ก่อนข้อมูลอื่นทั้งหมด — ไม่มี Card ล้อม ใช้ `Divider(height: 1)` คั่น header/comments อยู่แล้ว (แบบเดียวกับที่ DS-003 เพิ่งเพิ่มใน Home Feed — ยืนยันว่าภาษาภาพเดียวกันมีอยู่แล้วในโค้ดเบส) |
| Comment list | แถวเปล่า ไม่มี card ล้อมแต่ละคอมเมนต์ |
| Create (CreateDropScreen) | พื้นที่เลือกรูป 1:1 เป็นองค์ประกอบแรกสุดของหน้าจอ ก่อน caption field เสมอ |

**สรุป**: ไม่มีสิ่งใดต้องแก้ตาม literal ของชื่อ task นี้ — เกณฑ์ "image-first" satisfied ตั้งแต่ WYN-005 (Drop feature เดิม) อยู่แล้ว ไม่ใช่ผลจาก DS-001/DS-002/DS-003 (feature นี้ถูกออกแบบ image-first มาตั้งแต่ต้น)

จุดที่พิจารณาแล้ว **ตัดสินใจไม่ทำ** (เกินขอบเขต visual-layer ของ task นี้ / ความเสี่ยงสูงกว่าประโยชน์):
- **AppBar โปร่งใสซ้อนบนรูปในหน้า Detail** (แบบ Instagram/Unsplash) — เป็น pattern "image-first" ที่แรงกว่านี้จริง แต่ต้องมี scrim gradient ที่หัวจอ + ตรวจ contrast ปุ่ม back บนรูปทุกแบบ (สว่าง/มืด/สีเดียว) เป็น layout change ขนาดใหญ่กว่าที่ DS-001 กำหนดให้ task ย่อยควรเป็น (ต่างจาก DS-003's เส้นคั่นเส้นเดียว) ควรแยกเป็น task ใหม่ถ้า Founder ต้องการจริง ไม่ทำในรอบนี้เพราะยังไม่มี Design spec/screenshot approval รองรับ

Requirements: ไม่มี (audit-only)

Acceptance Criteria:
- [x] Grid ไม่มี card/border ล้อม tile
- [x] Detail screen: รูปเป็นองค์ประกอบแรกสุด full-bleed ไม่มี Card ล้อม
- [x] Create screen: พื้นที่รูปเป็นองค์ประกอบแรกสุด
- [x] ไม่มีการแก้โค้ดใดๆ ในรอบนี้ (ตามผล audit)

Dependencies: DS-001, DS-002, DS-003

Priority: กลาง

Risks: ไม่มี — ไม่มีการแก้โค้ด

Recommendation: อนุมัติแบบ audit-only ไม่ต้องแก้โค้ด ไปต่อ DS-005 (Club — community identity)

Handoff: ไม่มีการส่งต่อ AI Coding รอบนี้ (ไม่มีอะไรให้แก้) — ไปต่อ DS-005 โดยตรง

---

## QA Verification (2026-08-16)

```
Feature: DS-004 Drop image-first audit
Environment: Direct code read, no build/test needed (zero code changed)
Test Cases:
  1. Read all 4 Drop presentation files end-to-end, check for Card/BoxShadow/elevation/
     rounded-corner wrapping around images or list rows.
  2. Confirm image is the first visual element on both DropFeedScreen (grid) and
     DropDetailScreen (single image atop everything else).
  3. Confirm CreateDropScreen's image picker area is the first form element.
Passed: 3/3 -- zero gaps found, zero code changed, zero risk of regression.
Recommendation: Approve as audit-only. Continue to DS-005.
Final Status: PASS
```
