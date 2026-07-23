---
name: keep-local-checkout-synced
description: Keep your local checkout synced to origin/main after merges — `gh pr merge` updates the remote, not your local tree; a stale tree makes subagents analyze the wrong code.
---

`gh pr merge` merges on the **remote** — it does NOT update your local working tree.
After a run of merges the local `main` silently drifts behind `origin/main` (it can
drift many commits before you notice).

**Why it bites:** plan-review/code subagents that inspect the working tree
**directly** (not via `git fetch <branch>` + a fresh worktree) then read STALE code
and produce wrong verdicts — e.g. a "retire X" plan review can falsely claim that
already-merged files "don't exist" and flag a bogus parity gap, when those changes
are present on the real `origin/main`. You can nearly send a correct plan back on
bad information.

**How to apply:**
- After merging anything, `git -C <your-checkout> pull --ff-only origin main` so the
  tree reflects reality.
- For any subagent that must read current code, either ensure the tree is freshly
  pulled first, OR tell it to `git fetch origin main` and inspect `origin/main`
  (e.g. `git show origin/main:path`) / a detached worktree from `FETCH_HEAD` — never
  trust the bare working tree without confirming `git rev-parse HEAD == origin/main`.
- PR-branch verification subagents that already do `git fetch origin <branch>` + a
  detached worktree are fine — the gap is only direct-tree inspection. See
  `feedback-drive-workflow-role.md`.
