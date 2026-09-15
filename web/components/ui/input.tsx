import type { InputHTMLAttributes } from "react";

export type InputProps = InputHTMLAttributes<HTMLInputElement> & {
  label?: string;
  hint?: string;
  error?: string;
};

export function Input({ label, hint, error, className, id, name, ...props }: InputProps) {
  const inputId = id ?? name;
  const describedBy = [
    hint && inputId ? `${inputId}-hint` : null,
    error && inputId ? `${inputId}-error` : null,
  ]
    .filter(Boolean)
    .join(" ");

  return (
    <label className="wyn-field">
      {label ? <span className="wyn-field__label">{label}</span> : null}
      <input
        aria-describedby={describedBy || undefined}
        aria-invalid={error ? true : undefined}
        className={["wyn-input", className ?? ""].filter(Boolean).join(" ")}
        id={inputId}
        name={name}
        {...props}
      />
      {hint ? (
        <p className="wyn-field__hint" id={inputId ? `${inputId}-hint` : undefined}>
          {hint}
        </p>
      ) : null}
      {error ? (
        <p className="wyn-field__error" id={inputId ? `${inputId}-error` : undefined} role="alert">
          {error}
        </p>
      ) : null}
    </label>
  );
}
