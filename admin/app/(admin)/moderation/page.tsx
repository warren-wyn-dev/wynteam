import { Suspense } from "react";

import { SearchForm } from "./search-form";
import { SearchResults } from "./results";

export default async function ModerationPage({
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
        <p className="p-6 text-center text-muted-foreground">พิมพ์คำค้นเพื่อค้นหา Drop</p>
      ) : (
        <Suspense
          key={query}
          fallback={
            <div className="grid grid-cols-2 gap-3 md:grid-cols-4 lg:grid-cols-6">
              {Array.from({ length: 12 }).map((_, i) => (
                <div key={i} className="aspect-square animate-pulse rounded-lg border bg-muted/40" />
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
