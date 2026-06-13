---
name: drive-epic
description: >-
  Drive a multi-issue epic (a dependency DAG of GitHub issues worked by an
  autonomous coding bot, e.g. a loony-dev instance) through the dogfooded issue→plan→develop→PR→merge
  lifecycle, acting as the human-in-the-loop gatekeeper. Graduate plans, gate merges
  on CI + a *real* CodeRabbit review, unlock dependents as parents merge, escalate
  only on in-error. Use when asked to "drive the pivot/epic", babysit a set of
  dependent issues/PRs, or coordinate a bot-built feature epic to completion.
---

# Drive an epic

You are the **human-in-the-loop gatekeeper** for an epic: a set of GitHub issues
(usually a dependency DAG) that an autonomous coding bot (here: a **loony-dev** instance) plans,
develops, and raises PRs for. The bot does the engineering; you own the gates the
bot intentionally leaves open — **plan approval** and **merge** — plus sanity
oversight. CodeRabbit (`coderabbitai[bot]`) is the automated reviewer; a CI `test`
check runs pytest on each PR.

## Prime directive: coordinate, don't do the work

Your value is judgment and orchestration, not engineering. **Preserve your context
aggressively.** Delegate every verification, plan analysis, and code investigation
to subagents and act on their reports; keep your own context for lifecycle
decisions, labels, and merges. The only time you write code yourself (via a
subagent) is when the bot *cannot* — see "Bootstrapping bugs."

## Setup (once)

1. **Map the dependency DAG.** Know which issues are roots and which unlock only
   after a parent PR merges. Re-check with `gh` before acting — boards are
   time-sensitive.
2. **Arm a recurring loop** so the cadence survives: `/loop 10m drive the <name>
   epic: check the board, graduate plans I'm satisfied with, gate merges on
   CI+CodeRabbit, unlock dependents as parents merge, escalate only on in-error`.
   (Stop it with CronDelete when the epic is done.)
3. **Confirm your identity** is a non-bot collaborator (`gh api user -q .login`) so
   your comments actually trigger the bot (a bot ignores comments authored by
   itself).

## The per-cycle loop

Each time the loop fires, do a *delta* check (what changed since last cycle) and act:

1. **Check the board** — issue labels (`ready-for-planning` / `ready-for-development`
   / `in-progress` / `in-error`), open epic PRs, and their gate state.
2. **Graduate plans** you're satisfied with (`ready-for-planning` → review →
   `ready-for-development`). See "Plan review."
3. **Gate + merge** any PR that's genuinely green. See "Merge gate."
4. **Unlock dependents** — when a parent PR merges and closes its issue, label its
   DAG children `ready-for-planning`.
5. **Escalate only on `in-error`.** Otherwise hold and re-check next cycle.

Keep per-cycle reports terse when nothing changed. After each merge, **`git pull
--ff-only origin main`** locally (see Gotcha: stale checkout).

## Plan review & graduation

When the bot posts a `<!-- loony-plan -->` comment, **delegate the analysis to a
subagent** (it grounds in current code; you keep context), then make the call:

- Subagent verifies the plan against current code: architecture fit, accuracy of
  code claims (file:line), acceptance-criteria coverage, risks, and whether earlier
  feedback was addressed for revisions.
- **Graduate** (`gh issue edit N --remove-label ready-for-planning --add-label
  ready-for-development` + an approval comment) only when satisfied.
- **Send back** (a review comment listing specific, code-grounded required changes;
  leave `ready-for-planning`) when the plan has real problems — scope creep,
  dependence on unmerged work, a faulty premise, a missing interface/contract.
  Don't rubber-stamp. This is where your value is highest.
- Settle cross-issue **contracts/seams** before dependents build on them (e.g. a
  connection-file schema, a shared key). Send back a plan that leaves a downstream
  contract undefined.

## Merge gate — the checklist

Merge a PR only when **all** hold (verify each; don't merge on vibes):

- [ ] **CI `test` check is `SUCCESS`** on the current head. (PRs opened before the
      CI workflow existed, or before a base merge, may have *no* run — trigger one
      with `gh pr update-branch <n>`, which also surfaces conflicts.)
- [ ] **A *real* CodeRabbit review, not a rate-limit auto-pass.** The `CodeRabbit`
      status check goes `SUCCESS` even when rate-limited. **Always read the latest
      coderabbit comment** — if it says "rate limited / Review limit reached", it
      did NOT review. Confirm 0 unresolved actionable threads and a genuine
      "Actionable comments posted: N" / "No actionable comments" verdict.
- [ ] **Findings addressed.** If CR left findings, **relay them to the bot** (an
      authorized comment) — addressing/rebutting CR is the bot's job, not yours. The
      bot fixes or rebuts; CR may concede false positives. Wait for resolution.
- [ ] **For security-sensitive or concurrency-critical PRs, a subagent deep-review**
      beyond CI (security smoke / traversal / thread-safety / plan-conformance) —
      tests don't catch everything.
- [ ] **mergeable** (no conflicts). Sibling PRs touching the same files conflict;
      the bot's ConflictResolutionTask resolves them; whichever merges *second* may
      need `gh pr update-branch` / rebase.

Then `gh pr merge <n> --merge --delete-branch`. **Never fold the CR-check and the
merge into one command** — verify CR is a real pass *first*, then merge.

## Escalation — `in-error` only

The bot marks an item `in-error` after repeated identical failures (manual
intervention required). That is the *one* state you escalate to the operator on.
Everything else (waiting on CodeRabbit, waiting on the bot to push a fix, waiting on
CI) you handle by waiting and re-checking — not by asking.

- **Applying the `in-error` label halts the bot's retry loop** — use it to stop a
  PR thrashing (`<!-- loony-failure -->` comments every ~80s). Remove it to resume.
- When you escalate, give the operator the exact failing command/error, the
  diagnosis, and a recommended fix. You typically can't reach the bot's host
  (permission-denied) — env/process/auth fixes are operator actions.

## Bootstrapping bugs (when the bot can't self-heal)

If the blocker is a bug in the very flow the bot needs to fix it (e.g. the
review-addressing path itself is broken), the bot can't land its own fix. Then:
**file the bug issue, and launch a subagent to author the fix and open a PR**
(isolation: worktree). The fix must be reviewed and **merged manually/out-of-band**
(don't rely on the broken flow). Keep the fix minimal + well-tested + regression-proven.

## Reusable subagent prompts

**Plan review** — "Confirm the tree is current (`git rev-parse HEAD == origin/main`,
else `git pull --ff-only`). Fetch the latest `<!-- loony-plan -->` comment on issue
#N and the issue body. Ground in current code (cite file:line). Assess architecture
fit, accuracy of code claims, AC coverage, risks; for revisions, whether my prior
required changes were addressed. Verdict: LOOKS-READY or HAS-CONCERNS (list specific
blockers)."

**PR merge-gate verification** — "Read-only; do NOT modify/push/comment/merge.
Run the suite in a throwaway detached worktree: `git fetch -q origin <branch>; git
worktree add -q --detach /tmp/verifyN FETCH_HEAD; (cd /tmp/verifyN && uv run pytest
-q)`. Report head SHA + summary + confirm it matches PR head. Review the diff for
scope/correctness (quote code). For security/concurrency PRs, smoke-test the risky
surface. Classify CodeRabbit: NOT-YET-REVIEWED / RATE-LIMITED / CLEAN / N unresolved
findings. Clean up the worktree. Verdict: MERGE-READY / WAIT (CR) / NOT-READY."

## Gotchas (hard-won — these cost hours)

- **Stale local checkout.** `gh pr merge` updates the *remote*, not your local tree.
  `git pull --ff-only origin main` after merges, or subagents that inspect the bare
  working tree read old code and produce wrong verdicts. (Bit me: a "retire X" plan
  review falsely claimed merged files didn't exist.) PR-branch verifiers that
  `git fetch <branch>` + detached worktree are fine; only direct-tree inspection
  is the trap.
- **CodeRabbit rate-limits constantly** (credit-limited). The green check ≠ a review.
  Read the comment; wait for the reset (it states "available in X min" from its
  `created_at`); re-trigger with `@coderabbitai review`. Operator-endorsed: keep the
  gate strict, don't merge on the auto-pass.
- **A code merge does NOT need a supervisor restart** — the bot picks up merged code
  on its own. Only restart if a change actually breaks the running process.
- **The Claude CLI logs itself out randomly** (not restart-related). Symptom: tasks
  fail with `Agent exited with code 1` (no detail in the GitHub comment, only the
  bot's logs). Fix: operator re-logins. When you see that error, suspect a logout.
- **Relaying triggers the bot.** Any authorized comment on a PR spawns a bot task;
  while a worktree/env bug is active that can cause thrashing — label `in-error` to
  stop it.
- **Triage findings by where they live.** CodeRabbit "outside-diff" findings sit in
  the review *body*, not as inline threads, so "0 unresolved threads" ≠ clean — read
  the body too.

See also the operator's memory files (`feedback-drive-workflow-role`,
`coderabbit-ratelimit-workflow`, `worktree-add-conflict-blocker`,
`keep-local-checkout-synced`) for the same lessons in durable form.
