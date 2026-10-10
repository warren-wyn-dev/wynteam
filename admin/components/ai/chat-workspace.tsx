"use client";

import { useRef, useState, type FormEvent, type KeyboardEvent } from "react";
import { AlertTriangle, CheckCircle2, Clock, Loader2, ShieldAlert, Sparkles, Square, XCircle } from "lucide-react";

import { Markdown } from "@/components/ai/markdown";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { MODEL_TIER_LABEL, MODEL_TIERS } from "@/lib/ai/models";
import type { DataSource, ModelTier, SecretaryEvent, TokenUsage } from "@/lib/ai/types";
import { cn } from "@/lib/utils";

type ToolChip = Extract<SecretaryEvent, { type: "tool" }>;

type AssistantTurn = {
  role: "assistant";
  text: string;
  phase: "analyzing" | "calling_tools" | "writing" | "done" | "failed";
  tools: ToolChip[];
  notices: string[];
  unverifiedNumbers: string[];
  usage?: TokenUsage;
  model?: string;
  durationMs?: number;
  error?: string;
};

type Turn = { role: "user"; text: string } | AssistantTurn;

const SUGGESTIONS = [
  "สรุปภาพรวม WYNOS วันนี้ พร้อมสิ่งที่ผิดปกติ",
  "เทียบกิจกรรม 24 ชม.ล่าสุดกับเมื่อวาน",
  "ยอดขาย WYNOS Food 7 วันล่าสุดเป็นอย่างไร",
  "ตอนนี้ AI เข้าถึงข้อมูลระบบไหนได้บ้าง",
];

const PHASE_LABEL: Record<AssistantTurn["phase"], string> = {
  analyzing: "กำลังวิเคราะห์",
  calling_tools: "กำลังเรียกข้อมูล",
  writing: "กำลังเขียนคำตอบ",
  done: "เสร็จแล้ว",
  failed: "ไม่สำเร็จ",
};

export function ChatWorkspace({
  initialConversationId,
  initialTurns,
}: {
  initialConversationId: string | null;
  initialTurns: Array<{ role: "user" | "assistant"; text: string }>;
}) {
  const [conversationId, setConversationId] = useState<string | null>(initialConversationId);
  const [turns, setTurns] = useState<Turn[]>(() =>
    initialTurns.map((t) =>
      t.role === "user"
        ? { role: "user", text: t.text }
        : { role: "assistant", text: t.text, phase: "done", tools: [], notices: [], unverifiedNumbers: [] },
    ),
  );
  const [input, setInput] = useState("");
  const [tier, setTier] = useState<ModelTier>("standard");
  const [busy, setBusy] = useState(false);
  const abortRef = useRef<AbortController | null>(null);
  const endRef = useRef<HTMLDivElement | null>(null);

  const updateLast = (fn: (turn: AssistantTurn) => AssistantTurn) =>
    setTurns((prev) => {
      const next = [...prev];
      const last = next[next.length - 1];
      if (last?.role === "assistant") next[next.length - 1] = fn(last);
      return next;
    });

  async function send(text: string) {
    const message = text.trim();
    if (!message || busy) return;
    setInput("");
    setBusy(true);
    setTurns((prev) => [
      ...prev,
      { role: "user", text: message },
      { role: "assistant", text: "", phase: "analyzing", tools: [], notices: [], unverifiedNumbers: [] },
    ]);
    const controller = new AbortController();
    abortRef.current = controller;

    try {
      const response = await fetch("/api/ai/chat", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ message, conversationId, tier }),
        signal: controller.signal,
      });
      if (!response.ok || !response.body) {
        const body = (await response.json().catch(() => null)) as { error?: string } | null;
        throw new Error(body?.error ?? `คำขอไม่สำเร็จ (${response.status})`);
      }
      // An expired session is redirected to the login page (HTML), not an error status.
      if (!response.headers.get("content-type")?.includes("application/x-ndjson")) {
        throw new Error("เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่");
      }

      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let buffer = "";
      for (;;) {
        const { value, done } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split("\n");
        buffer = lines.pop() ?? "";
        for (const line of lines) {
          if (line.trim()) applyEvent(JSON.parse(line) as SecretaryEvent);
        }
      }
      updateLast((t) => (t.phase === "failed" ? t : { ...t, phase: "done" }));
    } catch (error) {
      const aborted = controller.signal.aborted;
      updateLast((t) => ({
        ...t,
        phase: "failed",
        error: aborted ? "หยุดคำขอแล้ว" : error instanceof Error ? error.message : "เกิดข้อผิดพลาด",
      }));
    } finally {
      abortRef.current = null;
      setBusy(false);
      requestAnimationFrame(() => endRef.current?.scrollIntoView({ behavior: "smooth", block: "end" }));
    }
  }

  function applyEvent(event: SecretaryEvent) {
    switch (event.type) {
      case "conversation":
        setConversationId(event.conversationId);
        if (typeof window !== "undefined") {
          const url = new URL(window.location.href);
          url.searchParams.set("c", event.conversationId);
          window.history.replaceState(null, "", url);
        }
        break;
      case "status":
        updateLast((t) => ({ ...t, phase: event.phase }));
        break;
      case "text":
        updateLast((t) => ({ ...t, text: t.text + event.delta }));
        break;
      case "tool":
        updateLast((t) => {
          const others = t.tools.filter((chip) => chip.id !== event.id);
          return { ...t, tools: [...others, event] };
        });
        break;
      case "notice":
        updateLast((t) => ({ ...t, notices: [...t.notices, event.message] }));
        break;
      case "verification":
        updateLast((t) => ({ ...t, unverifiedNumbers: event.unverifiedNumbers }));
        break;
      case "done":
        updateLast((t) => ({ ...t, phase: "done", usage: event.usage, model: event.model, durationMs: event.durationMs }));
        break;
      case "error":
        updateLast((t) => ({ ...t, phase: "failed", error: event.message }));
        break;
    }
  }

  function onSubmit(event: FormEvent) {
    event.preventDefault();
    void send(input);
  }

  function onKeyDown(event: KeyboardEvent<HTMLTextAreaElement>) {
    if (event.key === "Enter" && !event.shiftKey && !event.nativeEvent.isComposing) {
      event.preventDefault();
      void send(input);
    }
  }

  return (
    <div className="flex min-h-[60vh] flex-col gap-4">
      <div aria-live="polite" className="flex flex-1 flex-col gap-4">
        {turns.length === 0 ? (
          <div className="flex flex-col items-center gap-4 rounded-2xl border border-dashed bg-background p-8 text-center">
            <Sparkles className="size-6 text-violet-500" aria-hidden />
            <div className="flex flex-col gap-1">
              <p className="font-medium">ถามเลขา AI เรื่องข้อมูลของ WYNOS ได้เลย</p>
              <p className="text-sm text-muted-foreground">
                ทุกตัวเลขมาจากข้อมูลจริงของระบบ พร้อมบอกแหล่งที่มาและช่วงเวลา · Phase 1 อ่านและวิเคราะห์ได้อย่างเดียว
              </p>
            </div>
            <div className="flex flex-wrap justify-center gap-2">
              {SUGGESTIONS.map((suggestion) => (
                <button
                  key={suggestion}
                  type="button"
                  onClick={() => void send(suggestion)}
                  className="min-h-11 rounded-full border bg-background px-4 text-sm hover:bg-accent"
                >
                  {suggestion}
                </button>
              ))}
            </div>
          </div>
        ) : (
          turns.map((turn, index) =>
            turn.role === "user" ? (
              <div key={index} className="ml-auto max-w-[85%] rounded-2xl rounded-br-md bg-primary px-4 py-3 text-sm text-primary-foreground">
                <p className="whitespace-pre-wrap">{turn.text}</p>
              </div>
            ) : (
              <AssistantBubble key={index} turn={turn} />
            ),
          )
        )}
        <div ref={endRef} />
      </div>

      <form onSubmit={onSubmit} className="sticky bottom-24 flex flex-col gap-2 rounded-2xl border bg-background p-3 shadow-sm md:bottom-4">
        <label htmlFor="ai-message" className="sr-only">
          ข้อความถึง AI Secretary
        </label>
        <Textarea
          id="ai-message"
          value={input}
          onChange={(event) => setInput(event.target.value)}
          onKeyDown={onKeyDown}
          maxLength={4000}
          rows={2}
          placeholder="ถามเกี่ยวกับผู้ใช้ ยอดขาย หรือความผิดปกติของระบบ… (Enter เพื่อส่ง, Shift+Enter ขึ้นบรรทัดใหม่)"
          className="min-h-16 resize-none border-0 shadow-none focus-visible:ring-0"
          disabled={busy}
        />
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div role="group" aria-label="โหมดโมเดล" className="flex gap-1 rounded-full bg-muted p-1">
            {MODEL_TIERS.map((value) => (
              <button
                key={value}
                type="button"
                aria-pressed={tier === value}
                onClick={() => setTier(value)}
                className={cn(
                  "min-h-9 rounded-full px-3 text-xs font-medium",
                  tier === value ? "bg-background text-foreground shadow-sm" : "text-muted-foreground hover:text-foreground",
                )}
              >
                {MODEL_TIER_LABEL[value]}
              </button>
            ))}
          </div>
          <div className="flex items-center gap-2">
            <span className="text-xs text-muted-foreground tabular-nums">{input.length}/4000</span>
            {busy ? (
              <Button type="button" variant="outline" onClick={() => abortRef.current?.abort()}>
                <Square className="size-4" aria-hidden /> หยุด
              </Button>
            ) : (
              <Button type="submit" disabled={!input.trim()}>
                ส่ง
              </Button>
            )}
          </div>
        </div>
      </form>
    </div>
  );
}

function AssistantBubble({ turn }: { turn: AssistantTurn }) {
  const working = turn.phase !== "done" && turn.phase !== "failed";
  const sources = turn.tools.filter((tool): tool is ToolChip & { source: DataSource } => Boolean(tool.source));

  return (
    <div className="mr-auto flex w-full max-w-[92%] flex-col gap-3 rounded-2xl rounded-bl-md border bg-background px-4 py-3">
      <div className="flex flex-wrap items-center gap-2 text-xs">
        <StatusPill phase={turn.phase} />
        {turn.tools.map((tool) => (
          <ToolStatus key={tool.id} tool={tool} />
        ))}
      </div>

      {turn.text ? <Markdown text={turn.text} /> : working ? <p className="text-sm text-muted-foreground">…</p> : null}

      {turn.error ? (
        <p role="alert" className="flex items-center gap-2 rounded-lg bg-destructive/10 px-3 py-2 text-sm text-destructive">
          <XCircle className="size-4 shrink-0" aria-hidden /> {turn.error}
        </p>
      ) : null}

      {turn.notices.map((notice, n) => (
        <p key={n} className="flex items-center gap-2 rounded-lg bg-muted px-3 py-2 text-xs">
          <AlertTriangle className="size-4 shrink-0" aria-hidden /> {notice}
        </p>
      ))}

      {turn.unverifiedNumbers.length > 0 ? (
        <p className="flex items-start gap-2 rounded-lg border border-amber-300 bg-amber-50 px-3 py-2 text-xs text-amber-900 dark:border-amber-700 dark:bg-amber-950 dark:text-amber-100">
          <AlertTriangle className="mt-0.5 size-4 shrink-0" aria-hidden />
          <span>
            ตัวเลขที่ตรวจกับข้อมูลต้นทางไม่พบ (อาจเป็นค่าที่คำนวณเอง โปรดตรวจซ้ำ): {turn.unverifiedNumbers.join(", ")}
          </span>
        </p>
      ) : null}

      {sources.length > 0 ? (
        <details className="rounded-lg bg-muted/50 px-3 py-2 text-xs">
          <summary className="cursor-pointer font-medium">หลักฐานและแหล่งข้อมูล ({sources.length})</summary>
          <ul className="mt-2 flex flex-col gap-2">
            {sources.map((tool) => (
              <li key={tool.id} className="flex flex-col">
                <span className="font-medium">
                  {tool.source.system} · {tool.label}
                </span>
                <span className="text-muted-foreground">
                  {tool.source.reference} · ช่วงเวลา: {tool.source.window} · ดึงเมื่อ{" "}
                  {new Date(tool.source.retrievedAt).toLocaleString("th-TH", { timeZone: "Asia/Bangkok" })}
                </span>
              </li>
            ))}
          </ul>
        </details>
      ) : null}

      {turn.usage ? (
        <p className="text-[11px] text-muted-foreground tabular-nums">
          {turn.model} · {(turn.usage.inputTokens + turn.usage.outputTokens).toLocaleString()} tokens
          {turn.durationMs ? ` · ${(turn.durationMs / 1000).toFixed(1)} วินาที` : ""}
        </p>
      ) : null}
    </div>
  );
}

function StatusPill({ phase }: { phase: AssistantTurn["phase"] }) {
  const icon =
    phase === "done" ? (
      <CheckCircle2 className="size-3.5" aria-hidden />
    ) : phase === "failed" ? (
      <XCircle className="size-3.5" aria-hidden />
    ) : (
      <Loader2 className="size-3.5 animate-spin" aria-hidden />
    );
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-full px-2 py-0.5 font-medium",
        phase === "done" && "bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-200",
        phase === "failed" && "bg-destructive/15 text-destructive",
        phase !== "done" && phase !== "failed" && "bg-sky-100 text-sky-800 dark:bg-sky-950 dark:text-sky-200",
      )}
    >
      {icon}
      {PHASE_LABEL[phase]}
    </span>
  );
}

function ToolStatus({ tool }: { tool: ToolChip }) {
  const style = {
    running: { icon: <Loader2 className="size-3.5 animate-spin" aria-hidden />, text: "กำลังดึงข้อมูล", tone: "bg-muted" },
    succeeded: { icon: <CheckCircle2 className="size-3.5" aria-hidden />, text: "สำเร็จ", tone: "bg-muted" },
    failed: { icon: <XCircle className="size-3.5" aria-hidden />, text: "ล้มเหลว", tone: "bg-destructive/15 text-destructive" },
    timed_out: { icon: <Clock className="size-3.5" aria-hidden />, text: "หมดเวลา", tone: "bg-destructive/15 text-destructive" },
    denied: tool.needsApproval
      ? { icon: <ShieldAlert className="size-3.5" aria-hidden />, text: "ต้องอนุมัติ (ยังไม่เปิดใช้)", tone: "bg-amber-100 text-amber-900 dark:bg-amber-950 dark:text-amber-100" }
      : { icon: <ShieldAlert className="size-3.5" aria-hidden />, text: "ไม่มีสิทธิ์", tone: "bg-destructive/15 text-destructive" },
  }[tool.status];
  return (
    <span title={tool.error} className={cn("inline-flex items-center gap-1 rounded-full px-2 py-0.5", style.tone)}>
      {style.icon}
      {tool.label}: {style.text}
    </span>
  );
}
