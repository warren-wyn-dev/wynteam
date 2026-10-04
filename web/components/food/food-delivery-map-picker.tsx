"use client";

import type { SupabaseClient } from "@supabase/supabase-js";
import { Check, LocateFixed, MapPin, RefreshCw, Search, X } from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";

import {
  currentFoodLocation,
  reverseFoodPlace,
  searchFoodPlaces,
  searchStorePlaces,
  type FoodLocation,
  type FoodPlace,
} from "@/lib/food-customer";

type MapCenter = { lat: number; lng: number };
type MapStyle = string | {
  version: 8;
  sources: Record<string, {
    type: "raster";
    tiles: string[];
    tileSize: number;
    attribution: string;
  }>;
  layers: Array<{
    id: string;
    type: "raster";
    source: string;
    minzoom: number;
    maxzoom: number;
  }>;
};

type MapInstance = {
  getCenter: () => MapCenter;
  flyTo: (options: { center: [number, number]; zoom?: number; essential?: boolean }) => void;
  on: (event: string, handler: (event?: unknown) => void) => void;
  off: (event: string, handler: (event?: unknown) => void) => void;
  remove: () => void;
  resize: () => void;
  setStyle: (style: MapStyle) => void;
};

type MapLibreGlobal = {
  Map: new (options: {
    container: HTMLElement;
    style: MapStyle;
    center: [number, number];
    zoom: number;
    attributionControl?: boolean;
  }) => MapInstance;
};

declare global {
  interface Window {
    maplibregl?: MapLibreGlobal;
    __wynosMapLibrePromise?: Promise<MapLibreGlobal>;
  }
}

const MAPLIBRE_VERSION = "5.12.0";
const MAPLIBRE_JS = `https://unpkg.com/maplibre-gl@${MAPLIBRE_VERSION}/dist/maplibre-gl.js`;
const MAPLIBRE_CSS = `https://unpkg.com/maplibre-gl@${MAPLIBRE_VERSION}/dist/maplibre-gl.css`;
const MAP_STYLE = "https://tiles.openfreemap.org/styles/liberty";
const FALLBACK_MAP_STYLE: MapStyle = {
  version: 8,
  sources: {
    osm: {
      type: "raster",
      tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
      tileSize: 256,
      attribution: "© OpenStreetMap contributors",
    },
  },
  layers: [
    {
      id: "osm",
      type: "raster",
      source: "osm",
      minzoom: 0,
      maxzoom: 19,
    },
  ],
};

function loadMapLibre(): Promise<MapLibreGlobal> {
  if (window.maplibregl) return Promise.resolve(window.maplibregl);
  if (window.__wynosMapLibrePromise) return window.__wynosMapLibrePromise;

  window.__wynosMapLibrePromise = new Promise<MapLibreGlobal>((resolve, reject) => {
    const cssId = "wynos-maplibre-css";
    if (!document.getElementById(cssId)) {
      const link = document.createElement("link");
      link.id = cssId;
      link.rel = "stylesheet";
      link.href = MAPLIBRE_CSS;
      document.head.appendChild(link);
    }

    const ready = () => {
      if (window.maplibregl) resolve(window.maplibregl);
      else reject(new Error("MapLibre did not load"));
    };

    const existing = document.getElementById("wynos-maplibre-script") as HTMLScriptElement | null;
    if (existing) {
      if (window.maplibregl) {
        resolve(window.maplibregl);
        return;
      }
      existing.addEventListener("load", ready, { once: true });
      existing.addEventListener("error", () => reject(new Error("MapLibre failed to load")), { once: true });
      window.setTimeout(() => {
        if (window.maplibregl) resolve(window.maplibregl);
      }, 250);
      return;
    }

    const script = document.createElement("script");
    script.id = "wynos-maplibre-script";
    script.src = MAPLIBRE_JS;
    script.async = true;
    script.crossOrigin = "anonymous";
    script.addEventListener("load", ready, { once: true });
    script.addEventListener("error", () => reject(new Error("MapLibre failed to load")), { once: true });
    document.head.appendChild(script);
  });

  return window.__wynosMapLibrePromise;
}

function placeText(place: FoodPlace | null, location: FoodLocation | null) {
  if (place?.address) return [place.name, place.address].filter(Boolean).join(" · ");
  if (place?.name) return place.name;
  if (location) return `${location.latitude.toFixed(5)}, ${location.longitude.toFixed(5)}`;
  return "เลื่อนแผนที่หรือค้นหาสถานที่";
}

export function FoodDeliveryMapPicker({
  client,
  storeId,
  initialLocation,
  onClose,
  onConfirm,
}: {
  client: SupabaseClient;
  storeId: string | null;
  initialLocation: FoodLocation | null;
  onClose: () => void;
  onConfirm: (location: FoodLocation, place?: FoodPlace) => void;
}) {
  const mapNode = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<MapInstance | null>(null);
  const dragRef = useRef(false);
  const reverseTimerRef = useRef<number | null>(null);
  const [location, setLocation] = useState<FoodLocation | null>(initialLocation);
  const [place, setPlace] = useState<FoodPlace | null>(null);
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<FoodPlace[]>([]);
  const [status, setStatus] = useState("");
  const [working, setWorking] = useState(false);
  const [mapReady, setMapReady] = useState(false);
  const [mapFailed, setMapFailed] = useState(false);
  const [mapAttempt, setMapAttempt] = useState(0);
  const [chosen, setChosen] = useState(Boolean(initialLocation));

  const reverse = useCallback(async (next: FoodLocation) => {
    try {
      const found = await reverseFoodPlace(client, next);
      setPlace(found);
    } catch {
      setPlace(null);
    }
  }, [client]);

  useEffect(() => {
    let live = true;
    let map: MapInstance | null = null;
    let fallbackApplied = false;
    let styleLoaded = false;
    let fallbackTimer: number | null = null;
    let failureTimer: number | null = null;

    void loadMapLibre()
      .then((maplibre) => {
        if (!live || !mapNode.current) return;

        mapNode.current.replaceChildren();
        const start = initialLocation
          ? [initialLocation.longitude, initialLocation.latitude] as [number, number]
          : [100.5018, 13.7563] as [number, number];

        map = new maplibre.Map({
          container: mapNode.current,
          style: MAP_STYLE,
          center: start,
          zoom: initialLocation ? 16 : 5.4,
          attributionControl: true,
        });
        mapRef.current = map;

        const markReady = () => {
          if (!live) return;
          styleLoaded = true;
          setMapReady(true);
          setMapFailed(false);
        };

        const applyFallback = () => {
          if (!live || !map || styleLoaded || fallbackApplied) return;
          fallbackApplied = true;
          try {
            map.setStyle(FALLBACK_MAP_STYLE);
          } catch {
            setMapFailed(true);
          }
        };

        const onDragStart = () => {
          dragRef.current = true;
        };
        const onMoveEnd = () => {
          if (!dragRef.current || !map) return;
          dragRef.current = false;
          const center = map.getCenter();
          const next = { latitude: center.lat, longitude: center.lng };
          setLocation(next);
          setChosen(true);
          setPlace(null);
          if (reverseTimerRef.current) window.clearTimeout(reverseTimerRef.current);
          reverseTimerRef.current = window.setTimeout(() => void reverse(next), 650);
        };

        const onError = () => {
          if (!styleLoaded) applyFallback();
        };

        map.on("style.load", markReady);
        map.on("load", markReady);
        map.on("dragstart", onDragStart);
        map.on("moveend", onMoveEnd);
        map.on("error", onError);

        window.setTimeout(() => map?.resize(), 60);
        window.setTimeout(() => map?.resize(), 450);

        fallbackTimer = window.setTimeout(applyFallback, 3000);
        failureTimer = window.setTimeout(() => {
          if (!styleLoaded && live) setMapFailed(true);
        }, 8500);

        if (initialLocation) void reverse(initialLocation);
      })
      .catch(() => {
        if (!live) return;
        setMapFailed(true);
        setStatus("โหลดแผนที่ไม่สำเร็จ กรุณาลองใหม่");
      });

    return () => {
      live = false;
      if (fallbackTimer) window.clearTimeout(fallbackTimer);
      if (failureTimer) window.clearTimeout(failureTimer);
      if (reverseTimerRef.current) window.clearTimeout(reverseTimerRef.current);
      map?.remove();
      mapRef.current = null;
    };
  }, [initialLocation, mapAttempt, reverse]);

  const moveTo = (next: FoodLocation, nextPlace?: FoodPlace) => {
    setLocation(next);
    setChosen(true);
    setPlace(nextPlace ?? null);
    mapRef.current?.flyTo({
      center: [next.longitude, next.latitude],
      zoom: 17,
      essential: true,
    });
  };

  const pickCurrentLocation = async () => {
    setWorking(true);
    setStatus("");
    try {
      const next = await currentFoodLocation();
      moveTo(next);
      await reverse(next);
    } catch (error) {
      setStatus(error instanceof Error ? error.message : "หาตำแหน่งปัจจุบันไม่สำเร็จ");
    } finally {
      setWorking(false);
    }
  };

  const search = async () => {
    const trimmed = query.trim();
    if (!trimmed) return;
    setWorking(true);
    setStatus("");
    try {
      let next = storeId ? (await searchStorePlaces(client, storeId, trimmed)) ?? [] : [];
      if (!next.length) next = await searchFoodPlaces(client, trimmed);
      setResults(next);
      if (!next.length) setStatus("ไม่พบสถานที่ ลองพิมพ์ชื่อถนน หมู่บ้าน หอพัก หรือสถานที่ใกล้เคียง");
    } catch (error) {
      setResults([]);
      setStatus(error instanceof Error ? error.message : "ค้นหาสถานที่ไม่สำเร็จ");
    } finally {
      setWorking(false);
    }
  };

  const chooseResult = (result: FoodPlace) => {
    setResults([]);
    setQuery(result.name);
    moveTo({ latitude: result.latitude, longitude: result.longitude }, result);
  };

  return (
    <div className="wf-map-picker" role="dialog" aria-modal="true" aria-label="ปักหมุดตำแหน่งจัดส่ง">
      <header className="wf-map-picker-head">
        <button type="button" aria-label="ปิดแผนที่" onClick={onClose}><X size={22} /></button>
        <div><strong>ปักหมุดตำแหน่งจัดส่ง</strong><small>เลื่อนแผนที่ให้หมุดตรงจุดรับอาหาร</small></div>
        <span />
      </header>

      <div className="wf-map-search-wrap">
        <div className="wf-map-search">
          <Search size={18} />
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            onKeyDown={(event) => {
              if (event.key === "Enter") {
                event.preventDefault();
                void search();
              }
            }}
            placeholder="ค้นหาสถานที่ ถนน หมู่บ้าน หอพัก"
            aria-label="ค้นหาสถานที่หรือที่อยู่"
          />
          <button type="button" disabled={working || !query.trim()} onClick={() => void search()}>ค้นหา</button>
        </div>
        {results.length ? (
          <div className="wf-map-results">
            {results.map((result) => (
              <button key={`${result.latitude},${result.longitude},${result.name}`} type="button" onClick={() => chooseResult(result)}>
                <MapPin size={17} />
                <span><strong>{result.name || "สถานที่"}</strong>{result.address ? <small>{result.address}</small> : null}</span>
              </button>
            ))}
          </div>
        ) : null}
      </div>

      <div className="wf-map-canvas-wrap">
        <div ref={mapNode} className="wf-map-canvas" />
        {!mapReady && !mapFailed ? <div className="wf-map-loading">กำลังโหลดแผนที่…</div> : null}
        {mapFailed ? (
          <div className="wf-map-loading wf-map-loading--error">
            <MapPin size={30} />
            <strong>แผนที่ยังโหลดไม่สำเร็จ</strong>
            <small>ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่อีกครั้ง</small>
            <button type="button" onClick={() => {
              setMapReady(false);
              setMapFailed(false);
              setStatus("");
              setMapAttempt((value) => value + 1);
            }}><RefreshCw size={16} /> ลองใหม่</button>
          </div>
        ) : null}
        <div className="wf-map-center-pin" aria-hidden="true"><MapPin size={42} fill="currentColor" /></div>
        <button className="wf-map-current" type="button" disabled={working} onClick={() => void pickCurrentLocation()}>
          <LocateFixed size={19} /> <span>ตำแหน่งปัจจุบัน</span>
        </button>
      </div>

      <section className="wf-map-confirm">
        <div className="wf-map-confirm-copy">
          <span><MapPin size={18} /></span>
          <div>
            <small>ตำแหน่งจัดส่ง</small>
            <strong>{placeText(place, location)}</strong>
          </div>
        </div>
        {status ? <p role="status">{status}</p> : null}
        <button
          className="wf-primary wf-full"
          type="button"
          disabled={!chosen || !location}
          onClick={() => {
            if (!location) return;
            onConfirm(location, place ?? undefined);
          }}
        >
          <Check size={18} /> ยืนยันตำแหน่งนี้
        </button>
        <a href="https://locationiq.com" target="_blank" rel="noreferrer">Search by LocationIQ.com</a>
      </section>
    </div>
  );
}
