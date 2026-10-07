import type { MapsRoute, MapsTravelMode } from "@/lib/maps-routing";

type UnknownRecord = Record<string, unknown>;

function record(value: unknown): UnknownRecord | null {
  return value && typeof value === "object" && !Array.isArray(value) ? value as UnknownRecord : null;
}

function finiteNumber(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function routeCoordinate(value: unknown): [number, number] | null {
  if (!Array.isArray(value) || value.length < 2) return null;
  const lon = finiteNumber(value[0]);
  const lat = finiteNumber(value[1]);
  if (lon == null || lat == null || lon < -180 || lon > 180 || lat < -90 || lat > 90) return null;
  return [lon, lat];
}

export function orsProfileForCosting(costing: string) {
  if (costing === "auto" || costing === "motorcycle") return "driving-car";
  if (costing === "pedestrian") return "foot-walking";
  if (costing === "bicycle") return "cycling-regular";
  return null;
}

export function normalizeOrsGeoJson(raw: unknown, mode: MapsTravelMode): MapsRoute | null {
  const root = record(raw);
  const features = Array.isArray(root?.features) ? root.features : [];
  const feature = record(features[0]);
  const properties = record(feature?.properties);
  const geometry = record(feature?.geometry);
  const summary = record(properties?.summary);
  const distanceMeters = finiteNumber(summary?.distance);
  const durationSeconds = finiteNumber(summary?.duration);
  const rawCoordinates = Array.isArray(geometry?.coordinates) ? geometry.coordinates : [];
  if (distanceMeters == null || durationSeconds == null || distanceMeters < 0 || durationSeconds < 0) return null;

  const coordinates = rawCoordinates.flatMap((value) => {
    const coordinate = routeCoordinate(value);
    return coordinate ? [coordinate] : [];
  });
  if (coordinates.length < 2) return null;

  const steps: MapsRoute["steps"] = [];
  const segments = Array.isArray(properties?.segments) ? properties.segments : [];
  for (const segmentValue of segments) {
    const segment = record(segmentValue);
    const segmentSteps = Array.isArray(segment?.steps) ? segment.steps : [];
    for (const stepValue of segmentSteps) {
      const step = record(stepValue);
      const instruction = typeof step?.instruction === "string" ? step.instruction.trim() : "";
      const stepDistanceMeters = finiteNumber(step?.distance);
      const stepDurationSeconds = finiteNumber(step?.duration);
      const wayPoints = Array.isArray(step?.way_points) ? step.way_points : [];
      const begin = finiteNumber(wayPoints[0]);
      const end = finiteNumber(wayPoints[1]);
      if (
        !instruction
        || stepDistanceMeters == null
        || stepDurationSeconds == null
        || begin == null
        || end == null
        || !Number.isInteger(begin)
        || !Number.isInteger(end)
      ) continue;

      const beginShapeIndex = Math.min(coordinates.length - 1, Math.max(0, begin));
      const endShapeIndex = Math.min(coordinates.length - 1, Math.max(beginShapeIndex, end));
      steps.push({
        instruction,
        distanceKm: Math.max(0, stepDistanceMeters) / 1000,
        durationSeconds: Math.max(0, stepDurationSeconds),
        beginShapeIndex,
        endShapeIndex,
        coordinate: coordinates[beginShapeIndex],
      });
    }
  }

  return {
    distanceKm: distanceMeters / 1000,
    durationSeconds,
    coordinates,
    steps,
    mode,
  };
}
