// Trusted release control: publish this file and its finalized manifest on main
// in an ops-only PR. Application code is checked out separately at reviewed SHAs.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const manifestFile = resolve(dirname(fileURLToPath(import.meta.url)), 'zoky-fulfill-release.json');
const SHA = /^[0-9a-f]{40}$/;
const HASH = /^[0-9a-f]{64}$/;
const TEAM = 'team_Kamt1PUT5XKn9MWrF404re1w';
const DB = 'kqokpocajhfbidcxpvhh';
const FIXED = {
  web: { base: '71f7fb0f95bd3495c3f9fbf733cbf697456bd58c', projectId: 'prj_bzoZIUdyxaRvXiSLG1uSfjDsyS5a', rootDirectory: 'web' },
  admin: { base: '8fab9b4b5a9c0b137184e398410234a72bd4b3de', projectId: 'prj_gcMdUScNHnaUOwDWmNn3QR4uP4oN', rootDirectory: 'zoky-admin' },
};
const FROZEN = [
  'web/proxy.ts', 'web/next.config.ts', 'web/app/auth', 'web/lib/supabase',
  '.github/scripts/require-wynos-final-release-ready.sh',
  '.github/workflows/wyn-158-production-deploy.yml',
  '.github/workflows/zoky-web-exception-release.yml',
  '.github/workflows/zoky-merchant-ui-release.yml',
  '.github/workflows/zoky-merchant-stability-release.yml',
  '.github/workflows/zoky-web-thai-mobile-release.yml',
  'tools/check_wynos_release_freeze.py', 'tools/check_production_secret_scoping.py',
];
function requireTrue(value, message) { assert.ok(value, message); }
export function validateManifest(manifest, today = new Date().toISOString().slice(0, 10)) {
  requireTrue(manifest.version === 1 && manifest.repository === 'warren-wyn-dev/wynteam', 'Wrong repository or manifest version');
  requireTrue(manifest.teamId === TEAM && manifest.productionDatabaseRef === DB, 'Unexpected production targets');
  requireTrue(manifest.expiresUtc === '2026-11-09' && today <= manifest.expiresUtc, 'Release expired');
  for (const name of ['web', 'admin']) {
    const app = manifest.applications[name], fixed = FIXED[name];
    for (const key of ['base', 'projectId', 'rootDirectory']) requireTrue(app[key] === fixed[key], `Wrong ${name} ${key}`);
    requireTrue(SHA.test(app.candidateSha) && app.candidateSha !== app.base, `Finalize ${name} candidate SHA`);
    requireTrue(typeof app.branch === 'string' && /^feat\/zoky-fulfill-001(?:-complete|-admin-complete)$/.test(app.branch), 'Unexpected source branch');
    requireTrue(app.branch === (name === 'web' ? 'feat/zoky-fulfill-001-complete' : 'feat/zoky-fulfill-001-admin-complete'), 'Wrong application branch');
    requireTrue(/^dpl_[A-Za-z0-9]+$/.test(app.previousDeployment), 'Missing recovery target');
    requireTrue(Array.isArray(app.approvedPaths) && app.approvedPaths.length > 0 && new Set(app.approvedPaths).size === app.approvedPaths.length, 'Finalize exact reviewed paths');
    requireTrue(app.approvedPaths.every(path => typeof path === 'string' && !path.split('/').some(part => ['', '.', '..'].includes(part))), 'Unsafe manifest path');
  }
  const migration = manifest.migration;
  requireTrue(migration.path === 'supabase/migrations/20261026115927_zoky_fulfillment_v1.sql' && HASH.test(migration.sha256), 'Finalize migration hash');
  requireTrue(migration.verifyPath === 'supabase/tests/zoky_fulfillment_verify.sql' && HASH.test(migration.verifySha256), 'Finalize verification hash');
}
function git(root, ...args) { return execFileSync('git', ['-C', root, ...args], { encoding: 'utf8' }).trim(); }
function fileHash(root, path) { return createHash('sha256').update(readFileSync(resolve(root, path))).digest('hex'); }
export function validatePaths(name, actual, approved) {
  assert.deepEqual([...actual].sort(), [...approved].sort(), 'Candidate differs from reviewed exact path manifest');
  for (const path of actual) {
    requireTrue(!FROZEN.some(prefix => path === prefix || path.startsWith(prefix + '/')), `Frozen boundary changed: ${path}`);
    if (name === 'admin') requireTrue(path.startsWith('zoky-admin/') || path.startsWith('docs/qa/zoky-fulfill-001/'), `Out-of-scope Admin path: ${path}`);
    else {
      const permitted = path.startsWith('web/') || path.startsWith('supabase/') || path.startsWith('.wyn/') || path.startsWith('docs/qa/zoky-fulfill-001/') || path === '.github/workflows/zoky-fulfill-release.yml';
      requireTrue(permitted, `Out-of-scope fulfillment path: ${path}`);
    }
  }
}
export function verifyCandidate(manifest, name, root, sha, branchTip) {
  const app = manifest.applications[name];
  requireTrue(sha === app.candidateSha && sha === branchTip, `Use reviewed ${name} SHA and unchanged branch tip`);
  requireTrue(git(root, 'rev-parse', 'HEAD') === sha, 'Candidate checkout mismatch');
  requireTrue(git(root, 'status', '--porcelain', '--untracked-files=no') === '', 'Dirty candidate');
  git(root, 'merge-base', '--is-ancestor', app.base, sha);
  const actual = git(root, 'diff', '--name-only', '--no-renames', app.base, sha).split('\n').filter(Boolean);
  validatePaths(name, actual, app.approvedPaths);
  for (const path of actual) {
    const tree = git(root, 'ls-tree', sha, '--', path);
    if (tree) requireTrue(/^(100644|100755) blob /.test(tree), `Symlink/submodule refused: ${path}`);
  }
  if (name === 'web') {
    requireTrue(fileHash(root, manifest.migration.path) === manifest.migration.sha256, 'Migration hash mismatch');
    requireTrue(fileHash(root, manifest.migration.verifyPath) === manifest.migration.verifySha256, 'Verification SQL hash mismatch');
  }
}
async function vercel(path, init = {}) {
  requireTrue(process.env.VERCEL_TOKEN, 'Missing Vercel credential in protected step');
  const response = await fetch(`https://api.vercel.com${path}${path.includes('?') ? '&' : '?'}teamId=${TEAM}`, { ...init, headers: { Authorization: `Bearer ${process.env.VERCEL_TOKEN}`, ...init.headers } });
  requireTrue(response.ok, `Vercel metadata request failed (${response.status})`);
  return response.json();
}
function shaOf(deployment) { return deployment.meta?.githubCommitSha ?? deployment.gitSource?.sha; }
export function validateDeployment(manifest, name, deployment, { staged = false } = {}) {
  const app = manifest.applications[name];
  requireTrue(deployment.projectId === app.projectId || deployment.project?.id === app.projectId, 'Unexpected deployment project');
  requireTrue(deployment.teamId === TEAM || deployment.team?.id === TEAM || deployment.ownerId === TEAM, 'Unexpected deployment owner');
  requireTrue(deployment.target === 'production' && deployment.readyState === 'READY', 'Deployment is not ready production artifact');
  requireTrue(shaOf(deployment) === app.candidateSha, 'Deployment source pin mismatch');
  if (staged) requireTrue(deployment.aliasAssigned === false, 'Staged deployment already owns aliases');
}
async function checkLive(manifest, name, expectedId) {
  const app = manifest.applications[name];
  for (const host of app.domains) {
    const live = await vercel(`/v13/deployments/${encodeURIComponent(host)}`);
    requireTrue(live.id === expectedId, `${host} changed from reviewed deployment; stop`);
    requireTrue(live.projectId === app.projectId || live.project?.id === app.projectId, 'Domain project mismatch');
  }
}
function deploymentUrl(raw) {
  const url = new URL(raw);
  requireTrue(url.protocol === 'https:' && /^[a-z0-9-]+\.vercel\.app$/.test(url.hostname) && url.origin === raw, 'Invalid immutable deployment URL');
  return url;
}
async function sql(manifest, query, staging = false) {
  const token = staging ? process.env.STAGING_SUPABASE_ACCESS_TOKEN : process.env.SUPABASE_ACCESS_TOKEN;
  const ref = staging ? process.env.STAGING_SUPABASE_PROJECT_REF : manifest.productionDatabaseRef;
  requireTrue(token && /^[a-z0-9]{20}$/.test(ref), 'Missing database credentials or project ref in protected step');
  if (staging) requireTrue(ref !== DB, 'Staging must never target production');
  else {
    const url = new URL(process.env.SUPABASE_URL?.trim());
    requireTrue(url.protocol === 'https:' && url.hostname === `${DB}.supabase.co`, 'Unexpected database project');
  }
  const response = await fetch(`https://api.supabase.com/v1/projects/${ref}/database/query`, {
    method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }, body: JSON.stringify({ query }),
  });
  // Do not print response bodies: a database error can contain private context.
  requireTrue(response.ok, `Database apply/verify failed (${response.status}); inspect protected database tooling`);
  return response.json();
}
async function main() {
  const [command, name] = process.argv.slice(2);
  const manifest = JSON.parse(readFileSync(manifestFile, 'utf8'));
  validateManifest(manifest);
  requireTrue(['web', 'admin'].includes(name), 'Use application web or admin');
  const app = manifest.applications[name];
  if (command === 'guard') {
    const root = resolve(process.argv[4]);
    const sha = process.env.CANDIDATE_SHA;
    const tip = git(root, 'ls-remote', 'origin', `refs/heads/${app.branch}`).split(/\s/)[0];
    verifyCandidate(manifest, name, root, sha, tip);
    console.log(`PASS reviewed ${name} candidate ${sha}`);
  } else if (command === 'current') {
    const project = await vercel(`/v9/projects/${app.projectId}`);
    requireTrue(project.id === app.projectId && (project.rootDirectory ?? '') === app.rootDirectory, 'Project/rootDirectory mismatch');
    await checkLive(manifest, name, app.previousDeployment);
    console.log(`PASS current ${name} deployment remains the reviewed recovery target`);
  } else if (command === 'apply' || command === 'staging-apply') {
    requireTrue(name === 'web', 'Only the web release applies the migration');
    const staging = command === 'staging-apply';
    if (staging) {
      const isolation = await fetch('https://api.supabase.com/v1/projects', { headers: { Authorization: `Bearer ${process.env.STAGING_SUPABASE_ACCESS_TOKEN}` } });
      requireTrue(isolation.ok, 'Staging account isolation check failed');
      const projects = await isolation.json();
      requireTrue(Array.isArray(projects) && !projects.some(project => project.id === DB) && projects.some(project => project.id === process.env.STAGING_SUPABASE_PROJECT_REF), 'Staging credential must see staging and cannot see production');
    }
    const root = resolve(process.argv[4]);
    requireTrue(fileHash(root, manifest.migration.path) === manifest.migration.sha256, 'Migration hash mismatch');
    requireTrue(fileHash(root, manifest.migration.verifyPath) === manifest.migration.verifySha256, 'Verification hash mismatch');
    const verify = readFileSync(resolve(root, manifest.migration.verifyPath), 'utf8');
    // Retry does not reapply a non-idempotent migration after a lost HTTP response.
    const existing = await sql(manifest, verify, staging);
    if (!(Array.isArray(existing) && existing[0]?.schema_ok === true)) await sql(manifest, readFileSync(resolve(root, manifest.migration.path), 'utf8'), staging);
    const result = await sql(manifest, verify, staging);
    requireTrue(Array.isArray(result) && result[0]?.schema_ok === true, 'Post-migration catalog verification failed');
    console.log('PASS fulfillment catalog verification; no row data printed');
  } else if (['staged', 'promoted'].includes(command)) {
    const url = deploymentUrl(process.env.DEPLOYMENT_URL);
    const deployment = await vercel(`/v13/deployments/${url.hostname}`);
    validateDeployment(manifest, name, deployment, { staged: command === 'staged' });
    if (command === 'staged') {
      await checkLive(manifest, name, app.previousDeployment);
      console.log(`id=${deployment.id}`);
      console.log(`url=${url.origin}`);
    } else {
      await checkLive(manifest, name, deployment.id);
      console.log(`PASS ${name} production aliases and source pin`);
    }
  } else throw new Error('Unknown release control command');
}
if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) main().catch(error => { console.error(error.message); process.exitCode = 1; });
