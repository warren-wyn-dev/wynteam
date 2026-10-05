"use client";

import type { SupabaseClient } from "@supabase/supabase-js";
import { Check, Info, LocateFixed, MapPin, Minus, Plus, RefreshCw, Search, Store, X } from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";

import {
  checkFoodDeliveryAvailability,
  currentFoodLocation,
  fetchNearbyWynosPlaces,
  foodMoney,
  reverseFoodPlace,
  searchFoodPlaces,
  searchStorePlaces,
  submitWynosPlaceSuggestion,
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
  getZoom: () => number;
  flyTo: (options: { center: [number, number]; zoom?: number; essential?: boolean }) => void;
  on: (event: string, handler: (event?: unknown) => void) => void;
  off: (event: string, handler: (event?: unknown) => void) => void;
  remove: () => void;
  resize: () => void;
  setStyle: (style: MapStyle) => void;
};

type MarkerInstance = {
  setLngLat: (location: [number, number]) => MarkerInstance;
  addTo: (map: MapInstance) => MarkerInstance;
  remove: () => void;
};

type MapLibreGlobal = {
  Map: new (options: {
    container: HTMLElement;
    style: MapStyle;
    center: [number, number];
    zoom: number;
    attributionControl?: boolean;
    dragPan?: boolean;
    touchZoomRotate?: boolean;
    touchPitch?: boolean;
  }) => MapInstance;
  Marker: new (options: { element: HTMLElement; anchor?: string }) => MarkerInstance;
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
const MAP_STYLE = "/maps/wynos-green.json";
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

function nearbyRadiusForZoom(zoom: number) {
  if (zoom >= 17.5) return 1.5;
  if (zoom >= 16) return 3;
  if (zoom >= 14.5) return 7;
  if (zoom >= 13) return 15;
  return 25;
}

function placeCategory(place: FoodPlace) {
  if (place.category === "restaurant") return "ร้านอาหาร";
  if (place.category === "pickup_point") return "จุดรับอาหาร";
  if (place.category === "building") return "อาคาร";
  if (place.category === "entrance") return "ทางเข้า";
  return "สถานที่";
}

function placeIdentity(place: FoodPlace) {
  return place.placeId ?? `${place.latitude.toFixed(6)},${place.longitude.toFixed(6)},${place.name}`;
}

export function FoodDeliveryMapPicker({
  client,
  storeId,
  initialLocation,
  onClose,
  onConfirm,
  autoLocate = false,
  standalone = false,
}: {
  client: SupabaseClient;
  storeId: string | null;
  initialLocation: FoodLocation | null;
  onClose: () => void;
  onConfirm: (location: FoodLocation, place?: FoodPlace) => void;
  autoLocate?: boolean;
  standalone?: boolean;
}) {
  const mapNode = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<MapInstance | null>(null);
  const dragRef = useRef(false);
  const reverseTimerRef = useRef<number | null>(null);
  const reverseRequestRef = useRef(0);
  const nearbyRequestRef = useRef(0);
  const nearbyMarkersRef = useRef<MarkerInstance[]>([]);
  const autoLocateRef = useRef(false);
  const searchTimerRef = useRef<number | null>(null);
  const searchRequestRef = useRef(0);
  const sheetPointerStartRef = useRef<number | null>(null);
  const [location, setLocation] = useState<FoodLocation | null>(initialLocation);
  const [place, setPlace] = useState<FoodPlace | null>(null);
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<FoodPlace[]>([]);
  const [nearbyPlaces, setNearbyPlaces] = useState<FoodPlace[]>([]);
  const [activeNearbyPlace, setActiveNearbyPlace] = useState<FoodPlace | null>(null);
  const [nearbyAvailabilityState, setNearbyAvailabilityState] = useState<{
    key: string;
    value: Awaited<ReturnType<typeof checkFoodDeliveryAvailability>>;
  } | null>(null);
  const [status, setStatus] = useState("");
  const [working, setWorking] = useState(false);
  const [searching, setSearching] = useState(false);
  const [searchFocused, setSearchFocused] = useState(false);
  const [showAttribution, setShowAttribution] = useState(false);
  const [showSuggestion, setShowSuggestion] = useState(false);
  const [suggestionName, setSuggestionName] = useState("");
  const [suggestionCategory, setSuggestionCategory] = useState<"place" | "restaurant" | "store" | "building" | "residence" | "poi">("place");
  const [suggestionAddress, setSuggestionAddress] = useState("");
  const [suggestionNote, setSuggestionNote] = useState("");
  const [submittingSuggestion, setSubmittingSuggestion] = useState(false);
  const [resolvingPlace, setResolvingPlace] = useState(false);
  const [mapZoom, setMapZoom] = useState(initialLocation ? 16 : 5.4);
  const [mapReady, setMapReady] = useState(false);
  const [mapFailed, setMapFailed] = useState(false);
  const [mapAttempt, setMapAttempt] = useState(0);
  const [chosen, setChosen] = useState(Boolean(initialLocation));
  const [sheetExpanded, setSheetExpanded] = useState(false);
  const [currentLocationSelected, setCurrentLocationSelected] = useState(false);
  const [mapDragging, setMapDragging] = useState(false);

  const reverse = useCallback(async (next: FoodLocation) => {
    const requestId = ++reverseRequestRef.current;
    setResolvingPlace(true);
    try {
      const found = await reverseFoodPlace(client, next);
      if (reverseRequestRef.current === requestId) setPlace(found);
    } catch {
      if (reverseRequestRef.current === requestId) setPlace(null);
    } finally {
      if (reverseRequestRef.current === requestId) setResolvingPlace(false);
    }
  }, [client]);

  const loadNearby = useCallback(async (center: FoodLocation) => {
    const requestId = ++nearbyRequestRef.current;
    const zoom = mapRef.current?.getZoom() ?? (initialLocation ? 16 : 5.4);
    try {
      const places = await fetchNearbyWynosPlaces(client, center, nearbyRadiusForZoom(zoom));
      if (nearbyRequestRef.current === requestId) setNearbyPlaces(places);
    } catch {
      if (nearbyRequestRef.current === requestId) setNearbyPlaces([]);
    }
  }, [client, initialLocation]);

  const moveTo = useCallback((next: FoodLocation, nextPlace?: FoodPlace) => {
    reverseRequestRef.current += 1;
    setLocation(next);
    setChosen(true);
    setPlace(nextPlace ?? null);
    setResolvingPlace(false);
    setActiveNearbyPlace(null);
    setCurrentLocationSelected(false);
    mapRef.current?.flyTo({
      center: [next.longitude, next.latitude],
      zoom: 17,
      essential: true,
    });
    void loadNearby(next);
  }, [loadNearby]);

  const pickCurrentLocation = useCallback(async () => {
    setWorking(true);
    setStatus("");
    try {
      const next = await currentFoodLocation();
      moveTo(next);
      setCurrentLocationSelected(true);
      await reverse(next);
    } catch (error) {
      setStatus(error instanceof Error ? error.message : "หาตำแหน่งปัจจุบันไม่สำเร็จ");
    } finally {
      setWorking(false);
    }
  }, [moveTo, reverse]);

  useEffect(() => {
    let live = true;
    let map: MapInstance | null = null;
    let fallbackApplied = false;
    let styleLoaded = false;
    let fallbackTimer: number | null = null;
    let failureTimer: number | null = null;
    let touchNode: HTMLDivElement | null = null;
    let preventPagePan: ((event: TouchEvent) => void) | null = null;

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
          attributionControl: false,
          dragPan: true,
          touchZoomRotate: true,
          touchPitch: false,
        });
        mapRef.current = map;

        // iOS Safari can try to treat a one-finger vertical swipe as page movement
        // before MapLibre finishes claiming the gesture. Keep single-finger gestures
        // inside the map so drag-pan remains available in every direction.
        touchNode = mapNode.current;
        preventPagePan = (event: TouchEvent) => {
          if (event.touches.length === 1 && event.cancelable) event.preventDefault();
        };
        touchNode.addEventListener("touchmove", preventPagePan, { passive: false });

        const markReady = () => {
          if (!live) return;
          styleLoaded = true;
          setMapReady(true);
          setMapFailed(false);
          void loadNearby({ latitude: start[1], longitude: start[0] });
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
          setMapDragging(true);
          setCurrentLocationSelected(false);
        };
        const onMoveEnd = () => {
          if (!map) return;
          setMapZoom(map.getZoom());
          const center = map.getCenter();
          const next = { latitude: center.lat, longitude: center.lng };
          void loadNearby(next);
          if (!dragRef.current) return;
          dragRef.current = false;
          setMapDragging(false);
          reverseRequestRef.current += 1;
          setLocation(next);
          setChosen(true);
          setPlace(null);
          setResolvingPlace(true);
          setActiveNearbyPlace(null);
          if (reverseTimerRef.current) window.clearTimeout(reverseTimerRef.current);
          reverseTimerRef.current = window.setTimeout(() => void reverse(next), 450);
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
      if (searchTimerRef.current) window.clearTimeout(searchTimerRef.current);
      if (touchNode && preventPagePan) touchNode.removeEventListener("touchmove", preventPagePan);
      searchRequestRef.current += 1;
      reverseRequestRef.current += 1;
      nearbyRequestRef.current += 1;
      nearbyMarkersRef.current.forEach((marker) => marker.remove());
      nearbyMarkersRef.current = [];
      map?.remove();
      mapRef.current = null;
    };
  }, [initialLocation, loadNearby, mapAttempt, reverse]);

  useEffect(() => {
    if (!mapReady || !autoLocate || initialLocation || autoLocateRef.current) return;
    autoLocateRef.current = true;
    const timer = window.setTimeout(() => void pickCurrentLocation(), 0);
    return () => window.clearTimeout(timer);
  }, [autoLocate, initialLocation, mapReady, pickCurrentLocation]);

  useEffect(() => {
    const map = mapRef.current;
    const maplibre = window.maplibregl;
    if (!mapReady || !map || !maplibre) return;

    nearbyMarkersRef.current.forEach((marker) => marker.remove());
    const markers = nearbyPlaces.map((nearbyPlace, index) => {
      const button = document.createElement("button");
      button.type = "button";
      const selected = activeNearbyPlace
        ? placeIdentity(activeNearbyPlace) === placeIdentity(nearbyPlace)
        : false;
      const markerKind = nearbyPlace.merchantStoreId
        ? "wf-map-place-marker is-food"
        : "wf-map-place-marker is-place";
      button.className = `${markerKind}${selected ? " is-selected" : ""}`;
      button.setAttribute("aria-label", `${placeCategory(nearbyPlace)} ${nearbyPlace.name}`);
      button.title = nearbyPlace.name;
      const dot = document.createElement("span");
      dot.className = "wf-map-place-dot";
      button.appendChild(dot);
      const labelLimit = standalone ? 12 : 24;
      if (selected || (mapZoom >= 14.5 && index < labelLimit)) {
        const label = document.createElement("strong");
        label.className = "wf-map-place-label";
        label.textContent = nearbyPlace.name;
        button.appendChild(label);
      }
      button.addEventListener("click", (event) => {
        event.preventDefault();
        event.stopPropagation();
        setActiveNearbyPlace(nearbyPlace);
        if (standalone) setSheetExpanded(true);
      });
      return new maplibre.Marker({ element: button, anchor: "bottom" })
        .setLngLat([nearbyPlace.longitude, nearbyPlace.latitude])
        .addTo(map);
    });
    nearbyMarkersRef.current = markers;

    return () => {
      markers.forEach((marker) => marker.remove());
      if (nearbyMarkersRef.current === markers) nearbyMarkersRef.current = [];
    };
  }, [activeNearbyPlace, mapReady, mapZoom, nearbyPlaces, standalone]);

  const availabilityKey = activeNearbyPlace?.merchantStoreId && location
    ? `${activeNearbyPlace.merchantStoreId}|${location.latitude},${location.longitude}`
    : "";

  useEffect(() => {
    if (!activeNearbyPlace?.merchantStoreId || !location || !availabilityKey) return;
    let live = true;
    const store = activeNearbyPlace.merchantStoreId;
    const deliveryPoint = location;
    void checkFoodDeliveryAvailability(client, store, deliveryPoint)
      .then((value) => {
        if (live) setNearbyAvailabilityState({ key: availabilityKey, value });
      })
      .catch(() => {
        if (live) setNearbyAvailabilityState({ key: availabilityKey, value: null });
      });
    return () => { live = false; };
  }, [activeNearbyPlace?.merchantStoreId, availabilityKey, client, location]);

  const nearbyAvailability = nearbyAvailabilityState?.key === availabilityKey
    ? nearbyAvailabilityState.value
    : null;

  const runSearch = useCallback(async (rawQuery: string, silent = false) => {
    const trimmed = rawQuery.trim();
    if (!trimmed) {
      setResults([]);
      return;
    }
    const requestId = ++searchRequestRef.current;
    setSearching(true);
    if (!silent) setStatus("");
    try {
      let next = storeId ? (await searchStorePlaces(client, storeId, trimmed)) ?? [] : [];
      if (!next.length) next = await searchFoodPlaces(client, trimmed, location);
      if (searchRequestRef.current !== requestId) return;
      setResults(next);
      if (!silent && !next.length) {
        setStatus("ไม่พบสถานที่ ลองพิมพ์ชื่อถนน หมู่บ้าน หอพัก หรือสถานที่ใกล้เคียง");
      }
    } catch (error) {
      if (searchRequestRef.current !== requestId) return;
      setResults([]);
      if (!silent) setStatus(error instanceof Error ? error.message : "ค้นหาสถานที่ไม่สำเร็จ");
    } finally {
      if (searchRequestRef.current === requestId) setSearching(false);
    }
  }, [client, location, storeId]);

  useEffect(() => {
    if (!standalone || !searchFocused) return;
    const trimmed = query.trim();
    if (trimmed.length < 2) return;
    if (searchTimerRef.current) window.clearTimeout(searchTimerRef.current);
    searchTimerRef.current = window.setTimeout(() => {
      void runSearch(trimmed, true);
    }, 280);
    return () => {
      if (searchTimerRef.current) window.clearTimeout(searchTimerRef.current);
    };
  }, [query, runSearch, searchFocused, standalone]);

  const search = () => {
    setSearchFocused(true);
    void runSearch(query, false);
  };

  const openSuggestion = () => {
    if (!location) {
      setStatus("ปักหมุดตำแหน่งของสถานที่ก่อน");
      return;
    }
    setSuggestionName("");
    setSuggestionCategory("place");
    setSuggestionAddress(place?.address ?? "");
    setSuggestionNote("");
    setShowSuggestion(true);
    if (standalone) setSheetExpanded(true);
  };

  const submitSuggestion = async () => {
    if (!location || !suggestionName.trim()) return;
    setSubmittingSuggestion(true);
    setStatus("");
    try {
      await submitWynosPlaceSuggestion(client, {
        name: suggestionName,
        category: suggestionCategory,
        address: suggestionAddress,
        note: suggestionNote,
        location,
      });
      setShowSuggestion(false);
      setStatus("ส่งสถานที่ให้ WYNOS ตรวจสอบแล้ว เมื่ออนุมัติชื่อจะขึ้นบนแผนที่");
    } catch (error) {
      setStatus(error instanceof Error ? error.message : "ส่งสถานที่ไม่สำเร็จ");
    } finally {
      setSubmittingSuggestion(false);
    }
  };

  const chooseResult = (result: FoodPlace) => {
    setResults([]);
    setSearchFocused(false);
    setQuery(result.name);
    setSheetExpanded(false);
    moveTo({ latitude: result.latitude, longitude: result.longitude }, result);
  };

  const zoomMap = (delta: number) => {
    const map = mapRef.current;
    if (!map) return;
    const center = map.getCenter();
    const nextZoom = Math.min(19, Math.max(3, map.getZoom() + delta));
    map.flyTo({ center: [center.lng, center.lat], zoom: nextZoom, essential: true });
  };

  const showLegacySearchAttribution =
    place?.source === "legacy" || results.some((result) => result.source === "legacy");
  const showPhotonAttribution =
    place?.source === "photon" || results.some((result) => result.source === "photon");

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
            onFocus={() => setSearchFocused(true)}
            onChange={(event) => {
              const nextQuery = event.target.value;
              setQuery(nextQuery);
              setSearchFocused(true);
              if (nextQuery.trim().length < 2) {
                searchRequestRef.current += 1;
                setSearching(false);
                setResults([]);
              }
            }}
            onKeyDown={(event) => {
              if (event.key === "Enter") {
                event.preventDefault();
                search();
              } else if (event.key === "Escape") {
                setResults([]);
                setSearchFocused(false);
                event.currentTarget.blur();
              }
            }}
            placeholder="ค้นหาสถานที่ ถนน หมู่บ้าน หอพัก"
            aria-label="ค้นหาสถานที่หรือที่อยู่"
            autoComplete="off"
          />
          <button type="button" disabled={searching || !query.trim()} onClick={search}>
            {searching ? "กำลังค้น…" : "ค้นหา"}
          </button>
        </div>
        {results.length ? (
          <div className="wf-map-results">
            {results.map((result) => (
              <button key={result.placeId ?? `${result.latitude},${result.longitude},${result.name}`} type="button" onClick={() => chooseResult(result)}>
                <MapPin size={17} />
                <span>
                  <strong>{result.name || "สถานที่"}</strong>
                  <small>{placeCategory(result)}{result.address ? ` · ${result.address}` : ""}</small>
                </span>
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
        <div className={mapDragging ? "wf-map-center-pin is-dragging" : "wf-map-center-pin"} aria-hidden="true">
          <MapPin size={42} fill="currentColor" />
        </div>
        <div className="wf-map-attribution">
          {showAttribution ? (
            <div className="wf-map-attribution-panel" role="dialog" aria-label="ข้อมูลแผนที่และแหล่งข้อมูล">
              <strong>ข้อมูลแผนที่</strong>
              <a href="https://openfreemap.org" target="_blank" rel="noreferrer">OpenFreeMap</a>
              <a href="https://www.openmaptiles.org/" target="_blank" rel="noreferrer">© OpenMapTiles</a>
              <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noreferrer">© OpenStreetMap contributors</a>
              {showPhotonAttribution ? (
                <a href="https://photon.komoot.io" target="_blank" rel="noreferrer">Geocoding by Photon</a>
              ) : null}
              {showLegacySearchAttribution ? (
                <a href="https://locationiq.com" target="_blank" rel="noreferrer">Search by LocationIQ</a>
              ) : null}
              <button type="button" onClick={() => setShowAttribution(false)}>ปิด</button>
            </div>
          ) : null}
          <button
            type="button"
            className="wf-map-attribution-button"
            aria-label="ข้อมูลแผนที่และแหล่งข้อมูล"
            aria-expanded={showAttribution}
            onClick={() => setShowAttribution((value) => !value)}
          >
            <Info size={14} />
          </button>
        </div>
        <button
          className={currentLocationSelected ? "wf-map-current is-active" : "wf-map-current"}
          type="button"
          disabled={working}
          onClick={() => void pickCurrentLocation()}
        >
          <LocateFixed size={19} /> <span>{working ? "กำลังระบุตำแหน่ง…" : "ตำแหน่งปัจจุบัน"}</span>
        </button>
        {standalone ? (
          <div className="wf-map-zoom-control" aria-label="ควบคุมการซูมแผนที่">
            <button type="button" aria-label="ซูมเข้า" onClick={() => zoomMap(1)}><Plus size={18} /></button>
            <button type="button" aria-label="ซูมออก" onClick={() => zoomMap(-1)}><Minus size={18} /></button>
          </div>
        ) : null}
      </div>

      <section className={standalone ? `wf-map-confirm wf-map-sheet${sheetExpanded ? " is-expanded" : ""}` : "wf-map-confirm"}>
        {standalone ? (
          <button
            type="button"
            className="wf-map-sheet-handle"
            aria-label={sheetExpanded ? "ย่อรายละเอียดตำแหน่ง" : "ขยายรายละเอียดตำแหน่ง"}
            aria-expanded={sheetExpanded}
            onPointerDown={(event) => {
              event.preventDefault();
              event.stopPropagation();
              sheetPointerStartRef.current = event.clientY;
              event.currentTarget.setPointerCapture(event.pointerId);
            }}
            onPointerUp={(event) => {
              event.preventDefault();
              event.stopPropagation();
              const start = sheetPointerStartRef.current;
              sheetPointerStartRef.current = null;
              if (start == null) return;
              const distance = event.clientY - start;
              if (distance < -28) setSheetExpanded(true);
              else if (distance > 28) setSheetExpanded(false);
              else setSheetExpanded((value) => !value);
            }}
            onPointerCancel={() => {
              sheetPointerStartRef.current = null;
            }}
          >
            <span />
          </button>
        ) : null}
        {activeNearbyPlace ? (
          <article className="wf-map-place-card">
            <button className="wf-map-place-close" type="button" aria-label="ปิดข้อมูลสถานที่" onClick={() => {
              setActiveNearbyPlace(null);
              if (standalone) setSheetExpanded(false);
            }}>
              <X size={16} />
            </button>
            <div className={activeNearbyPlace.merchantStoreId ? "wf-map-place-icon is-food" : "wf-map-place-icon"}>
              {activeNearbyPlace.merchantStoreId ? <Store size={18} /> : <MapPin size={18} />}
            </div>
            <div className="wf-map-place-copy">
              <small>{placeCategory(activeNearbyPlace)}{activeNearbyPlace.verificationStatus === "wynos_verified" ? " · WYNOS Verified" : activeNearbyPlace.verificationStatus === "merchant_verified" ? " · Merchant Verified" : ""}</small>
              <strong>{activeNearbyPlace.name}</strong>
              {activeNearbyPlace.address ? <p>{activeNearbyPlace.address}</p> : null}
              {activeNearbyPlace.distanceKm != null ? <em>{activeNearbyPlace.distanceKm.toFixed(1)} กม. จากกลางแผนที่</em> : null}
              {activeNearbyPlace.merchantStoreId ? (
                <div className="wf-map-place-delivery">
                  <span className={activeNearbyPlace.isOpen ? "is-open" : ""}>
                    {activeNearbyPlace.isOpen ? "เปิดรับออเดอร์" : "ปิดรับออเดอร์"}
                  </span>
                  {!location ? <small>ปักหมุดที่อยู่ก่อนเพื่อเช็กการจัดส่ง</small> : nearbyAvailability?.can_deliver ? (
                    <small>ร้านนี้ส่งถึง · {nearbyAvailability.distance_km?.toFixed(1) ?? "—"} กม. · ค่าส่ง {foodMoney(nearbyAvailability.delivery_fee ?? 0)}</small>
                  ) : nearbyAvailability?.reason === "outside_delivery_area" ? (
                    <small>อยู่นอกระยะจัดส่งของร้าน</small>
                  ) : null}
                </div>
              ) : null}
            </div>
            <div className="wf-map-place-actions">
              <button
                type="button"
                onClick={() => {
                  moveTo(
                    { latitude: activeNearbyPlace.latitude, longitude: activeNearbyPlace.longitude },
                    activeNearbyPlace,
                  );
                  if (standalone) setSheetExpanded(false);
                }}
              >
                ใช้ตำแหน่งนี้
              </button>
              {activeNearbyPlace.merchantStoreId ? (
                <a href={`/food?store=${encodeURIComponent(activeNearbyPlace.merchantStoreId)}`}>ดูร้านใน WYNOS Food</a>
              ) : null}
            </div>
          </article>
        ) : null}

        <div className="wf-map-confirm-copy">
          <span><MapPin size={18} /></span>
          <div>
            <small>ตำแหน่งจัดส่ง</small>
            <strong>
              {place?.name
                || (resolvingPlace
                  ? "กำลังค้นหาชื่อสถานที่…"
                  : location
                    ? "ไม่พบชื่อสถานที่"
                    : "เลื่อนแผนที่หรือค้นหาสถานที่")}
            </strong>
            {place?.address ? <p className="wf-map-confirm-address">{place.address}</p> : null}
            {!place && location && !resolvingPlace ? (
              <code className="wf-map-confirm-coordinates">{location.latitude.toFixed(5)}, {location.longitude.toFixed(5)}</code>
            ) : null}
          </div>
        </div>
        {status ? <p role="status">{status}</p> : null}

        {showSuggestion ? (
          <div className="wf-map-suggestion">
            <div className="wf-map-suggestion-head">
              <div>
                <strong>เพิ่มสถานที่ที่หายไป</strong>
                <small>ใช้หมุดปัจจุบันเป็นตำแหน่ง สถานที่จะขึ้นแผนที่หลังผ่านการตรวจสอบ</small>
              </div>
              <button type="button" aria-label="ปิดฟอร์มเพิ่มสถานที่" onClick={() => setShowSuggestion(false)}><X size={16} /></button>
            </div>
            <input
              value={suggestionName}
              onChange={(event) => setSuggestionName(event.target.value)}
              placeholder="ชื่อสถานที่ เช่น หอพักธาราทิพย์"
              maxLength={160}
            />
            <select value={suggestionCategory} onChange={(event) => setSuggestionCategory(event.target.value as typeof suggestionCategory)}>
              <option value="residence">หอพัก / ที่พักอาศัย</option>
              <option value="restaurant">ร้านอาหาร</option>
              <option value="store">ร้านค้า</option>
              <option value="building">อาคาร</option>
              <option value="poi">จุดสำคัญ</option>
              <option value="place">สถานที่อื่น ๆ</option>
            </select>
            <input
              value={suggestionAddress}
              onChange={(event) => setSuggestionAddress(event.target.value)}
              placeholder="ที่อยู่หรือรายละเอียดพื้นที่ (ถ้ามี)"
              maxLength={1000}
            />
            <textarea
              value={suggestionNote}
              onChange={(event) => setSuggestionNote(event.target.value)}
              placeholder="ข้อมูลเพิ่มเติมสำหรับทีมตรวจสอบ (ถ้ามี)"
              maxLength={500}
            />
            <button
              type="button"
              className="wf-map-suggestion-submit"
              disabled={submittingSuggestion || !suggestionName.trim() || !location}
              onClick={() => void submitSuggestion()}
            >
              <Check size={16} /> {submittingSuggestion ? "กำลังส่ง…" : "ส่งให้ตรวจสอบ"}
            </button>
          </div>
        ) : (
          <button type="button" className="wf-map-add-place" disabled={!location} onClick={openSuggestion}>
            <Plus size={16} /> เพิ่มสถานที่ที่หายไป
          </button>
        )}

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

      </section>
    </div>
  );
}
