import type { Metadata } from "next";

import { PostDetailRoute } from "@/components/post-detail-route";
import { shareMetadata } from "@/lib/share-metadata";

export async function generateMetadata({ params }: { params: Promise<{ id: string }> }): Promise<Metadata> {
  const { id } = await params;
  return shareMetadata("โพสต์บน WYNOS", "เปิดดูโพสต์นี้บน WYNOS", `/drop/${id}`);
}

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <PostDetailRoute dropId={id} />;
}
