import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import ts from "typescript";
const source=readFileSync(new URL("../lib/phase3-data.ts",import.meta.url),"utf8");
const output=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022},reportDiagnostics:true});
assert.equal(output.diagnostics?.length??0,0);
const mod={exports:{}};
// Resolve the app's own "@/lib/*" runtime imports (e.g. upload-image).
function requireLib(name){
  if(!name.startsWith("@/lib/"))throw new Error("Unexpected import "+name);
  const src=readFileSync(new URL("../lib/"+name.slice(6)+".ts",import.meta.url),"utf8");
  const out=ts.transpileModule(src,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
  const m={exports:{}};new Function("module","exports","require",out)(m,m.exports,requireLib);return m.exports;
}
new Function("module","exports","require",output.outputText)(mod,mod.exports,requireLib);
const row={id:"98000000-0000-0000-0000-0000000000c1",name:"Public club",privacy:"public",cover_url:null,icon_url:null,created_at:"2026-09-24T00:00:00Z"};
const client={
  from(){return{select(){return{
    eq(){return{async maybeSingle(){return{data:row,error:null}}}},
    ilike(){return{order(){return{async range(){return{data:[row],error:null}}}}}}
  }}}},
  async rpc(){return {data:null,error:{message:"PGRST202 club_member_counts missing"}}},
  storage:{from(){throw Error("no media expected")}}
};
test("single-club RPC errors are not displayed as zero members",async()=>{
  await assert.rejects(mod.exports.fetchClub(client,row.id),/PGRST202/);
});
test("club-list RPC errors are not displayed as zero members",async()=>{
  await assert.rejects(mod.exports.searchClubs(client,"Public"),/PGRST202/);
});
