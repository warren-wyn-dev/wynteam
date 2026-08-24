import Link from "next/link";

import { Badge } from "@/components/ui/badge";
import { searchDrops } from "@/lib/admin-moderation";

export async function SearchResults({ query }: { query: string }) {
  const results = await searchDrops(query);

  if (results.length === 0) {
    return (
      <p className="p-6 text-center text-muted-foreground">
        ไม่พบ Drop ที่ตรงกับคำค้น &quot;{query}&quot;
      </p>
    );
  }

  return (
    <div className="flex flex-col gap-2">
      <div className="grid grid-cols-2 gap-3 md:grid-cols-4 lg:grid-cols-6">
        {results.map((drop) => (
          <Link
            key={drop.id}
            href={`/moderation/${drop.id}`}
            className="group relative aspect-square overflow-hidden rounded-lg border"
          >
            {/* eslint-disable-next-line @next/next/no-img-element -- drop.image_url
                is a per-project Supabase storage URL; there is no real project
                yet to pin into next.config's images.remotePatterns. */}
            <img
              src={drop.image_url}
              alt={`Drop โดย ${drop.author_username}`}
              className="h-full w-full object-cover"
            />
            {drop.deleted_at ? (
              <Badge variant="destructive" className="absolute right-1.5 top-1.5">
                ลบแล้ว
              </Badge>
            ) : null}
            <span className="absolute bottom-0 left-0 right-0 truncate bg-black/60 px-2 py-1 text-xs text-white">
              {drop.author_username}
            </span>
          </Link>
        ))}
      </div>
      {results.length === 30 ? (
        <p className="px-1 text-xs text-muted-foreground">
          แสดง 30 รายการแรก — ลองพิมพ์คำค้นที่เจาะจงกว่านี้ถ้าไม่พบที่ต้องการ
        </p>
      ) : null}
    </div>
  );
}
