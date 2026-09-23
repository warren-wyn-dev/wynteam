"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type Dispatch,
  type ReactNode,
  type SetStateAction,
} from "react";
import { usePathname } from "next/navigation";

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

type SignupStep1Draft = Pick<SignupDraft, "username" | "displayName" | "birthDate">;

const step1StorageKey = "wynos-signup-step1-draft";

const initialDraft: SignupDraft = {
  username: "",
  displayName: "",
  birthDate: "",
  email: "",
  password: "",
  confirmPassword: "",
};

const SignupDraftContext = createContext<SignupDraftContextValue | null>(null);

function readStep1Draft(): SignupStep1Draft | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = window.sessionStorage.getItem(step1StorageKey);
    if (!raw) return null;
    const value = JSON.parse(raw) as Partial<SignupStep1Draft>;
    return {
      username: typeof value.username === "string" ? value.username : "",
      displayName: typeof value.displayName === "string" ? value.displayName : "",
      birthDate: typeof value.birthDate === "string" ? value.birthDate : "",
    };
  } catch {
    return null;
  }
}

function persistStep1Draft(draft: SignupDraft) {
  if (typeof window === "undefined") return;
  try {
    const step1: SignupStep1Draft = {
      username: draft.username,
      displayName: draft.displayName,
      birthDate: draft.birthDate,
    };
    window.sessionStorage.setItem(step1StorageKey, JSON.stringify(step1));
  } catch {
    // In-memory state remains the primary path when session storage is unavailable.
  }
}

export function SignupDraftProvider({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const [draft, setDraftState] = useState<SignupDraft>(initialDraft);
  const draftRef = useRef<SignupDraft>(initialDraft);

  useEffect(() => {
    const saved = readStep1Draft();
    if (!saved) return;
    const next = { ...draftRef.current, ...saved };
    draftRef.current = next;
    setDraftState(next);
  }, []);

  // Passwords live only in React memory; erase them as soon as signup
  // step 2 is left, including cancellation, callback and successful signup.
  useEffect(() => {
    if (pathname === "/signup/step-2") return;
    if (!draftRef.current.password && !draftRef.current.confirmPassword) return;
    const next = { ...draftRef.current, password: "", confirmPassword: "" };
    draftRef.current = next;
    setDraftState(next);
  }, [pathname]);

  const setDraft = useCallback<Dispatch<SetStateAction<SignupDraft>>>((nextValue) => {
    const next = typeof nextValue === "function" ? nextValue(draftRef.current) : nextValue;
    draftRef.current = next;
    persistStep1Draft(next);
    setDraftState(next);
  }, []);

  const value = useMemo(() => ({ draft, setDraft }), [draft, setDraft]);

  return <SignupDraftContext.Provider value={value}>{children}</SignupDraftContext.Provider>;
}

export function useSignupDraft() {
  const value = useContext(SignupDraftContext);
  if (!value) throw new Error("useSignupDraft must be used within SignupDraftProvider");
  return value;
}
