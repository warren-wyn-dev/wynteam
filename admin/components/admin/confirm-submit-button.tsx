"use client";

import type { ComponentProps } from "react";

import { cn } from "@/lib/utils";

export function ConfirmSubmitButton({
  children,
  confirmText,
  className,
  ...props
}: ComponentProps<"button"> & { confirmText: string }) {
  return (
    <button
      type="submit"
      className={cn(
        "inline-flex min-h-11 items-center justify-center rounded-md bg-foreground px-4 text-sm font-semibold text-background transition-opacity hover:opacity-90 disabled:opacity-50",
        className,
      )}
      onClick={(event) => {
        if (!window.confirm(confirmText)) event.preventDefault();
      }}
      {...props}
    >
      {children}
    </button>
  );
}
