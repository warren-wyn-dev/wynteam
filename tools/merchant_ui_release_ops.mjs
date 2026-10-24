// Runs only behind the existing production environment reviewer. Never logs
// API response bodies or credentials; only fixed release metadata is returned.
import { readFile } from 'node:fs/promises';

const manifest = JSON.parse(await readFile(new URL('../.wyn/docs/deployment/zoky-merchant-ui-release.json', import.meta.url), 'utf8'));
const token = process.env.VERCEL_TOKEN;
if (!token) throw new Error('Vercel authentication unavailable');
const command = process.argv[2];
const candidateUrl = process.env.MERCHANT_DEPLOYMENT_URL;
const expectedAliases = ['wynos.online','geo.wynos.online','www.wynos.online','food.wynos.online','maps.wynos.online','zoky.wynos.online','tiles.wynos.online','routing.wynos.online','merchant.wynos.online','web-warren14.vercel.app'];
const require = (value, message) => { if (!value) throw new Error(message); };
async function deployment(id) {
  const response = await fetch(`https://api.vercel.com/v13/deployments/${encodeURIComponent(id)}?teamId=${manifest.teamId}`, {
    headers: { authorization: `Bearer ${token}` }, signal: AbortSignal.timeout(30000),
  });
  require(response.ok, `Deployment inspection rejected (${response.status})`);
  return response.json();
}
async function uploadRoot() {
  const response = await fetch(`https://api.vercel.com/v9/projects/${manifest.projectId}?teamId=${manifest.teamId}`, {
    headers: {authorization:`Bearer ${token}`}, signal:AbortSignal.timeout(30000),
  });
  require(response.ok, `Project metadata inspection rejected (${response.status})`);
  const project = await response.json();
  require(project.id === manifest.projectId && project.name === 'web', 'Unexpected upload project');
  // No environment endpoint, decryption, or configuration mutation is used.
  // A monorepo root is applied by Vercel after upload, so upload its parent.
  require(project.rootDirectory == null || project.rootDirectory === '' || project.rootDirectory === 'web', 'Unsupported project root directory');
  return project.rootDirectory === 'web' ? '..' : '.';
}
function target(d, sha) {
  require(d.projectId === manifest.projectId || d.project?.id === manifest.projectId, 'Wrong Vercel project');
  require(d.target === 'production' && d.readyState === 'READY', 'Artifact must be READY production');
  require((d.gitSource?.sha ?? d.meta?.githubCommitSha) === sha, 'Deployment source differs from reviewed SHA');
}
function artifactUrl() {
  require(/^https:\/\/web-[a-z0-9]+-warren14\.vercel\.app$/.test(candidateUrl ?? ''), 'Invalid staged artifact URL');
  return new URL(candidateUrl).hostname;
}
async function foodUnchanged() {
  const r = await fetch('https://food.wynos.online/', {redirect:'manual',signal:AbortSignal.timeout(30000)});
  require(r.status === 200 && !r.headers.has('location'), 'Live Food phase changed; rebase and review the release');
}
if (command === 'upload-root') {
  console.log(await uploadRoot());
} else if (command === 'current') {
  const d = await deployment('merchant.wynos.online');
  target(d, manifest.productionBase);
  require(d.id === manifest.rollbackDeployment, 'Live deployment changed while awaiting review');
  require(expectedAliases.every(alias => d.alias?.includes(alias)) && d.alias.length === expectedAliases.length, 'Production aliases changed');
  await foodUnchanged();
  console.log(`PASS current production ${d.id} / ${manifest.productionBase}`);
} else if (command === 'staged') {
  const d = await deployment(artifactUrl());
  target(d, manifest.releaseSha);
  require(!d.alias?.some(alias => expectedAliases.includes(alias)), 'Staging unexpectedly assigned production domains');
  console.log(`PASS staged production ${d.id} / ${manifest.releaseSha}`);
} else if (command === 'promoted') {
  const staged = await deployment(artifactUrl());
  const live = await deployment('merchant.wynos.online');
  target(live, manifest.releaseSha);
  require(live.id === staged.id, 'Production is not the tested artifact');
  require(expectedAliases.every(alias => live.alias?.includes(alias)), 'Production aliases were not preserved');
  await foodUnchanged();
  console.log(`PASS promoted production ${live.id} / ${manifest.releaseSha}`);
} else {
  throw new Error('Unknown release inspection');
}
