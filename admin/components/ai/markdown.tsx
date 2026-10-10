import { Fragment, type ReactNode } from "react";

/**
 * A small Markdown subset for AI answers: headings, paragraphs, bullet and
 * numbered lists, tables, fenced code, **bold**, *italic* and `code`.
 * Everything is rendered as React text nodes -- never as HTML -- so model
 * output cannot inject markup or scripts. Links are shown as plain text on
 * purpose (no clickable URLs from model output in Phase 1).
 */
export function Markdown({ text }: { text: string }) {
  return <div className="flex flex-col gap-3 text-sm leading-relaxed">{renderBlocks(text)}</div>;
}

function renderBlocks(text: string): ReactNode[] {
  const lines = text.replace(/\r\n/g, "\n").split("\n");
  const out: ReactNode[] = [];
  let i = 0;
  let key = 0;

  while (i < lines.length) {
    const line = lines[i];

    if (line.trim() === "") {
      i++;
      continue;
    }

    if (line.trimStart().startsWith("```")) {
      const code: string[] = [];
      i++;
      while (i < lines.length && !lines[i].trimStart().startsWith("```")) code.push(lines[i++]);
      i++;
      out.push(
        <pre key={key++} className="overflow-x-auto rounded-lg bg-muted p-3 text-xs">
          <code>{code.join("\n")}</code>
        </pre>,
      );
      continue;
    }

    const heading = /^(#{1,4})\s+(.*)$/.exec(line);
    if (heading) {
      const size = heading[1].length <= 2 ? "text-base" : "text-sm";
      out.push(
        <p key={key++} role="heading" aria-level={Math.min(heading[1].length + 2, 6)} className={`${size} font-semibold`}>
          {inline(heading[2])}
        </p>,
      );
      i++;
      continue;
    }

    if (isTableRow(line) && i + 1 < lines.length && /^\s*\|?\s*:?-{2,}/.test(lines[i + 1])) {
      const header = cells(line);
      i += 2;
      const rows: string[][] = [];
      while (i < lines.length && isTableRow(lines[i])) rows.push(cells(lines[i++]));
      out.push(
        <div key={key++} className="overflow-x-auto rounded-lg border">
          <table className="w-full text-left text-xs">
            <thead className="bg-muted/60">
              <tr>
                {header.map((cell, c) => (
                  <th key={c} scope="col" className="px-3 py-2 font-semibold">
                    {inline(cell)}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((row, r) => (
                <tr key={r} className="border-t">
                  {header.map((_, c) => (
                    <td key={c} className="px-3 py-2 tabular-nums">
                      {inline(row[c] ?? "")}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>,
      );
      continue;
    }

    const listMatch = /^\s*([-*•]|\d+[.)])\s+/.exec(line);
    if (listMatch) {
      const ordered = /\d/.test(listMatch[1]);
      const items: string[] = [];
      while (i < lines.length) {
        const m = /^\s*([-*•]|\d+[.)])\s+(.*)$/.exec(lines[i]);
        if (!m || /\d/.test(m[1]) !== ordered) break;
        items.push(m[2]);
        i++;
      }
      const ListTag = ordered ? "ol" : "ul";
      out.push(
        <ListTag key={key++} className={`flex flex-col gap-1 pl-5 ${ordered ? "list-decimal" : "list-disc"}`}>
          {items.map((item, n) => (
            <li key={n}>{inline(item)}</li>
          ))}
        </ListTag>,
      );
      continue;
    }

    const paragraph: string[] = [];
    while (
      i < lines.length &&
      lines[i].trim() !== "" &&
      !/^(#{1,4})\s/.test(lines[i]) &&
      !/^\s*([-*•]|\d+[.)])\s+/.test(lines[i]) &&
      !lines[i].trimStart().startsWith("```") &&
      !isTableRow(lines[i])
    ) {
      paragraph.push(lines[i++]);
    }
    if (paragraph.length === 0) paragraph.push(lines[i++]);
    out.push(
      <p key={key++} className="whitespace-pre-wrap">
        {inline(paragraph.join("\n"))}
      </p>,
    );
  }
  return out;
}

function isTableRow(line: string) {
  const trimmed = line.trim();
  return trimmed.startsWith("|") && trimmed.endsWith("|") && trimmed.length > 2;
}

function cells(line: string) {
  return line.trim().replace(/^\|/, "").replace(/\|$/, "").split("|").map((cell) => cell.trim());
}

/** **bold**, *italic* and `code`; everything else stays text. */
function inline(text: string): ReactNode {
  const parts = text.split(/(\*\*[^*]+\*\*|`[^`]+`|\*[^*\s][^*]*\*)/g);
  return parts.map((part, n) => {
    if (part.startsWith("**") && part.endsWith("**") && part.length > 4) return <strong key={n}>{part.slice(2, -2)}</strong>;
    if (part.startsWith("`") && part.endsWith("`") && part.length > 2)
      return (
        <code key={n} className="rounded bg-muted px-1 py-0.5 text-xs">
          {part.slice(1, -1)}
        </code>
      );
    if (part.startsWith("*") && part.endsWith("*") && part.length > 2) return <em key={n}>{part.slice(1, -1)}</em>;
    return <Fragment key={n}>{part}</Fragment>;
  });
}
