import type { Metadata } from "next";

import { WynosFoodDeveloperApp } from "@/components/food/wynos-food-developer-app";
import { foodStoreShareMetadata } from "@/lib/food-share-preview";

// A shared store link (food.wynos.online/?store=<id>) previews with that
// store's name and photo; any other visit keeps the layout's metadata.
export async function generateMetadata({ searchParams }: PageProps<"/food">): Promise<Metadata> {
  const { store } = await searchParams;
  return (await foodStoreShareMetadata(store)) ?? {};
}

export default function FoodPage() {
  return <WynosFoodDeveloperApp />;
}
