import { Suspense } from "react";

import { AccountAddRoute } from "@/components/account-add-route";

export const metadata = { title: "WYNOS — เพิ่มบัญชี" };

export default function AddAccountPage() {
  return <Suspense fallback={null}><AccountAddRoute /></Suspense>;
}
