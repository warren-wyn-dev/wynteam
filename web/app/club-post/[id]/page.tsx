import type { Metadata } from "next";

import { ClubPostRoute } from "@/components/deep-link-routes";
import { shareMetadata } from "@/lib/share-metadata";

export async function generateMetadata({ params }: { params: Promise<{ id: string }> }): Promise<Metadata> {
  const { id } = await params;
  return shareMetadata("โพสต์ใน Club บน WYNOS", "เปิดดูโพสต์นี้ใน Club บน WYNOS", `/club-post/${id}`);
}

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <ClubPostRoute postId={id} />;
}
