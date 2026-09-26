import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import ts from "typescript";

const source = readFileSync(new URL("../lib/google-pwa-oauth.ts", import.meta.url), "utf8");
const compiled = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const compiledModule = { exports: {} };
new Function("module", "exports", "process", compiled)(compiledModule, compiledModule.exports, process);
const { isInstalledIosWebApp, startGoogleOAuth, consumeGooglePwaPopupMarker, announceGooglePwaCompletion, GOOGLE_PWA_POPUP_MARKER } = compiledModule.exports;
const AUTH_URL = "https://test.supabase.co/auth/v1/authorize?provider=google";

function setup({ installed = true, blocked = false } = {}) {
  const previous = { window: globalThis.window, navigator: globalThis.navigator, BroadcastChannel: globalThis.BroadcastChannel };
  const storage = new Map();
  const calls = [];
  const popup = {
    sessionStorage: {
      setItem: (k,v) => storage.set(k,v),
      getItem: (k) => storage.get(k) ?? null,
      removeItem: (k) => storage.delete(k),
    },
    document: { title: "", body: { textContent: "" } },
    location: { replace: (url) => calls.push(["navigate-popup",url]) },
    close: () => calls.push(["close-popup"]),
  };
  globalThis.window = {
    location: { origin: "https://wynos.online" },
    matchMedia: () => ({ matches: installed }),
    open: (url,target) => { calls.push(["open",url,target]); return blocked ? null : popup; },
    sessionStorage: popup.sessionStorage,
    opener: { postMessage: (message,origin) => calls.push(["opener",message,origin]) },
  };
  Object.defineProperty(globalThis, "navigator", { configurable: true, value: {
    userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X)",
    maxTouchPoints: 5, standalone: installed,
  } });
  const channels = [];
  globalThis.BroadcastChannel = class {
    constructor(name) { this.name=name; channels.push(this); }
    postMessage(message) { calls.push(["broadcast",message]); }
    close() { calls.push(["close-channel"]); }
  };
  process.env.NEXT_PUBLIC_SUPABASE_URL = "https://test.supabase.co";
  const restore = () => {
    globalThis.window = previous.window;
    if (previous.navigator === undefined) delete globalThis.navigator;
    else Object.defineProperty(globalThis, "navigator", { configurable: true, value: previous.navigator });
    globalThis.BroadcastChannel = previous.BroadcastChannel;
  };
  return { popup,storage,calls,channels,restore };
}

test("installed iOS opens SAME-app window synchronously before asynchronous OAuth and stays on allowed callback",async()=>{
  const f=setup();try{
    assert.equal(isInstalledIosWebApp(),true);
    const client={auth:{signInWithOAuth:async({provider,options})=>{
      f.calls.push(["sign-in",provider,options]);
      return {data:{url:AUTH_URL},error:null};
    }}};
    const pending=startGoogleOAuth(client,"https://wynos.online/welcome");
    assert.deepEqual(f.calls[0],["open","about:blank","_blank"]);
    const result=await pending;
    assert.equal(result.started,true);
    const signin=f.calls.find(x=>x[0]==="sign-in");
    assert.equal(signin[2].skipBrowserRedirect,true);
    assert.equal(signin[2].redirectTo,"https://wynos.online/auth/callback");
    assert.equal(f.calls.find(x=>x[0]==="navigate-popup")[1],AUTH_URL);
    assert.ok(Number(f.storage.get(GOOGLE_PWA_POPUP_MARKER))>0);
    assert.equal(consumeGooglePwaPopupMarker(),true);
    assert.equal(consumeGooglePwaPopupMarker(),false);
  }finally{f.restore();}
});

test("normal Safari preserves existing OAuth redirect rather than opening popup",async()=>{
 const f=setup({installed:false});try{
   const client={auth:{signInWithOAuth:async({options})=>{
     f.calls.push(["oauth",options]);return {data:{url:AUTH_URL},error:null};
   }}};
   const result=await startGoogleOAuth(client,"https://wynos.online/welcome");
   assert.equal(result.started,true);
   assert.equal(f.calls.some(x=>x[0]==="open"),false);
   assert.equal(f.calls[0][1].redirectTo,"https://wynos.online/welcome");
   assert.equal(f.calls[0][1].skipBrowserRedirect,undefined);
 }finally{f.restore();}
});

test("popup blocking does not fall back into Safari or call Google OAuth",async()=>{
 const f=setup({blocked:true});try{
   const client={auth:{signInWithOAuth:()=>{throw Error("Must not start external OAuth");}}};
   const result=await startGoogleOAuth(client,"https://wynos.online/welcome");
   assert.equal(result.started,false);
   assert.match(result.error,/บล็อก/);
   assert.equal(f.calls.length,1);
 }finally{f.restore();}
});

test("rejects unexpected OAuth host and safely closes the popup",async()=>{
 const f=setup();try{
   const client={auth:{signInWithOAuth:async()=>({data:{url:"https://example.evil/steal"},error:null})}};
   const result=await startGoogleOAuth(client,"https://wynos.online/welcome");
   assert.equal(result.started,false);
   assert.equal(f.calls.some(x=>x[0]==="navigate-popup"),false);
   assert.ok(f.calls.some(x=>x[0]==="close-popup"));
 }finally{f.restore();}
});

test("success signal contains no tokens and the popup marker expires",()=>{
 const f=setup();try{
   f.storage.set(GOOGLE_PWA_POPUP_MARKER,String(Date.now()-11*60*1000));
   assert.equal(consumeGooglePwaPopupMarker(),false);
   announceGooglePwaCompletion();
   assert.deepEqual(f.calls.find(x=>x[0]==="broadcast")[1],{type:"google-oauth-verified"});
   assert.deepEqual(f.calls.find(x=>x[0]==="opener")[1],{type:"google-oauth-verified"});
 }finally{f.restore();}
});


test("Add Account iOS popup targets the isolated same-origin auth callback",async()=>{
  const f=setup();try{
    const client={auth:{signInWithOAuth:async({options})=>{
      f.calls.push(["oauth",options]);
      return {data:{url:AUTH_URL},error:null};
    }}};
    const target="https://wynos.online/auth/callback?slot=wynos.account.12345678&popupAdd=1";
    const result=await startGoogleOAuth(client,"https://wynos.online/account/add",target);
    assert.equal(result.started,true);
    assert.equal(f.calls.find(x=>x[0]==="oauth")[1].redirectTo,target);
    assert.equal(f.calls.find(x=>x[0]==="oauth")[1].skipBrowserRedirect,true);
  }finally{f.restore();}
});

test("Add Account popup rejects a callback outside WYNOS before sending OAuth",async()=>{
  const f=setup();try{
    const client={auth:{signInWithOAuth:async()=>{throw Error("OAuth must not be called");}}};
    const result=await startGoogleOAuth(client,"https://wynos.online/account/add","https://malicious.example/auth/callback");
    assert.equal(result.started,false);
    assert.equal(f.calls.some(x=>x[0]==="close-popup"),true);
    assert.equal(f.calls.some(x=>x[0]==="navigate-popup"),false);
  }finally{f.restore();}
});
