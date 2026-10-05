#!/usr/bin/env python3
"""Derive the dark WYNOS Maps style from the light one.

Run from web/: python3 scripts/build-wynos-dark-map-style.py
Re-run after editing public/maps/wynos-green.json so both styles stay in step.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "public" / "maps"
style = json.loads((ROOT / "wynos-green.json").read_text())

GROUND = "#1b1c1f"
RESIDENTIAL = "#202125"
GREEN = "#1f2b23"
WATER = "#1c3346"
WATERWAY = "#2a4a62"
BUILDING = "#2b2c31"
ROAD = "#3b3c42"
CASING = "#26272b"
MAIN_ROAD = "#7a6430"
MAIN_CASING = "#4f4224"
SECONDARY = "#5a5137"
SECONDARY_CASING = "#3e3828"
TERTIARY = "#47443b"
RAIL = "#4a4a50"
TEXT, TEXT_SOFT, TEXT_MUTED, WATER_TEXT = "#eceff1", "#c9ccd1", "#9aa0a6", "#7fb0d6"

GREEN_FILLS = {"park", "landcover_wood", "landcover_grass", "landcover_wetland", "landuse_pitch", "landuse_cemetery"}

for layer in style["layers"]:
    lid, kind = layer["id"], layer["type"]
    paint = layer.setdefault("paint", {})
    if kind == "background":
        paint["background-color"] = GROUND
    elif kind == "raster":
        paint["raster-brightness-max"] = 0.35
        paint["raster-saturation"] = -0.4
    elif kind == "fill":
        if "fill-pattern" in paint:
            paint["fill-opacity"] = 0.18
        elif lid in GREEN_FILLS:
            paint["fill-color"] = GREEN
        elif lid == "water":
            paint["fill-color"] = WATER
        elif lid == "building":
            paint["fill-color"] = BUILDING
            paint["fill-outline-color"] = BUILDING
        elif lid == "landuse_residential":
            paint["fill-color"] = RESIDENTIAL
        elif lid == "landuse_school":
            paint["fill-color"] = "#23222b"
        elif lid == "landuse_hospital":
            paint["fill-color"] = "#2b2225"
        elif "fill-color" in paint and lid != "road_area_pattern":
            paint["fill-color"] = RESIDENTIAL
    elif kind == "line":
        if lid.startswith("waterway"):
            paint["line-color"] = WATERWAY
        elif lid.startswith("boundary"):
            paint["line-color"] = "#5f6368"
        elif "rail" in lid:
            paint["line-color"] = RAIL
        elif lid == "park_outline":
            paint["line-color"] = "rgba(0,0,0,0)"
        elif layer.get("source-layer") == "transportation" or lid.startswith("aeroway"):
            casing = "casing" in lid
            if "motorway" in lid or "trunk_primary" in lid:
                paint["line-color"] = MAIN_CASING if casing else MAIN_ROAD
            elif "secondary_tertiary" in lid:
                paint["line-color"] = (
                    ["match", ["get", "class"], "secondary", SECONDARY_CASING, CASING]
                    if casing
                    else ["match", ["get", "class"], "secondary", SECONDARY, TERTIARY]
                )
            else:
                paint["line-color"] = CASING if casing else ROAD
    elif kind == "symbol" and "text-color" in paint:
        if "water" in lid:
            paint["text-color"] = WATER_TEXT
        elif lid.startswith(("label_city", "label_town", "label_country")):
            paint["text-color"] = TEXT
        elif lid.startswith("label_") or lid == "airport":
            paint["text-color"] = TEXT_SOFT
        else:
            paint["text-color"] = TEXT_MUTED
        paint["text-halo-color"] = GROUND
    if not paint:
        layer.pop("paint")

(ROOT / "wynos-dark.json").write_text(json.dumps(style, indent=2, ensure_ascii=False) + "\n")
print("wrote", ROOT / "wynos-dark.json")
