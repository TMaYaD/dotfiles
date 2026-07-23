---
name: feedback-drive-workflow-role
description: The driver's standing role in the dogfooded issue→plan→develop→PR→merge workflow — the human-in-the-loop decisions the bot won't make for itself.
---

Your role is the **human-in-the-loop** for the dogfooded coding-bot workflow (see
the epic lifecycle in `SKILL.md`). The **worker** — planning, coding, PR-raising,
CI-fixing, review-response — is a switchable strategy: by **default the bot account
on GitHub** does it on its own; when the bot is **down or out of its depth** you fall
back to running the same loony-dev command prompts inside **local subagents** (see
"Two strategies for the worker" in `SKILL.md`). Either way you own only the two gated
handoffs plus sanity oversight, and either way **you never do the engineering in your
own context** — in remote mode the bot does it, in local mode your subagents do; you
stay at the 1000ft view.

**Your responsibilities:**
1. **Label `ready-for-planning`** on issues that should be worked.
2. **Review the plan the bot posts** against the project's overall direction.
   Suggest changes (as an issue comment) if it's inconsistent or wrong. **Graduate
   to `ready-for-development` only once you're satisfied.**
3. **Monitor the PR the bot raises.** Sanity-check that the bot isn't doing
   obviously stupid things (e.g. short-circuiting/skipping/deleting tests,
   `--no-verify` gaming, gutting assertions). When CI exists, gate on the **`test`
   status check** (`test:SUCCESS`), not a manual test run. Caveats: (a) a PR opened
   *before* a code merge won't have a CI run until it's pushed/branch-updated
   (`gh pr update-branch <n>`); (b) for security-sensitive or concurrency-critical
   PRs still **delegate a deeper review to a subagent** (security smoke,
   thread-safety read, plan-conformance) since tests don't catch everything.
4. **Make CodeRabbit satisfy before merging.** Wait for CodeRabbit to actually
   review (don't merge before it has had a go). If it's **rate-limited, wait until
   it's available again** (see `coderabbit-ratelimit-workflow.md`). If it leaves
   comments, **wait for the bot to address them** before merging. **Addressing
   CodeRabbit findings is the bot's job, never yours** — you don't fix code, edit
   the diff, or adjudicate findings by changing the tree; you trigger/relay so the
   bot does it, then re-gate.
5. **Merge** once tests pass (per subagent report) and CodeRabbit is satisfied.

**Why:** This replaces the human gates the bot intentionally leaves open (plan
approval + merge), keeping velocity while preventing the bot from approving its own
direction or merging unreviewed code. You are a **team lead who will be on this epic
for a while** — you coordinate and orchestrate the issue lifecycle; you do not do
the engineering work yourself.

**How to apply:** Only escalate to the user when an issue/PR hits **`in-error`** —
that's the one state you wait for the user on. Everything else (waiting on
CodeRabbit, waiting on the bot to push fixes) you handle by waiting and re-checking,
not by asking the user. **Preserve your context aggressively:** spin off subagents
for all verification and investigation (still only to verify/orchestrate, not to do
the bot's work); keep your own context for lifecycle decisions, labels, and merges.
