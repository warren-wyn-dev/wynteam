import { Suspense } from "react";

import { HomeFixture } from "@/components/home/home-fixture";

export default function HomeFixturePage() {
  return <Suspense fallback={null}><HomeFixture /></Suspense>;
}
