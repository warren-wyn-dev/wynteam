import Link from "next/link";

import { Badge } from "@/components/ui/badge";
import { searchUsers } from "@/lib/admin-users";

const ROLE_LABEL: Record<string, string> = {
  admin: "Admin",
  moderator: "Moderator",
  user: "User",
};

export async function SearchResults({ query }: { query: string }) {
  const results = await searchUsers(query);

  if (results.length === 0) {
    return (
      <p className="p-6 text-center text-muted-foreground">
        ไม่พบผู้ใช้ที่ตรงกับ &quot;{query}&quot;
      </p>
    );
  }

  return (
    <div className="flex flex-col divide-y rounded-lg border">
      {results.map((user) => (
        <Link
          key={user.id}
          href={`/users/${user.id}`}
          className="flex items-center justify-between gap-4 px-4 py-3 hover:bg-accent"
        >
          <div>
            <p className="font-medium">{user.username}</p>
            {user.display_name ? (
              <p className="text-sm text-muted-foreground">{user.display_name}</p>
            ) : null}
          </div>
          <Badge variant="outline">{ROLE_LABEL[user.platform_role] ?? user.platform_role}</Badge>
        </Link>
      ))}
      {results.length === 30 ? (
        <p className="px-4 py-2 text-xs text-muted-foreground">
          แสดง 30 รายการแรก — ลองพิมพ์คำค้นที่เจาะจงกว่านี้ถ้าไม่พบที่ต้องการ
        </p>
      ) : null}
    </div>
  );
}
