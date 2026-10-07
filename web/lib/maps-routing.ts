export type MapsTravelMode = "auto" | "motorcycle" | "pedestrian";

export type MapsRoute = {
  distanceKm: number;
  durationSeconds: number;
  coordinates: Array<[number, number]>;
  mode: MapsTravelMode;
};

type UnknownRecord = Record<string, unknown>;

function record(value: unknown): UnknownRecord | null {
  return value && typeof value === "object" && !Array.isArray(value) ? value as UnknownRecord : null;
}

function finiteNumber(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

export function decodeValhallaPolyline(encoded: string, precision = 6): Array<[number, number]> {
  if (!encoded) return [];
  const factor = 10 ** precision;
  const coordinates: Array<[number, number]> = [];
  let index = 0;
  let latitude = 0;
  let longitude = 0;

  const readDelta = () => {
    let result = 0;
    let shift = 0;
    while (index < encoded.length) {
      const byte = encoded.charCodeAt(index++) - 63;
      if (byte < 0 || byte > 63) return null;
      result |= (byte & 0x1f) << shift;
      if (byte < 0x20) return (result & 1) ? ~(result >> 1) : (result >> 1);
      shift += 5;
      if (shift > 30) return null;
    }
    return null;
  };

  while (index < encoded.length) {
    const latitudeDelta = readDelta();
    const longitudeDelta = readDelta();
    if (latitudeDelta == null || longitudeDelta == null) return [];
    latitude += latitudeDelta;
    longitude += longitudeDelta;
    coordinates.push([longitude / factor, latitude / factor]);
  }

  return coordinates;
}

export function parseWynosRoute(raw: unknown, mode: MapsTravelMode): MapsRoute | null {
  const root = record(raw);
  const trip = record(root?.trip);
  const summary = record(trip?.summary);
  const legs = Array.isArray(trip?.legs) ? trip.legs : [];
  const distanceKm = finiteNumber(summary?.length);
  const durationSeconds = finiteNumber(summary?.time);
  if (distanceKm == null || durationSeconds == null || distanceKm < 0 || durationSeconds < 0 || !legs.length) return null;

  const coordinates: Array<[number, number]> = [];
  for (const value of legs) {
    const leg = record(value);
    const shape = typeof leg?.shape === "string" ? leg.shape : "";
    const points = decodeValhallaPolyline(shape);
    if (points.length < 2) continue;
    if (coordinates.length && points.length) {
      const previous = coordinates[coordinates.length - 1];
      const first = points[0];
      if (previous && first && Math.abs(previous[0] - first[0]) < 1e-7 && Math.abs(previous[1] - first[1]) < 1e-7) {
        points.shift();
      }
    }
    coordinates.push(...points);
  }

  if (coordinates.length < 2) return null;
  return { distanceKm, durationSeconds, coordinates, mode };
}

export function formatRouteDuration(seconds: number) {
  if (!Number.isFinite(seconds) || seconds < 0) return "";
  const minutes = Math.max(1, Math.round(seconds / 60));
  if (minutes < 60) return `${minutes} นาที`;
  const hours = Math.floor(minutes / 60);
  const remainder = minutes % 60;
  return remainder ? `${hours} ชม. ${remainder} นาที` : `${hours} ชม.`;
}

export function formatRouteDistance(km: number) {
  if (!Number.isFinite(km) || km < 0) return "";
  if (km < 1) return `${Math.max(10, Math.round((km * 1000) / 10) * 10)} ม.`;
  return `${km < 10 ? km.toFixed(1) : Math.round(km)} กม.`;
}
