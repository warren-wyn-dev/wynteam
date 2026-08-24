import { Suspense } from "react";

import { SearchForm } from "./search-form";
import { SearchResults } from "./results";

export default async function UsersPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>;
}) {
  const { q } = await searchParams;
  const query = (q ?? "").trim();

  return (
    <div className="flex flex-col gap-4 p-6">
      <SearchForm />
      {query.length === 0 ? (
        <p className="p-6 text-center text-muted-foreground">พิมพ์ username เพื่อค้นหา</p>
      ) : (
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
      )}
    </div>
  );
}
