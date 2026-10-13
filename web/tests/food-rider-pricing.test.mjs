import test from "node:test";
import assert from "node:assert/strict";
import { wynosRiderDeliveryFee } from "../lib/food-rider-pricing.ts";

test("future rider tariff rounds excess distance per100m and final fee up to baht", () => {
  for (const [meters,fee] of [[0,10],[1999,10],[2000,10],[2000.01,11],[2100,11],[2100.01,11],[2200,11],[2200.01,12],[2500,13],[3000,15]]) {
    assert.equal(wynosRiderDeliveryFee(meters),fee, `${meters}m`);
  }
});
test("invalid rider distance cannot yield a price", () => {
  for (const meters of [-1,NaN,Infinity,Number.MAX_VALUE]) assert.throws(() => wynosRiderDeliveryFee(meters));
});
