---
name: worktree-add-conflict-blocker
description: A class of bootstrapping bug where the bot's orchestrator parks its base checkout on a PR branch, breaking `git worktree add` — plus durable operational lessons.
---

**A worktree-add failure class (bootstrapping bug).** For tasks that operate on an
*existing* branch (addressing review comments, fixing CI, resolving conflicts), an
orchestrator that "resets" to the branch by checking it out **in the base checkout**
(`git checkout -B <branch> origin/<branch>`) parks the base on the PR branch. A
subsequent `git worktree add -B <branch> … <branch>` then fails with
`fatal: '<branch>' is already used by worktree at '<base>'` (exit 128) — blocking
the bot from ever addressing findings on that branch. The fix is to refresh the ref
**without** checking it out in the base (`git fetch` + `git branch -f <branch>
origin/<branch>`), keeping the base pinned to the default branch. Because the bot
can't self-heal a bug that stops it from working on branches, the driver has to fix
this class of bug itself (via a subagent) — a bootstrapping exception to "don't do
the engineering."

**Operational lessons (durable — these cost hours of debugging):**
1. **Applying the `in-error` label to a PR halts the bot's retry loop.** Use it to
   stop thrashing on a repeated failure marker; remove it to resume.
2. **A code merge does NOT generally need a supervisor restart** — the bot picks up
   merged changes on its own. Only restart if a change actually breaks the running
   process. (Don't tell the operator to restart just because a PR merged.)
3. **The Claude CLI can log itself out** (not caused by restarts — it happens on its
   own). Symptom: tasks fail with `Agent exited with code 1` (a
   Claude-CLI-exited-non-zero failure, no detail in the GitHub comment — only in the
   bot's logs). Fix: the operator re-logins the Claude CLI. **When you see `Agent
   exited with code 1`, suspect a logout** and escalate that specifically.
4. **You can't read the bot's home directory** (permission denied), so
   supervisor/process/auth fixes are operator actions — escalate. See
   `coderabbit-ratelimit-workflow.md`, `feedback-drive-workflow-role.md`.
