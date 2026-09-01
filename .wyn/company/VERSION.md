# WYNOS Version Control

Source of truth for the project's current version, per the WYNOS Version Control Policy set by Owner (2026-09-01). See that policy for the full rules — summarized below.

## Current Version

**WYNOS v1.0.0 Beta1**

Baseline: `main` @ `fc87256bddadce5c1b693a60b247f06624bd56aa` (2026-09-01)

Everything in the codebase as of this commit — code, features, systems, UI/UX, database schema, API, and configuration — is part of WYNOS v1.0.0 Beta1. This includes every task deployed to production through this date: WYN-001 through WYN-075 (most recently WYN-072 Onboarding/guest browsing, WYN-073 Home layout + tabs restyle, WYN-074 post-image loading fix, WYN-075 P0 revert of WYN-074).

## Policy summary (full text: Owner's 2026-09-01 message)

- Only Owner sets a new version number and decides what feature work goes into it.
- No AI role changes the version number, adds a major feature, or removes an existing feature without an explicit Owner instruction.
- Existing WYNOS capability stays intact unless Owner instructs otherwise.
- If a version has a problem (build failure, runtime error, broken feature, broken UI/UX, migration issue, API issue, security/performance regression, outage): **stop, analyze, report cause + impact, propose a fix, and wait for Owner's decision on whether to roll back.** Never auto-rollback. Rollback only on an explicit Owner instruction (e.g. "Rollback WYNOS กลับไป v1.0.0 Beta1").
- Every new version Owner declares gets recorded here, keeping this file's history intact — never overwritten without reason.

## Version History

| Version | Set by | Date | Baseline commit | Notes |
|---|---|---|---|---|
| v1.0.0 Beta1 | Owner | 2026-09-01 | `fc87256bddadce5c1b693a60b247f06624bd56aa` | Current codebase confirmed as this baseline; Version Control Policy established same day. |
