"use client";

import { createContext, useContext, useMemo, useState, type Dispatch, type ReactNode, type SetStateAction } from "react";

export type CreateClubDraft = {
  name: string;
  description: string;
};

type CreateClubDraftContextValue = {
  draft: CreateClubDraft;
  setDraft: Dispatch<SetStateAction<CreateClubDraft>>;
};

const initialDraft: CreateClubDraft = { name: "", description: "" };
const CreateClubDraftContext = createContext<CreateClubDraftContextValue | null>(null);

export function CreateClubDraftProvider({ children }: { children: ReactNode }) {
  const [draft, setDraft] = useState<CreateClubDraft>(initialDraft);
  const value = useMemo(() => ({ draft, setDraft }), [draft]);
  return <CreateClubDraftContext.Provider value={value}>{children}</CreateClubDraftContext.Provider>;
}

export function useCreateClubDraft() {
  const value = useContext(CreateClubDraftContext);
  if (!value) throw new Error("useCreateClubDraft must be used within CreateClubDraftProvider");
  return value;
}
