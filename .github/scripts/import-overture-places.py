#!/usr/bin/env python3
"""Import Overture Places GeoJSON into WYNOS Places through Supabase Management API.

Input should come from:
  overturemaps download --bbox=... -f geojson --type=place -o overture-places.geojson

This importer intentionally maps Overture Places into the smaller WYNOS taxonomy,
keeps Overture's stable id as source_ref, and auto-activates only high-confidence
records. Re-running the same area is idempotent.
"""

import argparse
import json
import math
import os
import sys
import urllib.request


def text(value):
    return value.strip() if isinstance(value, str) else ""


def first_address(props):
    rows = props.get("addresses")
    if not isinstance(rows, list) or not rows:
        return ""
    row = rows[0] if isinstance(rows[0], dict) else {}
    return text(row.get("freeform")) or text(row.get("address"))


def primary_name(props):
    names = props.get("names")
    if isinstance(names, dict):
        value = text(names.get("primary"))
        if value:
            return value
    return text(props.get("name"))


def taxonomy_primary(props):
    taxonomy = props.get("taxonomy")
    if isinstance(taxonomy, dict):
        return text(taxonomy.get("primary")).lower()
    return text(props.get("basic_category")).lower()


def wynos_category(raw):
    v = raw.lower()
    if any(k in v for k in ("restaurant", "cafe", "food", "bakery", "bar", "coffee")):
        return "restaurant"
    if any(k in v for k in ("store", "shop", "retail", "supermarket", "convenience", "market")):
        return "store"
    if any(k in v for k in ("lodging", "hotel", "hostel", "dorm", "apartment", "guest_house", "residence")):
        return "residence"
    if "building" in v:
        return "building"
    return "poi"


def sql_quote(value):
    return "'" + str(value).replace("'", "''") + "'"


def post_query(api, token, query):
    payload = json.dumps({"query": query}).encode()
    req = urllib.request.Request(
        api,
        data=payload,
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=60) as response:
        body = response.read().decode()
        if response.status not in (200, 201):
            raise RuntimeError(f"Supabase HTTP {response.status}: {body}")
        return body


def load_features(path):
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    if isinstance(data, dict) and data.get("type") == "FeatureCollection":
        return data.get("features") or []
    if isinstance(data, list):
        return data
    raise ValueError("Expected GeoJSON FeatureCollection")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", required=True)
    parser.add_argument("--supabase-url", required=True)
    parser.add_argument("--access-token", required=True)
    parser.add_argument("--min-confidence", type=float, default=0.80)
    parser.add_argument("--activate-confidence", type=float, default=0.97)
    parser.add_argument("--max-places", type=int, default=10000)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    project_ref = args.supabase_url.split("//", 1)[-1].split(".", 1)[0]
    api = f"https://api.supabase.com/v1/projects/{project_ref}/database/query"

    rows = []
    skipped = 0
    for feature in load_features(args.file):
        if len(rows) >= args.max_places:
            break
        if not isinstance(feature, dict):
            skipped += 1
            continue
        props = feature.get("properties") if isinstance(feature.get("properties"), dict) else {}
        geom = feature.get("geometry") if isinstance(feature.get("geometry"), dict) else {}
        coords = geom.get("coordinates")
        if geom.get("type") != "Point" or not isinstance(coords, list) or len(coords) < 2:
            skipped += 1
            continue

        try:
            lon, lat = float(coords[0]), float(coords[1])
            confidence = float(props.get("confidence") or 0)
        except (TypeError, ValueError):
            skipped += 1
            continue
        if not (math.isfinite(lat) and math.isfinite(lon)) or confidence < args.min_confidence:
            skipped += 1
            continue

        oid = text(props.get("id")) or text(feature.get("id"))
        name = primary_name(props)
        if not oid or not name:
            skipped += 1
            continue

        category_raw = taxonomy_primary(props)
        rows.append({
            "source_ref": oid[:240],
            "name": name[:160],
            "category": wynos_category(category_raw),
            "address": first_address(props)[:1000],
            "lat": lat,
            "lon": lon,
            "active": confidence >= args.activate_confidence,
        })

    print(json.dumps({
        "accepted": len(rows),
        "skipped": skipped,
        "dry_run": args.dry_run,
        "auto_active": sum(1 for r in rows if r["active"]),
    }, ensure_ascii=False))

    if args.dry_run or not rows:
        return

    batch_size = 300
    for start in range(0, len(rows), batch_size):
        batch = rows[start:start + batch_size]
        values = []
        for r in batch:
            values.append("(" + ",".join([
                sql_quote(r["name"]),
                sql_quote(r["category"]),
                "NULL" if not r["address"] else sql_quote(r["address"]),
                str(r["lat"]),
                str(r["lon"]),
                "'overture'",
                sql_quote(r["source_ref"]),
                "'unverified'",
                "true" if r["active"] else "false",
            ]) + ")")

        sql = f"""
insert into public.wynos_places(
  name_th, category, address, latitude, longitude,
  source, source_ref, verification_status, is_active
)
values {','.join(values)}
on conflict (source, source_ref) where source_ref is not null do update
set name_th = excluded.name_th,
    category = excluded.category,
    address = excluded.address,
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    is_active = case
      when public.wynos_places.verification_status = 'wynos_verified'
        then public.wynos_places.is_active
      else excluded.is_active
    end,
    updated_at = now();
"""
        post_query(api, args.access_token.strip(), sql)
        print(f"imported {min(start + len(batch), len(rows))}/{len(rows)}")


if __name__ == "__main__":
    main()
