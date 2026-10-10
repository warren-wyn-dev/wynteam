import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";

import { LoginForm } from "./login-form";

export default function LoginPage() {
  return (
    <div className="flex min-h-dvh items-center justify-center bg-muted/30 px-4 py-8 sm:px-6">
      <Card className="w-full max-w-[420px] shadow-sm">
        <CardHeader>
          <p className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">WYNOS · Control Center</p>
          <CardTitle className="text-2xl tracking-tight">WYNOS Admin</CardTitle>
          <CardDescription>
            เข้าสู่ระบบจัดการ WYNOS Social, Food และ Merchant
            สำหรับบัญชี Admin หรือ Moderator เท่านั้น
          </CardDescription>
        </CardHeader>
        <CardContent>
          <LoginForm />
        </CardContent>
      </Card>
    </div>
  );
}
