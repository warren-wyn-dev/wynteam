export type MapsTravelMode = "auto" | "motorcycle" | "pedestrian";

export type MapsRouteStep = {
  instruction: string;
  distanceKm: number;
  durationSeconds: number;
  beginShapeIndex: number;
  endShapeIndex: number;
  coordinate: [number, number];
};

export type MapsRoute = {
  distanceKm: number;
  durationSeconds: number;
  coordinates: Array<[number, number]>;
  steps: MapsRouteStep[];
  mode: MapsTravelMode;
};

type UnknownRecord = Record<string, unknown>;

function record(value: unknown): UnknownRecord | null {
  return value && typeof value === "object" && !Array.isArray(value) ? value as UnknownRecord : null;
}

function finiteNumber(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function nonNegativeInteger(value: unknown) {
  return typeof value === "number" && Number.isInteger(value) && value >= 0 ? value : null;
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
  const steps: MapsRouteStep[] = [];

  for (const value of legs) {
    const leg = record(value);
    const shape = typeof leg?.shape === "string" ? leg.shape : "";
    const originalPoints = decodeValhallaPolyline(shape);
    if (originalPoints.length < 2) continue;

    const globalStart = coordinates.length;
    const previous = coordinates[coordinates.length - 1];
    const first = originalPoints[0];
    const sharesBoundary = Boolean(previous && first
      && Math.abs(previous[0] - first[0]) < 1e-7
      && Math.abs(previous[1] - first[1]) < 1e-7);

    const points = sharesBoundary ? originalPoints.slice(1) : originalPoints;
    coordinates.push(...points);

    const maneuvers = Array.isArray(leg?.maneuvers) ? leg.maneuvers : [];
    for (const maneuverValue of maneuvers) {
      const maneuver = record(maneuverValue);
      const instruction = typeof maneuver?.instruction === "string" ? maneuver.instruction.trim() : "";
      const length = finiteNumber(maneuver?.length);
      const time = finiteNumber(maneuver?.time);
      const begin = nonNegativeInteger(maneuver?.begin_shape_index);
      const end = nonNegativeInteger(maneuver?.end_shape_index);
      if (!instruction || length == null || time == null || begin == null || end == null) continue;

      const localToGlobal = (localIndex: number) => {
        if (sharesBoundary && localIndex === 0) return Math.max(0, globalStart - 1);
        return globalStart + localIndex - (sharesBoundary ? 1 : 0);
      };
      const beginShapeIndex = Math.min(coordinates.length - 1, Math.max(0, localToGlobal(begin)));
      const endShapeIndex = Math.min(coordinates.length - 1, Math.max(beginShapeIndex, localToGlobal(end)));
      const coordinate = coordinates[beginShapeIndex];
      if (!coordinate) continue;

      steps.push({
        instruction,
        distanceKm: length,
        durationSeconds: time,
        beginShapeIndex,
        endShapeIndex,
        coordinate,
      });
    }
  }

  if (coordinates.length < 2) return null;
  return { distanceKm, durationSeconds, coordinates, steps, mode };
}

function toLocalMeters(
  location: { latitude: number; longitude: number },
  coordinate: [number, number],
) {
  const earthRadius = 6_371_000;
  const latitudeRadians = location.latitude * Math.PI / 180;
  return {
    x: (coordinate[0] - location.longitude) * Math.PI / 180 * earthRadius * Math.cos(latitudeRadians),
    y: (coordinate[1] - location.latitude) * Math.PI / 180 * earthRadius,
  };
}

function coordinateDistanceMeters(a: [number, number], b: [number, number]) {
  const earthRadius = 6_371_000;
  const lat1 = a[1] * Math.PI / 180;
  const lat2 = b[1] * Math.PI / 180;
  const dLat = (b[1] - a[1]) * Math.PI / 180;
  const dLon = (b[0] - a[0]) * Math.PI / 180;
  const sinLat = Math.sin(dLat / 2);
  const sinLon = Math.sin(dLon / 2);
  const h = sinLat * sinLat + Math.cos(lat1) * Math.cos(lat2) * sinLon * sinLon;
  return 2 * earthRadius * Math.asin(Math.min(1, Math.sqrt(h)));
}

export function distanceToRouteCoordinateMeters(
  location: { latitude: number; longitude: number },
  coordinate: [number, number],
) {
  return coordinateDistanceMeters([location.longitude, location.latitude], coordinate);
}

export function nearestRoutePosition(
  location: { latitude: number; longitude: number },
  coordinates: Array<[number, number]>,
  options?: { minSegmentIndex?: number; maxSegmentIndex?: number },
) {
  if (!Number.isFinite(location.latitude) || !Number.isFinite(location.longitude) || coordinates.length < 2) return null;

  const lastSegmentIndex = coordinates.length - 2;
  const minSegmentIndex = Math.min(
    lastSegmentIndex,
    Math.max(0, Math.floor(options?.minSegmentIndex ?? 0)),
  );
  const maxSegmentIndex = Math.min(
    lastSegmentIndex,
    Math.max(minSegmentIndex, Math.floor(options?.maxSegmentIndex ?? lastSegmentIndex)),
  );

  let bestDistanceSquared = Number.POSITIVE_INFINITY;
  let bestIndex = minSegmentIndex;
  let bestProgress = 0;

  for (let index = minSegmentIndex; index <= maxSegmentIndex; index += 1) {
    const start = toLocalMeters(location, coordinates[index]);
    const end = toLocalMeters(location, coordinates[index + 1]);
    const dx = end.x - start.x;
    const dy = end.y - start.y;
    const lengthSquared = dx * dx + dy * dy;
    const progress = lengthSquared > 0
      ? Math.min(1, Math.max(0, -(start.x * dx + start.y * dy) / lengthSquared))
      : 0;
    const x = start.x + dx * progress;
    const y = start.y + dy * progress;
    const distanceSquared = x * x + y * y;
    if (distanceSquared < bestDistanceSquared) {
      bestDistanceSquared = distanceSquared;
      bestIndex = index;
      bestProgress = progress;
    }
  }

  return {
    distanceMeters: Math.sqrt(bestDistanceSquared),
    shapeIndex: bestProgress >= 0.5 ? bestIndex + 1 : bestIndex,
    segmentIndex: bestIndex,
    segmentProgress: bestProgress,
    routeProgress: bestIndex + bestProgress,
  };
}

export function routeRemainingDistanceMeters(
  coordinates: Array<[number, number]>,
  segmentIndex: number,
  segmentProgress: number,
) {
  if (coordinates.length < 2) return Number.POSITIVE_INFINITY;
  const index = Math.min(coordinates.length - 2, Math.max(0, Math.floor(segmentIndex)));
  const progress = Math.min(1, Math.max(0, segmentProgress));
  const start = coordinates[index];
  const end = coordinates[index + 1];
  const current: [number, number] = [
    start[0] + (end[0] - start[0]) * progress,
    start[1] + (end[1] - start[1]) * progress,
  ];

  let distance = coordinateDistanceMeters(current, end);
  for (let next = index + 1; next < coordinates.length - 1; next += 1) {
    distance += coordinateDistanceMeters(coordinates[next], coordinates[next + 1]);
  }
  return distance;
}

export function nextRouteStep(route: MapsRoute, segmentIndex: number, segmentProgress = 0) {
  if (!route.steps.length) return null;
  const targetShapeIndex = segmentIndex + (segmentProgress >= 0.4 ? 1 : 0);
  let selected = route.steps[0] ?? null;
  for (const step of route.steps) {
    if (step.beginShapeIndex > targetShapeIndex) break;
    selected = step;
  }
  return selected;
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
