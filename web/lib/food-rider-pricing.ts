/** Future Rider tariff only. Not connected to checkout or merchant delivery. */
export function wynosRiderDeliveryFee(distanceMeters: number): number {
  if (!Number.isFinite(distanceMeters) || distanceMeters < 0 || distanceMeters > Number.MAX_SAFE_INTEGER) {
    throw new Error("invalid delivery distance");
  }
  const excessSteps = Math.ceil(Math.max(distanceMeters - 2000, 0) / 100);
  return Math.ceil((1000 + excessSteps * 50) / 100);
}
