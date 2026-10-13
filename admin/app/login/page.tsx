import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";

import { LoginForm } from "./login-form";

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ logout?: string | string[] }>;
}) {
  const localOnlyLogout = (await searchParams).logout === "local";

  return (
    <div className="flex min-h-screen items-center justify-center bg-muted/30 px-4">
      <Card className="w-full max-w-[400px]">
        <CardHeader>
          <CardTitle className="text-xl">WYNOS Admin</CardTitle>
          <CardDescription>
            สำหรับผู้ดูแลระบบและผู้ตรวจสอบเนื้อหาเท่านั้น
          </CardDescription>
        </CardHeader>
        <CardContent>
          {localOnlyLogout ? (
            <p role="status" className="mb-4 rounded-lg border bg-muted/50 p-3 text-sm text-muted-foreground">
              ออกจาก WYNOS Admin ในเบราว์เซอร์นี้แล้ว แต่ยังยืนยันการออกจากระบบในอุปกรณ์อื่นไม่ได้
            </p>
          ) : null}
          <LoginForm />
        </CardContent>
      </Card>
    </div>
  );
}
