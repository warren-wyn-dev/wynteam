"use client";

import type { SupabaseClient } from "@supabase/supabase-js";
import { ArrowLeft, Briefcase, Building2, Check, Clock, Coffee, Home, ImagePlus, Info, LocateFixed, MapPin, Minus, Navigation, Plus, RefreshCw, Search, Share, ShoppingBag, Star, Store, Utensils, X } from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";

import {
  checkFoodDeliveryAvailability,
  currentFoodLocation,
  fetchNearbyWynosPlaces,
  fetchWynosPlaceDetails,
  foodMoney,
  foodPublicUrl,
  reverseFoodPlace,
  searchFoodPlaces,
  searchStorePlaces,
  submitWynosPlaceSuggestion,
  type FoodLocation,
  type FoodPlace,
  type WynosPlaceDetails,
} from "@/lib/food-customer";
import {
  canHavePhotos,
  loadPlacePhotos,
  uploadPlacePhoto,
  withdrawPlacePhoto,
  type PlacePhotosState,
} from "@/lib/maps-place-photos";
import {
  deleteSavedPlace,
  loadSavedPlaces,
  saveMapPlace,
  type SavedPlace,
  type SavedPlaceKind,
  type SavedPlacesState,
} from "@/lib/maps-saved-places";
import {
  clearRecentPlaces,
  formatDistanceKm,
  loadRecentPlaces,
  mapsShareUrl,
  rememberRecentPlace,
  type MapsRecentPlace,
} from "@/lib/maps-places";
import { formatRouteDistance, formatRouteDuration, parseWynosRoute, type MapsRoute, type MapsTravelMode } from "@/lib/maps-routing";

type MapCenter = { lat: number; lng: number };
type MapPoint = { x: number; y: number };
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

type ServiceAreaFeature = {
  type: "Feature";
  properties: {
    code?: string;
    name?: string;
    service?: string;
    source?: string;
    attribution?: string;
  };
  geometry: {
    type: "Polygon";
    coordinates: number[][][];
  };
};

type RouteLineFeature = {
  type: "Feature";
  properties: {
    mode: MapsTravelMode;
  };
  geometry: {
    type: "LineString";
    coordinates: Array<[number, number]>;
  };
};

type RouteTarget = {
  name: string;
  latitude: number;
  longitude: number;
};

type MapInstance = {
  getCenter: () => MapCenter;
  getZoom: () => number;
  project: (location: [number, number]) => MapPoint;
  flyTo: (options: { center: [number, number]; zoom?: number; essential?: boolean }) => void;
  fitBounds: (
    bounds: [[number, number], [number, number]],
    options?: { padding?: { top: number; right: number; bottom: number; left: number }; maxZoom?: number; duration?: number },
  ) => void;
  on: (event: string, handler: (event?: unknown) => void) => void;
  off: (event: string, handler: (event?: unknown) => void) => void;
  remove: () => void;
  resize: () => void;
  setStyle: (style: MapStyle) => void;
  getSource: (id: string) => unknown;
  getLayer: (id: string) => unknown;
  addSource: (id: string, source: { type: "geojson"; data: ServiceAreaFeature | RouteLineFeature }) => void;
  removeLayer: (id: string) => void;
  removeSource: (id: string) => void;
  addLayer: (layer: {
    id: string;
    type: "fill" | "line";
    source: string;
    paint: Record<string, string | number>;
  }) => void;
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
const MAP_STYLE_DARK = "/maps/wynos-dark.json";
const SERVICE_AREA_URL = "/maps/food-service-area-maha-sarakham.json";
const SERVICE_AREA_SOURCE = "wynos-food-service-area";
const SERVICE_AREA_FILL_LAYER = "wynos-food-service-area-fill";
const SERVICE_AREA_LINE_LAYER = "wynos-food-service-area-line";
const ROUTE_SOURCE = "wynos-maps-route";
const ROUTE_LINE_LAYER = "wynos-maps-route-line";
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

// Same rule as the app theme (lib/theme-preference.ts): an explicit
// data-theme wins, otherwise follow the phone.
function prefersDarkMap() {
  const theme = document.documentElement.dataset.theme;
  if (theme === "dark") return true;
  if (theme === "light") return false;
  return window.matchMedia?.("(prefers-color-scheme: dark)").matches ?? false;
}

type SheetDetent = "peek" | "half" | "full";

function mapsStorage() {
  try {
    return window.localStorage;
  } catch {
    return null;
  }
}

function nearbyRadiusForZoom(zoom: number) {
  if (zoom >= 17.5) return 1.5;
  if (zoom >= 16) return 3;
  if (zoom >= 14.5) return 7;
  if (zoom >= 13) return 15;
  return 25;
}

function isServiceAreaFeature(value: unknown): value is ServiceAreaFeature {
  if (!value || typeof value !== "object") return false;
  const feature = value as Partial<ServiceAreaFeature>;
  return feature.type === "Feature"
    && feature.geometry?.type === "Polygon"
    && Array.isArray(feature.geometry.coordinates?.[0])
    && feature.geometry.coordinates[0].length >= 3;
}

function pointInServiceArea(location: FoodLocation, feature: ServiceAreaFeature) {
  const ring = feature.geometry.coordinates[0] ?? [];
  if (ring.length < 3) return false;
  const x = location.longitude;
  const y = location.latitude;
  let inside = false;
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const xi = ring[i]?.[0];
    const yi = ring[i]?.[1];
    const xj = ring[j]?.[0];
    const yj = ring[j]?.[1];
    if (xi == null || yi == null || xj == null || yj == null) continue;
    const crosses = (yi > y) !== (yj > y)
      && x < ((xj - xi) * (y - yi)) / ((yj - yi) || Number.EPSILON) + xi;
    if (crosses) inside = !inside;
  }
  return inside;
}

function placeCategory(place: FoodPlace) {
  if (place.category === "restaurant") return "ร้านอาหาร";
  if (place.category === "pickup_point") return "จุดรับอาหาร";
  if (place.category === "building") return "อาคาร";
  if (place.category === "entrance") return "ทางเข้า";
  if (place.category === "store") return "ร้านค้า";
  if (place.category === "residence") return "ที่พัก";
  if (place.category === "poi") return "จุดสำคัญ";
  return "สถานที่";
}

function placeIdentity(place: FoodPlace) {
  return place.placeId ?? `${place.latitude.toFixed(6)},${place.longitude.toFixed(6)},${place.name}`;
}

type MapMarkerKind = "food" | "cafe" | "building" | "shop" | "pickup" | "place";

function placeMarkerKind(place: FoodPlace): MapMarkerKind {
  const name = place.name.toLocaleLowerCase();
  if (/คาเฟ่|กาแฟ|coffee|cafe|café|amazon/.test(name)) return "cafe";
  if (place.merchantStoreId || place.category === "restaurant") return "food";
  if (place.category === "pickup_point") return "pickup";
  if (
    place.category === "building"
    || place.category === "residence"
    || /มหาวิทยาลัย|คณะ|อาคาร|หอพัก|university|faculty|institute|dorm/.test(name)
  ) return "building";
  if (place.category === "store" || /ร้านค้า|ตลาด|shop|store|market/.test(name)) return "shop";
  return "place";
}

function placeMarkerSvg(kind: MapMarkerKind) {
  const common = 'viewBox="0 0 24 24" aria-hidden="true" focusable="false"';
  if (kind === "food") {
    return `<svg ${common}><path d="M7 3v7M4.5 3v4.5A2.5 2.5 0 0 0 7 10v11M16.5 3v18M16.5 3c-2 2.2-3 5-3 8h3"/></svg>`;
  }
  if (kind === "cafe") {
    return `<svg ${common}><path d="M5 7h11v6a5 5 0 0 1-5 5H10a5 5 0 0 1-5-5V7Z"/><path d="M16 9h1.5a2.5 2.5 0 0 1 0 5H16M7 3.5c.8.6.8 1.3 0 2M11 3.5c.8.6.8 1.3 0 2"/></svg>`;
  }
  if (kind === "building") {
    return `<svg ${common}><path d="M5 21V4a1 1 0 0 1 1-1h9a1 1 0 0 1 1 1v17M16 8h3v13M8 7h2M12 7h1M8 11h2M12 11h1M8 15h2M12 15h1M3 21h18"/></svg>`;
  }
  if (kind === "shop") {
    return `<svg ${common}><path d="M5 9h14l-1 12H6L5 9Z"/><path d="M9 10V7a3 3 0 0 1 6 0v3"/></svg>`;
  }
  if (kind === "pickup") {
    return `<svg ${common}><path d="M5 7.5 12 4l7 3.5V17l-7 3-7-3V7.5Z"/><path d="m5 7.5 7 3.5 7-3.5M12 11v9"/></svg>`;
  }
  return `<svg ${common}><circle cx="12" cy="12" r="4"/><path d="M12 3v3M12 18v3M3 12h3M18 12h3"/></svg>`;
}

export function FoodLocationMapPreview({
  location,
  label = "ตำแหน่งร้าน",
}: {
  location: FoodLocation;
  label?: string;
}) {
  const node = useRef<HTMLDivElement | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let live = true;
    let map: MapInstance | null = null;
    void loadMapLibre()
      .then((maplibre) => {
        if (!live || !node.current) return;
        node.current.replaceChildren();
        map = new maplibre.Map({
          container: node.current,
          style: MAP_STYLE,
          center: [location.longitude, location.latitude],
          zoom: 16.5,
          attributionControl: false,
          dragPan: false,
          touchZoomRotate: false,
          touchPitch: false,
        });
        const resize = () => map?.resize();
        map.on("load", resize);
        window.setTimeout(resize, 80);
        window.setTimeout(resize, 360);
      })
      .catch(() => { if (live) setFailed(true); });
    return () => {
      live = false;
      map?.remove();
    };
  }, [location.latitude, location.longitude]);

  return (
    <div className="wf-location-map-preview" aria-label={label}>
      <div ref={node} className="wf-location-map-preview-canvas" />
      <span className="wf-location-map-preview-pin" aria-hidden="true"><MapPin size={28} fill="currentColor" /></span>
      <small>{failed ? "แผนที่โหลดไม่สำเร็จ" : label}</small>
    </div>
  );
}

export function FoodDeliveryMapPicker({
  client,
  storeId,
  initialLocation,
  onClose,
  onConfirm,
  autoLocate = false,
  standalone = false,
  title,
  subtitle,
  confirmLabel,
}: {
  client: SupabaseClient;
  storeId: string | null;
  initialLocation: FoodLocation | null;
  onClose: () => void;
  onConfirm: (location: FoodLocation, place?: FoodPlace) => void;
  autoLocate?: boolean;
  standalone?: boolean;
  title?: string;
  subtitle?: string;
  confirmLabel?: string;
}) {
  const mapNode = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<MapInstance | null>(null);
  const dragRef = useRef(false);
  const reverseTimerRef = useRef<number | null>(null);
  const reverseRequestRef = useRef(0);
  const nearbyRequestRef = useRef(0);
  const routeRequestRef = useRef(0);
  const nearbyMarkersRef = useRef<MarkerInstance[]>([]);
  const userLocationMarkerRef = useRef<MarkerInstance | null>(null);
  const entranceMarkerRef = useRef<MarkerInstance | null>(null);
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
  const [activePlaceDetails, setActivePlaceDetails] = useState<WynosPlaceDetails | null>(null);
  const [nearbyAvailabilityState, setNearbyAvailabilityState] = useState<{
    key: string;
    value: Awaited<ReturnType<typeof checkFoodDeliveryAvailability>>;
  } | null>(null);
  const [status, setStatus] = useState("");
  const [working, setWorking] = useState(false);
  const [searching, setSearching] = useState(false);
  const [searchFocused, setSearchFocused] = useState(false);
  // Standalone Maps hides the sheet by default, so search feedback shows under the search box.
  const [searchStatus, setSearchStatus] = useState("");
  const [recentPlaces, setRecentPlaces] = useState<MapsRecentPlace[]>([]);
  const [saved, setSaved] = useState<SavedPlacesState>({ status: "unavailable" });
  const [saveTarget, setSaveTarget] = useState<{
    name: string;
    address: string | null;
    placeId: string | null;
    latitude: number;
    longitude: number;
  } | null>(null);
  const [savingPlace, setSavingPlace] = useState(false);
  const [placePhotos, setPlacePhotos] = useState<{ placeId: string; state: PlacePhotosState } | null>(null);
  const [uploadingPhoto, setUploadingPhoto] = useState(false);
  const photoInputRef = useRef<HTMLInputElement | null>(null);
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
  // Standalone Maps uses a three-stop sheet: peek (search only), half
  // (search + selected place) and full (results or place details).
  const [sheetDetent, setSheetDetent] = useState<SheetDetent>("half");
  const sheetExpanded = sheetDetent === "full";
  const setSheetExpanded = useCallback((expanded: boolean) => setSheetDetent(expanded ? "full" : "half"), []);
  const [currentLocationSelected, setCurrentLocationSelected] = useState(false);
  const [userLocation, setUserLocation] = useState<FoodLocation | null>(null);
  const [mapDragging, setMapDragging] = useState(false);
  const [mapStyleRevision, setMapStyleRevision] = useState(0);
  const [serviceAreaBoundary, setServiceAreaBoundary] = useState<ServiceAreaFeature | null>(null);
  const [directionsTarget, setDirectionsTarget] = useState<RouteTarget | null>(null);
  const [routeMode, setRouteMode] = useState<MapsTravelMode>("motorcycle");
  const [route, setRoute] = useState<MapsRoute | null>(null);
  const [routeWorking, setRouteWorking] = useState(false);
  const [routeStatus, setRouteStatus] = useState("");

  const serviceAreaState = standalone && location && serviceAreaBoundary
    ? (pointInServiceArea(location, serviceAreaBoundary) ? "inside" : "outside")
    : "unknown";

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
      zoom: standalone ? 15.8 : 17,
      essential: true,
    });
    void loadNearby(next);
  }, [loadNearby, standalone]);

  const pickCurrentLocation = useCallback(async () => {
    setWorking(true);
    setStatus("");
    try {
      const next = await currentFoodLocation();
      setUserLocation(next);
      moveTo(next);
      setCurrentLocationSelected(true);
      await reverse(next);
    } catch (error) {
      setStatus(error instanceof Error ? error.message : "หาตำแหน่งปัจจุบันไม่สำเร็จ");
    } finally {
      setWorking(false);
    }
  }, [moveTo, reverse]);

  const clearRoute = useCallback(() => {
    routeRequestRef.current += 1;
    setDirectionsTarget(null);
    setRoute(null);
    setRouteStatus("");
    setRouteWorking(false);
  }, []);

  const requestRoute = useCallback(async (target: RouteTarget, mode: MapsTravelMode = routeMode) => {
    if (!standalone) return;
    const requestId = ++routeRequestRef.current;
    setDirectionsTarget(target);
    setRouteMode(mode);
    setRoute(null);
    setRouteStatus("");
    setRouteWorking(true);
    setSearchFocused(false);
    setResults([]);
    setSheetDetent("half");

    try {
      let origin = userLocation;
      if (!origin) {
        origin = await currentFoodLocation();
        if (routeRequestRef.current !== requestId) return;
        setUserLocation(origin);
      }

      const response = await fetch("/api/maps/route", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          locations: [
            { lat: origin.latitude, lon: origin.longitude },
            { lat: target.latitude, lon: target.longitude },
          ],
          costing: mode,
        }),
      });
      const payload = await response.json().catch(() => null) as unknown;
      if (routeRequestRef.current !== requestId) return;
      if (!response.ok) {
        const error = payload && typeof payload === "object" && "error" in payload
          ? String((payload as { error?: unknown }).error ?? "")
          : "";
        if (response.status === 503 || error === "WYNOS_ROUTING_NOT_CONFIGURED") {
          throw new Error("ระบบเส้นทางของ WYNOS Maps ยังไม่พร้อมใช้งาน");
        }
        throw new Error("คำนวณเส้นทางไม่สำเร็จ กรุณาลองใหม่");
      }

      const parsed = parseWynosRoute(payload, mode);
      if (!parsed) throw new Error("ยังไม่พบเส้นทางที่เหมาะสม");
      setRoute(parsed);
      setActiveNearbyPlace(null);
    } catch (error) {
      if (routeRequestRef.current !== requestId) return;
      setRouteStatus(error instanceof Error ? error.message : "คำนวณเส้นทางไม่สำเร็จ");
    } finally {
      if (routeRequestRef.current === requestId) setRouteWorking(false);
    }
  }, [routeMode, standalone, userLocation]);

  useEffect(() => {
    if (!standalone) return;
    const timer = window.setTimeout(() => setRecentPlaces(loadRecentPlaces(mapsStorage())), 0);
    return () => window.clearTimeout(timer);
  }, [standalone]);

  const activePhotoPlaceId = standalone && canHavePhotos(activeNearbyPlace?.placeId) ? activeNearbyPlace?.placeId ?? null : null;

  const refreshPhotos = useCallback(async (placeId: string) => {
    try {
      const state = await loadPlacePhotos(client, placeId);
      setPlacePhotos({ placeId, state });
    } catch {
      setPlacePhotos({ placeId, state: { status: "ready", photos: [] } });
    }
  }, [client]);

  useEffect(() => {
    if (!activePhotoPlaceId) return;
    const timer = window.setTimeout(() => void refreshPhotos(activePhotoPlaceId), 0);
    return () => window.clearTimeout(timer);
  }, [activePhotoPlaceId, refreshPhotos]);

  const refreshSaved = useCallback(async () => {
    if (!standalone) return;
    try {
      setSaved(await loadSavedPlaces(client));
    } catch {
      // Keep whatever was shown; saved places are optional.
    }
  }, [client, standalone]);

  useEffect(() => {
    const timer = window.setTimeout(() => void refreshSaved(), 0);
    return () => window.clearTimeout(timer);
  }, [refreshSaved]);

  useEffect(() => {
    if (!standalone) return;
    let live = true;
    void fetch(SERVICE_AREA_URL, { cache: "force-cache" })
      .then((response) => {
        if (!response.ok) throw new Error("service area unavailable");
        return response.json() as Promise<unknown>;
      })
      .then((value) => {
        if (live && isServiceAreaFeature(value)) setServiceAreaBoundary(value);
      })
      .catch(() => {
        if (live) setServiceAreaBoundary(null);
      });
    return () => {
      live = false;
    };
  }, [standalone]);

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
          style: standalone && prefersDarkMap() ? MAP_STYLE_DARK : MAP_STYLE,
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
          setMapStyleRevision((value) => value + 1);
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
      routeRequestRef.current += 1;
      nearbyMarkersRef.current.forEach((marker) => marker.remove());
      nearbyMarkersRef.current = [];
      userLocationMarkerRef.current?.remove();
      userLocationMarkerRef.current = null;
      entranceMarkerRef.current?.remove();
      entranceMarkerRef.current = null;
      map?.remove();
      mapRef.current = null;
    };
  }, [initialLocation, loadNearby, mapAttempt, reverse, standalone]);

  useEffect(() => {
    if (!standalone || !mapReady) return;
    let dark = prefersDarkMap();
    const sync = () => {
      const next = prefersDarkMap();
      if (next === dark) return;
      dark = next;
      try {
        mapRef.current?.setStyle(next ? MAP_STYLE_DARK : MAP_STYLE);
      } catch {
        // Keep the current style if the swap fails.
      }
    };
    const media = window.matchMedia?.("(prefers-color-scheme: dark)");
    media?.addEventListener("change", sync);
    const observer = new MutationObserver(sync);
    observer.observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] });
    return () => {
      media?.removeEventListener("change", sync);
      observer.disconnect();
    };
  }, [mapReady, standalone]);

  useEffect(() => {
    const map = mapRef.current;
    if (!standalone || !mapReady || !map || !serviceAreaBoundary) return;
    try {
      if (!map.getSource(SERVICE_AREA_SOURCE)) {
        map.addSource(SERVICE_AREA_SOURCE, { type: "geojson", data: serviceAreaBoundary });
      }
      if (!map.getLayer(SERVICE_AREA_FILL_LAYER)) {
        map.addLayer({
          id: SERVICE_AREA_FILL_LAYER,
          type: "fill",
          source: SERVICE_AREA_SOURCE,
          paint: {
            "fill-color": "#159447",
            "fill-opacity": 0.035,
          },
        });
      }
      if (!map.getLayer(SERVICE_AREA_LINE_LAYER)) {
        map.addLayer({
          id: SERVICE_AREA_LINE_LAYER,
          type: "line",
          source: SERVICE_AREA_SOURCE,
          paint: {
            "line-color": "#0b7f3b",
            "line-width": 1.5,
            "line-opacity": 0.38,
          },
        });
      }
    } catch {
      // The picker remains usable if the optional service-area overlay cannot render.
    }
  }, [mapReady, mapStyleRevision, serviceAreaBoundary, standalone]);

  useEffect(() => {
    const map = mapRef.current;
    if (!standalone || !mapReady || !map) return;

    if (!route) {
      try {
        if (map.getLayer(ROUTE_LINE_LAYER)) map.removeLayer(ROUTE_LINE_LAYER);
        if (map.getSource(ROUTE_SOURCE)) map.removeSource(ROUTE_SOURCE);
      } catch {
        // Route cleanup is optional; a style refresh will also clear it.
      }
      return;
    }

    const feature: RouteLineFeature = {
      type: "Feature",
      properties: { mode: route.mode },
      geometry: { type: "LineString", coordinates: route.coordinates },
    };

    try {
      const source = map.getSource(ROUTE_SOURCE) as { setData?: (data: RouteLineFeature) => void } | undefined;
      if (source?.setData) source.setData(feature);
      else map.addSource(ROUTE_SOURCE, { type: "geojson", data: feature });

      if (!map.getLayer(ROUTE_LINE_LAYER)) {
        map.addLayer({
          id: ROUTE_LINE_LAYER,
          type: "line",
          source: ROUTE_SOURCE,
          paint: {
            "line-color": "#1a73e8",
            "line-width": 5,
            "line-opacity": 0.9,
          },
        });
      }

      const longitudes = route.coordinates.map(([longitude]) => longitude);
      const latitudes = route.coordinates.map(([, latitude]) => latitude);
      map.fitBounds(
        [[Math.min(...longitudes), Math.min(...latitudes)], [Math.max(...longitudes), Math.max(...latitudes)]],
        { padding: { top: 92, right: 44, bottom: 330, left: 44 }, maxZoom: 16.5, duration: 520 },
      );
    } catch {
      // Keep the route summary usable even if the optional line overlay cannot render.
    }
  }, [mapReady, mapStyleRevision, route, standalone]);

  useEffect(() => {
    if (!mapReady || !autoLocate || initialLocation || autoLocateRef.current) return;
    autoLocateRef.current = true;
    const timer = window.setTimeout(() => void pickCurrentLocation(), 0);
    return () => window.clearTimeout(timer);
  }, [autoLocate, initialLocation, mapReady, pickCurrentLocation]);

  useEffect(() => {
    const map = mapRef.current;
    const maplibre = window.maplibregl;
    if (!standalone || !mapReady || !map || !maplibre || !userLocation) return;

    userLocationMarkerRef.current?.remove();
    const markerNode = document.createElement("span");
    markerNode.className = "wf-map-user-location";
    markerNode.setAttribute("aria-label", "ตำแหน่งปัจจุบันของคุณ");
    const marker = new maplibre.Marker({ element: markerNode, anchor: "center" })
      .setLngLat([userLocation.longitude, userLocation.latitude])
      .addTo(map);
    userLocationMarkerRef.current = marker;

    return () => {
      marker.remove();
      if (userLocationMarkerRef.current === marker) userLocationMarkerRef.current = null;
    };
  }, [mapReady, standalone, userLocation]);

  useEffect(() => {
    const map = mapRef.current;
    const maplibre = window.maplibregl;
    if (!mapReady || !map || !maplibre) return;

    nearbyMarkersRef.current.forEach((marker) => marker.remove());

    const markerLimit = standalone
      ? (mapZoom >= 17 ? 18 : mapZoom >= 15.5 ? 12 : mapZoom >= 13.5 ? 8 : 5)
      : nearbyPlaces.length;
    const selectedIdentity = activeNearbyPlace ? placeIdentity(activeNearbyPlace) : null;
    // Keep the backend's proximity-first order for normal POIs. Only the
    // actively selected place is promoted so decluttering never hides a
    // closer address in favor of a farther category.
    const candidates = [...nearbyPlaces].sort((a, b) => {
      const aSelected = selectedIdentity === placeIdentity(a);
      const bSelected = selectedIdentity === placeIdentity(b);
      if (aSelected === bSelected) return 0;
      return aSelected ? -1 : 1;
    });
    const occupied: MapPoint[] = [];
    const minimumGap = standalone
      ? (mapZoom >= 17 ? 46 : mapZoom >= 15.5 ? 58 : 70)
      : (mapZoom >= 17 ? 34 : mapZoom >= 15.5 ? 42 : 50);
    const visiblePlaces: FoodPlace[] = [];

    for (const nearbyPlace of candidates) {
      const selected = selectedIdentity === placeIdentity(nearbyPlace);
      if (!selected && visiblePlaces.length >= markerLimit) continue;
      const point = map.project([nearbyPlace.longitude, nearbyPlace.latitude]);
      const overlaps = occupied.some((other) => Math.hypot(point.x - other.x, point.y - other.y) < minimumGap);
      if (overlaps && !selected) continue;
      occupied.push(point);
      visiblePlaces.push(nearbyPlace);
    }

    const markers = visiblePlaces.map((nearbyPlace) => {
      const button = document.createElement("button");
      button.type = "button";
      const selected = selectedIdentity === placeIdentity(nearbyPlace);
      const kind = placeMarkerKind(nearbyPlace);
      button.className = `wf-map-place-marker is-${kind}${selected ? " is-selected" : ""}`;
      button.setAttribute("aria-label", `${placeCategory(nearbyPlace)} ${nearbyPlace.name}`);
      button.title = nearbyPlace.name;

      const dot = document.createElement("span");
      dot.className = "wf-map-place-dot";
      const symbol = document.createElement("span");
      symbol.className = "wf-map-place-symbol";
      symbol.innerHTML = placeMarkerSvg(kind);
      dot.appendChild(symbol);
      button.appendChild(dot);

      if (selected) {
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

      return new maplibre.Marker({ element: button, anchor: selected ? "bottom" : "center" })
        .setLngLat([nearbyPlace.longitude, nearbyPlace.latitude])
        .addTo(map);
    });
    nearbyMarkersRef.current = markers;

    return () => {
      markers.forEach((marker) => marker.remove());
      if (nearbyMarkersRef.current === markers) nearbyMarkersRef.current = [];
    };
  }, [activeNearbyPlace, mapReady, mapZoom, nearbyPlaces, setSheetExpanded, standalone]);

  useEffect(() => {
    const placeId = activeNearbyPlace?.placeId;
    if (!placeId) return;
    let live = true;
    void fetchWynosPlaceDetails(client, placeId)
      .then((details) => { if (live) setActivePlaceDetails(details); })
      .catch(() => { if (live) setActivePlaceDetails(null); });
    return () => { live = false; };
  }, [activeNearbyPlace?.placeId, client]);

  const currentPlaceDetails =
    activePlaceDetails?.placeId === activeNearbyPlace?.placeId ? activePlaceDetails : null;

  useEffect(() => {
    const map = mapRef.current;
    const maplibre = window.maplibregl;
    entranceMarkerRef.current?.remove();
    entranceMarkerRef.current = null;
    if (!mapReady || !map || !maplibre || currentPlaceDetails?.entranceLatitude == null || currentPlaceDetails.entranceLongitude == null) return;
    const node = document.createElement("button");
    node.type = "button";
    node.className = "wf-map-entrance-marker";
    node.setAttribute("aria-label", "จุดรับอาหารหรือทางเข้าร้าน");
    node.textContent = "รับอาหาร";
    node.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      map.flyTo({
        center: [currentPlaceDetails.entranceLongitude!, currentPlaceDetails.entranceLatitude!],
        zoom: Math.max(map.getZoom(), 17),
        essential: true,
      });
    });
    const marker = new maplibre.Marker({ element: node, anchor: "bottom" })
      .setLngLat([currentPlaceDetails.entranceLongitude, currentPlaceDetails.entranceLatitude])
      .addTo(map);
    entranceMarkerRef.current = marker;
    return () => {
      marker.remove();
      if (entranceMarkerRef.current === marker) entranceMarkerRef.current = null;
    };
  }, [currentPlaceDetails, mapReady]);

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
    const reportSearch = (message: string) => (standalone ? setSearchStatus(message) : setStatus(message));
    const signedOutMessage = async () => {
      const { data } = await client.auth.getSession();
      return data.session ? null : "เข้าสู่ระบบ WYNOS ก่อน แล้วลองค้นหาอีกครั้ง";
    };
    const requestId = ++searchRequestRef.current;
    setSearching(true);
    if (!silent) reportSearch("");
    try {
      let next = storeId ? (await searchStorePlaces(client, storeId, trimmed)) ?? [] : [];
      if (!next.length) next = await searchFoodPlaces(client, trimmed, location);
      if (searchRequestRef.current !== requestId) return;
      setResults(next);
      if (!silent && !next.length) {
        const signedOut = standalone ? await signedOutMessage() : null;
        if (searchRequestRef.current !== requestId) return;
        reportSearch(signedOut ?? "ไม่พบสถานที่ ลองพิมพ์ชื่อถนน หมู่บ้าน หอพัก หรือสถานที่ใกล้เคียง");
      }
    } catch (error) {
      if (searchRequestRef.current !== requestId) return;
      setResults([]);
      if (!silent) {
        const signedOut = standalone ? await signedOutMessage().catch(() => null) : null;
        if (searchRequestRef.current !== requestId) return;
        reportSearch(signedOut ?? (error instanceof Error ? error.message : "ค้นหาสถานที่ไม่สำเร็จ"));
      }
    } finally {
      if (searchRequestRef.current === requestId) setSearching(false);
    }
  }, [client, location, standalone, storeId]);

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

  const quickSearch = (value: string) => {
    setQuery(value);
    setSearchFocused(true);
    if (standalone) setSheetDetent("half");
    void runSearch(value, false);
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
    if (standalone) setRecentPlaces(rememberRecentPlace(mapsStorage(), result));
    setResults([]);
    setSearchStatus("");
    setSearchFocused(false);
    // Standalone Maps shows the chosen place in the sheet and keeps the search
    // field empty, so the next tap opens recents.
    setQuery(standalone ? "" : result.name);
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

  const searchActive = standalone && searchFocused;
  const showRecents = standalone && searchFocused && !query.trim() && !results.length && recentPlaces.length > 0;

  const savedPlaces = saved.status === "ready" ? saved.places : [];
  const savedHome = savedPlaces.find((item) => item.kind === "home") ?? null;
  const savedWork = savedPlaces.find((item) => item.kind === "work") ?? null;
  const savedFavorites = savedPlaces.filter((item) => item.kind === "favorite");
  const showSaved = standalone && searchFocused && !query.trim() && !results.length && saved.status !== "unavailable";

  const openSaved = (item: SavedPlace) => {
    setSearchFocused(false);
    setQuery("");
    setSearchStatus("");
    moveTo(
      { latitude: item.latitude, longitude: item.longitude },
      { placeId: item.placeId, name: item.name, address: item.address, latitude: item.latitude, longitude: item.longitude, source: "wynos" },
    );
    setSheetDetent("half");
  };

  const startSave = (target: { name?: string | null; address?: string | null; placeId?: string | null; latitude: number; longitude: number }) => {
    if (saved.status === "signed-out") {
      setStatus("เข้าสู่ระบบ WYNOS ก่อน จึงจะบันทึกสถานที่ได้");
      return;
    }
    setSaveTarget({
      name: target.name?.trim() || "ตำแหน่งที่ปักหมุด",
      address: target.address ?? null,
      placeId: target.placeId ?? null,
      latitude: target.latitude,
      longitude: target.longitude,
    });
    setSheetDetent("full");
  };

  const saveTo = async (kind: SavedPlaceKind) => {
    if (!saveTarget) return;
    setSavingPlace(true);
    try {
      await saveMapPlace(client, { ...saveTarget, kind });
      setSaveTarget(null);
      setStatus(kind === "home" ? "บันทึกเป็นบ้านแล้ว" : kind === "work" ? "บันทึกเป็นที่ทำงานแล้ว" : "เพิ่มในรายการโปรดแล้ว");
      await refreshSaved();
    } catch (error) {
      setStatus(error instanceof Error ? error.message : "บันทึกสถานที่ไม่สำเร็จ");
    } finally {
      setSavingPlace(false);
    }
  };

  const removeSaved = async (item: SavedPlace) => {
    try {
      await deleteSavedPlace(client, item.id);
      await refreshSaved();
    } catch (error) {
      setSearchStatus(error instanceof Error ? error.message : "ลบสถานที่ไม่สำเร็จ");
    }
  };

  const activePhotos = placePhotos && placePhotos.placeId === activePhotoPlaceId ? placePhotos.state : null;

  const addPhoto = async (file: File | undefined) => {
    if (!file || !activePhotoPlaceId) return;
    setUploadingPhoto(true);
    setStatus("");
    try {
      await uploadPlacePhoto(client, activePhotoPlaceId, file);
      setStatus("ส่งรูปให้ทีม WYNOS ตรวจแล้ว รูปจะขึ้นหลังผ่านการตรวจ");
      await refreshPhotos(activePhotoPlaceId);
    } catch (error) {
      setStatus(error instanceof Error ? error.message : "เพิ่มรูปไม่สำเร็จ");
    } finally {
      setUploadingPhoto(false);
      if (photoInputRef.current) photoInputRef.current.value = "";
    }
  };

  const removePhoto = async (photoId: string) => {
    if (!activePhotoPlaceId) return;
    try {
      await withdrawPlacePhoto(client, photoId);
      await refreshPhotos(activePhotoPlaceId);
    } catch (error) {
      setStatus(error instanceof Error ? error.message : "ลบรูปไม่สำเร็จ");
    }
  };

  const sharePlace = async (target: { name?: string | null; latitude: number; longitude: number }) => {
    const url = mapsShareUrl(window.location.origin, target.latitude, target.longitude);
    const title = target.name?.trim() || "ตำแหน่งบน WYNOS Maps";
    try {
      if (navigator.share) {
        await navigator.share({ title, text: title, url });
        return;
      }
      await navigator.clipboard.writeText(url);
      setStatus("คัดลอกลิงก์ตำแหน่งแล้ว");
    } catch (error) {
      if (error instanceof DOMException && error.name === "AbortError") return;
      setStatus("แชร์ตำแหน่งไม่สำเร็จ");
    }
  };

  const cancelSearch = () => {
    searchRequestRef.current += 1;
    setQuery("");
    setResults([]);
    setSearching(false);
    setSearchStatus("");
    setSearchFocused(false);
    if (standalone) setSheetDetent("half");
  };

  const searchBlock = (
    <div className="wf-map-search-wrap">
      <div className="wf-map-search">
        <Search size={18} />
        <input
          value={query}
          onFocus={() => {
            setSearchFocused(true);
            if (standalone) setSheetDetent("half");
          }}
          onChange={(event) => {
            const nextQuery = event.target.value;
            setQuery(nextQuery);
            setSearchFocused(true);
            setSearchStatus("");
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
              event.currentTarget.blur();
              cancelSearch();
            }
          }}
          placeholder={standalone ? "ค้นหาใน WYNOS Maps" : "ค้นหาสถานที่ ถนน หมู่บ้าน หอพัก"}
          aria-label={standalone ? "ค้นหาใน WYNOS Maps" : "ค้นหาสถานที่หรือที่อยู่"}
          autoComplete="off"
        />
        <button type="button" disabled={searching || !query.trim()} onClick={search}>
          {searching ? "กำลังค้น…" : "ค้นหา"}
        </button>
        {standalone && (searchFocused || query) ? (
          <button type="button" className="wf-map-search-cancel" onClick={cancelSearch}>ยกเลิก</button>
        ) : null}
      </div>
      {standalone ? (
        <div className="wf-map-quick-filters" aria-label="หมวดหมู่สถานที่">
          <button type="button" className={query === "ร้านอาหาร" ? "is-active" : ""} onClick={() => quickSearch("ร้านอาหาร")}>
            <Utensils size={16} /><span>ร้านอาหาร</span>
          </button>
          <button type="button" className={query === "คาเฟ่" ? "is-active" : ""} onClick={() => quickSearch("คาเฟ่")}>
            <Coffee size={16} /><span>คาเฟ่</span>
          </button>
          <button type="button" className={query === "หอพัก" ? "is-active" : ""} onClick={() => quickSearch("หอพัก")}>
            <Building2 size={16} /><span>หอพัก</span>
          </button>
          <button type="button" className={query === "ร้านค้า" ? "is-active" : ""} onClick={() => quickSearch("ร้านค้า")}>
            <ShoppingBag size={16} /><span>ร้านค้า</span>
          </button>
        </div>
      ) : null}
      {standalone && !results.length && (searching || searchStatus) ? (
        <p className="wf-map-search-status" role="status" aria-live="polite">
          {searching ? "กำลังค้นหา…" : searchStatus}
        </p>
      ) : null}
      {showSaved ? (
        <div className="wf-map-saved-places">
          <div className="wf-map-recents-head">
            <strong>รายการโปรด</strong>
          </div>
          {saved.status === "signed-out" ? (
            <p className="wf-map-saved-hint">เข้าสู่ระบบ WYNOS เพื่อบันทึกบ้าน ที่ทำงาน และรายการโปรด</p>
          ) : (
            <>
              <div className="wf-map-saved-tiles">
                {([["home", savedHome, "บ้าน"], ["work", savedWork, "ที่ทำงาน"]] as const).map(([kind, item, label]) => (
                  <button
                    key={kind}
                    type="button"
                    className={item ? "wf-map-saved-tile" : "wf-map-saved-tile is-empty"}
                    onClick={() => (item
                      ? openSaved(item)
                      : setSearchStatus(`ปักหมุดที่${label} แล้วกดปุ่มดาวเพื่อบันทึก`))}
                  >
                    <span>{kind === "home" ? <Home size={18} /> : <Briefcase size={18} />}</span>
                    <strong>{label}</strong>
                    <small>{item ? item.name : "ยังไม่ได้ตั้ง"}</small>
                  </button>
                ))}
              </div>
              {savedFavorites.length ? (
                <div className="wf-map-results wf-map-favorites">
                  {savedFavorites.map((item) => (
                    <div key={item.id} className="wf-map-favorite-row">
                      <button type="button" onClick={() => openSaved(item)}>
                        <Star size={17} />
                        <span>
                          <strong>{item.name}</strong>
                          {item.address ? <small>{item.address}</small> : null}
                        </span>
                      </button>
                      <button
                        type="button"
                        className="wf-map-favorite-remove"
                        aria-label={`ลบ ${item.name} ออกจากรายการโปรด`}
                        onClick={() => void removeSaved(item)}
                      >
                        <X size={16} />
                      </button>
                    </div>
                  ))}
                </div>
              ) : null}
            </>
          )}
        </div>
      ) : null}
      {showRecents ? (
        <div className="wf-map-recents">
          <div className="wf-map-recents-head">
            <strong>ล่าสุด</strong>
            <button
              type="button"
              onClick={() => {
                clearRecentPlaces(mapsStorage());
                setRecentPlaces([]);
              }}
            >
              ล้าง
            </button>
          </div>
          <div className="wf-map-results">
            {recentPlaces.map((recent) => (
              <button
                key={recent.placeId ?? `${recent.latitude},${recent.longitude},${recent.name}`}
                type="button"
                onClick={() => chooseResult({ ...recent, source: "wynos" })}
              >
                <Clock size={17} />
                <span>
                  <strong>{recent.name}</strong>
                  {recent.address ? <small>{recent.address}</small> : null}
                </span>
              </button>
            ))}
          </div>
        </div>
      ) : null}
      {results.length ? (
        <div className="wf-map-results">
          {results.map((result) => (
            <button key={result.placeId ?? `${result.latitude},${result.longitude},${result.name}`} type="button" onClick={() => chooseResult(result)}>
              <MapPin size={17} />
              <span>
                <strong>{result.name || "สถานที่"}</strong>
                <small>
                  {[standalone ? formatDistanceKm(result.distanceKm) : null, placeCategory(result), result.address]
                    .filter(Boolean)
                    .join(" · ")}
                </small>
              </span>
            </button>
          ))}
        </div>
      ) : null}
    </div>
  );

  const showLegacySearchAttribution =
    place?.source === "legacy" || results.some((result) => result.source === "legacy");
  const showPhotonAttribution =
    place?.source === "photon" || results.some((result) => result.source === "photon");

  return (
    <div
      className="wf-map-picker"
      role={standalone ? "region" : "dialog"}
      aria-modal={standalone ? undefined : true}
      aria-label={standalone ? "WYNOS Maps" : "ปักหมุดตำแหน่งจัดส่ง"}
    >
      <header className="wf-map-picker-head">
        <button type="button" aria-label={standalone ? "ย้อนกลับ" : "ปิดแผนที่"} onClick={onClose}>
          {standalone ? <ArrowLeft size={22} /> : <X size={22} />}
        </button>
        <div>
          <strong>{title ?? (standalone ? "WYNOS Maps" : "ปักหมุดตำแหน่งจัดส่ง")}</strong>
          <small>{subtitle ?? (standalone ? "ค้นหา สำรวจ และเลือกตำแหน่ง" : "เลื่อนแผนที่ให้หมุดตรงจุดรับอาหาร")}</small>
        </div>
        <span />
      </header>

      {standalone ? null : searchBlock}

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
        <div className={`wf-map-center-pin${mapDragging ? " is-dragging" : ""}${currentLocationSelected ? " is-current-location" : ""}${directionsTarget ? " is-route-active" : ""}`} aria-hidden="true">
          <MapPin size={standalone ? 36 : 42} fill="currentColor" />
        </div>
        {standalone && serviceAreaBoundary ? (
          <div
            className={`wf-map-service-area${serviceAreaState === "inside" ? " is-inside" : serviceAreaState === "outside" ? " is-outside" : ""}`}
            role="status"
          >
            <span className="wf-map-service-area-dot" />
            <strong>
              {serviceAreaState === "inside"
                ? "อยู่ในพื้นที่ให้บริการ"
                : serviceAreaState === "outside"
                  ? "นอกพื้นที่ให้บริการ"
                  : "พื้นที่ให้บริการ WYNOS Food"}
            </strong>
            <small>มหาสารคาม</small>
          </div>
        ) : null}
        <div className="wf-map-attribution">
          {showAttribution ? (
            <div className="wf-map-attribution-panel" role="dialog" aria-label="ข้อมูลแผนที่และแหล่งข้อมูล">
              <strong>ข้อมูลแผนที่</strong>
              <a href="https://openfreemap.org" target="_blank" rel="noreferrer">OpenFreeMap</a>
              <a href="https://www.openmaptiles.org/" target="_blank" rel="noreferrer">© OpenMapTiles</a>
              <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noreferrer">© OpenStreetMap contributors</a>
              <a href="https://overturemaps.org" target="_blank" rel="noreferrer">Places: Overture Maps Foundation</a>
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

      <section
        className={standalone
          ? `wf-map-confirm wf-map-sheet is-${sheetDetent}${sheetExpanded ? " is-expanded" : ""}${searchActive ? " is-searching" : ""}`
          : "wf-map-confirm"}
      >
        {standalone ? (
          <button
            type="button"
            className="wf-map-sheet-handle"
            aria-label={sheetDetent === "full" ? "ย่อแผง" : "ขยายแผง"}
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
              if (distance < -28) setSheetDetent((value) => (value === "peek" ? "half" : "full"));
              else if (distance > 28) setSheetDetent((value) => (value === "full" ? "half" : "peek"));
              else setSheetDetent((value) => (value === "full" ? "half" : value === "half" ? "full" : "half"));
            }}
            onPointerCancel={() => {
              sheetPointerStartRef.current = null;
            }}
          >
            <span />
          </button>
        ) : null}
        {standalone ? searchBlock : null}
        <div className="wf-map-sheet-body">
        {standalone && directionsTarget ? (
          <div className="wf-map-directions" role="region" aria-label="เส้นทาง">
            <div className="wf-map-directions-head">
              <span><Navigation size={18} /></span>
              <div>
                <small>จากตำแหน่งของคุณ</small>
                <strong>{directionsTarget.name}</strong>
              </div>
              <button type="button" aria-label="ปิดเส้นทาง" onClick={clearRoute}><X size={16} /></button>
            </div>
            <div className="wf-map-route-modes" aria-label="รูปแบบการเดินทาง">
              {([
                ["motorcycle", "มอเตอร์ไซค์"],
                ["auto", "รถยนต์"],
                ["pedestrian", "เดิน"],
              ] as const).map(([mode, label]) => (
                <button
                  key={mode}
                  type="button"
                  className={routeMode === mode ? "is-active" : ""}
                  disabled={routeWorking}
                  onClick={() => void requestRoute(directionsTarget, mode)}
                >
                  {label}
                </button>
              ))}
            </div>
            {routeWorking ? <p className="wf-map-route-status">กำลังคำนวณเส้นทาง…</p> : null}
            {!routeWorking && route ? (
              <div className="wf-map-route-summary">
                <strong>{formatRouteDuration(route.durationSeconds)}</strong>
                <span>{formatRouteDistance(route.distanceKm)}</span>
                <small>เวลาโดยประมาณจาก WYNOS Routing</small>
              </div>
            ) : null}
            {!routeWorking && routeStatus ? <p className="wf-map-route-status is-error">{routeStatus}</p> : null}
          </div>
        ) : null}
        {activeNearbyPlace ? (
          <article className="wf-map-place-card">
            <button className="wf-map-place-close" type="button" aria-label="ปิดข้อมูลสถานที่" onClick={() => {
              setActiveNearbyPlace(null);
              if (standalone) setSheetExpanded(false);
            }}>
              <X size={16} />
            </button>
            {activeNearbyPlace.merchantStoreId && currentPlaceDetails ? (
              <div className="wf-map-store-brand">
                {currentPlaceDetails.storeCoverPath ? <img className="wf-map-store-cover" src={foodPublicUrl(client, currentPlaceDetails.storeCoverPath) ?? ""} alt="" /> : null}
                {currentPlaceDetails.storeLogoPath ? <img className="wf-map-store-logo" src={foodPublicUrl(client, currentPlaceDetails.storeLogoPath) ?? ""} alt="" /> : null}
              </div>
            ) : null}
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
              {currentPlaceDetails?.entranceLatitude != null && currentPlaceDetails.entranceLongitude != null ? (
                <div className="wf-map-pickup-detail">
                  <strong>จุดรับอาหาร / ทางเข้า</strong>
                  {currentPlaceDetails.pickupNote ? <small>{currentPlaceDetails.pickupNote}</small> : <small>ร้านกำหนดหมุดสำหรับรับอาหารไว้แล้ว</small>}
                  <button type="button" onClick={() => mapRef.current?.flyTo({
                    center: [currentPlaceDetails.entranceLongitude!, currentPlaceDetails.entranceLatitude!],
                    zoom: 17.5,
                    essential: true,
                  })}>ดูจุดรับอาหารบนแผนที่</button>
                </div>
              ) : null}
            </div>
            {activePhotos?.status === "ready" ? (
              <div className="wf-map-place-photos" aria-label="รูปสถานที่">
                {activePhotos.photos.map((photo) => (
                  <figure key={photo.id}>
                    {/* Signed Storage URLs; next/image would proxy and re-cache them. */}
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={photo.url} alt={`รูปของ ${activeNearbyPlace.name}`} loading="lazy" />
                    {photo.status === "pending" ? <figcaption>รอตรวจ</figcaption> : null}
                    {photo.isMine ? (
                      <button type="button" aria-label="ลบรูปนี้" onClick={() => void removePhoto(photo.id)}>
                        <X size={14} />
                      </button>
                    ) : null}
                  </figure>
                ))}
                <button
                  type="button"
                  className="wf-map-photo-add"
                  disabled={uploadingPhoto}
                  onClick={() => photoInputRef.current?.click()}
                >
                  <ImagePlus size={20} />
                  <span>{uploadingPhoto ? "กำลังส่ง…" : "เพิ่มรูป"}</span>
                </button>
                <input
                  ref={photoInputRef}
                  className="wf-map-photo-input"
                  type="file"
                  accept="image/jpeg,image/png,image/webp,image/heic,image/heif"
                  tabIndex={-1}
                  aria-hidden="true"
                  onChange={(event) => void addPhoto(event.target.files?.[0])}
                />
              </div>
            ) : null}
            <div className="wf-map-place-actions">
              {standalone ? (
                <button
                  type="button"
                  onClick={() => void requestRoute({
                    name: activeNearbyPlace.name || "สถานที่ที่เลือก",
                    latitude: activeNearbyPlace.latitude,
                    longitude: activeNearbyPlace.longitude,
                  })}
                >
                  <Navigation size={15} /> เส้นทาง
                </button>
              ) : null}
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
              {standalone && saved.status !== "unavailable" ? (
                <button type="button" className="wf-map-share" onClick={() => startSave(activeNearbyPlace)}>
                  <Star size={15} /> บันทึก
                </button>
              ) : null}
              {standalone ? (
                <button type="button" className="wf-map-share" onClick={() => void sharePlace(activeNearbyPlace)}>
                  <Share size={15} /> แชร์
                </button>
              ) : null}
              {activeNearbyPlace.merchantStoreId ? (
                <a href={`https://food.wynos.online/?store=${encodeURIComponent(activeNearbyPlace.merchantStoreId)}`}>สั่งใน WYNOS Food</a>
              ) : null}
            </div>
          </article>
        ) : null}

        {standalone && serviceAreaState === "outside" ? (
          <div className="wf-map-service-area-warning" role="alert">
            <MapPin size={18} />
            <div>
              <strong>นอกพื้นที่ให้บริการ</strong>
              <span>ตอนนี้ WYNOS Food ให้บริการในจังหวัดมหาสารคาม</span>
            </div>
          </div>
        ) : null}

        <div className="wf-map-confirm-copy">
          <span><MapPin size={18} /></span>
          <div>
            <small>{standalone ? "ตำแหน่งที่เลือก" : "ตำแหน่งจัดส่ง"}</small>
            <strong>
              {place?.name
                || (resolvingPlace
                  ? "กำลังค้นหาชื่อสถานที่…"
                  : location
                    ? "ไม่พบชื่อสถานที่"
                    : standalone
                      ? "ค้นหาหรือเลื่อนแผนที่"
                      : "เลื่อนแผนที่หรือค้นหาสถานที่")}
            </strong>
            {place?.address ? <p className="wf-map-confirm-address">{place.address}</p> : null}
            {!place && location && !resolvingPlace ? (
              <code className="wf-map-confirm-coordinates">{location.latitude.toFixed(5)}, {location.longitude.toFixed(5)}</code>
            ) : null}
            {location ? <p className="wf-map-adjust-hint">เลื่อนแผนที่เพื่อปรับหมุดให้ตรงตำแหน่งจริง</p> : null}
          </div>
          {standalone && location ? (
            <div className="wf-map-confirm-tools">
              <button
                type="button"
                className="wf-map-confirm-share"
                aria-label="เส้นทางไปตำแหน่งนี้"
                disabled={routeWorking}
                onClick={() => void requestRoute({
                  name: place?.name?.trim() || "ตำแหน่งที่เลือก",
                  latitude: location.latitude,
                  longitude: location.longitude,
                })}
              >
                <Navigation size={18} />
              </button>
              {saved.status !== "unavailable" ? (
                <button
                  type="button"
                  className="wf-map-confirm-share"
                  aria-label="บันทึกตำแหน่งนี้"
                  onClick={() => startSave({
                    name: place?.name,
                    address: place?.address,
                    placeId: place?.placeId,
                    latitude: location.latitude,
                    longitude: location.longitude,
                  })}
                >
                  <Star size={18} />
                </button>
              ) : null}
              <button
                type="button"
                className="wf-map-confirm-share"
                aria-label="แชร์ตำแหน่งนี้"
                onClick={() => void sharePlace({ name: place?.name, latitude: location.latitude, longitude: location.longitude })}
              >
                <Share size={18} />
              </button>
            </div>
          ) : null}
        </div>
        {standalone && saveTarget ? (
          <div className="wf-map-save-menu" role="group" aria-label="บันทึกสถานที่">
            <strong>{`บันทึก “${saveTarget.name}” เป็น`}</strong>
            <div>
              <button type="button" disabled={savingPlace} onClick={() => void saveTo("home")}><Home size={17} /> บ้าน</button>
              <button type="button" disabled={savingPlace} onClick={() => void saveTo("work")}><Briefcase size={17} /> ที่ทำงาน</button>
              <button type="button" disabled={savingPlace} onClick={() => void saveTo("favorite")}><Star size={17} /> รายการโปรด</button>
            </div>
            <button type="button" className="wf-map-save-cancel" onClick={() => setSaveTarget(null)}>ยกเลิก</button>
          </div>
        ) : null}
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
          disabled={!chosen || !location || (standalone && serviceAreaState === "outside")}
          onClick={() => {
            if (!location || (standalone && serviceAreaState === "outside")) return;
            onConfirm(location, place ?? undefined);
          }}
        >
          <Check size={18} /> {standalone && serviceAreaState === "outside" ? "ยืนยันไม่ได้ · นอกพื้นที่ให้บริการ" : confirmLabel ?? (standalone ? "ใช้ตำแหน่งนี้" : "ยืนยันตำแหน่งนี้")}
        </button>
        </div>
      </section>
    </div>
  );
}
