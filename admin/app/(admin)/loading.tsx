/**
 * Next.js shows this automatically (via Suspense) while
 * AdminLayout's requireAdminRole() call is in flight -- Design spec's
 * Screen 2 "Loading" state: a visible placeholder instead of a blank
 * flash during the session/role check.
 */
export default function AdminLoading() {
  return (
    <div className="flex min-h-screen items-center justify-center">
      <div
        role="status"
        aria-label="กำลังโหลด"
        className="size-6 animate-spin rounded-full border-2 border-muted-foreground border-t-transparent"
      />
    </div>
  );
}
