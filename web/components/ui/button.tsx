import type { ButtonHTMLAttributes, ReactNode } from "react";

type ButtonVariant = "primary" | "outline";
type ButtonShape = "pill" | "rounded";
type ButtonSize = "default" | "compact";

export type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: ButtonVariant;
  shape?: ButtonShape;
  size?: ButtonSize;
  leadingIcon?: ReactNode;
  trailingIcon?: ReactNode;
};

export function Button({
  variant = "primary",
  shape = "pill",
  size = "default",
  leadingIcon,
  trailingIcon,
  className,
  children,
  type = "button",
  ...props
}: ButtonProps) {
  const classes = [
    "wyn-button",
    `wyn-button--${variant}`,
    shape === "rounded" ? "wyn-button--rounded" : "",
    size === "compact" ? "wyn-button--compact" : "",
    className ?? "",
  ]
    .filter(Boolean)
    .join(" ");

  return (
    <button className={classes} type={type} {...props}>
      {leadingIcon}
      {children}
      {trailingIcon}
    </button>
  );
}
