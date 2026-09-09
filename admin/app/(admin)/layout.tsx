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
    <div className="flex min-h-screen min-w-0 bg-muted/30">
      <a
        href="#admin-main-content"
        className="sr-only z-50 rounded-md bg-background px-4 py-3 font-medium shadow-lg focus:not-sr-only focus:fixed focus:left-4 focus:top-4"
      >
        ข้ามไปยังเนื้อหาหลัก
      </a>
      <AdminSidebar />
      <div className="flex min-w-0 flex-1 flex-col">
        <AdminHeader email={email} role={role} signOutAction={signOutAction} />
        <main
          id="admin-main-content"
          tabIndex={-1}
          className="mx-auto flex w-full max-w-[1180px] flex-1 flex-col pb-24 md:pb-0"
        >
          {children}
        </main>
      </div>
    </div>
  );
}
