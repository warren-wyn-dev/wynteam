#!/usr/bin/env bash
# WYNOS Founder release freeze — shared gate for legacy, manual-only production paths.
# This script must execute before any Vercel deploy, domain alias reassignment,
# promotion, or production schema/write action. Does not perform a deployment.
set -euo pipefail

if [[ "${GITHUB_REPOSITORY:-}" != "warren-wyn-dev/wynteam" ]] || [[ "${GITHUB_REF:-}" != "refs/heads/main" ]]; then
  echo "::error::WYNOS release allowed only from main in the original repository."
  exit 1
fi
if [[ "${WYNOS_RELEASE_CONFIRMATION:-}" != "RELEASE_ALL_APPROVED" ]]; then
  echo "::error::Release freeze active. Explicit RELEASE_ALL_APPROVED is required."
  exit 1
fi
if [[ -z "${GH_TOKEN:-}" ]]; then
  echo "::error::Missing GitHub token for acceptance gate."
  exit 1
fi
if ! command -v gh >/dev/null 2>&1; then
  echo "::error::GitHub CLI is required to verify release acceptance."
  exit 1
fi

# These issues are the source of truth for the cross-system release criteria.
# Do not substitute PR merges / migrations for authenticated acceptance testing.
for issue in 1142 1143 1144 1145 1146 1147 1148 1149 1150 1151; do
  if ! state="$(gh api "repos/${GITHUB_REPOSITORY}/issues/${issue}" --jq '.state')"; then
    echo "::error::Cannot verify release acceptance #${issue}. Fail closed."
    exit 1
  fi
  if [[ "$state" != "closed" ]]; then
    echo "::error::Release frozen: acceptance #${issue} is ${state}."
    exit 1
  fi
done
echo "WYNOS cross-system release prerequisites verified."
echo "Continue only with checked release commit, production reviewer approval, and coordinated Admin+Web release plan."
