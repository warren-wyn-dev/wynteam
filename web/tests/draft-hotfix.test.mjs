import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import ts from "typescript";
function compile(path) {
  const source = readFileSync(new URL(path, import.meta.url), "utf8");
  const result = ts.transpileModule(source, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022,
  }, reportDiagnostics: true });
  assert.equal(result.diagnostics?.length ?? 0, 0);
  const mod = { exports: {} };
  new Function("module", "exports", result.outputText)(mod, mod.exports);
  return mod.exports;
}
const { saveDraft, loadDraftImageFile } = compile("../lib/drafts.ts");
const A = "11111111-1111-4111-8111-111111111111";
const B = "22222222-2222-4222-8222-222222222222";
function mock() {
  const uploads = [], downloads = [], rows = new Map();
  const prefix = "https://example.supabase.co/storage/v1/object/public/drop-images/";
  const bucket = {
    async upload(path, file, options) { uploads.push({ path, file, options }); return { error: null }; },
    getPublicUrl(path) { return { data: { publicUrl: prefix + path } }; },
    async download(path) { downloads.push(path); return { data: new Blob(["jpeg"], { type: "image/jpeg" }), error: null }; },
  };
  const client = {
    storage: { from() { return bucket; } },
    from(table) {
      assert.equal(table, "drop_drafts");
      return {
        insert(row) { return { select() { return { async single() { rows.set(row.id,row); return { data: { id:row.id },error:null }; } }; } }; },
        update(row) { return { eq(key,id) { assert.equal(key,"id"); return { select() { return { async single() { rows.set(id,{...rows.get(id),...row}); return { data:{id},error:null }; } }; } }; } }; },
      };
    },
  };
  return { client, uploads, downloads, rows, prefix };
}
test("first and repeated saves reuse the row UUID as object path", async () => {
  const {client,uploads,rows}=mock(),file=new File(["jpeg"],"camera.jpeg",{type:"image/jpeg"});
  const id=await saveDraft(client,A,{file,caption:"First"});
  assert.equal(uploads[0].path,A+"/drafts/"+id+".jpeg");
  assert.equal(rows.get(id).id,id);
  assert.equal(uploads[0].options.upsert,true);
  assert.equal(await saveDraft(client,A,{draftId:id,file,caption:"Updated"}),id);
  assert.equal(uploads[1].path,uploads[0].path);
  assert.equal(rows.size,1);
  assert.ok(new URL(rows.get(id).image_url).searchParams.has("v"));
});
test("reopened image draft is downloaded from the owner's directory",async()=>{
  const {client,downloads,prefix}=mock();
  const photo=await loadDraftImageFile(client,A,prefix+A+"/drafts/photo.jpeg?v=1");
  assert.equal(downloads[0],A+"/drafts/photo.jpeg");
  assert.equal(photo.type,"image/jpeg");
});
test("other-user drafts and arbitrary URLs cannot be downloaded",async()=>{
  const {client,downloads,prefix}=mock();
  await assert.rejects(loadDraftImageFile(client,A,prefix+B+"/drafts/other.jpeg"));
  await assert.rejects(loadDraftImageFile(client,A,"https://attacker.example/"+A+"/drafts/pic.jpeg"));
  await assert.rejects(loadDraftImageFile(client,A,prefix+A+"/drafts/..%2Fsecret.jpeg"));
  assert.equal(downloads.length,0);
});
