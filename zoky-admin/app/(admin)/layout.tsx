import { AdminSidebar } from "@/components/admin/sidebar";
import { AdminHeader } from "@/components/admin/header";
import { AdminNavProvider } from "@/components/admin/nav-state";
import { requireAdminRole } from "@/lib/auth";

import { signOutAction } from "./actions";

/**
 * Wraps every ZOKY Admin page -- requireAdminRole() runs server-side and
 * redirects to /login for anyone without a session or without food/merchant
 * access, before any child page renders.
 */
export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const { email, role, access } = await requireAdminRole();

  return (
    <AdminNavProvider>
      <div className="flex min-h-screen min-w-0 bg-muted/30">
        <a
          href="#admin-main-content"
          className="sr-only z-50 rounded-md bg-background px-4 py-3 font-medium shadow-lg focus:not-sr-only focus:fixed focus:left-4 focus:top-4"
        >
          ข้ามไปยังเนื้อหาหลัก
        </a>
        <AdminSidebar role={role} access={access} />
        <div className="flex min-w-0 flex-1 flex-col">
          <AdminHeader email={email} role={role} signOutAction={signOutAction} />
          <main
            id="admin-main-content"
            tabIndex={-1}
            className="mx-auto flex w-full max-w-[1180px] flex-1 flex-col"
          >
            {children}
          </main>
        </div>
      </div>
    </AdminNavProvider>
  );
}
