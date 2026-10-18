#!/usr/bin/env python3
"""Regression test: the secret-scoping gate rejects workflows that read a
production credential outside the `production` environment. Runs the real
gate against a temporary copy, never modifying the repository."""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GATE = "tools/check_production_secret_scoping.py"
WF = ".github/workflows"


def run_gate(mutate=None):
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        (tmp / "tools").mkdir()
        shutil.copy(ROOT / GATE, tmp / GATE)
        shutil.copytree(ROOT / WF, tmp / WF)
        if mutate:
            mutate(tmp / WF)
        result = subprocess.run([sys.executable, "-I", str(tmp / GATE)], capture_output=True, text=True)
        return result.returncode, result.stdout + result.stderr


def edit(name, old, new):
    def mutate(wf):
        path = wf / name
        text = path.read_text()
        assert old in text, f"test fixture drift: {old!r} not in {name}"
        path.write_text(text.replace(old, new, 1))
    return mutate


def add(name, content):
    return lambda wf: (wf / name).write_text(content)


NEW_JOB = "name: x\non:\n  workflow_dispatch:\njobs:\n  apply:\n    runs-on: ubuntu-latest\n    steps:\n      - env:\n          T: ${{ secrets.%s }}\n        run: echo ok\n"

code, out = run_gate()
assert code == 0, out

cases = {
    "environment removed from DB apply job": edit("storage-upload-validator.yml", "    environment: production\n", ""),
    "environment removed from prod deploy job": edit("wyn-158-production-deploy.yml", "    environment: production\n", ""),
    "environment commented out": edit("deploy-edge-functions.yml", "    environment: production\n", "    # environment: production\n"),
    "environment set to preview": edit("web-next-phase5-preview.yml", "    environment: production\n", "    environment: preview\n"),
    "new ungated Supabase token job": add("new-apply.yml", NEW_JOB % "SUPABASE_ACCESS_TOKEN"),
    "new ungated Vercel token job": add("new-deploy.yml", NEW_JOB % "VERCEL_TOKEN"),
    "4-space-indented jobs, ungated": add("indent4.yml", "name: x\non:\n  workflow_dispatch:\njobs:\n    apply:\n      runs-on: ubuntu-latest\n      steps:\n        - env:\n            T: ${{ secrets.SUPABASE_ACCESS_TOKEN }}\n          run: echo ok\n"),
    "job key with trailing comment after a gated job": add("comment-key.yml", "name: x\non:\n  workflow_dispatch:\njobs:\n  ok:\n    environment: production\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo ok\n  evil: # x\n    runs-on: ubuntu-latest\n    steps:\n      - env:\n          T: ${{ secrets.VERCEL_TOKEN }}\n        run: echo ok\n"),
    "quoted job key after a gated job": add("quoted-key.yml", "name: x\non:\n  workflow_dispatch:\njobs:\n  ok:\n    environment: production\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo ok\n  'evil':\n    runs-on: ubuntu-latest\n    steps:\n      - env:\n          T: ${{ secrets.VERCEL_TOKEN }}\n        run: echo ok\n"),
    "credential in a top-level key after jobs": add("after-jobs.yml", "name: x\non:\n  workflow_dispatch:\njobs:\n  ok:\n    environment: production\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo ok\nenv:\n  T: ${{ secrets.VERCEL_TOKEN }}\n"),
    "lowercase secret name, ungated": add("lower.yml", NEW_JOB % "vercel_token"),
    "index-syntax secret name, ungated": add("index.yml", (NEW_JOB % "X").replace("secrets.X", "secrets['SUPABASE_ACCESS_TOKEN']")),
    "whitespace before secret index, ungated": add("ws.yml", (NEW_JOB % "X").replace("secrets.X", "secrets [ 'VERCEL_TOKEN' ]")),
    "anchored ungated job after a gated job": add("anchor.yml", "name: x\non:\n  workflow_dispatch:\njobs:\n  ok:\n    environment: production\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo ok\n  evil: &ungated\n    runs-on: ubuntu-latest\n    steps:\n      - env:\n          T: ${{ secrets.VERCEL_TOKEN }}\n        run: echo ok\n"),
    "alias reuses gated steps in an ungated job": add("alias.yml", "name: x\non:\n  workflow_dispatch:\njobs:\n  ok:\n    environment: production\n    runs-on: ubuntu-latest\n    steps: &s\n      - env:\n          T: ${{ secrets.VERCEL_TOKEN }}\n        run: echo ok\n  evil:\n    runs-on: ubuntu-latest\n    steps: *s\n"),
    "format()-built secret name, ungated": add("fmt.yml", (NEW_JOB % "X").replace("secrets.X", "secrets[format('{0}_{1}', 'VERCEL', 'TOKEN')]")),
    "whole secrets context, ungated": add("tojson.yml", (NEW_JOB % "X").replace("secrets.X", "toJSON(secrets)")),
    "secrets: inherit to a reusable workflow, ungated": add("inherit.yml", "name: x\non:\n  workflow_dispatch:\njobs:\n  call:\n    uses: ./.github/workflows/deploy-web.yml\n    secrets: inherit\n"),
    "workflow-level env credential": add("top-env.yml", "name: x\non:\n  workflow_dispatch:\nenv:\n  T: ${{ secrets.VERCEL_TOKEN }}\njobs:\n  a:\n    environment: production\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo ok\n"),
}
for label, mutate in cases.items():
    code, out = run_gate(mutate)
    assert code != 0, f"secret-scoping gate accepted: {label}"

code, out = run_gate(add("block-env.yml", (NEW_JOB % "VERCEL_TOKEN").replace("    runs-on:", "    environment:\n      name: production\n    runs-on:")))
assert code == 0, f"block-form environment must be accepted: {out}"

code, out = run_gate(add("literal-other.yml", (NEW_JOB % "X").replace("secrets.X", "secrets [ 'SUPABASE_URL' ]")))
assert code == 0, f"ungated literal non-production secret must be accepted: {out}"

code, out = run_gate(add("indent4-gated.yml", "name: x\non:\n  workflow_dispatch:\njobs:\n    apply:\n      environment: production\n      runs-on: ubuntu-latest\n      steps:\n        - env:\n            T: ${{ secrets.SUPABASE_ACCESS_TOKEN }}\n          run: echo ok\n"))
assert code == 0, f"4-space-indented gated job must be accepted: {out}"

print(f"PASS secret-scoping gate rejects {len(cases)} ungated variants")
