import * as React from "react";
import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";

import { cn } from "@/lib/utils";

const badgeVariants = cva(
  // rounded-full (pill), not rounded-md, per wyn-admin-design-system.md
  // section 5 (Radius) / 6.2 (Status Badge redesign).
  "inline-flex items-center justify-center rounded-full border px-2 py-0.5 text-xs font-medium w-fit whitespace-nowrap shrink-0 gap-1",
  {
    variants: {
      variant: {
        default: "border-transparent bg-primary/15 text-primary",
        secondary: "border-transparent bg-secondary text-secondary-foreground",
        destructive: "border-transparent bg-destructive/15 text-destructive",
        outline: "text-foreground",
        // Role-hierarchy variants added per section 6.2 -- replace the old
        // purple/blue/gray role-badge colors with neutral weight/contrast
        // only. Highest emphasis (admin) down to lowest (user, which
        // reuses the existing `outline` variant above -- already neutral,
        // no new variant needed for that tier).
        "ink-solid": "border-transparent bg-primary text-primary-foreground",
        "gray-tonal": "border-transparent bg-zinc-200 text-foreground",
      },
    },
    defaultVariants: {
      variant: "default",
    },
  },
);

function Badge({
  className,
  variant,
  asChild = false,
  ...props
}: React.ComponentProps<"span"> &
  VariantProps<typeof badgeVariants> & { asChild?: boolean }) {
  const Comp = asChild ? Slot : "span";

  return (
    <Comp
      data-slot="badge"
      className={cn(badgeVariants({ variant }), className)}
      {...props}
    />
  );
}

export { Badge, badgeVariants };
