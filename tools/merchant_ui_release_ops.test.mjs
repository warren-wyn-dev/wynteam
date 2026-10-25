import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

const manifest = JSON.parse(readFileSync(new URL('../.wyn/docs/deployment/zoky-merchant-ui-release.json', import.meta.url), 'utf8'));
const customerAliases = ['wynos.online','geo.wynos.online','www.wynos.online','food.wynos.online','maps.wynos.online','zoky.wynos.online','tiles.wynos.online','routing.wynos.online','merchant.wynos.online'];
const generatedAlias = 'web-warren14.vercel.app';
const aliases = [...customerAliases, generatedAlias];
function artifact(current = true) {
  return {id:current ? manifest.rollbackDeployment : manifest.stagedDeploymentId,projectId:manifest.projectId,
    target:'production',readyState:'READY',meta:{githubCommitSha:current ? manifest.productionBase : manifest.releaseSha},alias:current ? aliases : [generatedAlias]};
}
function aliasResponses(d = artifact(), names = customerAliases) {
  return names.map(alias => ({id:alias,body:structuredClone(d)}));
}
function currentResponses(d = artifact()) {
  return [{id:'merchant.wynos.online',body:d},...aliasResponses(),{food:true,status:200}];
}
function stagedResponses(d = artifact(false)) {
  return [{id:new URL(manifest.stagedUrl).hostname,body:d},...aliasResponses()];
}
function promotedResponses() {
  const d={...artifact(false),alias:aliases};
  return [{id:new URL(manifest.stagedUrl).hostname,body:artifact(false)},{id:'merchant.wynos.online',body:d},...aliasResponses(d,aliases),{food:true,status:200}];
}
function inspect(command, responses, url = manifest.stagedUrl) {
  const source = `
    process.env.VERCEL_TOKEN='synthetic-not-a-credential';
    process.env.MERCHANT_DEPLOYMENT_URL=${JSON.stringify(url)};
    process.argv[2]=${JSON.stringify(command)};
    const responses=${JSON.stringify(responses)};
    globalThis.fetch=async value=>{
      const url=new URL(value),item=responses.shift();
      if(!item)throw new Error('Unexpected request');
      if(item.food){if(url.hostname!=='food.wynos.online')throw new Error('Wrong public phase target');}
      else {
        if(url.hostname!=='api.vercel.com'||decodeURIComponent(url.pathname.split('/').at(-1))!==item.id)throw new Error('Wrong inspection target');
        if(url.searchParams.get('teamId')!==${JSON.stringify(manifest.teamId)})throw new Error('Wrong team');
      }
      return new Response(JSON.stringify(item.body??{}),{status:item.status??200,headers:item.headers??{}});
    };
    await import(${JSON.stringify(new URL('./merchant_ui_release_ops.mjs', import.meta.url).href)});
    if(responses.length)throw new Error('Expected requests were skipped');
  `;
  return spawnSync(process.execPath, ['--input-type=module','-e',source], {encoding:'utf8'});
}

test('current inspects every customer hostname rather than stale alias metadata', () => {
  const result=inspect('current',currentResponses());
  assert.equal(result.status,0,result.stderr);
  for(const mutation of [d=>{d.id='dpl_newer';},d=>{d.projectId='prj_other';},d=>{d.target='preview';},
    d=>{d.readyState='BUILDING';},d=>{d.meta.githubCommitSha='b'.repeat(40);},d=>{d.alias=['unknown.test'];}]) {
    const d=artifact();mutation(d);
    assert.notEqual(inspect('current',currentResponses(d)).status,0);
  }
  for(let i=0;i<customerAliases.length;i++) {
    const responses=currentResponses();
    responses[1+i].body.id='dpl_moved';
    // The primary deployment still claims all aliases: the resolution must win.
    assert.notEqual(inspect('current',responses).status,0,customerAliases[i]);
  }
  const responses=currentResponses();responses.at(-1).status=307;responses.at(-1).headers={location:'https://zoky.wynos.online/'};
  assert.notEqual(inspect('current',responses).status,0);
});

test('staging allows only the known generated alias while customer domains remain old', () => {
  for(const allowed of [[],[generatedAlias]]) {
    const d=artifact(false);d.alias=allowed;
    const result=inspect('staged',stagedResponses(d));
    assert.equal(result.status,0,result.stderr);
  }
  for(const forbidden of [[customerAliases[0]],['unknown.vercel.app'],['unexpected.test'],[generatedAlias,'unknown.vercel.app']]) {
    const d=artifact(false);d.alias=forbidden;
    assert.notEqual(inspect('staged',stagedResponses(d)).status,0);
  }
  for(let i=0;i<customerAliases.length;i++) {
    const responses=stagedResponses();responses[1+i].body=artifact(false);
    assert.notEqual(inspect('staged',responses).status,0,customerAliases[i]);
  }
});

test('staging rejects another project, source, ID, state and any unpinned URL', () => {
  for(const mutation of [d=>{d.target='preview';},d=>{d.projectId='prj_wrong';},d=>{d.meta.githubCommitSha='c'.repeat(40);},d=>{d.id='dpl_other';},d=>{d.readyState='BUILDING';}]) {
    const d=artifact(false);mutation(d);
    assert.notEqual(inspect('staged',stagedResponses(d)).status,0);
  }
  for(const url of ['https://evil.test','https://web-other-warren14.vercel.app',manifest.stagedUrl+'/path',manifest.stagedUrl.replace('https:','http:')]) {
    assert.notEqual(inspect('staged',stagedResponses(),url).status,0);
  }
});

test('resume emits only the manifest URL after inspecting the exact existing artifact', () => {
  const result=inspect('resume-url',stagedResponses());
  assert.equal(result.status,0,result.stderr);
  assert.equal(result.stdout.trim(),manifest.stagedUrl);
  const d=artifact(false);d.id='dpl_rebuilt_same_sha';
  assert.notEqual(inspect('resume-url',stagedResponses(d)).status,0);
});

test('promotion resolves all customer and generated aliases to the exact tested ID', () => {
  const result=inspect('promoted',promotedResponses());
  assert.equal(result.status,0,result.stderr);
  for(let i=0;i<aliases.length;i++) {
    const responses=promotedResponses();responses[2+i].body.id='dpl_not_promoted';
    assert.notEqual(inspect('promoted',responses).status,0,aliases[i]);
  }
  const responses=promotedResponses();responses[0].body.id='dpl_other';
  assert.notEqual(inspect('promoted',responses).status,0);
});
