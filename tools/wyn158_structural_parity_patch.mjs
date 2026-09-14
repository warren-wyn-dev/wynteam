import { readFileSync, writeFileSync } from "node:fs";

function replaceOnce(source, oldText, newText, label) {
  const first = source.indexOf(oldText);
  if (first < 0) throw new Error(`Missing patch target: ${label}`);
  if (source.indexOf(oldText, first + oldText.length) >= 0) throw new Error(`Ambiguous patch target: ${label}`);
  return source.slice(0, first) + newText + source.slice(first + oldText.length);
}

const homePath = "web/components/parity-home-final.tsx";
let home = readFileSync(homePath, "utf8");
home = replaceOnce(
  home,
  'import { RichPostText } from "@/components/rich-post-text";\n',
  'import { Beta4Composer } from "@/components/beta4-composer";\nimport { RichPostText } from "@/components/rich-post-text";\n',
  "composer import",
);
const composerStart = home.indexOf("function Composer({");
const homeExport = home.indexOf("export function ParityHomeFinal", composerStart);
if (composerStart < 0 || homeExport < 0) throw new Error("Composer function markers missing");
home = home.slice(0, composerStart) + home.slice(homeExport);
home = replaceOnce(home, "        <Composer\n", "        <Beta4Composer\n", "composer usage");
writeFileSync(homePath, home);

const publicationPath = "web/lib/drop-publication.ts";
let publication = readFileSync(publicationPath, "utf8");
publication = replaceOnce(
  publication,
  'type PublishInput = {\n  caption: string;\n  files: File[];\n  operationId?: string | null;\n};',
  'type PublishInput = {\n  caption: string;\n  files: File[];\n  operationId?: string | null;\n  audience?: "everyone" | "friends" | "friends_except" | "close_friends" | "only_me";\n  excludedFriendIds?: string[];\n};',
  "PublishInput audience",
);
publication = replaceOnce(
  publication,
  '      p_audience: "everyone",\n      p_excluded_friend_ids: [],',
  '      p_audience: input.audience ?? "everyone",\n      p_excluded_friend_ids: input.excludedFriendIds ?? [],',
  "publish audience params",
);
writeFileSync(publicationPath, publication);

console.log("WYN-158 structural parity patch applied");
