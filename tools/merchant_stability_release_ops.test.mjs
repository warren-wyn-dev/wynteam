import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { inspectStabilityRelease } from './merchant_stability_release_ops.mjs';

const m = { ...JSON.parse(readFileSync(new URL('../.wyn/docs/deployment/zoky-merchant-stability-release.json', import.meta.url), 'utf8')), releaseSha:'a'.repeat(40) };
const names = ['wynos.online','geo.wynos.online','www.wynos.online','food.wynos.online','maps.wynos.online','zoky.wynos.online','tiles.wynos.online','routing.wynos.online','merchant.wynos.online'];
const generated = 'web-warren14.vercel.app', url = 'https://web-fixture-warren14.vercel.app', id = 'dpl_tested';
const artifact = (old=false) => ({ id:old?m.rollbackDeployment:id, url:old?'web-old-warren14.vercel.app':new URL(url).hostname, projectId:m.projectId, target:'production', readyState:'READY', meta:{githubCommitSha:old?m.productionBase:m.releaseSha}, alias:old?[...names,generated]:[generated] });
const resolutions = (old=true, all=false) => (all?[...names,generated]:names).map(name=>({name,body:artifact(old)}));
const food = () => ({food:true,status:200});
const current = () => [{name:'merchant.wynos.online',body:artifact(true)},...resolutions(),food()];
const staged = () => [{name:new URL(url).hostname,body:artifact()},...resolutions(),food()];
const promoted = () => [{name:new URL(url).hostname,body:{...artifact(),alias:[...names,generated]}},...resolutions(false,true),food()];
async function inspect(command, responses, options={}) {
  const output = await inspectStabilityRelease({manifest:m,command,candidateUrl:url,expectedId:id,token:'synthetic-not-a-credential',...options,
    fetch:async value=>{
      const u = new URL(value), item = responses.shift(); assert.ok(item, 'Unexpected request');
      if(item.food) assert.equal(u.href,'https://food.wynos.online/');
      else { assert.equal(u.hostname,'api.vercel.com'); assert.equal(decodeURIComponent(u.pathname.split('/').at(-1)),item.name); assert.equal(u.searchParams.get('teamId'),m.teamId); }
      return new Response(JSON.stringify(item.body??{}),{status:item.status??200,headers:item.headers??{}});
    }});
  assert.equal(responses.length,0,'Inspection skipped expected routing checks');
  return output;
}

test('current resolves every customer alias despite stale alias arrays',async()=>{
  assert.match(await inspect('current',current()),/PASS current/);
  for(let i=0;i<names.length;i++){
    const r=current(); r[1+i].body.id='dpl_changed';
    await assert.rejects(inspect('current',r),/hostname moved/,names[i]);
  }
  const r=current(); r.at(-1).status=307; r.at(-1).headers={location:'https://zoky.wynos.online/'};
  await assert.rejects(inspect('current',r),/Food phase/);
});

test('stage outputs only the inspected immutable pair and permits only the generated alias',async()=>{
  assert.equal(await inspect('staged-output',staged()),`url=${url}\nid=${id}`);
  for(const aliases of [[],[generated]]) {const r=staged();r[0].body.alias=aliases;assert.match(await inspect('staged',r),/PASS inspected/);}
  for(const aliases of [[names[0]],['other.vercel.app'],[generated,'unknown.test']]){
    const r=staged(); r[0].body.alias=aliases;await assert.rejects(inspect('staged',r),/alias/);
  }
  for(let i=0;i<names.length;i++){const r=staged();r[1+i].body=artifact();await assert.rejects(inspect('staged',r),/source|hostname/,names[i]);}
});

test('promotion cannot substitute a same-source artifact or another project/state/URL',async()=>{
  for(const mutation of [d=>d.id='dpl_rebuilt',d=>d.projectId='prj_other',d=>d.target='preview',d=>d.readyState='BUILDING',d=>d.meta.githubCommitSha='b'.repeat(40),d=>d.url='alias.vercel.app']){
    const r=staged();mutation(r[0].body);await assert.rejects(inspect('staged',r));
  }
  for(const candidateUrl of ['https://evil.test',url+'/path',url+'?x=1',url.replace('https:','http:'),'https://web-warren14.vercel.app'])await assert.rejects(inspect('staged',[],{candidateUrl}),/artifact URL/);
  await assert.rejects(inspect('staged',staged(),{expectedId:undefined}),/stage ID/);
});

test('all customer and generated aliases must resolve to the exact tested artifact after promotion',async()=>{
  assert.match(await inspect('promoted',promoted()),/PASS promoted/);
  for(let i=0;i<names.length+1;i++){const r=promoted();r[1+i].body.id='dpl_old';await assert.rejects(inspect('promoted',r),/hostname moved/);}
});

test('upload uses only the existing known root metadata and unfinalized pins reject before network',async()=>{
  for(const rootDirectory of [null,'','web']) assert.equal(await inspect('upload-root',[{name:m.projectId,body:{id:m.projectId,name:'web',rootDirectory}}]),rootDirectory==='web'?'..':'.');
  await assert.rejects(inspect('upload-root',[{name:m.projectId,body:{id:m.projectId,name:'web',rootDirectory:'admin'}}]),/root directory/);
  await assert.rejects(inspect('current',[],{manifest:{...m,releaseSha:'0'.repeat(40)}}),/Unfinalized/);
  await assert.rejects(inspect('current',[],{token:undefined}),/authentication/);
});
