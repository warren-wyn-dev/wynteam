import { Suspense } from "react";

import { SearchForm } from "./search-form";
import { SearchResults } from "./results";
import { DirectorySortPills, DirectoryRolePills, DirectoryStatusPills } from "./directory-controls";
import { UserDirectory } from "./directory";
import type { DirectorySort, DirectoryStatus } from "@/lib/admin-users";

export default async function UsersPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; sort?: string; role?: string; status?: string }>;
}) {
  const { q, sort, role, status } = await searchParams;
  const query = (q ?? "").trim();

  return (
    <div className="flex flex-col gap-4 p-6">
      <SearchForm />
      {query.length > 0 ? (
        <Suspense
          key={query}
          fallback={
            <div className="flex flex-col gap-2">
              {Array.from({ length: 5 }).map((_, i) => (
                <div key={i} className="h-14 animate-pulse rounded-lg border bg-muted/40" />
              ))}
            </div>
          }
        >
          <SearchResults query={query} />
        </Suspense>
      ) : (
        // The "wide-angle" view -- rank/filter every user instead of
        // typing a username. Search above still works exactly as
        // before; it takes over the moment something is typed.
        <div className="flex flex-col gap-4">
          <div className="flex flex-col gap-2">
            <DirectorySortPills />
            <div className="flex flex-wrap items-center gap-3 text-xs text-muted-foreground">
              <DirectoryRolePills />
              <span className="text-border">·</span>
              <DirectoryStatusPills />
            </div>
          </div>
          <Suspense
            key={`${sort}-${role}-${status}`}
            fallback={
              <div className="flex flex-col gap-2">
                {Array.from({ length: 5 }).map((_, i) => (
                  <div key={i} className="h-14 animate-pulse rounded-lg border bg-muted/40" />
                ))}
              </div>
            }
          >
            <UserDirectory
              sort={(sort as DirectorySort) ?? "newest"}
              role={role === "all" || !role ? undefined : (role as "user" | "moderator" | "admin")}
              status={status === "all" || !status ? undefined : (status as DirectoryStatus)}
            />
          </Suspense>
        </div>
      )}
    </div>
  );
}
