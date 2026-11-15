import assert from "node:assert/strict";
import test from "node:test";

async function rewritesFor(env) {
  const saved = { ...process.env };
  Object.assign(process.env, env);
  for (const key of ["ZOKY_MAPS_UPSTREAM_ORIGIN", "WYNOS_GEO_ORIGIN"]) if (!(key in env)) delete process.env[key];
  try {
    const config = (await import(`../next.config.ts?${Math.random()}`)).default;
    return (await config.rewrites()).beforeFiles.filter((rule) => rule.source.startsWith("/api/maps"));
  } finally {
    process.env = saved;
  }
}

test("without a geo origin every /api/maps call is forwarded upstream (current behaviour)", async () => {
  const rules = await rewritesFor({ ZOKY_MAPS_UPSTREAM_ORIGIN: "https://upstream.example" });
  assert.deepEqual(rules, [{ source: "/api/maps/:path*", destination: "https://upstream.example/api/maps/:path*" }]);
});

test("with a geo origin only routing is forwarded; search and reverse are served here", async () => {
  const rules = await rewritesFor({ ZOKY_MAPS_UPSTREAM_ORIGIN: "https://upstream.example", WYNOS_GEO_ORIGIN: "https://maps.example/api/geo" });
  assert.deepEqual(rules, [{ source: "/api/maps/route", destination: "https://upstream.example/api/maps/route" }]);
});

test("with no upstream there is no forwarding at all", async () => {
  assert.deepEqual(await rewritesFor({ WYNOS_GEO_ORIGIN: "https://maps.example/api/geo" }), []);
});
