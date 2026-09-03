// WYN-098: unit tests for the pure logic in _lib.ts -- no network, no
// Deno.serve, no real LocationIQ account needed. Run with `deno test`.
import { assertEquals } from "jsr:@std/assert@1";

import {
  buildReverseUrl,
  buildSearchUrl,
  isRateLimited,
  parseReverseGeocodeResult,
  parseSearchResults,
  RATE_LIMIT_MAX_REQUESTS,
  userIdFromAuthHeader,
} from "./_lib.ts";

Deno.test("parseSearchResults splits display_name into name + address", () => {
  const results = parseSearchResults([
    {
      place_id: "12345",
      lat: "13.7466",
      lon: "100.5347",
      display_name: "Starbucks, 991, Rama I Rd, Pathum Wan, Bangkok, 10330, Thailand",
    },
  ]);

  assertEquals(results.length, 1);
  assertEquals(results[0].name, "Starbucks");
  assertEquals(
    results[0].address,
    "991, Rama I Rd, Pathum Wan, Bangkok, 10330, Thailand",
  );
  assertEquals(results[0].lat, 13.7466);
  assertEquals(results[0].lon, 100.5347);
  assertEquals(results[0].placeId, "12345");
});

Deno.test("parseSearchResults returns 2 distinct rows for ambiguous same-name results "
  + "(Product spec's disambiguation edge case)", () => {
  const results = parseSearchResults([
    {
      place_id: "1",
      lat: "13.7466",
      lon: "100.5347",
      display_name: "Starbucks, สยามพารากอน, Bangkok, Thailand",
    },
    {
      place_id: "2",
      lat: "13.7466",
      lon: "100.5407",
      display_name: "Starbucks, เซ็นทรัลเวิลด์, Bangkok, Thailand",
    },
  ]);

  assertEquals(results.length, 2);
  assertEquals(results[0].name, "Starbucks");
  assertEquals(results[0].address, "สยามพารากอน, Bangkok, Thailand");
  assertEquals(results[1].address, "เซ็นทรัลเวิลด์, Bangkok, Thailand");
});

Deno.test("parseSearchResults falls back to osm_type:osm_id when place_id is absent", () => {
  const results = parseSearchResults([
    {
      osm_type: "way",
      osm_id: "987",
      lat: "13.0",
      lon: "100.0",
      display_name: "สยามพารากอน, Bangkok, Thailand",
    },
  ]);

  assertEquals(results[0].placeId, "way:987");
});

Deno.test("parseSearchResults treats a single-segment display_name (no comma) as "
  + "name-only, address null", () => {
  const results = parseSearchResults([
    { place_id: "1", lat: "13.0", lon: "100.0", display_name: "Thailand" },
  ]);

  assertEquals(results[0].name, "Thailand");
  assertEquals(results[0].address, null);
});

Deno.test("parseSearchResults skips an entry with a non-numeric lat/lon rather than "
  + "throwing", () => {
  const results = parseSearchResults([
    { place_id: "1", lat: "not-a-number", lon: "100.0", display_name: "Bad Row" },
    { place_id: "2", lat: "13.0", lon: "100.0", display_name: "Good Row" },
  ]);

  assertEquals(results.length, 1);
  assertEquals(results[0].name, "Good Row");
});

Deno.test("parseSearchResults returns an empty list (not a throw) for a non-array "
  + "response -- e.g. LocationIQ's own error payload shape", () => {
  assertEquals(parseSearchResults({ error: "Invalid key" }), []);
  assertEquals(parseSearchResults(null), []);
  assertEquals(parseSearchResults(undefined), []);
});

Deno.test("parseReverseGeocodeResult parses a single object", () => {
  const result = parseReverseGeocodeResult({
    place_id: "555",
    lat: "13.75",
    lon: "100.50",
    display_name: "วัดพระแก้ว, Phra Nakhon, Bangkok, Thailand",
  });

  assertEquals(result?.name, "วัดพระแก้ว");
  assertEquals(result?.placeId, "555");
});

Deno.test("parseReverseGeocodeResult returns null for an array (the /search shape, "
  + "not /reverse's) or any other unparseable input", () => {
  assertEquals(parseReverseGeocodeResult([{ lat: "1", lon: "1", display_name: "x" }]), null);
  assertEquals(parseReverseGeocodeResult(null), null);
  assertEquals(parseReverseGeocodeResult("not json"), null);
});

Deno.test("buildSearchUrl includes the api key, query, and a Thailand bias", () => {
  const url = buildSearchUrl("test-key", "starbucks");
  assertEquals(url.startsWith("https://us1.locationiq.com/v1/search?"), true);
  const parsed = new URL(url);
  assertEquals(parsed.searchParams.get("key"), "test-key");
  assertEquals(parsed.searchParams.get("q"), "starbucks");
  assertEquals(parsed.searchParams.get("countrycodes"), "th");
});

Deno.test("buildReverseUrl includes the api key and coordinates", () => {
  const url = buildReverseUrl("test-key", 13.75, 100.5);
  const parsed = new URL(url);
  assertEquals(parsed.searchParams.get("lat"), "13.75");
  assertEquals(parsed.searchParams.get("lon"), "100.5");
});

Deno.test("isRateLimited is false right up to the cap, true once at/over it", () => {
  assertEquals(isRateLimited(0), false);
  assertEquals(isRateLimited(RATE_LIMIT_MAX_REQUESTS - 1), false);
  assertEquals(isRateLimited(RATE_LIMIT_MAX_REQUESTS), true);
  assertEquals(isRateLimited(RATE_LIMIT_MAX_REQUESTS + 5), true);
});

Deno.test("userIdFromAuthHeader decodes the sub claim from a well-formed JWT", () => {
  // header.payload.signature -- payload is {"sub":"user-123"} base64url-encoded.
  // (Signature is never verified here -- see _lib.ts's own doc comment
  // on why that's the platform's job, already done before this runs.)
  const payload = btoa(JSON.stringify({ sub: "user-123" }))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  const token = `eyJhbGciOiJIUzI1NiJ9.${payload}.fake-signature`;

  assertEquals(userIdFromAuthHeader(`Bearer ${token}`), "user-123");
  // Also works without the "Bearer " prefix.
  assertEquals(userIdFromAuthHeader(token), "user-123");
});

Deno.test("userIdFromAuthHeader returns null for a missing/malformed header", () => {
  assertEquals(userIdFromAuthHeader(null), null);
  assertEquals(userIdFromAuthHeader(""), null);
  assertEquals(userIdFromAuthHeader("Bearer not-a-jwt"), null);
  assertEquals(userIdFromAuthHeader("Bearer a.b"), null);
});
