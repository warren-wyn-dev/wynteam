"use client";

import { useActionState, useId } from "react";
import { LoaderCircle, LogOut } from "lucide-react";

import type { SignOutResult } from "@/app/(admin)/actions";
import { Button } from "@/components/ui/button";

export function LogoutButton({
  signOutAction,
}: {
  signOutAction: (previousState: SignOutResult) => Promise<SignOutResult>;
}) {
  const [state, formAction, pending] = useActionState(signOutAction, { error: null });
  const errorId = useId();
  const error = pending ? null : state.error;

  return (
    <div className="relative shrink-0">
      <form action={formAction}>
        <Button
          type="submit"
          variant="outline"
          size="sm"
          className="min-h-11 gap-2"
          disabled={pending}
          aria-busy={pending}
          aria-describedby={error ? errorId : undefined}
        >
          {pending ? (
            <LoaderCircle className="size-4 animate-spin motion-reduce:animate-none" aria-hidden="true" />
          ) : (
            <LogOut className="size-4" aria-hidden="true" />
          )}
          {pending ? "กำลังออก..." : "ออกจากระบบ"}
        </Button>
      </form>
      {error ? (
        <p
          id={errorId}
          role="alert"
          className="absolute right-0 top-full z-40 mt-2 w-72 max-w-[calc(100vw-2rem)] rounded-lg border border-destructive/30 bg-background p-3 text-sm text-destructive shadow-lg"
        >
          {error}
        </p>
      ) : null}
    </div>
  );
}
