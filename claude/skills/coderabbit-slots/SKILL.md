---
name: coderabbit-slots
description: Claim CodeRabbit review slots when rate-limited, and verify a review genuinely happened. Use when CodeRabbit reports "Review limit reached", when several PRs are queued waiting on review, when a merge gate needs a real review whose range reaches the head commit, or when deciding whether the green CodeRabbit check actually means anything.
allowed-tools: Bash, Read
---

# CodeRabbit slot claiming

Two jobs that look like one: **getting a review to run** when the included tier is rate-limited, and **knowing whether a review actually happened**. The status check lies about both, so neither can be taken on trust.

## When to use

- CodeRabbit's check is green but you are not sure it reviewed anything.
- Several PRs are queued and each is waiting on a review slot.
- A PR was updated after its last review and you need the review range to reach the new head.
- You are about to merge on "CI green, zero unresolved threads".

## The core mistake to avoid

**The limit does not release one slot per window.** Several are often free at once. Waiting politely for a "turn" gets you one review; probing until the limit re-asserts gets three or four. Assuming a fixed cadence once left seven PRs stacked for hours.

## Claiming slots

### 1. Compute the reset — never guess it

Take the rate-limit comment's `updated_at` **plus** the duration it states, and compare with now:

```bash
gh api "repos/OWNER/REPO/issues/PR/comments" \
  --jq '[.[]|select(.user.login=="coderabbitai[bot]" and (.body|test("Review limit reached")))]|last|"updated=\(.updated_at)"'
gh api "repos/OWNER/REPO/issues/PR/comments" \
  --jq '[.[]|select(.user.login=="coderabbitai[bot]" and (.body|test("Review limit reached")))]|last|.body' \
  | grep -oE 'available in:[^0-9]*[0-9]+ [a-z]+'
```

The stated wait moves constantly — observed anywhere from **1 to 52 minutes**. Re-read it every time; a value you cached five minutes ago is worthless.

### 2. Probe in unblock-order until the limit re-asserts

Trigger, wait ~2 minutes, read the check. Claimed → try the next PR. Limit re-asserted with a *new future* timer → stop and wait.

```bash
# zsh does NOT word-split unquoted parameters — list the PRs literally.
for p in 649 646 635 634; do
  echo "===== PR $p at $(date -u +%H:%M:%SZ) ====="
  gh pr comment "$p" --body '@coderabbitai review' >/dev/null && echo "  triggered"
  sleep 140
  S=$(gh pr checks "$p" 2>&1 | grep -i coderabbit | awk -F'\t' '{print $2" "$5}')
  echo "  check: $S"
  case "$S" in *"rate limited"*)
     gh api "repos/OWNER/REPO/issues/$p/comments" \
       --jq '[.[]|select(.user.login=="coderabbitai[bot]" and (.body|test("Review limit reached")))]|last|"  RESET updated=\(.updated_at)"'
     echo "  >>> limit re-asserted — stop"; break;;
  esac
  echo "  >>> slot claimed"
done
```

Order the list by what each PR **unblocks**, not by age.

### 3. Budget roughly two slots per PR

A review produces findings; fixing them moves the head; the range no longer reaches it; you need another review. Ten PRs is closer to twenty slots than ten.

**Opening a PR also spends a slot** via its automatic review — a burst of new PRs eats the drip while you wonder why nothing is moving.

## Verifying a review actually happened

**The `CodeRabbit` status check reports `pass` while rate-limited.** It is not evidence. The real signal is the **walkthrough comment** — the first CodeRabbit issue-comment on the PR, updated in place on each pass.

```bash
H=$(gh pr view PR --json headRefOid --jq '.headRefOid')
gh api "repos/OWNER/REPO/issues/PR/comments" \
  --jq '[.[]|select(.user.login=="coderabbitai[bot]")][0]|"upd=\(.updated_at)"'
gh api "repos/OWNER/REPO/issues/PR/comments" \
  --jq '[.[]|select(.user.login=="coderabbitai[bot]")][0].body' \
  | grep -oE '(Actionable comments posted: [0-9]+|No actionable comments were generated|Review limit reached|Review skipped|[0-9a-f]{40})'
```

Read the verdict **and** the two SHAs it names — that is the range reviewed. The second must equal the head.

| What you see | What it means |
|---|---|
| `No actionable comments were generated` + range reaching head | Genuinely clean. |
| `Actionable comments posted: N` | Real findings; address them. |
| `Review limit reached` | **Not reviewed**, whatever the check says. |
| `Review skipped — No new commits` | CodeRabbit asserts head is already covered. Acceptable when the unreviewed delta is trivial — check `git log <lastReviewed>..<head>` and say plainly that you are making a judgement call. |
| A length-0 review record at head | **Ambiguous.** Not proof of anything. Fall back to the walkthrough. |

### Zero unresolved threads is not clean

**Outside-diff findings live in the review body, not as threads.** A PR can show zero unresolved threads and a green check while carrying a Major finding.

```bash
gh api repos/OWNER/REPO/pulls/PR/reviews \
  --jq '[.[]|select(.user.login=="coderabbitai[bot]" and (.body|length)>0)]|last|"body_at=\(.commit_id[0:9])"'
gh api repos/OWNER/REPO/pulls/PR/reviews \
  --jq '[.[]|select(.user.login=="coderabbitai[bot]" and (.body|length)>0)]|last|.body' \
  | grep -c 'Outside diff range'
```

Check the body's `commit_id` — a block from an older head may already be addressed.

Thread count:

```bash
gh api graphql -f query='{repository(owner:"OWNER",name:"REPO"){pullRequest(number:PR){reviewThreads(first:60){nodes{isResolved comments(first:1){nodes{path body}}}}}}}' \
  --jq '[.data.repository.pullRequest.reviewThreads.nodes[]|select(.isResolved==false)]|length'
```

## Gotchas

- **Bot login differs by API.** REST is `coderabbitai[bot]`; GraphQL is `coderabbitai`. The wrong filter silently returns nothing and reads as "clean".
- **A suggested fix can be wrong.** Treat proposed diffs with the same scepticism as findings — an over-narrow key, a trim that removes load-bearing rationale.
- **Severity predicts nothing.** Findings rated Trivial have exposed non-discriminating tests, an op-authoring path that could describe values a row does not hold, and prose asserting the opposite of its meaning. Follow them properly or rebut them with evidence; do not wave them through because of the label.
- **Rebuttals work.** A well-evidenced reply is often accepted and the finding withdrawn. Verify before complying *and* before refusing.

## Related

- `address-coderabbit-review` — triaging and answering findings once you have them.
- `drive-epic` — the merge gate these checks feed.
