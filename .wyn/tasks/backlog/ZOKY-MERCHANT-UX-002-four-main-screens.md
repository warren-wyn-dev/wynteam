# ZOKY-MERCHANT-UX-002 — Redesign the four main Merchant screens

Status: **Design proposal — awaiting Founder approval of the prototype**
Requested: Founder, 2026-11-01 ("ออกแบบ UX UI Merchant ให้ใหม่")

## Founder decisions (2026-11-01)

- Scope: the four main tabs only — หน้าหลัก, ออเดอร์, เมนูอาหาร, เพิ่มเติม.
- Problems to solve: too many taps, dated look, hard to find things, slow/janky.
- Process: approve a clickable prototype first, then implement.
- Keep the 3D icon style (Founder likes it). Use 3D for tools, More rows, empty states; keep bottom nav, primary buttons and status chips flat.
- Option ข: shrink the 3D atlas (`web/merchant_flutter/assets/brand/merchant-tools-3d.webp`, 638 KB, 443 px cells) to ~768×384 (~71 KB at q90, 192 px cells) as part of the redesign release, not separately.

## Prototype

https://claude.ai/artifact/8EDw34ZpwmnserTfmq2hbZ (private to the Founder; 390×844, interactive)

- Home: open/close switch, "ต้องทำตอนนี้" counts (new / slip / preparing) linking to Orders, today's sales, 8 3D tools, LINE status.
- Orders: tabs ใหม่ · กำลังเตรียม · จัดส่ง · เสร็จ · ยกเลิก; inline slip + one action "เงินเข้าแล้ว · รับออเดอร์"; inline ETA chips; one next-step button per stage.
- Menu: search, categories, "หมดอยู่" filter, one-tap available/sold-out switch, floating "เพิ่มเมนู".
- More: grouped (ขายและเงิน, ร้านค้า, การตลาดและคุณภาพ, ทีมและการแจ้งเตือน) with 3D icons.

## Open items

- Missing 3D icons (store, orders, menu, report, team, bell): Founder may supply the LINE rich-menu 3D artwork; Claude cannot render new 3D art.
- Combined "verify payment + accept" must keep the existing server checks (payment verification RPC, then transition) and the manual-confirmation checkbox semantics for slip-less pending orders — design review before implementation.
- Performance work (critical-first loading, instant tap feedback) is implementation-side.

## Status 2026-11-01
- Round 1 (order cards + atlas shrink) live on `dpl_3NeC39MgBUY5frNZ2UtgQ635u4cT`.
- Remaining: Home, Menu, More screens.
- Round 2 (Home, Menu, More) live on `dpl_38dkGyWCexrTsByZdoo6LXjeEQ9d`. All four main screens redesigned.
- Remaining optional: dedicated 3D icons for store/orders/menu/report/team/bell (Founder may supply art).
