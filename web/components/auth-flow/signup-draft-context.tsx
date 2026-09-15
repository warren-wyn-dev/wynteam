"use client";

import {
  createContext,
  useContext,
  useMemo,
  useState,
  type Dispatch,
  type ReactNode,
  type SetStateAction,
} from "react";

export type SignupDraft = {
  username: string;
  displayName: string;
  birthDate: string;
  email: string;
  password: string;
  confirmPassword: string;
};

type SignupDraftContextValue = {
  draft: SignupDraft;
  setDraft: Dispatch<SetStateAction<SignupDraft>>;
};

const initialDraft: SignupDraft = {
  username: "",
  displayName: "",
  birthDate: "",
  email: "",
  password: "",
  confirmPassword: "",
};

const SignupDraftContext = createContext<SignupDraftContextValue | null>(null);

export function SignupDraftProvider({ children }: { children: ReactNode }) {
  const [draft, setDraft] = useState<SignupDraft>(initialDraft);
  const value = useMemo(() => ({ draft, setDraft }), [draft]);

  return <SignupDraftContext.Provider value={value}>{children}</SignupDraftContext.Provider>;
}

export function useSignupDraft() {
  const value = useContext(SignupDraftContext);
  if (!value) throw new Error("useSignupDraft must be used within SignupDraftProvider");
  return value;
}
