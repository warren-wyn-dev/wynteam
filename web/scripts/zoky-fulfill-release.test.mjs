import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';
import {validateManifest,validatePaths,validateDeployment} from './zoky-fulfill-release.mjs';
const draft=JSON.parse(readFileSync(new URL('./zoky-fulfill-release.json',import.meta.url)));
function valid(){const m=structuredClone(draft);m.migration.sha256='a'.repeat(64);m.migration.verifySha256='b'.repeat(64);for(const key of ['web','admin']){m.applications[key].candidateSha=(key==='web'?'c':'d').repeat(40);m.applications[key].approvedPaths=[key==='web'?'web/lib/food-customer.ts':'zoky-admin/lib/admin-food.ts'];}return m;}
test('draft pins fail closed and reviewed targets cannot be redirected',()=>{
 const unfinalized=structuredClone(draft);unfinalized.applications.web.candidateSha='';
 assert.throws(()=>validateManifest(unfinalized));validateManifest(valid(),'2026-10-26');
 for(const change of [m=>{m.teamId='foreign'},m=>{m.productionDatabaseRef='foreign'},m=>{m.applications.web.projectId='foreign'},m=>{m.applications.web.base='e'.repeat(40)},m=>{m.applications.admin.candidateSha=''},m=>{m.migration.sha256=''},m=>{m.applications.web.branch='main'}]){const m=valid();change(m);assert.throws(()=>validateManifest(m,'2026-10-26'));}
 assert.throws(()=>validateManifest(valid(),'2026-11-10'));
});
test('exact paths preserve frozen authentication/release boundaries and separate Admin',()=>{
 validatePaths('web',['web/lib/food-customer.ts'],['web/lib/food-customer.ts']);
 assert.throws(()=>validatePaths('web',['web/lib/food-customer.ts','web/app/unrelated.tsx'],['web/lib/food-customer.ts']));
 assert.throws(()=>validatePaths('web',['web/proxy.ts'],['web/proxy.ts']));
 assert.throws(()=>validatePaths('admin',['web/lib/food-customer.ts'],['web/lib/food-customer.ts']));
});
test('production artifact identity and staged alias status are mandatory',()=>{
 const m=valid(),deployment={projectId:m.applications.web.projectId,teamId:m.teamId,target:'production',readyState:'READY',meta:{githubCommitSha:m.applications.web.candidateSha},aliasAssigned:false};
 validateDeployment(m,'web',deployment,{staged:true});
 for(const patch of [{projectId:'foreign'},{teamId:'foreign'},{target:'preview'},{readyState:'ERROR'},{meta:{githubCommitSha:'e'.repeat(40)}},{aliasAssigned:true}])assert.throws(()=>validateDeployment(m,'web',{...deployment,...patch},{staged:true}));
});
