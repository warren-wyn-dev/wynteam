/** Root layout owns the signup draft above the keyed page transition so typed
 * credentials do not disappear when the entry/exit animation completes. */
export default function AuthFlowLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return children;
}
