# Design Spec — WYN-050 (WYN Admin Dashboard)

Status: active
Owner: AI Design
อ้างอิง Product spec: `.wyn/tasks/backlog/WYN-050-admin-dashboard.md`
อ้างอิง Design system: `.wyn/docs/design/wyn-049-admin-foundation.md` (shadcn neutral base + WYN Cyan accent, ตัดสินใจไว้แล้ว ไม่คิดใหม่รอบนี้) — เพิ่ม `Badge` component ใหม่ 1 ตัว (ยังไม่มีใน `components/ui/` ของ WYN-049) ตามหลักการเดียวกัน (เขียนเองตาม shadcn source มาตรฐาน เพราะ `ui.shadcn.com` ยังบล็อกอยู่)

## Screen — Dashboard (`app/(admin)/page.tsx`, แทนที่ placeholder เดิม)

Purpose: ให้ Admin/Moderator เห็นภาพรวมสุขภาพแพลตฟอร์มทันทีที่เปิด WYN Admin โดยไม่ต้องเปิด SQL editor

User Flow:
1. Sign-in สำเร็จ → เข้าหน้า `/` (Dashboard) ทันที (ไม่เปลี่ยนจาก WYN-049)
2. เห็น stat card 12 ใบ จัดกลุ่มเป็น 4 หมวด โหลดพร้อมกันครั้งเดียวตอนเปิดหน้า (เรียก `admin_dashboard_metrics()` ครั้งเดียว)
3. กดปุ่ม "รีเฟรช" มุมขวาบน → เรียก RPC ใหม่ → อัปเดตตัวเลขทั้งหมดพร้อมกัน (ไม่มี auto-refresh ต่อเนื่องตามที่ Product ล็อกสโคปไว้)

Components:

**Header ของหน้า**: "แดชบอร์ด" (จัดการโดย `AdminHeader` เดิมจาก WYN-049 อัตโนมัติผ่าน `ADMIN_NAV_ITEMS` — ไม่ต้องแก้) + ปุ่ม "รีเฟรช" (`Icons: RefreshCw` จาก lucide-react, `variant="outline" size="sm"`) วางในหน้า content เอง (ไม่ใช่ header component เพราะ header เป็น shared component ข้ามทุกหน้า ปุ่มนี้เฉพาะ Dashboard)

**Stat Card** (component ใหม่ `components/admin/stat-card.tsx`, reuse `Card` เดิมจาก WYN-049):
- `CardHeader`: label ภาษาไทยของ metric (เช่น "ผู้ใช้ใหม่วันนี้") + icon เล็กมุมขวาบน (`lucide-react`, เลือกตามความหมาย metric)
- `CardContent`: ตัวเลขใหญ่ (`text-3xl font-bold tabular-nums` — `tabular-nums` กันตัวเลขขยับตำแหน่งเวลาเปลี่ยนเลขหลัก) + label ย่อยเล็กใต้ตัวเลข (เช่น "ใน 24 ชม.ล่าสุด") ถ้ามี
- Card ที่มี 2 ตัวเลข (Clubs, Reports) ใช้ layout แยก 2 คอลัมน์ในการ์ดเดียว (ตัวเลขหลัก + ตัวเลขรอง) ไม่ทำเป็น 2 การ์ดแยก (Product ระบุไว้ตรงๆ ว่าให้รวม)

**Grid Layout**: `grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4` แบ่งเป็น 4 section หัวข้อ (heading เล็ก `text-sm font-medium text-muted-foreground` เหนือแต่ละกลุ่ม การ์ด มิเรอร์ sidebar's section grouping mental model):

| Section | Card | ตัวเลขหลัก | ตัวเลขรอง | Icon |
|---|---|---|---|---|
| ผู้ใช้งาน | ผู้ใช้ใหม่ | New Users (24h) | — | `UserPlus` |
| ผู้ใช้งาน | DAU | Active users (1 วัน) | — | `Activity` |
| ผู้ใช้งาน | WAU | Active users (7 วัน) | — | `Activity` |
| ผู้ใช้งาน | MAU | Active users (30 วัน) | — | `Activity` |
| เนื้อหา | Drop | Drops (24h) | — | `Image` |
| เนื้อหา | ยอดดู Drop | Views (24h) | — | `Eye` |
| เนื้อหา | Club | Total clubs | +N วันนี้ | `Users` |
| การมีส่วนร่วม | ถูกใจ | Likes (24h) | — | `Heart` |
| การมีส่วนร่วม | คอมเมนต์ | Comments (24h) | — | `MessageCircle` |
| การมีส่วนร่วม | ReDrop | ReDrops (24h) | — | `Repeat2` |
| การมีส่วนร่วม | ข้อความ | Messages (24h) | — | `Mail` |
| รายงาน | รายงาน | Total reports | Pending (เด่น, สีต่างจากตัวเลขอื่น) | `Flag` |

**DAU/WAU/MAU disclaimer**: ใต้ 3 การ์ดนี้ (หรือ tooltip บน icon `Info` ข้าง header ของ section "ผู้ใช้งาน") ข้อความ: "นับจากผู้ใช้ที่มีกิจกรรมบนแพลตฟอร์ม (โพสต์/ถูกใจ/คอมเมนต์/ReDrop/ส่งข้อความ) ไม่ใช่จำนวนครั้งที่เปิดแอป" — **ต้องแสดงตลอดเวลาไม่ใช่ tooltip ที่ซ่อนไว้จนต้อง hover** (ตาม Product's Acceptance Criteria "มีคำอธิบายชัดเจน") ใช้ `<p className="text-xs text-muted-foreground mt-1">` ใต้ทั้ง 3 การ์ดในกลุ่มเดียวกันแทน — เขียนสั้นครั้งเดียวใต้ section heading ของ "ผู้ใช้งาน" แทนการซ้ำ 3 รอบใต้แต่ละการ์ด

**Reports card**: ตัวเลข pending ใช้สีต่างจากตัวเลขอื่น — **ถ้า pending > 0** ใช้สี `text-destructive` (แดง, เตือนว่าต้องดำเนินการ) **ถ้า pending = 0** ใช้สีปกติ (`text-foreground`, ไม่มีอะไรต้องเตือน) — ไม่ใช้ Badge/สีแดงตายตัวเสมอเพราะจะทำให้ Admin ชินกับสีแดงจนไม่รู้สึกว่าต้อง action จริง

Interactions:
- ปุ่มรีเฟรชระหว่างรอ: disabled + icon หมุน (`animate-spin`) — มิเรอร์ loading state ของปุ่มอื่นในแอปนี้ (`LoginForm`'s submit button, WYN-049)
- ไม่มี interaction อื่นบนการ์ด (ไม่ clickable, ไม่ link ไปหน้าอื่นในรอบนี้ — Reports card ไม่ลิงก์ไป Report Center เพราะ WYN-053 ยังไม่มี ป้องกันลิงก์ตายที่ดูเหมือนใช้งานได้)

States:
- **Loading (ครั้งแรก)**: skeleton grid (การ์ดเปล่าสีเทาจางๆ `animate-pulse`) แทนตัวเลขจริง 12 ใบ ตำแหน่งเดียวกับ layout จริงเป๊ะ (กัน layout shift ตอนโหลดเสร็จ)
- **Loaded**: ตัวเลขจริงทั้ง 12 การ์ด
- **Refreshing**: ตัวเลขเดิมยังแสดงอยู่ (ไม่ blank/skeleton ซ้ำ) แค่ปุ่มรีเฟรช disabled+spin จนกว่าจะเสร็จ
- **Error** (RPC ล้มเหลว): แทนที่ grid ทั้งหมดด้วยข้อความ error กลางจอ + ปุ่ม "ลองใหม่" (มิเรอร์ pattern เดิมของ `NotificationSettingsScreen`/`BlockedListScreen` ฝั่ง Flutter — ความสม่ำเสมอของ error-state UX ข้าม platform)

Responsive Behavior: Desktop-first ตาม WYN-049 — grid ปรับ 1 คอลัมน์ (มือถือ) → 2 คอลัมน์ (tablet) → 4 คอลัมน์ (desktop) ผ่าน Tailwind breakpoint มาตรฐาน (`md:`/`lg:`) ไม่ต้องออกแบบ breakpoint ใหม่

Accessibility: ตัวเลขใหญ่ใน `CardContent` มี label ที่ associate ผ่าน `aria-label` บน `Card` เอง (เช่น `aria-label="ผู้ใช้ใหม่วันนี้: 12 คน"`) ให้ screen reader อ่านค่า+ความหมายพร้อมกัน ไม่ใช่แค่ตัวเลขลอยๆ — ปุ่มรีเฟรชมี `aria-busy` ระหว่างโหลด

Design Rules:
- **ไม่มี card สำหรับ Storage/Errors/Server Health เลย** (ตามที่ Product ล็อกสโคปไว้ตรงๆ — ไม่ใส่เป็น "0"/"N/A" ที่ทำให้เข้าใจผิด)
- **ไม่มี graph/chart ในรอบนี้** (ตัวเลข ณ ปัจจุบันอย่างเดียว)
- ใช้ WYN Cyan (`--primary`) กับ icon ของแต่ละการ์ดเท่านั้น (ความสม่ำเสมอของ accent เดียวที่ WYN-049 วางไว้) ไม่ใช้สีอื่นนอกจาก destructive (แดง) สำหรับ pending reports > 0 โดยเฉพาะ

Handoff: AI Coding — RPC `admin_dashboard_metrics()` ต้องคืนโครงสร้างข้อมูลที่ map ตรงกับตาราง metric ด้านบนได้ตรงๆ (1 round-trip, 1 object ครอบคลุมทั้ง 12 การ์ด) — ฝั่ง client fetch ครั้งเดียวตอน mount (Server Component, ไม่ต้อง client-side loading state สำหรับการโหลดครั้งแรก) ส่วนปุ่มรีเฟรชเป็น client component ที่เรียก RPC ผ่าน browser client ซ้ำ (`router.refresh()` หรือเทียบเท่า เพื่อให้ Server Component fetch ใหม่)
