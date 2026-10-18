#!/usr/bin/env python3
"""Regression test: the freeze guard fails when the ZOKY exception workflow or
the edge deploy workflow is loosened, and still passes when the exception
workflow is deleted.

Runs the real guard against a temporary copy of the files it reads, so the
repository itself is never modified.
"""
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUARD = "tools/check_wynos_release_freeze.py"
ZOKY = ".github/workflows/zoky-web-exception-release.yml"
EDGE = ".github/workflows/deploy-edge-functions.yml"


def run_guard(mutate=None, target=ZOKY):
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        (tmp / "tools").mkdir()
        shutil.copy(ROOT / GUARD, tmp / GUARD)
        shutil.copytree(ROOT / ".github", tmp / ".github")
        if mutate:
            mutate(tmp / target)
        result = subprocess.run([sys.executable, "-I", str(tmp / GUARD)], capture_output=True, text=True)
        return result.returncode, result.stdout + result.stderr


def replace(old, new):
    def mutate(path):
        text = path.read_text()
        assert old in text, f"test fixture drift: {old!r} not found"
        path.write_text(text.replace(old, new, 1))
    return mutate


def move_environment_to_guard(path):
    text = path.read_text()
    text = text.replace("    environment: production\n", "", 1)
    text = text.replace("    runs-on: ubuntu-latest\n", "    environment: production\n    runs-on: ubuntu-latest\n", 1)
    path.write_text(text)


def drop_deploy_expiry_check(path):
    text = path.read_text()
    new, count = re.subn(r"      # Re-checked after the production review.*?(?=      - name: Checkout pinned release commit)",
                         "", text, count=1, flags=re.S)
    assert count == 1, "test fixture drift: deploy expiry step not found"
    path.write_text(new)


code, out = run_guard()
assert code == 0, out

code, out = run_guard(lambda path: path.unlink())
assert code == 0, f"deleting the exception workflow must be allowed: {out}"

loosened = {
    "push trigger": replace("on:\n  workflow_dispatch:", "on:\n  push:\n    branches: [release/zoky-web-20261018]\n  workflow_dispatch:"),
    "no production environment": replace("environment: production", "environment: preview"),
    "main-only guard removed": replace("if: github.ref == 'refs/heads/main' && inputs.confirmation", "if: inputs.confirmation"),
    "expiry extended": replace('ZOKY_EXCEPTION_EXPIRES_UTC: "2026-11-30"', 'ZOKY_EXCEPTION_EXPIRES_UTC: "2027-12-31"'),
    "base SHA changed": replace("b19687afdec361da846a2d9ceb11429547c92a24", "42a8f9373fe900ff1de14b18cf0bc6ad8ae8b1de"),
    "#1133 exclusion removed": replace("806390ed8ab56810c6141b925e6b8aa6eb3eca49 ", ""),
    "path allowlist removed": replace("Out-of-scope path in release", "path note"),
    "write permission": replace("permissions:\n  contents: read", "permissions:\n  contents: write"),
    "cancels in-progress": replace("cancel-in-progress: false", "cancel-in-progress: true"),
    "deploys repo ref instead of pinned SHA": replace("ref: ${{ inputs.release_sha }}", "ref: main"),
    "guard job not required": replace("needs: guard", "needs: []"),
    # CTO review R1/R3/R4: per-job structure, not substrings.
    "environment moved to guard job": move_environment_to_guard,
    "environment only in a comment": replace("    environment: production", "    # environment: production"),
    "wrong concurrency group (wyn-158 lane)": replace("group: zoky-web-exception-release", "group: wyn-158-production"),
    "cancel-in-progress false only in a comment": replace("  cancel-in-progress: false", "  cancel-in-progress: true # cancel-in-progress: false"),
    "inputs in run block": replace('          set -euo pipefail\n          test "$(git rev-parse HEAD)"',
                                   '          set -euo pipefail\n          echo "${{ inputs.release_sha }}"\n          test "$(git rev-parse HEAD)"'),
    "inputs in shell comment": replace('          set -euo pipefail\n          test "$(git rev-parse HEAD)"',
                                       '          set -euo pipefail\n          # ${{ inputs.release_sha }}\n          test "$(git rev-parse HEAD)"'),
    "github.event.inputs in inline run": replace("run: npm ci --no-audit --no-fund", "run: npm ci --no-audit --no-fund --tag ${{ github.event.inputs.phase }}"),
    "deploy expiry check removed": drop_deploy_expiry_check,
    "secrets read in guard job": replace("      - name: Exception has not expired\n        run: |",
                                         "      - name: Exception has not expired\n        env:\n          T: ${{ secrets.VERCEL_TOKEN }}\n        run: |"),
    "extra job added": lambda path: path.write_text(path.read_text() + "\n  extra:\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo hi\n"),
    "credentials persisted": replace("persist-credentials: false", "persist-credentials: true"),
    "Vercel CLI unpinned": replace("vercel@63.1.2", "vercel@latest"),
    # Edge phase (ZOKY edge functions from the pinned SHA).
    "edge job without production environment": replace(
        "    if: github.ref == 'refs/heads/main' && inputs.confirmation == 'ZOKY_FREEZE_EXCEPTION_20261018' && inputs.phase == 'EDGE'\n    environment: production\n",
        "    if: github.ref == 'refs/heads/main' && inputs.confirmation == 'ZOKY_FREEZE_EXCEPTION_20261018' && inputs.phase == 'EDGE'\n"),
    "edge job not gated on phase": replace("inputs.confirmation == 'ZOKY_FREEZE_EXCEPTION_20261018' && inputs.phase == 'EDGE'",
                                           "inputs.confirmation == 'ZOKY_FREEZE_EXCEPTION_20261018'"),
    "web deploy also runs on EDGE": replace(" && inputs.phase != 'EDGE'", ""),
    "edge allowlist extended": replace('ZOKY_EDGE_FUNCTIONS: "food-stripe-checkout food-stripe-cancel wynos-maps-geocode"',
                                       'ZOKY_EDGE_FUNCTIONS: "food-stripe-checkout food-stripe-cancel wynos-maps-geocode stripe-webhook"'),
    "edge deploys an extra function": replace('          done\n          echo "Next: plan section 4',
                                              '          done\n          supabase functions deploy stripe-webhook --project-ref "$PROJECT_REF"\n          echo "Next: plan section 4'),
    "edge deploys repo ref instead of pinned SHA": replace("      - name: Checkout pinned release commit (edge)\n        uses: actions/checkout@v4\n        with:\n          ref: ${{ inputs.release_sha }}",
                                                           "      - name: Checkout pinned release commit (edge)\n        uses: actions/checkout@v4\n        with:\n          ref: main"),
    "edge job not required to wait for guard": replace("    name: Deploy the 3 allowlisted edge functions to production\n    needs: guard",
                                                       "    name: Deploy the 3 allowlisted edge functions to production\n    needs: []"),
    "edge verify_jwt pin removed": replace("          grep -qx '\\[functions\\.wynos-maps-geocode\\]' supabase/config.toml || {", "          true || {"),
    "edge Supabase CLI unpinned": replace("version: 2.120.0", "version: latest"),
    "edge --no-verify-jwt": replace('--project-ref "$PROJECT_REF"\n            echo "- deployed', '--project-ref "$PROJECT_REF" --no-verify-jwt\n            echo "- deployed'),
    "guard accepts any phase": replace('case "$PHASE" in EDGE|PHASE1|PHASE2) ;; *)', 'case "$PHASE" in *) ;; EDGE)'),
    "edge expiry check removed": replace("      # Re-checked after the production review (edge phase).\n      - name: Exception has not expired\n", "      - name: Expiry note\n"),
}
edge_loosened = {
    "edge environment removed": replace("    environment: production\n", ""),
    "edge geocode verify_jwt check removed": replace("grep -qx '\\[functions\\.wynos-maps-geocode\\]' supabase/config.toml", "true"),
    "edge pin step renamed": replace("      - name: wynos-maps-geocode verify_jwt is pinned", "      - name: wynos-maps-geocode verify_jwt check"),
}
for label, mutate in loosened.items():
    code, out = run_guard(mutate)
    assert code != 0, f"freeze guard accepted a loosened exception workflow: {label}"
for label, mutate in edge_loosened.items():
    code, out = run_guard(mutate, target=EDGE)
    assert code != 0, f"freeze guard accepted a loosened edge workflow: {label}"

print(f"PASS freeze guard rejects {len(loosened)} loosened variants of {Path(ZOKY).name} "
      f"and {len(edge_loosened)} of {Path(EDGE).name}")
