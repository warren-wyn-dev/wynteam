# WYNOS Design Reference — how to use this folder

## Reading order (numbered on purpose — follow it)

| File | What it is |
|---|---|
| `00-prototype.jsx` | **Read this first.** A working multi-screen app showing how everything connects: bottom nav, push navigation (Post Detail, Settings), the side menu overlay. This is the map of the app, not pixel-perfect detail for every screen. |
| `SPEC.md` | Design tokens (colors, fonts, spacing) used across the *entire* app. Read this second, before touching any individual screen. |
| `01-home.jsx` | Home feed — full detail, including empty state, sticky tabs, new-posts pill, double-tap-to-like, reply preview, verified badge. |
| `02-notifications.jsx` | Notifications, grouped by day, with type badges. |
| `03-search.jsx` | Search / Top 100 trending hashtags. |
| `04-drop.jsx` | Create-post compose screen (text-first, X/Threads-style). |
| `05-profile.jsx` | Profile — identity block, stats, posts as full rows (not an image grid). |
| `06-edit-profile.jsx` | Edit Profile — single-card field layout, focus-to-reveal helper text. |
| `07-post-detail.jsx` | Single post + full comment thread. |
| `08-club.jsx` | Both "Create Club" and "Club detail" screens (toggle between them at the bottom of the file). No category field/badge anywhere — this was deliberately removed. |
| `09-club-explore.jsx` | Browse/discover Clubs — no category filters. |
| `10-side-menu.jsx` | The ☰ drawer opened from Home. Plain list, not a card grid. No logout button here. |
| `11-settings.jsx` | Settings screen (reached from Profile's gear icon). Logout lives here, at the bottom, visually separated. |
| `12-chat.jsx` | Chat inbox. Reached from a new icon in Home's top-right header, replacing what used to be a duplicate search icon there (search already has its own bottom-nav tab). |
| `13-chat-thread.jsx` | One conversation thread — bubbles, avatar-per-run (not per-bubble), quiet composer at the bottom. Reached by tapping a row in `12-chat.jsx`. |
| `14-followers.jsx` | Followers / Following list. Reached by tapping the counts on Profile. |
| `15-bookmarks.jsx` | Saved posts. Reached from the side menu and from any post's "···" menu. Includes both populated and empty states (toggle at the bottom). |
| `16-top100-full.jsx` | Full ranked Top 100 list. Reached from "ดูอันดับทั้งหมด" on Search. |
| `17-new-message.jsx` | Person picker for starting a new chat. Reached from the pencil icon on `12-chat.jsx`. |
| `18-other-profile.jsx` | Someone else's profile — "ติดตาม"/message instead of "แก้ไขโปรไฟล์", plus a "···" for report/block. |
| `19-onboarding.jsx` | Welcome / Sign up / Log in. The one screen where the Fraunces wordmark gets real emphasis — the first brand moment a new person sees. |
| `20-image-viewer.jsx` | Full-screen photo viewer. Intentionally dark (ink background) instead of paper — a deliberate exception, not a mistake. |
| `21-report-block.jsx` | Report / Block, presented as a bottom sheet over a dimmed background rather than a pushed screen. |
| `22-empty-states.jsx` | Empty states for Notifications and Chat inbox — both only existed in populated form before this. |
| `bottom-nav-reference.jsx` | Isolated, interactive reference for the 5-item bottom nav shared across Home/Search/Notifications/Profile (Drop pushes over the current tab rather than being a persistent tab you stay on). |

**Note:** `00-prototype.jsx` includes the Chat inbox, Chat thread, and the header icon swap (search → chat). Files `14` through `22` are standalone references, not yet wired into the prototype's click-through — treat them as the next batch to integrate once `00-prototype.jsx` is updated further.

## What's deliberately NOT in this folder

Earlier draft/comparison files (Threads-style mockup, premium-app multi-screen demo, shop/e-commerce screens, the 3-way Create-Club layout comparison) are excluded. They were exploratory steps, not the final direction, and including them would make it unclear which version is authoritative. **Only the files listed above are current.**

E-commerce/shop screens specifically are out of scope for now — this app is social-only at this stage.

## Prompt to give Claude Code

```
โฟลเดอร์ /design-reference มีไฟล์ reference design ทั้งหมดของแอป
เรียงลำดับตามเลขนำหน้า อ่าน README.md ในโฟลเดอร์นี้ก่อนเป็นอันดับแรก

ขั้นตอน:
1. อ่าน 00-prototype.jsx เพื่อเข้าใจภาพรวม flow การเชื่อมหน้าทั้งหมด
   (bottom nav, push navigation, side menu overlay)
2. อ่าน SPEC.md เพื่อเข้าใจ design tokens ที่ใช้ทั้งแอป (สี, font, spacing)
   ให้แปลงเป็นค่าคงที่ในโปรเจกต์ (theme/tailwind config) ไม่ hardcode
   กระจายในแต่ละไฟล์
3. อ่านไฟล์แต่ละหน้า (01 ถึง 22) ทีละไฟล์ตามลำดับเลข — ไฟล์เหล่านี้คือ
   รายละเอียด pixel-level ที่แม่นกว่า prototype ในข้อ 1
4. ทำทีละหน้าตามลำดับเลข เทียบกับไฟล์ reference ให้ตรง 100% ก่อนไปหน้าถัดไป
   อย่าข้ามหรือทำรวดเดียวทั้งหมด — โชว์ผลแต่ละหน้าให้ดูก่อน
5. คงโครงสร้าง state/data/API ของแอปจริงไว้ เปลี่ยนแค่ styling และ
   component structure ให้ตรงกับ reference

กฎที่ห้ามฝ่าฝืน:
- ห้ามเปลี่ยนสี, font, หรือค่า spacing จาก SPEC.md แม้แต่จุดเดียว
- ห้ามเพิ่มสีใหม่โดยไม่ถามก่อน (มีสี accent เดียวคือ sapphire #1B3A6B)
- ถ้า reference ขัดกันเอง หรือมีจุดที่ไม่ชัดเจน ให้ถามก่อน ห้ามเดาเอง

หลังทำแต่ละหน้าเสร็จ ให้เทียบกับไฟล์ reference อีกครั้งทีละส่วน
บอกว่าจุดไหนยังไม่ตรง 100% และทำไม
```
