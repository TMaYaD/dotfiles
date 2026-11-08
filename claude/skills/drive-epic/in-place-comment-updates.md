---
name: in-place-comment-updates
description: The plan comment and the CodeRabbit walkthrough are single comments edited in place, never re-posted — so a delta check keyed on a comment's existence, position, or created_at reports "no change" when everything changed.
---

The two signals the epic loop leans on hardest are **single comments that are edited
in place on every update, never re-posted**:

- the bot's **`<!-- loony-plan -->` comment** on the issue (the bot rewrites
  this same comment on every plan revision), and
- CodeRabbit's **walkthrough comment** on the PR — the **first** CodeRabbit
  issue-comment, rewritten on each pass.

`created_at` never moves for either. Only `updated_at` does. **A per-cycle delta check
that looks for a *new* comment, or keys on `created_at`, will report "nothing
happened" on a board where everything happened.**

**It bit me for real.** Checking the board with `gh issue view N --json comments --jq
'.comments[].createdAt'` plus the first two lines of each body, I concluded "#163 and
#171 haven't revised yet" and reported that to the operator. Both had revised:

```
#163  created=2026-08-07T12:06:58Z  updated=2026-08-07T12:19:27Z
#171  created=2026-08-07T12:04:23Z  updated=2026-08-07T12:18:21Z
```

**Correct detection — a revision happened iff `updated_at != created_at`:**

```bash
gh api "repos/:owner/:repo/issues/N/comments" --paginate \
  --jq '.[]|select(.user.login=="<bot-login>" and (.body|test("loony-plan")))|"created=\(.created_at) updated=\(.updated_at)"'
```

**Then RE-READ THE BODY.** The timestamp only tells you *that* it changed; it tells
you nothing about *what* changed, and the previous body is gone.

**The CodeRabbit walkthrough has the same shape.** Its verdict, its rate-limit state,
and the SHA range it reviewed all change **in place**. Take it from the **first**
CodeRabbit issue-comment — *not* the latest, which may be an unrelated newer comment
that doesn't carry the walkthrough at all. See the `coderabbit-slots` skill for the
walkthrough query and how to read the range against head.

**Corollary — grepping an in-place body is not reading it.** Searching a revised plan
for a forbidden string tells you the string is *present*, not that it is *used*. A
grep of the revised #163 plan for `where.not(status: :cancelled)` returned 4 hits: all
four were the plan **explaining why that clause is wrong**, plus one deliberate,
documented divergence. Trusting the count would have been wrong in either direction —
a nonzero count read as "still broken", a zero count read as "fixed". **Discussion is
not use.** Read the body and judge it; don't grade a revision by string count.
