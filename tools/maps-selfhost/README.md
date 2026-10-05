# WYNOS Maps Core — Self-hosted (ฟรีทั้งหมด)

ชุดติดตั้งระบบค้นหาที่อยู่ (geo) และนำทาง (routing) ของ WYNOS Maps บนเครื่องของเราเอง ใช้ซอฟต์แวร์ open source และข้อมูล OpenStreetMap ของประเทศไทย ไม่มีค่า license

```text
WYNOS web (Vercel) ── /api/maps/* (rate limit ต่อผู้ใช้)
        │  HTTPS + X-WYNOS-Maps-Token
        ▼
caddy (HTTPS ฟรี Let's Encrypt) → gateway nginx (ตรวจ token + rate limit รวม + เปิดเฉพาะ endpoint ที่ใช้)
                                        ├─ /geo/search, /geo/reverse → Nominatim
                                        └─ /routing/route (POST)     → Valhalla
```

ภาพแผนที่ (tiles) อยู่ที่ `tiles.wynos.online` อยู่แล้ว ไม่เกี่ยวกับชุดนี้

## Decision record

| หัวข้อ | รายละเอียด |
|---|---|
| คำตัดสินใจ | Founder กำหนดว่า "ทำแผนที่ใช้เอง ใช้ระบบฟรีเท่านั้น" (2026-10-05) |
| ทางเลือกที่เลือก | Nominatim + Valhalla บนเครื่อง Oracle Cloud Always Free (ARM Ampere A1, 4 OCPU / 24GB RAM / 200GB disk) |
| ทางเลือกที่ไม่เลือก | API สาธารณะฟรี (nominatim.openstreetmap.org, OSRM demo) ห้ามใช้กับ production ตาม usage policy และบริการแบบเสียเงิน |
| ความเสี่ยง | Oracle อาจไม่มีเครื่อง ARM ว่างในบาง region, อาจเรียกคืนเครื่อง Always Free ที่ idle นาน, เป็นเครื่องเดียวไม่มี redundancy |
| ผลเมื่อเครื่องล่ม | ไม่ downtime: API ตอบ 502/503 แล้ว client กลับไปใช้ WYNOS Places + legacy search อัตโนมัติ ส่วนการนำทางจะใช้ไม่ได้ชั่วคราว |
| Rollback | ลบ env `WYNOS_GEO_ORIGIN` / `WYNOS_ROUTING_ORIGIN` บน Vercel แล้ว redeploy → กลับสู่สถานะเดิมทันที |
| Backup | ไม่ต้อง backup ข้อมูลทั้งหมด import ใหม่จาก OpenStreetMap ได้ |
| License | ข้อมูล OSM เป็น ODbL ต้องแสดง "© OpenStreetMap contributors" (แผนที่แสดงอยู่แล้ว) |

## ขั้นที่ 1 — สร้างเครื่องฟรี (Founder ทำ)

1. สมัคร https://www.oracle.com/cloud/free/ เลือก home region ที่ใกล้ไทย เช่น Singapore (`ap-singapore-1`) — **เปลี่ยน home region ภายหลังไม่ได้**
   - ต้องใช้บัตรเครดิตยืนยันตัวตน ไม่ถูกเก็บเงินถ้าใช้เฉพาะ resource ที่มีป้าย "Always Free"
   - **อย่ากด Upgrade to Pay As You Go** ถ้าต้องการให้ฟรี 100%
2. Compute → Instances → Create instance
   - Image: **Ubuntu 24.04** (หรือ 22.04)
   - Shape: **VM.Standard.A1.Flex** → 4 OCPU, 24 GB RAM
   - Boot volume: **150–200 GB**
   - ใส่ SSH public key ของคุณ
   - ถ้าขึ้น "Out of capacity" ให้ลองใหม่ภายหลังหรือเปลี่ยน availability domain
3. เปิดพอร์ต 80 และ 443: VCN → Security List → Add Ingress Rules (`0.0.0.0/0`, TCP 80 และ 443)
4. จดค่า Public IP ของเครื่องไว้

## ขั้นที่ 2 — ตั้ง DNS (Founder ทำ)

เพิ่ม A record `maps-core.wynos.online` → Public IP ของเครื่อง ที่ผู้ให้บริการ DNS ของ `wynos.online`

## ขั้นที่ 3 — ติดตั้งบนเครื่อง

SSH เข้าเครื่องแล้วรัน:

```bash
# Docker
sudo apt-get update && sudo apt-get install -y docker.io docker-compose-v2 git
sudo usermod -aG docker $USER && newgrp docker

# Ubuntu image ของ Oracle บล็อกพอร์ตด้วย iptables เพิ่มเติม ต้องเปิดเอง
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
sudo apt-get install -y iptables-persistent && sudo netfilter-persistent save

# โค้ด: copy โฟลเดอร์นี้จากเครื่องคุณขึ้น server (repo เป็น private จึงใช้ scp ง่ายที่สุด)
#   บนเครื่องคุณ:  scp -r tools/maps-selfhost ubuntu@<PUBLIC_IP>:~/
cd ~/maps-selfhost

# ค่าลับ — สร้างบนเครื่องเท่านั้น ห้าม commit / ห้ามส่งในแชท
cp .env.example .env
sed -i "s/^WYNOS_MAPS_UPSTREAM_TOKEN=.*/WYNOS_MAPS_UPSTREAM_TOKEN=$(openssl rand -hex 32)/" .env
sed -i "s/^NOMINATIM_DB_PASSWORD=.*/NOMINATIM_DB_PASSWORD=$(openssl rand -hex 24)/" .env
chmod 600 .env

docker compose up -d
docker compose logs -f nominatim valhalla   # ดูความคืบหน้า กด Ctrl+C เพื่อออก
```

ครั้งแรกจะดาวน์โหลดข้อมูลไทย (~400MB) แล้ว import โดย **Nominatim ใช้เวลาประมาณ 1–3 ชั่วโมง** และ **Valhalla ประมาณ 15–45 นาที** ระหว่างนั้น geo/routing ยังตอบไม่ได้ ซึ่งเป็นเรื่องปกติ

> ถ้า image ตัวใดไม่รองรับ ARM (`exec format error`) ให้แจ้งทีม เราจะเปลี่ยน tag ให้ — ณ วันที่เขียน ทั้ง `mediagis/nominatim` และ `valhalla-scripted` มี build สำหรับ arm64 แต่ควรยืนยันอีกครั้งตอนติดตั้ง

## ขั้นที่ 4 — ตรวจว่าใช้ได้

```bash
./check.sh
```

ต้องได้ `PASS` ทุกบรรทัด: health, ไม่มี token ถูกปฏิเสธ (401), ค้นหา "มหาสารคาม", reverse, routing และ path อื่นถูกปิด (404)

## ขั้นที่ 5 — เชื่อมกับ WYNOS web (staging ก่อน)

ตั้ง Environment Variables บน Vercel ของโปรเจกต์ `web` **เฉพาะ Preview/Staging ก่อน**:

| Name | Value |
|---|---|
| `WYNOS_GEO_ORIGIN` | `https://maps-core.wynos.online/geo` |
| `WYNOS_ROUTING_ORIGIN` | `https://maps-core.wynos.online/routing` |
| `WYNOS_MAPS_UPSTREAM_TOKEN` | ค่าเดียวกับใน `.env` บนเครื่อง (ใส่เป็น Sensitive) |

redeploy staging แล้วเปิด `/api/maps/health` ต้องได้ `"geo":"configured","routing":"configured"` จากนั้นส่งให้ QA ทดสอบ เมื่อผ่าน QA และ Founder อนุมัติแล้ว จึงตั้งค่าเดียวกันใน Production

## การดูแลประจำ

| งาน | วิธี |
|---|---|
| อัปเดตข้อมูลที่อยู่ | Nominatim ดึงข้อมูลอัปเดตจาก Geofabrik เองวันละครั้ง (`UPDATE_MODE=continuous`) |
| อัปเดตถนนสำหรับนำทาง (เดือนละครั้ง) | `docker compose stop valhalla && docker compose run --rm -e force_rebuild=True -e use_tiles_ignore_pbf=False -e serve_tiles=False valhalla` แล้วเมื่อ build เสร็จให้ `docker compose up -d valhalla` |
| ดูสถานะ | `docker compose ps` และ `./check.sh` |
| อัปเดตระบบ | `sudo apt-get upgrade` เดือนละครั้ง และ `docker compose pull && docker compose up -d` เมื่อทีมแจ้ง |
| เปลี่ยน token | สร้างค่าใหม่ใน `.env` → `docker compose up -d gateway` → อัปเดต `WYNOS_MAPS_UPSTREAM_TOKEN` บน Vercel → redeploy |
| Monitoring ฟรี | ตั้ง UptimeRobot (ฟรี) ให้เรียก `https://maps.wynos.online/api/maps/health` ทุก 5 นาที และแจ้งเตือนเมื่อค่าไม่ใช่ `configured` |

## ความปลอดภัย

- เปิดสู่ internet แค่พอร์ต 80/443 (Caddy) ส่วน Nominatim, Valhalla และ Postgres อยู่ใน docker network ภายใน
- ทุก request ต้องมี `X-WYNOS-Maps-Token` ที่ถูกต้อง จึงเรียกเลี่ยง rate limit ของเว็บโดยตรงไม่ได้ และ token ถูกตัดออกก่อนส่งต่อไปยัง service ภายใน
- เปิดเฉพาะ `/geo/search`, `/geo/reverse`, `/routing/route` (POST) และ `/health`
- rate limit 2 ชั้น: ชั้นแรกที่เว็บ (ต่อ IP ต่อ instance: search/reverse 30 ครั้ง/นาที, route 10 ครั้ง/นาที) และชั้นสองที่ gateway (รวมทั้งระบบ: geo 20 ครั้ง/วินาที, routing 5 ครั้ง/วินาที)
- ห้าม commit `.env` (มี `.gitignore` กันไว้แล้ว)
