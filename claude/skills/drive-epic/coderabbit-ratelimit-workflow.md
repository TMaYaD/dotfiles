---
name: coderabbit-ratelimit-workflow
description: How to handle CodeRabbit rate-limits at the merge gate — wait for the reset, then re-trigger; plus the "already reviewed" stalemate and its fix.
---

CodeRabbit (the merge-gate reviewer) is often on a credit-constrained org plan and
can hit its hourly PR-review rate limit. When a PR's only CodeRabbit activity is a
"Review limit reached" comment (and the green "CodeRabbit" status check is just the
rate-limit auto-pass, **not** a real review), the PR is **not** reviewed yet — do
not merge it.

**Handling (do NOT loosen the gate):** keep gating strictly on a real CodeRabbit
review. To time the re-trigger: read the rate-limit comment's **`updated_at`** plus its
"More reviews will be available in X minutes" value → that's the reset time. (That
comment is edited **in place**, so `created_at` is wrong — see
`in-place-comment-updates.md`. The stated wait moves constantly, observed 1–52 min:
re-read it every time rather than caching it.) After the reset, post
`@coderabbitai review` as a PR comment to kick the review (any authorized non-bot
collaborator can do this). Pushing new commits also re-triggers.

**The "already reviewed" stalemate + the fix (learned the hard way):** when
CodeRabbit is rate-limited *at a push*, its incremental tracker marks that commit
"seen" but emits no review. Afterwards a plain `@coderabbitai review` returns
*"Review finished — does not re-review already reviewed commits"* and refuses —
**even after the credit reset**. Plain re-trigger is then a dead end. The unblock is
**`@coderabbitai full review`** (forces a complete re-review, ignoring the
incremental "already-seen" state; ack = "Full review triggered", and the CodeRabbit
check flips to "Review in progress"). Needs credits available. Alternative: a new
commit advances the head → fresh auto-review. In practice a forced full review has
caught real findings the incremental path missed — vindicating the strict hold.

**The stance is contextual, not absolute:** the default is
wait-for-a-real-CodeRabbit-review (strict). The operator may, via an explicit
per-PR decision, authorize a one-time merge-on-independent-verification when
CodeRabbit is structurally stuck, or top up credits + re-trigger to unblock. Treat
merge-without-a-real-CodeRabbit-review as an explicit per-PR operator decision,
never a standing default. See `feedback-drive-workflow-role.md`.
