import type { Metadata } from "next";

import { WynosFoodDeveloperApp } from "@/components/food/wynos-food-developer-app";
import { foodStoreShareMetadata } from "@/lib/food-share-preview";

// Store-specific link previews are optional. Any metadata lookup failure must
// fall back to the layout metadata instead of failing the customer entry route.
export async function generateMetadata({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}): Promise<Metadata> {
  try {
    const { store } = await searchParams;
    return (await foodStoreShareMetadata(store)) ?? {};
  } catch {
    return {};
  }
}

export default function FoodPage() {
  return <WynosFoodDeveloperApp />;
}
