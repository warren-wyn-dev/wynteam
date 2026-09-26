import type { Metadata } from "next";

import { PopUnavailableRoute } from "@/components/deep-link-routes";
import { shareMetadata } from "@/lib/share-metadata";

// Pop links are still shared from the WYNOS app; give them their own URL
// in link previews instead of inheriting the site defaults.
export async function generateMetadata({ params }: { params: Promise<{ id: string }> }): Promise<Metadata> {
  const { id } = await params;
  return shareMetadata("Pop บน WYNOS", "เปิดดู Pop นี้บน WYNOS", `/pop/${id}`);
}

export default function Page() {
  return <PopUnavailableRoute />;
}
