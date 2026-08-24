"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { useState, useTransition } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

export function SearchForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [query, setQuery] = useState(searchParams.get("q") ?? "");
  const [isPending, startTransition] = useTransition();

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    startTransition(() => {
      router.push(`/moderation?q=${encodeURIComponent(query)}`);
    });
  }

  return (
    <form onSubmit={handleSubmit} className="flex gap-2">
      <Input
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="ค้นหาด้วย caption หรือ username ผู้เขียน"
        aria-label="ค้นหาด้วย caption หรือ username ผู้เขียน"
      />
      <Button type="submit" disabled={isPending || query.trim().length === 0}>
        ค้นหา
      </Button>
    </form>
  );
}
