# WYN-220 — WYNOS AI Secretary: สถาปัตยกรรมและแผนพัฒนา

สถานะ: **Phase 1 foundation implement แล้วบน branch `feature/wyn-220-ai-secretary-foundation` — ยังไม่ apply DB, ยังไม่ deploy**
ผู้ขอ: Founder (Master Prompt "WYNOS AI Secretary", 2026-10-10)
เอกสารนี้: System Architecture · Database/API · Security · AI Agent · UI/UX · Development Plan · Env Guide · Deploy/Rollback · สิ่งที่เสร็จ/ยังไม่เสร็จ

> **ต้องได้ Founder approval ก่อนไป staging/production** (AGENTS.md → Change Control):
> 1. ส่งข้อมูลภายใน WYNOS (เฉพาะตัวเลขรวม ไม่มีข้อมูลรายบุคคล) ไปยัง AI provider ภายนอก (Anthropic) — privacy/data-sharing decision
> 2. ค่าใช้จ่าย AI API (มี daily token budget ต่อคน ค่าเริ่มต้น 300,000 tokens/วัน)
> 3. dependency ใหม่ `@anthropic-ai/sdk` (exact pin 0.133.0)
> 4. apply migration `20261010170000_wyn220_ai_secretary_foundation.sql` (additive) — ต้อง apply WYN-219 foundation ก่อน
> 5. ใครใช้ AI Secretary ได้ — Phase 1 ตั้งไว้ **super admin เท่านั้น** (least privilege) การเปิดให้ admin คนอื่นเป็นคำตัดสินใจแยก

---

## 0. ผลการตรวจระบบที่มีอยู่ (ก่อนเขียนโค้ด)

| หัวข้อ | สิ่งที่พบจริงใน repo |
|---|---|
| Admin app | `admin/` — Next.js 16.3 (App Router) + React 19 + TypeScript + Tailwind 4 + shadcn/ui, deploy บน Vercel |
| Auth | Supabase Auth ผ่าน `@supabase/ssr`; `proxy.ts` บังคับ session; `requireAdminRole()` ตรวจ `profiles.platform_role` ∈ {admin, moderator} ฝั่ง server |
| สิทธิ์รายระบบ | WYN-219: `admin_permissions` (account/social/food/merchant/maps × view/edit), `internal.is_super_admin()`, `admin_my_access()` — merged แต่ **ยังไม่ apply production** |
| Database | Supabase Postgres ตัวเดียวร่วมทุกระบบ; Admin เรียก RPC แบบ `security definer` ด้วย publishable key + JWT ของผู้ใช้ (ไม่มี service-role key ใน Admin) |
| ข้อมูลที่อ่านได้จริง | `admin_dashboard_metrics`, `admin_dashboard_trends`, `admin_signup_counts` (Social/Account), `admin_food_overview` (Food) — เป็นตัวเลขรวม |
| ยังไม่มี | API ของ Merchant/Maps สำหรับ analytics, application logs, payment-failure feed, error tracking, background job runner ฝั่ง Admin |
| Tests | DB tests แบบ `supabase/tests/*.sh` (PostgreSQL 16); Admin ไม่มี unit test runner มาก่อน |

ความเสี่ยงต่อฟีเจอร์เดิม: ต่ำ — โค้ดใหม่อยู่ใน `admin/lib/ai/`, `admin/app/(admin)/ai/`, `admin/app/api/ai/` และ migration เป็น additive ทั้งหมด สิ่งเดียวที่แตะของเดิมคือเพิ่มเมนู 1 รายการ (`superAdminOnly`), `allowImportingTsExtensions` ใน tsconfig, และ `npm test` ใน CI

## 1. System Architecture

```text
Browser (admin.wynos.online/ai)
  │  POST /api/ai/chat  (same-origin JSON, session cookie)
  ▼
Next.js Route Handler  app/api/ai/chat/route.ts
  1 env gate: AI_SECRETARY_ENABLED + ANTHROPIC_API_KEY
  2 CSRF: Origin == Host, content-type JSON, body ≤ 20 KB
  3 auth: supabase.auth.getUser()
  4 DB gate: rpc ai_secretary_begin_request  ← super admin? kill switch? rate limit? token budget?
  5 Orchestrator (lib/ai/orchestrator.ts)
       ├─ Model Abstraction (lib/ai/types.ts ModelProvider) ── AnthropicProvider (lib/ai/providers/anthropic.ts)
       ├─ Policy (lib/ai/policy.ts)  ← authorizeTool(): level + per-system permission
       ├─ Tool Registry (lib/ai/tools.ts) ── Supabase RPC as the signed-in admin (RPC re-checks)
       ├─ Guard (lib/ai/guard.ts) ← sanitize, mask PII, wrap as untrusted, grounding check
       └─ Audit  rpc ai_secretary_record_tool_run (append-only)
  6 rpc ai_secretary_record_reply (assistant text + token usage)
  ▼
NDJSON stream → ChatWorkspace (status, tool chips, evidence, verification warning)
```

หลักการ: **Orchestrator ตัวเดียว + เครื่องมือเฉพาะทาง** (ไม่ทำ multi-agent ตั้งแต่ต้น ตามข้อ 3 ของ Master Prompt) — "Agent" แต่ละบทบาทใน Phase ถัดไปคือชุด tools + prompt section ไม่ใช่ process แยก จนกว่าจะมีเหตุผลรองรับ

## 2. Database และ API Design

Migration: `supabase/migrations/20261010170000_wyn220_ai_secretary_foundation.sql` (additive, idempotent, มี rollback block)

| Object | หน้าที่ | การเข้าถึง |
|---|---|---|
| `internal.ai_secretary_settings` (1 แถว) | kill switch (ค่าเริ่มต้น **ปิด**), `daily_token_limit` 300k, `requests_per_minute` 6 | ไม่มี grant ให้ API role; อ่าน/แก้ผ่าน RPC เท่านั้น |
| `ai_conversations` | บทสนทนา (หมดอายุ 90 วัน) | select เฉพาะเจ้าของ + ยังไม่หมดอายุ; insert ผ่าน RPC |
| `ai_messages` | ข้อความ user/assistant | select เฉพาะเจ้าของ; insert ผ่าน RPC |
| `ai_tool_runs` | audit ทุกการเรียกเครื่องมือ (รวมที่ถูกปฏิเสธ) | select เจ้าของ; **append-only** (ไม่มี update/delete grant); เก็บ 1 ปี |
| `ai_usage` | token ต่อคำขอ | select เจ้าของ; insert ผ่าน RPC (client ปลอมยอดไม่ได้) |
| `ai_memory_items` | ความจำที่ผู้ใช้บันทึกเอง (note/decision/context) | select/insert/delete เฉพาะเจ้าของ; หมดอายุ ≤ 366 วัน; แก้ไขไม่ได้ |

RPC (ทั้งหมด `security definer`, `search_path=''`, ตรวจ `internal.ai_secretary_allowed()` = super admin):
`ai_secretary_status()`, `ai_secretary_set_enabled(bool)` (audit), `ai_secretary_set_limits(int,int)` (audit),
`ai_secretary_begin_request(uuid,text)` (gate + advisory lock กัน race), `ai_secretary_record_reply(...)`,
`ai_secretary_record_tool_run(...)`, `ai_secretary_conversation_messages(uuid,int)`, `internal.ai_secretary_purge_expired()` (ไม่เปิดให้ API role)

HTTP API: `POST /api/ai/chat` body `{ message: string(1–4000), conversationId?: uuid, tier?: "fast"|"standard"|"deep" }` → `application/x-ndjson` ของ `SecretaryEvent` (`conversation`, `status`, `text`, `tool`, `verification`, `notice`, `done`, `error`) — ดู `admin/lib/ai/types.ts`

## 3. Security Architecture

| ข้อกำหนด | Phase 1 ทำอย่างไร |
|---|---|
| RBAC | super admin เท่านั้น (DB) + per-tool `system`/`access` ผ่าน `hasSystemAccess()` ของ WYN-219 (fail closed ถ้ายังไม่ติดตั้ง) |
| ตรวจสิทธิ์ก่อนใช้เครื่องมือทุกครั้ง | `authorizeTool()` ใน server ก่อนทุก call + RPC ปลายทางตรวจซ้ำในฐานข้อมูล (defense in depth) |
| Level 1/2/3 | Phase 1 ลงทะเบียนเฉพาะ Level 1; Level 2/3 ถูกปฏิเสธใน policy แม้ลงทะเบียนพลาด (มี test) |
| AI ยกระดับสิทธิ์ตัวเองไม่ได้ | สิทธิ์มาจาก session ของผู้ใช้ + DB; โมเดลไม่มีเครื่องมือใดที่แก้สิทธิ์/ตั้งค่า; tool list คงที่ฝั่ง server |
| Human-in-the-loop / MFA | ยังไม่มี action ที่ต้องอนุมัติ — ออกแบบไว้ใน Phase 3 (ดูข้อ 6) |
| Audit logs | `ai_tool_runs` append-only (เก็บรูปร่าง output ไม่เก็บเนื้อหา); kill switch/limits → `audit_log` (`ai_secretary_settings_changed`); ถ้าเขียน audit ไม่สำเร็จ ผลลัพธ์ของเครื่องมือถูกทิ้ง (fail closed) |
| Secrets | `ANTHROPIC_API_KEY` อ่านเฉพาะ server (`import "server-only"`), ไม่มี `NEXT_PUBLIC_`, หน้า settings แสดงแค่ "ตั้งค่าแล้ว/ยังไม่ได้ตั้ง" |
| Rate limit / cost limit | ต่อคนต่อนาที + token ต่อวัน (นับรวม cache tokens) บังคับใน DB ก่อนเรียกโมเดล; usage ที่ใช้ไปก่อน error ก็ถูกนับ; สูงสุด 6 รอบ tool ต่อคำขอ |
| Prompt injection | tool output ถูก sanitize (control/bidi chars), จำกัดขนาด, ห่อใน `<tool_data trust="untrusted">`; system prompt สั่งให้ถือเป็นข้อมูล; ที่สำคัญคือ Phase 1 ไม่มีเครื่องมือที่เขียนข้อมูล ผลกระทบสูงสุดจึงจำกัดที่คำตอบผิด |
| Data privacy | เครื่องมือคืนเฉพาะตัวเลขรวม; mask email/เบอร์โทรอีกชั้น; ข้อความแชตเก็บ 90 วัน; memory หมดอายุและลบได้ |
| Tool isolation | เครื่องมือรันด้วยสิทธิ์ของผู้ใช้ (RLS/RPC) ไม่มี service-role; timeout ต่อเครื่องมือ + AbortSignal |
| Kill switch | 2 ชั้น: env `AI_SECRETARY_ENABLED` (deploy) และ DB kill switch (super admin กดในหน้า settings มีผลทันที) |
| CSRF | ตรวจ `Origin` == `Host` และบังคับ `content-type: application/json` |
| Output safety (UI) | Markdown renderer สร้าง React nodes เท่านั้น ไม่มี `dangerouslySetInnerHTML`, ไม่ทำลิงก์คลิกได้จาก output ของโมเดล |

## 4. AI Agent Design

- **Loop**: Understand → (tools) Analyze → Report → Verify. Manual streaming loop (`runSecretary`) เพื่อแทรก policy/audit ทุก call
- **Tools (Level 1)**: `get_platform_overview`, `compare_today_vs_yesterday` (คำนวณ % ฝั่ง server เพื่อลดเลขผิด), `get_signup_counts`, `get_food_overview`, `get_integration_status` (รายงานตรงๆ ว่าระบบไหนยังไม่เชื่อม), `search_memory`
- **Source & time window**: ทุก tool คืน `source { system, reference, window, retrievedAt }` → แสดงเป็น "หลักฐานและแหล่งข้อมูล" ใต้คำตอบ; window คัดจากนิยามจริงใน SQL (เช่น "today" ของ dashboard = 24 ชม. rolling, Food = วันตามเวลาไทย)
- **Verification**: `findUngroundedNumbers()` เทียบตัวเลขในคำตอบกับข้อมูลจาก tool — ถ้าไม่พบจะขึ้นคำเตือนสีเหลือง (ไม่ใช่การพิสูจน์ว่าผิด)
- **Reliability**: timeout ต่อ tool, retry 1 ครั้งสำหรับ read (idempotent) ยกเว้น timeout, SDK retry 429/5xx, ไม่รัน tool_use ที่ถูกตัดที่ max_tokens, จัดการ refusal (+ server-side refusal fallback `fallbacks: "default"`)
- **Model abstraction** (`ModelProvider`): เปลี่ยน provider ได้โดยเขียน adapter ใหม่ไฟล์เดียว; tiers — เร็ว `claude-haiku-5-5` (effort low) · มาตรฐาน `claude-opus-5-5` (medium) · วิเคราะห์ลึก `claude-opus-5-5` (high); override ด้วย env `AI_MODEL_FAST/STANDARD/DEEP`
- **Memory**: Phase 1 = บันทึกบทสนทนา (20 ข้อความล่าสุดเป็น context) + memory notes ที่ผู้ใช้บันทึกเอง ค้นด้วย `search_memory`; RAG/embeddings เป็น Phase 4 เมื่อมีเอกสารภายในจำนวนมากพอ

## 5. UI/UX Structure

`/ai` (เมนู "AI Secretary" เห็นเฉพาะ super admin) แบ่งแท็บ:

| ส่วนใน Master Prompt | สถานะ |
|---|---|
| 1 AI Chat Workspace | ✅ streaming, สถานะ กำลังวิเคราะห์/เรียกข้อมูล/เขียน/เสร็จ/ล้มเหลว, chip ต่อเครื่องมือ (สำเร็จ/ล้มเหลว/หมดเวลา/ไม่มีสิทธิ์/ต้องอนุมัติ), Markdown + ตาราง, หลักฐาน, คำเตือนตัวเลข, ปุ่มหยุด, เลือกโหมดโมเดล, ประวัติบทสนทนา |
| 8 Activity & Audit History · 10 Cost & Usage | ✅ แท็บ "กิจกรรมและค่าใช้จ่าย" |
| 7 AI Memory & Knowledge | ✅ แท็บ "ความจำ" (เพิ่ม/ลบ/หมดอายุ) |
| 9 AI Settings | ✅ kill switch, limits, โมเดล, รายการเครื่องมือและระดับ |
| 2 Executive Dashboard · 3 Insights · 4 Tasks & Workflows · 5 Pending Approvals · 6 Monitoring Center | ⏳ Phase 2–3 (ไม่ทำหน้าเปล่า/ข้อมูลปลอมไว้ก่อน) |
| กราฟในแชต | ⏳ ยังไม่ทำ (แสดงเป็นตาราง Markdown) |
| ภาษาอังกฤษ | AI ตอบตามภาษาที่ถาม; UI ของ Admin ทั้งแอปยังเป็นภาษาไทย — i18n ทั้งแอปเป็นงานแยก |

Visual: ขาว/neutral ตาม design system ของ Admin, rainbow accent เฉพาะแถบบางเหนือหัวข้อและไอคอน, mobile-first (แชตเต็มจอบนมือถือ, input ติดด้านล่างเหนือ bottom nav), touch target ≥ 44px, `aria-live` สำหรับ streaming

## 6. Development Plan (Phase และเกณฑ์ยอมรับ)

| Phase | ขอบเขต | Acceptance criteria หลัก |
|---|---|---|
| **1 Foundation (ทำแล้ว)** | Chat, model integration, auth/permissions, secure tool layer (L1), memory foundation, audit, limits, kill switch | DB test 63 checks ผ่าน; unit test 33 ผ่าน; lint/tsc/build ผ่าน; คำตอบอ้างอิงแหล่งข้อมูล; ไม่มี tool เขียนข้อมูล |
| 2 WYNOS Integration | RPC อ่านแบบรวมสำหรับ Merchant/Maps/payments/errors, Executive Dashboard + Insights, รายงาน, เปิดให้ admin รายระบบ (ตามสิทธิ์ WYN-219) | ทุก RPC ใหม่มี DB test ว่า admin ระบบอื่นอ่านไม่ได้; dashboard ใช้ข้อมูลจริงเท่านั้น |
| 3 Agentic Automation | ตาราง `ai_action_requests` (pending/approved/rejected/expired, ผู้ขอ ≠ ผู้อนุมัติ, idempotency key, หมดอายุ), Level 2 tools ที่ "เตรียม" แล้วรอคนกด, re-auth/MFA สำหรับ Level 3, scheduled jobs (pg_cron / Vercel Cron) สำหรับสรุปรายวันและ alert แบบ dedupe + rate control (ไม่มี email) | AI ไม่มีทางรัน L2/L3 โดยไม่มี approval row ที่ถูกต้อง (DB-enforced); alert ซ้ำถูกรวม |
| 4 Advanced | multi-agent เมื่อวัดได้ว่าดีกว่า, predictive analytics, Developer Assistant (อ่าน GitHub/logs, เตรียม PR), RAG บนเอกสารภายใน | eval set ก่อน/หลัง; ไม่มีการ merge/deploy อัตโนมัติ |

## 7. Automated Tests

- `supabase/tests/wyn_220_ai_secretary_foundation_test.sh` — 63 checks: access เฉพาะ super admin, kill switch ค่าเริ่มต้นปิด, gate (ปิด/สิทธิ์/ข้อความ/บทสนทนาคนอื่น), audit + idempotent, rate limit, token budget, ห้ามเขียนตรง, append-only, row visibility, memory (owner/expiry/blank), purge, idempotent migration
- `admin/lib/ai/__tests__/*.test.ts` (`npm test`, ใช้ `node --test` ไม่มี dependency ใหม่) — 33 tests: policy, guard (PII mask, sanitize, untrusted wrap, grounding), orchestrator (tool loop, audit, L2 ถูกปฏิเสธ, ไม่มีสิทธิ์, ชื่อ tool แปลก, input ผิด, retry, timeout, audit ล้มเหลว → ทิ้งผล, max_tokens, max steps, usage เมื่อ error, refusal), tools, model tiers
- CI: เพิ่ม `npm test` ใน job Admin ของ `ci.yml`

## 8. Environment Configuration Guide

ตั้งค่าบน server เท่านั้น (Vercel → Project Settings → Environment Variables) ห้าม prefix `NEXT_PUBLIC_`:

| ตัวแปร | ค่า | หมายเหตุ |
|---|---|---|
| `AI_SECRETARY_ENABLED` | `true` / ไม่ตั้ง | ไม่ตั้ง = ปิด (deploy-level kill switch) |
| `ANTHROPIC_API_KEY` | key ของ workspace ที่จำกัดวงเงิน | แนะนำตั้ง spend limit ใน Anthropic Console ด้วย |
| `AI_MODEL_FAST` / `AI_MODEL_STANDARD` / `AI_MODEL_DEEP` | model id (ไม่บังคับ) | ค่า invalid จะถูกละเลย |

ลำดับเปิดใช้: apply WYN-219 foundation → apply WYN-220 migration → ตั้ง env → deploy → super admin เปิด kill switch ที่ `/ai/settings`
Retention: ตั้ง scheduled job เรียก `select internal.ai_secretary_purge_expired();` วันละครั้ง (ops step แยก ต้องอนุมัติ)

## 9. Deployment & Rollback Plan

1. QA & Security review branch → CTO review → Founder อนุมัติข้อ 1–5 ด้านบน
2. Staging: apply migration ด้วย workflow (แบบ `wyn219-apply-*.yml`) → รัน DB test → deploy Admin preview โดย `AI_SECRETARY_ENABLED=true` → ทดสอบตาม checklist (คำถาม 4 ข้อแนะนำ, สลับ kill switch, ชน rate limit, account ที่ไม่ใช่ super admin เปิด `/ai` และเรียก `/api/ai/chat` ตรงๆ ต้องได้ 403)
3. Production (หลัง Founder อนุมัติแยก): apply migration → deploy โดยยัง **ไม่ตั้ง** `AI_SECRETARY_ENABLED` → smoke test หน้าอื่น → ตั้ง env + เปิด kill switch → ติดตาม usage/ค่าใช้จ่ายในแท็บกิจกรรม

Rollback (เรียงจากเร็วไปช้า): (a) กด kill switch ปิด (ทันที) → (b) ลบ `AI_SECRETARY_ENABLED` แล้ว redeploy → (c) revert commit ของ Admin → (d) drop objects ตาม ROLLBACK block ในหัว migration (ไม่มีอะไรนอก AI Secretary อ้างถึง)

## 10. สิ่งที่ทำสำเร็จและยังไม่สำเร็จ

ทำแล้ว (Phase 1, development): ดูข้อ 2–7 — ทั้งหมดผ่าน lint, `tsc`, `next build` (env จำลอง), unit tests 33/33, DB tests 63/63 และตรวจรูปแบบ request ของ adapter กับ mock fetch

**ยังไม่ได้ทดสอบ/ยังไม่ทำ:**
- ยังไม่ได้เรียกโมเดลจริง (ไม่มี API key ใน environment ที่พัฒนา) และยังไม่ได้ทดสอบ E2E ในเบราว์เซอร์กับ session จริง — ต้องทำบน staging
- ยังไม่ apply DB ใดๆ และยังไม่ deploy
- Merchant, Maps, application logs, payment failures, API errors/downtime: **ยังไม่เชื่อมต่อ** (AI จะตอบตรงๆ ว่าไม่มีข้อมูล)
- Executive Dashboard, Insights, Workflows, Pending Approvals, Monitoring Center, proactive alerts/scheduled reports, Level 2/3 actions + approval + MFA, Developer Assistant, RAG, กราฟในแชต, i18n อังกฤษของ UI
- Forecast เป็นเพียงการอ่านแนวโน้มจากข้อมูลที่มี ไม่ใช่ prediction model
