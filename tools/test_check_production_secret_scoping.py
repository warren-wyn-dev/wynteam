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
    "workflow-level env credential": add("top-env.yml", "name: x\non:\n  workflow_dispatch:\nenv:\n  T: ${{ secrets.VERCEL_TOKEN }}\njobs:\n  a:\n    environment: production\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo ok\n"),
}
for label, mutate in cases.items():
    code, out = run_gate(mutate)
    assert code != 0, f"secret-scoping gate accepted: {label}"

code, out = run_gate(add("block-env.yml", (NEW_JOB % "VERCEL_TOKEN").replace("    runs-on:", "    environment:\n      name: production\n    runs-on:")))
assert code == 0, f"block-form environment must be accepted: {out}"

print(f"PASS secret-scoping gate rejects {len(cases)} ungated variants")
