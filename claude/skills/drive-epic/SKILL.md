---
name: drive-epic
description: >-
  Drive a multi-issue epic (a dependency DAG of GitHub issues) through the
  dogfooded issue→plan→develop→PR→merge lifecycle as the human-in-the-loop
  gatekeeper. The engineering is done by a **worker** you orchestrate but never
  become: by default a remote autonomous coding bot (a loony-dev instance); when
  the bot is down or out of its depth, you fall back to running the same loony-dev
  command prompts inside local subagents. Either way you graduate plans, gate
  merges on CI + a *real* CodeRabbit review, unlock dependents as parents merge,
  and stay at the 1000ft view. Use when asked to "drive the pivot/epic", babysit a
  set of dependent issues/PRs, or coordinate a bot-built feature epic to completion.
---

# Drive an epic

You are the **human-in-the-loop gatekeeper** for an epic: a set of GitHub issues
(usually a dependency DAG) taken through the issue→plan→develop→PR→merge lifecycle.
You own the gates the workflow intentionally leaves open — **plan approval** and
**merge** — plus sanity oversight. CodeRabbit (`coderabbitai[bot]`) is the automated
reviewer; a CI `test` check runs pytest on each PR. **GitHub owns CI and CodeRabbit
owns regular review in every strategy** — those never move in-house.

The *engineering* — planning, coding, PRs, CI fixes, review responses — is done by a
**worker** you orchestrate but never become. Who that worker is is a switchable
strategy.

## Two strategies for the worker

Pick one per epic; you may switch **per issue** or mid-flight:

- **Remote (default) — the coding bot.** A loony-dev instance plans, develops,
  raises PRs, fixes CI, and answers reviews on its own. You gate and relay. This is
  this skill's default voice.
- **Local (fallback) — subagents you drive.** When the bot is **down/unreachable**
  or a specific issue is **beyond it**, you fill the worker role yourself by spawning
  subagents that execute *the same loony-dev command prompts*. You still write no
  code in your own context — the subagents do — and you still preserve context by
  delegating everything. See **[Local strategy](#local-strategy)**.

**Everything else in this skill is strategy-agnostic** — the per-cycle loop, plan
review, the merge gate, DAG unlocking, and escalation apply unchanged to both. Only
*who performs the worker steps* differs: the remote bot, or your local subagents.

### When to fall back to local

- The bot's host is **offline / the supervisor crashed**, or tasks keep failing with
  `Agent exited with code 1` (a Claude-CLI logout — see Gotchas) and no operator is
  available to re-login.
- The gates are fine but the **bot can't make progress** on an issue: it repeatedly
  fails a large refactor, needs a capability it doesn't have, or is blocked by a
  bootstrapping bug in its own flow (see Bootstrapping bugs).
- You need one issue landed *now* and the bot is rate-thrashing. Fall back for that
  issue; leave the rest on the bot, and hand it back when the bot recovers.

### How to switch into local mode

1. **The worker commands are already installed.** The loony-dev command prompts
   (`plan-issue`, `implement-issue`, `address-reviews`, `fix-ci`, `fix-review`,
   `fix-hook`, `resolve-conflicts`, `commit-message`, `pr-body`, `cleanup-stuck`)
   ship as user slash commands in this dotfiles repo (`claude/commands/`, installed to
   `~/.claude/commands/`). A subagent runs one by following `~/.claude/commands/<cmd>.md`
   — nothing to vendor per repo. Keep them in step with upstream loony-dev by
   re-copying when the bot's commands change.
2. **Quiesce the bot on issues you're taking over** so it doesn't race you — label
   them `in-error` (halts its retry loop) or stop the supervisor. Resume by removing
   the label when you hand an issue back.
3. **Labels become your kanban, not triggers.** Nothing polls them now; you advance
   the state machine yourself. The identity check (a non-bot commenter) also stops
   mattering — there is no bot to trigger — but CodeRabbit and CI still fire on PR
   events exactly as before.

## Prime directive: coordinate, don't do the work

Your value is judgment and orchestration, not engineering. **Preserve your context
aggressively.** The worker — remote bot or local subagent — does every bit of
planning, coding, verification, and review-response; you keep your own context for
lifecycle decisions, alignment review, labels, and merges, acting on the workers'
terse reports. In **local** mode your subagents *do write code* (in isolated
worktrees) — that is still not *you* doing it: you stay at the **1000ft view and
review for alignment**, never dropping into the diff to hand-edit. The only classic
exception is a bootstrapping bug the remote bot cannot self-heal — see below.

## Setup (once)

1. **Map the dependency DAG.** Know which issues are roots and which unlock only
   after a parent PR merges. Re-check with `gh` before acting — boards are
   time-sensitive.
2. **Pick a strategy.** Remote by default; local if the bot is down or an issue is
   beyond it. For local, do the switch steps above (they're cheap to keep ready).
3. **Arm a recurring loop** so the cadence survives: `/loop 10m drive the <name>
   epic: check the board, graduate plans I'm satisfied with, gate merges on
   CI+CodeRabbit, unlock dependents as parents merge, escalate only on in-error`.
   (Stop it with CronDelete when the epic is done.)
4. **Confirm your identity** is a non-bot collaborator (`gh api user -q .login`) so
   your comments actually trigger the bot (a bot ignores comments authored by
   itself). *Remote mode only* — irrelevant once you're the worker.

## The per-cycle loop

Each time the loop fires, do a *delta* check (what changed since last cycle) and act.
This loop is strategy-agnostic; the only difference is that in **local** mode you
*advance the worker steps yourself* (spawn the next subagent) where in remote mode
you'd *wait on / relay to the bot*:

1. **Check the board** — issue labels (`ready-for-planning` / `ready-for-development`
   / `in-progress` / `in-error`), open epic PRs, and their gate state. **The delta
   check must be content-based:** re-read the `<!-- loony-plan -->` comment body and
   the CodeRabbit walkthrough body *every* cycle. Both are single comments **edited in
   place** — never infer state from a comment's existence, position, or `created_at`
   (a revision moves only `updated_at`). See
   [`in-place-comment-updates.md`](in-place-comment-updates.md).
2. **Graduate plans** you're satisfied with (`ready-for-planning` → review →
   `ready-for-development`). See "Plan review."
3. **Gate + merge** any PR that's genuinely green. See "Merge gate."
4. **Unlock dependents** — when a parent PR merges and closes its issue, label its
   DAG children `ready-for-planning`.
5. **Escalate only on `in-error`** (remote) or a stuck worker subagent (local).
   Otherwise hold and re-check next cycle.

**In local mode the same cycle also carries loony-dev's orchestration:** on top of the
gatekeeping steps above, scan every open item for the worker-trigger conditions the
bot's orchestrator would react to (new review comments, CI failures, conflicts, stuck
items) and kick off the matching command — you monitor and kick off, a subagent
performs. See [Local strategy](#local-strategy) for the trigger→command mapping.

Keep per-cycle reports terse when nothing changed. After each merge, **`git pull
--ff-only origin main`** locally (see Gotcha: stale checkout).

## Plan review & graduation

When a plan lands (the bot's `<!-- loony-plan -->` comment in remote mode, or your
planner subagent's output in local mode), **delegate the analysis to a subagent** (it
grounds in current code; you keep context), then make the call:

- Subagent verifies the plan against current code: architecture fit, accuracy of code
  claims (file:line), acceptance-criteria coverage, risks, and whether earlier
  feedback was addressed for revisions.
- **Graduate** (`gh issue edit N --remove-label ready-for-planning --add-label
  ready-for-development` + an approval comment) only when satisfied.
- **Send back** (a review comment listing specific, code-grounded required changes;
  leave `ready-for-planning`) when the plan has real problems — scope creep,
  dependence on unmerged work, a faulty premise, a missing interface/contract. Don't
  rubber-stamp. This is where your value is highest.
- Settle cross-issue **contracts/seams** before dependents build on them (e.g. a
  connection-file schema, a shared key). Send back a plan that leaves a downstream
  contract undefined.
- **Steer with comments. Never rewrite the issue body.** The bot **reads the issue's
  comments**, not just its body — a comment is sufficient to redirect planning. So when
  triage contradicts the issue's premise, when you finalise provisional acceptance
  criteria, or when a decision supersedes the issue's approach, all of it goes in a
  comment. Leave the wrong reading standing and correct it alongside. See the gotcha
  below for why this is not merely a style preference.
- **Local mode:** the plan-review subagent must be a *different* subagent from the one
  that wrote the plan — never let the planner grade its own homework. Your alignment
  judgment is still the gate.

## Merge gate — the checklist

Merge a PR only when **all** hold (verify each; don't merge on vibes). This gate is
**identical in both strategies** — a PR raised by your local subagents clears the same
bar as one the bot raised:

- [ ] **CI `test` check is `SUCCESS`** on the current head. (PRs opened before the CI
      workflow existed, or before a base merge, may have *no* run — trigger one with
      `gh pr update-branch <n>`, which also surfaces conflicts.)
- [ ] **A *real* CodeRabbit review, not a rate-limit auto-pass.** The `CodeRabbit`
      status check goes `SUCCESS` even when rate-limited. **Always re-read the
      CodeRabbit walkthrough — the *first* CodeRabbit issue-comment on the PR, which is
      edited in place on each pass** (not the *latest* comment, which may be a newer,
      unrelated one). If it says "rate limited / Review limit reached", it did NOT
      review. Confirm 0 unresolved actionable threads and a genuine "Actionable
      comments posted: N" / "No actionable comments" verdict, and that the SHA range it
      names reaches the current head. See the `coderabbit-slots` skill for the queries.
- [ ] **Findings addressed.** Remote: **relay them to the bot** (an authorized
      comment) — addressing/rebutting CR is the bot's job, not yours. Local: spawn an
      `address-reviews` subagent to triage/fix/rebut and push. Either way the *worker*
      adjudicates CR, never you; wait for resolution.
- [ ] **For security-sensitive or concurrency-critical PRs, a subagent deep-review**
      beyond CI (security smoke / traversal / thread-safety / plan-conformance) —
      tests don't catch everything.
- [ ] **mergeable** (no conflicts). Sibling PRs touching the same files conflict;
      resolve via the worker (bot's ConflictResolutionTask, or a local
      `resolve-conflicts` subagent); whichever merges *second* may need
      `gh pr update-branch` / rebase.

Then `gh pr merge <n> --merge --delete-branch`. **Never fold the CR-check and the
merge into one command** — verify CR is a real pass *first*, then merge.

## Local strategy — run the worker with subagents {#local-strategy}

When you own the worker role, each lifecycle step maps to a loony-dev command you run
**inside a subagent** (never in your own context). Prep a tiny JSON context file in
your scratchpad with the fields that command expects and pass its path as the
command's argument; the subagent reads `~/.claude/commands/<cmd>.md` and follows it
verbatim. Keep each worker in its own subagent so your context stays clean, and use
`isolation: worktree` for any step that edits files so parallel issues don't collide
(see the worktree gotcha). CI and CodeRabbit stay on GitHub and fire on your PRs
exactly as they would on the bot's.

**You are now loony-dev's orchestrator, too.** In remote mode the bot's orchestrator
continuously watches issues/PRs — new comments, a CI check flipping to failure, a
branch going conflicted, an item stuck `in-progress` — and fires the matching command
on its own. In local mode **nothing watches: that monitoring-and-kickoff job is
yours.** Each cycle, scan every open epic item and, when a trigger fires, spawn the
matching worker subagent. You **monitor and kick off; you never run the command in
your own context** — the subagent performs, you hold the 1000ft view. (Because you're
now the orchestrator and not just the gate, consider a tighter `/loop` interval in
local mode.)

| When you detect… | Kick off (in a subagent) |
| --- | --- |
| issue `ready-for-planning` | `plan-issue` → post the plan → your plan-review gate |
| plan graduated (`ready-for-development`) | `implement-issue` (+`fix-hook`) → `commit-message` → `pr-body` → open the PR |
| PR `test` check `FAILURE` | `fix-ci` |
| new unaddressed review comments (CodeRabbit/human) | `address-reviews` (or `fix-review` for a CR review body) |
| PR branch conflicted with base | `resolve-conflicts` |
| worker subagent died / item stuck `in-progress` | `cleanup-stuck`, then re-kick the interrupted step |

The steps below are that mapping in dependency order for one clean issue; in practice
fire whichever step the current state calls for.

Per issue, in order:

1. **Plan — `plan-issue`.** Context `{issue_number, title, body}` (add `current_plan`,
   `feedback`, `revision_note_delimiter: <!-- loony-revision-note -->` for a revision).
   The subagent outputs plan markdown; post it as the issue's `<!-- loony-plan -->`
   comment for an auditable record. **Then run your normal plan-review gate with a
   *different* subagent** and graduate.
   **This hand-assembled context is a local-mode detail — do not read it as the remote
   bot's input contract.** You prep `body` explicitly here only because nothing else
   will; the remote bot reads the issue's comments on its own. Never conclude from this
   line that steering the bot requires editing the body — it does not (see the gotcha
   below). In local mode, fold the relevant comment content into `feedback`.
2. **Develop — `implement-issue` (+ `fix-hook`).** After graduation, an implementer
   subagent (isolation: worktree) with context `{issue_number, title, body, plan}`
   writes the code, runs `.githooks/pre-commit`, and loops `fix-hook` on any hook
   rejection — **no commits yet**.
3. **Commit & open the PR — `commit-message`, `pr-body`.** Generate the conventional
   commit (must reference `#<issue>`), commit, push the branch, then generate the PR
   body and `gh pr create`. This is the PR the bot would have raised.
4. **Green CI — `fix-ci`.** On a failing check, a subagent with context
   `{pr_number, title, branch, failed_checks:[{name,conclusion,url}]}` reads the logs,
   fixes on the branch, and pushes.
5. **Answer review — `address-reviews` / `fix-review`.** The local stand-in for
   "relay to the bot": when CodeRabbit posts findings, a subagent runs
   `address-reviews` (triage each FIX/IGNORE/DEFER against the diff-scope test, reply,
   resolve only the bot inline threads it fixed, push). It — not you — adjudicates and
   answers CodeRabbit.
6. **Conflicts — `resolve-conflicts`.** A subagent merges `default_branch`, resolves,
   and `git push --force-with-lease`.
7. **Gate & merge.** The **merge gate above is identical.** Verify, merge,
   `--delete-branch`, `git pull --ff-only`, unlock DAG children.

Your job across all of this is unchanged: the **1000ft view + alignment**. Sanity-check
that a subagent isn't gaming the gate (skipping/gutting tests, `--no-verify`, hollow
assertions) exactly as you'd police the bot.

## Escalation — the one thing you wait on the operator for

Everything routine (waiting on CodeRabbit, waiting on a fix to push, waiting on CI) you
handle by waiting and re-checking — not by asking. You escalate on a genuine stuck
state:

- **Remote:** the bot marks an item `in-error` after repeated identical failures.
  That's the state you escalate on. Applying the `in-error` label yourself **halts the
  bot's retry loop** — use it to stop a PR thrashing (`<!-- loony-failure -->` comments
  every ~80s); remove it to resume.
- **Local:** when a worker subagent fails the *same* step repeatedly (the analog of
  `in-error`), stop re-spawning it and escalate rather than thrash.
- When you escalate, give the operator the exact failing command/error, the diagnosis,
  and a recommended fix. Env/process/auth fixes on the bot's host are operator actions
  (you typically can't reach it — permission denied); falling back to **local mode** is
  often the faster unblock you *can* do yourself.

## Bootstrapping bugs (when the remote bot can't self-heal)

If the blocker is a bug in the very flow the bot needs to fix it (e.g. the
review-addressing path itself is broken), the bot can't land its own fix. Then: **file
the bug issue, and launch a subagent to author the fix and open a PR** (isolation:
worktree). The fix must be reviewed and **merged manually/out-of-band** (don't rely on
the broken flow). Keep the fix minimal + well-tested + regression-proven. (In local
mode there's no "bot can't self-heal" — a fix like this is just another worker step you
run through the same gate.)

## Reusable subagent prompts

These verification prompts are strategy-agnostic — you use them to *gate*, whichever
worker built the PR. (For the *worker* steps in local mode, the prompts are the installed
commands themselves; point the subagent at `~/.claude/commands/<cmd>.md` per the pipeline
above — don't re-derive them.)

**Plan review** — "Confirm the tree is current (`git rev-parse HEAD == origin/main`,
else `git pull --ff-only`). Re-read the `<!-- loony-plan -->` comment on issue #N (there
is only one — it's edited in place; read the *body*, don't grep it) and the issue body.
Ground in current code (cite file:line). Assess architecture fit,
accuracy of code claims, AC coverage, risks; for revisions, whether my prior required
changes were addressed. Verdict: LOOKS-READY or HAS-CONCERNS (list specific blockers)."

**PR merge-gate verification** — "Read-only; do NOT modify/push/comment/merge. Run the
suite in a throwaway detached worktree: `git fetch -q origin <branch>; git worktree add
-q --detach /tmp/verifyN FETCH_HEAD; (cd /tmp/verifyN && uv run pytest -q)`. Report head
SHA + summary + confirm it matches PR head. Review the diff for scope/correctness (quote
code). For security/concurrency PRs, smoke-test the risky surface. Classify CodeRabbit:
NOT-YET-REVIEWED / RATE-LIMITED / CLEAN / N unresolved findings. Clean up the worktree.
Verdict: MERGE-READY / WAIT (CR) / NOT-READY."

## Gotchas (hard-won — these cost hours)

- **Never rewrite an issue body (universal).** The body is the **operator's alignment
  baseline** — what they read back later to judge whether what shipped answers what they
  asked. Rewriting it destroys that, and it is *not recoverable*: GitHub's
  `userContentEdits` GraphQL `diff` returns the **current** body, not the prior one, so
  once you have overwritten it the original exists only in your context. Put triage,
  premise corrections, finalised acceptance criteria and supersession notices in
  **comments**, and structure them to be checkable against the body — name each premise
  you are correcting rather than quietly replacing it, and mark superseded ACs as
  replaced rather than restating them as if they had always been there. (Bit me: I
  rewrote an issue's body with root-cause findings because I had assumed the bot plans
  from the body alone — it does not, it reads comments — and had to restore the original
  from earlier context. Two mistakes, one edit.) Applies to PR descriptions authored by
  others, for the same reason. If a plan ever *demonstrably* ignores a comment, that is a
  bug to file at `<owner>/loony-dev` — never a licence to edit the body.
- **Stale local checkout (universal).** `gh pr merge` updates the *remote*, not your
  local tree. `git pull --ff-only origin main` after merges, or subagents that inspect
  the bare working tree read old code and produce wrong verdicts. (Bit me: a "retire X"
  plan review falsely claimed merged files didn't exist.) PR-branch verifiers that `git
  fetch <branch>` + detached worktree are fine; only direct-tree inspection is the trap.
- **The key comments are edited in place (universal).** The `<!-- loony-plan -->`
  comment and CodeRabbit's walkthrough (the *first* CR issue-comment) are each ONE
  comment rewritten on every update — `created_at` never moves, only `updated_at`. A
  revision happened iff `updated_at != created_at`; then **re-read the body**. (Bit me:
  keying on `createdAt` I reported two issues as "not revised yet" when both had
  revised.) And grepping a body ≠ reading it — 4 hits for a forbidden clause were the
  plan *explaining why it's wrong*. See
  [`in-place-comment-updates.md`](in-place-comment-updates.md).
- **CodeRabbit rate-limits constantly (universal).** The green check ≠ a review. Read
  the rate-limit comment; compute the reset from its **`updated_at`** plus the wait it
  states — that comment is edited in place too, so `created_at` is wrong. The stated
  wait moves constantly (observed 1–52 min), so **re-read it every time**; a value you
  cached five minutes ago is worthless. After the reset, re-trigger with `@coderabbitai
  review`. Keep the gate strict in both strategies — don't merge on the auto-pass.
- **Parallel local workers collide on worktrees (local).** Two implementer subagents on
  sibling issues editing the same files conflict. Give each `isolation: worktree` and a
  distinct branch; see [`worktree-add-conflict-blocker.md`](worktree-add-conflict-blocker.md)
  for the base-checkout footgun.
- **A code merge does NOT need a supervisor restart (remote).** The bot picks up merged
  code on its own. Only restart if a change actually breaks the running process.
- **The Claude CLI logs itself out randomly (remote).** Symptom: tasks fail with `Agent
  exited with code 1` (no detail in the GitHub comment, only the bot's logs). Fix:
  operator re-logins. When you see that error, suspect a logout — and it's a prime cue to
  **fall back to local** while the operator is away.
- **Relaying triggers the bot (remote).** Any authorized comment on an **issue or a PR**
  spawns a bot task; while a worktree/env bug is active that can cause thrashing — label
  `in-error` to stop it. (No analog in local mode — your subagents push directly, nothing
  is triggered by comments.)
- **"Hold" written in prose does not hold anything (remote).** The dispatch fires on the
  comment event; the bot never reads your comment and decides not to work. So **to pause
  an issue, remove `ready-for-planning` FIRST, then comment** — in that order. Comment
  first and you have just re-dispatched the very issue you were parking. (Bit me: I
  posted "hold, do not re-plan yet — wait for #723" on two issues and both re-planned
  within 30 seconds.) Resuming is the same mechanism in reverse: re-add the label, which
  is itself the trigger, so the comment explaining the resume can come before it.
- **A revision comment and a hold comment are the same event to the bot (remote).** If a
  comment contains actionable required changes you *do* want acted on, leave the label
  on. If it contains anything else — a supersession notice, a re-sequencing, a correction
  to your own earlier feedback — de-label first. Decide which kind of comment you are
  writing before you post it, not after.
- **Triage findings by where they live (universal).** CodeRabbit "outside-diff" findings
  sit in the review *body*, not as inline threads, so "0 unresolved threads" ≠ clean —
  read the body too.

See the field notes bundled next to this skill for the same lessons in durable form:
[`feedback-drive-workflow-role.md`](feedback-drive-workflow-role.md),
[`coderabbit-ratelimit-workflow.md`](coderabbit-ratelimit-workflow.md),
[`worktree-add-conflict-blocker.md`](worktree-add-conflict-blocker.md),
[`keep-local-checkout-synced.md`](keep-local-checkout-synced.md),
[`in-place-comment-updates.md`](in-place-comment-updates.md).
