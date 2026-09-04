import {
  fetchUserDirectory,
  type DirectorySort,
  type DirectoryStatus,
} from "@/lib/admin-users";

export async function UserDirectory({
  sort,
  role,
  status,
}: {
  sort: DirectorySort;
  role?: "user" | "moderator" | "admin";
  status?: DirectoryStatus;
}) {
  // TEMPORARY diagnostic (remove once root-caused -- same technique
  // that found today's earlier Dashboard bug): catch the fetch AND
  // dump the raw row instead of rendering, since Next.js redacts
  // thrown Server Component error messages before they reach the
  // client boundary, and a throw during render (not just the fetch)
  // would bypass a plain try/catch around the await alone.
  let users;
  try {
    users = await fetchUserDirectory({ sort, role, status });
  } catch (e) {
    return (
      <pre className="m-6 whitespace-pre-wrap break-words rounded-lg border border-destructive bg-destructive/10 p-4 text-xs text-destructive">
        {e instanceof Error ? `${e.name}: ${e.message}\n${JSON.stringify(e, null, 2)}` : String(e)}
      </pre>
    );
  }

  return (
    <pre className="m-6 whitespace-pre-wrap break-words rounded-lg border p-4 text-xs">
      {JSON.stringify(users, null, 2)}
    </pre>
  );
}
