# Product Task — WYN-114

Status: **QA FAIL (2026-09-06)** — โค้ด Dart ที่แก้ถูกต้อง แต่พบว่า Vercel hosting ไม่มี SPA rewrite เลย ทุก path นอกจาก `/` ได้ HTTP 404 ตรงๆ (ดู "## AI QA & Security Output" ท้ายไฟล์ + bug report `.wyn/tasks/bugs/WYN-114-vercel-404-no-spa-rewrite.md`) ส่งต่อ AI Debug Engineer
Owner: AI Product Manager
Feature: Share Link ชี้โดเมนจริง (ค้างจาก Beta3 Security Audit item A-7)
Goal: ให้ปุ่มแชร์ (Drop/Pop/Club/ClubPost/Profile) ส่งลิงก์ที่เปิดได้จริง แทนโดเมนปลอมที่ไม่มีอยู่จริง
Target User: ทุกคนที่ได้รับลิงก์ที่ผู้ใช้ WYN แชร์มา (ทั้งคนที่มี WYN อยู่แล้วและคนที่ไม่เคยเห็น WYN มาก่อน — กลุ่มหลังสำคัญกว่าเพราะเชื่อมกับปัญหา growth ที่ WYN-112 กำลังสืบอยู่)
Problem: ตรวจโค้ดพบว่ามี **5 จุด** ที่ generate share link ด้วยโดเมนปลอม `https://wyn.app/...` ซึ่งไม่มี DNS จริง (คลิกแล้วเบราว์เซอร์ขึ้น error "ไม่พบเว็บไซต์" ทันที):

| ฟังก์ชัน | ไฟล์ | Path ที่ generate |
|---|---|---|
| `dropShareLink()` | `drop_detail_screen.dart` | `/drop/$id` |
| `popShareLink()` | `pop_clip_view.dart` | `/pop/$id` |
| `clubShareLink()` | `club_page.dart` | `/club/$id` |
| `clubPostShareLink()` | `club_post_detail_screen.dart` | `/club-post/$id` |
| `profileShareLink()` | `view_profile_screen.dart` | `/@$username` |

**พบข้อเท็จจริงใหม่ที่ไม่มีในเอกสาร A-7 เดิม** (A-7 เดิมสมมติว่าปัญหาคือ "โดเมนผิด" อย่างเดียว): ตรวจ `app/lib/main.dart` แล้วพบว่า **แอปไม่มีระบบ path-based routing เลย** — `MaterialApp(home: const AuthGate())` ตายตัว ไม่มี `GoRouter`, ไม่มี `onGenerateRoute`, ไม่มีจุดไหนอ่าน `Uri.base.path` (มีแค่ `Uri.base.queryParameters` สำหรับอ่าน UTM parameter ของ WYN-077 เท่านั้น ไม่เกี่ยวกับ path)

**ผลที่ตามมา**: ต่อให้แก้โดเมนเป็น `https://wynos.online/drop/$id` ที่มี DNS จริงแล้ว **การเปิดลิงก์นั้นจะไม่พาไปที่โพสต์นั้นเลย** — Flutter Web จะ boot แอปแล้วโชว์หน้า `AuthGate` (login/home) เหมือนเปิด `wynos.online` เฉยๆ ทุกครั้ง ไม่ว่า path จะเป็นอะไรก็ตาม เพราะไม่มีอะไรอ่านค่า path นั้นเลย — เปลี่ยนจาก "ลิงก์เปิดไม่ได้" (dead domain) เป็น "ลิงก์เปิดได้แต่ไปที่หน้าแรกเสมอ ไม่ใช่โพสต์ที่แชร์มา" (ยังดีกว่าเดิม แต่ยังไม่ใช่สิ่งที่คำว่า "แชร์ลิงก์นี้" สื่อถึงจริงๆ)

ข้อดี: แอปมีระบบ **Guest Browsing** อยู่แล้ว (WYN-072, Anonymous Sign-In) ที่ทำให้คนที่ไม่มีบัญชียัง reach `RootShell` ได้โดยไม่ต้อง login เต็มรูปแบบ — แปลว่าถ้าจะทำ deep-link จริงในอนาคต ไม่มี login wall บล็อกอยู่ก่อนแล้ว

Requirements:

**Tier 1 — แก้โดเมนอย่างเดียว (ขอบเขตเดิมที่ Founder อนุมัติ)**
- เปลี่ยนโดเมนใน 5 ฟังก์ชันข้างบนจาก `https://wyn.app` → `https://wynos.online`
- ไม่แตะ routing/navigation ใดๆ ในแอป

**Tier 2 — Deep Linking จริง (ขอบเขตใหม่ที่เพิ่งค้นพบว่าจำเป็นถ้าอยากให้ลิงก์พาไปถูกที่จริง — ยังไม่อนุมัติ)**
- เพิ่มจุดอ่าน `Uri.base.path` ตอนแอป boot บนเว็บ, แปลงเป็น route เป้าหมาย (`/drop/:id` → เปิด `DropDetailScreen`, ทำนองเดียวกันอีก 4 path)
- ต้องตัดสินใจ UX ร่วมกับ AI Design: ระหว่างรอ resolve target (auth/guest state + query ข้อมูลโพสต์) จะโชว์อะไร, โพสต์ถูกลบ/private จะขึ้นข้อความอะไร, คนที่ไม่มีบัญชีจะเห็นเป็น guest หรือโดนชวนสมัครก่อน
- เป็นงานที่แตะ core navigation ของแอป (`main.dart`) — ต้องระวัง regression กับ flow ปกติ (ปุ่ม back, deep-link ซ้อน navigation stack ที่มีอยู่)

Acceptance Criteria (Tier 1):
- แปะ `dropShareLink('x')`/`popShareLink('x')`/`clubShareLink('x')`/`clubPostShareLink('x')`/`profileShareLink('x')` ในเบราว์เซอร์ → ต้องเปิดเว็บ `wynos.online` ได้จริง (ไม่ error "ไม่พบเว็บไซต์" อีกต่อไป)
- ไม่กระทบพฤติกรรมปุ่มแชร์เดิม (ยังคัดลอก/ส่งข้อความเดียวกัน เปลี่ยนแค่ค่าโดเมนในสตริง)
- `flutter analyze`/`flutter test` ผ่านปกติ

Dependencies: ไม่มี — ไม่ต้องรอ WYN-112/WYN-113
Priority: **Tier 1 = P1 (ทำได้ทันที)**, **Tier 2 = P2 (ต้องตัดสินใจแยก ไม่ใช่ส่วนหนึ่งของงานที่อนุมัติวันนี้)**
Risks: Tier 1 ความเสี่ยงต่ำมาก (แก้ string literal 5 จุด ไม่มี logic เปลี่ยน) — ความเสี่ยงเดียวคือถ้า Founder เข้าใจว่า "แก้แล้วลิงก์จะพาไปโพสต์นั้นเลย" ทั้งที่จริงยังไม่ใช่ (ต้องสื่อสารให้ชัดตามที่เขียนไว้ข้างบน กันความคาดหวังผิด)

Recommendation: **ทำ Tier 1 ทันทีตามที่อนุมัติ** — คุ้มค่าแน่นอน (ลิงก์ที่เปิดไม่ได้เลย เป็น "เปิดได้แต่ไม่ตรงจุด" ดีขึ้นชัดเจน ต้นทุนต่ำมาก ไม่มีความเสี่ยง) — ส่วน Tier 2 (deep-linking จริง) แยกเป็นการตัดสินใจเชิง roadmap ต่างหาก เพราะเป็นงานใหญ่กว่าที่คิดไว้เดิมมาก และควรพิจารณาคู่กับผล WYN-112 (ถ้าปัญหาจริงคือคนไม่คลิกลิงก์เลย deep-linking จะยังช่วยไม่ได้จนกว่าจะมีคนคลิกก่อน)

Handoff: Tier 1 → ส่งตรงไป **AI Coding** ได้เลย (ไม่ต้องผ่าน AI Design เพราะไม่มีการเปลี่ยนแปลงด้าน UI/visual ใดๆ เป็นการแก้ string constant ล้วนๆ) → AI QA & Security ตรวจ → AI Deploy & DevOps

## AI Coding Output (2026-09-06) — Tier 1

Implementation: เปลี่ยนโดเมนใน 5 ฟังก์ชัน share link จาก `https://wyn.app` → `https://wynos.online` พร้อมอัปเดต doc comment เดิม (ที่เขียนไว้ว่า "revisit once Founder confirms a real domain" — เงื่อนไขนั้นเกิดขึ้นแล้ว) ให้บอกสถานะจริงและระบุชัดว่านี่คือ Tier 1 เท่านั้น ยังไม่ใช่ deep-link จริง กันคนอ่านโค้ดในอนาคตเข้าใจผิด

Files Changed:
- `app/lib/features/drop/presentation/drop_detail_screen.dart` — `dropShareLink()`
- `app/lib/features/pop/presentation/widgets/pop_clip_view.dart` — `popShareLink()`
- `app/lib/features/club/presentation/club_page.dart` — `clubShareLink()`
- `app/lib/features/club/presentation/club_post_detail_screen.dart` — `clubPostShareLink()`
- `app/lib/features/profile/presentation/view_profile_screen.dart` — `profileShareLink()`

(ทั้ง 5 ไฟล์แก้แค่ string literal 1 บรรทัด + comment เหนือมัน ไม่แตะโค้ดอื่นเลย)

Reason: ตาม Product spec Tier 1 — โดเมนปลอมไม่มี DNS จริง ตอนนี้ชี้โดเมนจริงที่ deploy อยู่แล้ว (`wynos.online`, ใช้ค่าเดียวกับที่ WYN-113 ใช้ใน `og:url` ไปแล้ว)

Tests: **ไม่มี test อ้างอิงฟังก์ชันเหล่านี้เลย** (grep `app/test/` หา `ShareLink`/`wyn.app` ไม่เจอ) — จึงไม่มี test ที่ต้องแก้ และไม่มีความเสี่ยง regression จาก test suite เดิม — ตรวจ diff ด้วยตาเทียบ pattern ที่ถูกต้อง (string literal + `$variable` interpolation) ด้วย Python regex แล้วผ่านครบทั้ง 5 จุด

Build: **ยืนยันเองไม่ได้เต็มรูปแบบ** — sandbox นี้ไม่มี Flutter SDK เหมือนรอบ WYN-113 — ความเสี่ยงต่ำมากเพราะเป็นการแก้ string literal ล้วนๆ ไม่มีการเปลี่ยน syntax/type/import ใดๆ (ตรวจ diff แล้วยืนยันว่าเปลี่ยนแค่เนื้อใน `'...'` กับ comment เท่านั้น) — **AI QA & Security ควรรัน `flutter analyze`/`flutter test` จริงอย่างน้อยครั้งก่อน PASS**

Known Issues:
- Tier 1 ไม่ทำให้ลิงก์พาไปโพสต์ที่ถูกต้อง (ตามที่ระบุไว้ใน Product spec) — เปิดลิงก์แล้วจะเจอหน้าแรกของแอปเสมอ ไม่ใช่บั๊ก แต่เป็นข้อจำกัดที่ทราบอยู่แล้วของขอบเขตงานนี้ (Tier 2 ที่ยังไม่อนุมัติจะแก้จุดนี้)
- ไม่ได้แตะ `io.wyn.app://login-callback` (native OAuth URL scheme ใน `auth_repository.dart`/`README.md`) เพราะเป็นคนละเรื่องกัน (custom URL scheme identifier สำหรับ native app ไม่ใช่ web domain สำหรับ share link) — ตรวจแล้วว่าไม่เกี่ยวข้องกับ scope นี้

Handoff: ส่งต่อ **AI QA & Security** — ตรวจ `flutter analyze`/`flutter test` ผ่านจริง + สุ่มเปิดลิงก์ตัวอย่าง (เช่น `https://wynos.online/drop/test123`) ยืนยันว่าเว็บเปิดได้จริง (ไม่ error "ไม่พบเว็บไซต์") ก่อนถือว่าเสร็จ — ย้ำ QA ว่า Acceptance Criteria ของ Tier 1 คือ "ลิงก์เปิดเว็บได้" ไม่ใช่ "ลิงก์พาไปโพสต์ที่ถูกต้อง" (เก็บไว้ใน Tier 2)

## AI QA & Security Output (2026-09-06)

Feature: WYN-114 Tier 1 — share link domain fix (5 ฟังก์ชัน)

Environment: sandbox นี้มี network egress ถึง `wynos.online` จริง (ต่างจากบางรอบก่อนหน้า) — ใช้ `curl` ตรวจ production โดยตรงได้เลย ไม่ต้องพึ่ง Facebook Sharing Debugger

Test Cases:
1. Scope check: diff เทียบ `origin/main` จำกัดแค่ 5 ไฟล์ที่ระบุ ไม่มีไฟล์อื่นถูกแตะ
2. Secret exposure scan ทั้ง diff
3. ตรวจโค้ดแต่ละ 5 จุดว่า path/โดเมนตรงตาม spec เป๊ะ (`/drop/`, `/pop/`, `/club/`, `/club-post/`, `/@username`)
4. **ทดสอบจริงกับ production ปัจจุบัน (ก่อน deploy การเปลี่ยนแปลงนี้ด้วยซ้ำ — เพราะโดเมน `wynos.online` deploy อยู่แล้วจาก WYN-113)**: curl ทุก path pattern ที่ 5 ฟังก์ชันจะ generate จริง

Passed: 1, 2, 3 — โค้ดที่แก้ถูกต้องตรงสเปกทุกจุด ไม่มี secret รั่ว ไม่กระทบไฟล์อื่น

Failed: **4 — พบปัญหาจริงที่ Product/Coding ไม่ได้คาดไว้**

Severity: **Medium** (ไม่ใช่ security bug, ไม่ทำให้แอปพัง แต่ acceptance criteria หลักของงานนี้ไม่เป็นจริง)

Reproduction Steps:
```
curl -I https://wynos.online/drop/test123
curl -I https://wynos.online/pop/test123
curl -I https://wynos.online/club/test123
curl -I https://wynos.online/club-post/test123
curl -I https://wynos.online/@testuser
```

Expected: ตาม Product spec ที่เขียนไว้ (อ้างอิงจากที่ AI Product Manager วิเคราะห์โค้ด Flutter แล้วสรุปว่า "จะ boot แอปแล้วโชว์หน้า AuthGate เหมือนเปิด wynos.online เฉยๆ") — คือ**อย่างน้อยควรเห็นหน้าแอป** (ต่อให้ไม่ใช่โพสต์ที่ถูกต้อง)

Actual: **ทุก path ข้างต้นได้ `HTTP 404` จาก Vercel ตรงๆ** (`x-vercel-error: NOT_FOUND`, body เป็น "The page could not be found / NOT_FOUND" ข้อความดิบจาก Vercel platform เอง) — **ไม่ถึงขั้น boot Flutter app ด้วยซ้ำ** เพราะ Vercel เป็น static hosting ที่ serve เฉพาะไฟล์ที่ path ตรงตัวเป๊ะ ไม่มี catch-all rewrite ไปที่ `index.html` เลย (ตรวจแล้วว่าไม่มี `vercel.json` ในโปรเจกต์ และ `deploy-web.yml` ไม่ได้ตั้งค่า rewrite ใดๆ ตอน deploy)

**สรุปสิ่งที่ค้นพบ**: สมมติฐานที่ Product spec ใช้ตอนวิเคราะห์ (อ่านแค่โค้ด Flutter ฝั่ง client ว่าไม่มี path routing) **ถูกครึ่งเดียว** — ที่จริงปัญหาลึกกว่านั้นอีกชั้น: แม้จะแก้ Flutter ให้มี routing ในอนาคต (Tier 2) ก็ยังไม่พอ เพราะ **ชั้น hosting (Vercel) เองก็ block ไม่ให้ path อื่นนอกจาก `/` ไปถึง Flutter app ตั้งแต่แรก** ต้องแก้ทั้งสองชั้น: (1) Vercel rewrite ให้ทุก path serve `index.html` แทนที่จะ 404 (2) ค่อยให้ Flutter อ่าน path เพื่อ deep-link จริง (Tier 2)

**ผลต่อ Tier 1**: ข้อความ Acceptance Criteria เดิม ("เปิดเว็บได้จริง ไม่ error 'ไม่พบเว็บไซต์' อีกต่อไป") **ยังไม่จริง 100%** — จาก DNS-level error (เดิม, "ไม่พบเว็บไซต์" ระดับเบราว์เซอร์) กลายเป็น HTTP-level 404 (ใหม่, ยังเป็น "ไม่พบหน้านี้" อยู่ดี แต่มาจากเซิร์ฟเวอร์แทนที่จะเป็น DNS) — ดีขึ้นจริงในแง่ที่โดเมนพิสูจน์ได้ว่ามีตัวตนจริง แต่ผู้ใช้ปลายทางยังเห็น error อยู่ดี ไม่ใช่สิ่งที่ Founder น่าจะคาดหวังจากคำว่า "แก้ share link ให้ใช้งานได้"

Security Findings: ไม่พบ — ไม่มี secret รั่ว ไม่มี XSS/injection (เนื้อหา static string ล้วนๆ)

Recommendation:
- **FAIL การเทส 404** — ต้องเพิ่ม Vercel rewrite (`app/vercel.json` มาตรฐาน SPA catch-all: `{"rewrites":[{"source":"/(.*)","destination":"/index.html"}]}`) เป็นงานเพิ่มเติมก่อนถือว่า Tier 1 เสร็จจริงตามที่ตั้งใจไว้
- โค้ด Dart ที่แก้ไปแล้ว (5 จุด) **ถูกต้องและไม่ต้องแก้เพิ่ม** — ปัญหาอยู่ที่ config การ deploy/hosting คนละชั้นกัน ไม่ใช่ bug ในโค้ดที่ตรวจรอบนี้
- ส่งต่อ AI Debug Engineer เพื่อเพิ่ม Vercel rewrite config (root cause ทราบแน่ชัดแล้ว ไม่ต้อง investigate เพิ่ม) — ดู bug report `.wyn/tasks/bugs/WYN-114-vercel-404-no-spa-rewrite.md`

Final Status: **FAIL**
