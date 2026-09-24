import type { Metadata } from "next";

import { WynosFoodPreviewRoute } from "@/components/food/wynos-food-preview-route";

export const metadata: Metadata = { title: "WYNOS Food — กำลังพัฒนา" };

export default function FoodPage() {
  return <WynosFoodPreviewRoute />;
}
