import { fetchAdminDashboardMetrics } from "@/lib/admin-metrics";

/**
 * The actual data-fetching grid, per Design spec's Screen -- lives in
 * its own async component (not inline in page.tsx) so `<Suspense>` in
 * page.tsx can show DashboardSkeleton while this specific fetch is in
 * flight, without delaying the rest of the page (header/refresh button).
 */
export async function DashboardMetrics() {
  // TEMPORARY diagnostic (remove once the production RPC failure is
  // root-caused): Next.js redacts thrown Server Component error
  // messages before they reach the client error boundary, so the only
  // way to actually see the real Postgres/PostgREST error text is to
  // catch it here and render it directly instead of letting it throw.
  let m;
  try {
    m = await fetchAdminDashboardMetrics();
  } catch (e) {
    return (
      <pre className="m-6 whitespace-pre-wrap break-words rounded-lg border border-destructive bg-destructive/10 p-4 text-xs text-destructive">
        {e instanceof Error ? `${e.name}: ${e.message}\n${JSON.stringify(e, null, 2)}` : String(e)}
      </pre>
    );
  }

  // TEMPORARY (see above): the fetch itself may now succeed while a
  // downstream component (StatCard/TopSourcesCard) throws on the actual
  // shape of the data during React's render pass -- a throw there
  // bypasses this function's own try/catch entirely (that only covers
  // the await), and bubbles to the same error.tsx boundary. Dumping the
  // raw row here, before any of those components run, rules that out.
  return (
    <pre className="m-6 whitespace-pre-wrap break-words rounded-lg border p-4 text-xs">
      {JSON.stringify(m, null, 2)}
    </pre>
  );
}
