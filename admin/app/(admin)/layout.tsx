import { AdminSidebar } from "@/components/admin/sidebar";
import { AdminHeader } from "@/components/admin/header";
import { requireAdminRole } from "@/lib/auth";

import { signOutAction } from "./actions";

/**
 * Wraps every Admin page -- requireAdminRole() runs server-side and
 * redirects to /login for anyone without a session or without an
 * admin/moderator platform_role, before any child page renders (Design
 * spec's Screen 2: "role check ต้องเกิดที่ layout level (server-side)
 * ไม่ใช่ทำซ้ำในทุกหน้าลูก").
 */
export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const { email, role } = await requireAdminRole();

  return (
    <div className="flex min-h-screen">
      <AdminSidebar />
      <div className="flex flex-1 flex-col">
        <AdminHeader email={email} role={role} signOutAction={signOutAction} />
        <main className="flex flex-1 flex-col">{children}</main>
      </div>
    </div>
  );
}
