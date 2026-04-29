---
name: coderabbit-review
description: Process CodeRabbit review comments on a GitHub PR - verify each finding, then either fix and push, or reply with a justification when ignoring. Handles both inline review comments and conversation comments, and resolves review threads via the GitHub GraphQL API. Use when the user mentions CodeRabbit reviews, addressing CodeRabbit feedback, triaging bot comments, or resolving PR review threads.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# CodeRabbit Review Handler

Triages CodeRabbit review comments on a GitHub PR. For each comment you verify the finding against current code, then either **fix it** (commit + push + resolve) or **ignore it** (reply with a reason + resolve once CodeRabbit acknowledges).

## When to use

- User asks to "address CodeRabbit", "process the bot review", "go through PR review comments", "triage CodeRabbit feedback", or names a PR with pending CodeRabbit threads.
- Only applies to comments authored by `coderabbitai` / `coderabbitai[bot]`.

## Required inputs

Ask the user if any are missing — do not guess:

- **PR number or URL** (e.g. `123` or `https://github.com/owner/repo/pull/123`).
- **Working branch**: confirm the PR branch is checked out locally (needed to fix and push). If the user wants triage-only (reply + resolve without code changes), note that.

Derive `OWNER`, `REPO`, and `PR` from the URL/number plus `gh repo view --json nameWithOwner -q .nameWithOwner`.

## Workflow

```
CodeRabbit Triage Progress:
- [ ] Step 1: Confirm PR, branch checked out, working tree clean
- [ ] Step 2: Fetch all CodeRabbit threads (inline + conversation) with IDs
- [ ] Step 3: For each thread, parse the "Prompt for AI Agents" block
- [ ] Step 4: Verify the finding against current code
- [ ] Step 5: Decide FIX vs IGNORE vs DEFER (record reasoning)
- [ ] Step 6a: For FIX — apply edit, stage, commit, push
- [ ] Step 6b: For IGNORE — reply to the comment with the reason
- [ ] Step 7: After push (or after CodeRabbit ack on IGNORE), resolve the thread
- [ ] Step 8: Re-check the PR for any CodeRabbit replies that push back
- [ ] Step 9: Summarize: fixed / ignored / deferred counts and remaining open threads
```

## Step 1: Preflight

Run in parallel:

```bash
gh pr view $PR --json number,headRefName,headRepositoryOwner,headRepository,baseRefName,isDraft,url
git status --porcelain
git rev-parse --abbrev-ref HEAD
```

Verify:
- Current branch matches `headRefName` (or warn the user and ask before switching).
- Working tree is clean (otherwise ask before making new commits on top).

## Step 2: Fetch CodeRabbit threads

CodeRabbit uses **review threads** (inline) and **issue comments** (conversation). Fetch both.

### Review threads (inline) — via GraphQL

This returns thread IDs (needed to resolve), comment IDs, resolution state, and bodies in one call:

```bash
gh api graphql -F owner="$OWNER" -F repo="$REPO" -F pr=$PR -f query='
query($owner:String!, $repo:String!, $pr:Int!) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$pr) {
      reviewThreads(first:100) {
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          comments(first:50) {
            nodes {
              id
              databaseId
              author { login }
              body
              url
              createdAt
            }
          }
        }
      }
    }
  }
}'
```

Filter to threads where the **first comment's author login** starts with `coderabbitai` AND `isResolved` is `false`. Keep unresolved replies from CodeRabbit on the same thread — they may be pushback on an earlier human reply.

### Conversation comments (issue comments)

```bash
gh api "repos/$OWNER/$REPO/issues/$PR/comments?per_page=100" \
  --jq '.[] | select(.user.login | startswith("coderabbitai")) | {id, body, html_url, created_at}'
```

These are not tied to a review thread and cannot be "resolved" — they are replied to via issue comments.

## Step 3: Parse the "Prompt for AI Agents" block

Each CodeRabbit comment typically embeds:

```
<details>
<summary>🤖 Prompt for AI Agents</summary>

```
Verify each finding against the current code and only fix it if needed.

<the actionable instruction>
```

</details>
```

Extract the instruction between the inner code fences. If a comment has no prompt block, treat the visible comment body as the instruction. Always read the surrounding comment body too — it usually includes the rationale and a suggested diff.

## Step 4: Verify the finding

**Do not trust the bot blindly.** For each comment:

1. Open the file at the referenced path and line (`path` + `line` from the thread).
2. Read a meaningful window around it — the bot may be commenting on stale code.
3. Re-derive whether the concern is valid:
   - Is the code still there? (`isOutdated: true` threads are usually safe to skip with a short note.)
   - Is the bug real, or does the bot misread the control flow?
   - Does the fix improve correctness/safety, or is it stylistic churn that conflicts with repo conventions?
4. Grep for related usages if the change has ripple effects.

Record a one-line verdict per thread: `FIX | IGNORE | DEFER` plus a one-sentence reason.

### Triage guidance

| Verdict | When to use |
|---------|-------------|
| **FIX** | Real bug, security issue, correctness gap, or clearly-better idiom that matches repo conventions. |
| **IGNORE** | False positive, stylistic disagreement with repo conventions, outdated context, or suggestion conflicts with intentional design. |
| **DEFER** | Valid but out of scope for this PR — reply explaining the follow-up plan, then resolve. |

## Step 5a: Apply a FIX

1. Edit the file(s) with the smallest change that addresses the concern. Don't bundle unrelated cleanups.
2. Run the project's test/lint gates for the touched area (e.g. `bundle exec rspec <file>`, `bin/rubocop <file>`). If the repo has a full CI script, prefer the scoped command for speed.
3. Stage only the files you changed and commit. Reference the comment in the message:

   ```bash
   git add <paths>
   git commit -m "$(cat <<'EOF'
   Address CodeRabbit: <short summary>

   Refs: <comment html_url>
   EOF
   )"
   ```

4. Push to the PR branch:

   ```bash
   git push
   ```

5. After the push lands, **resolve the thread** (Step 7). Do not wait for CodeRabbit to re-review before resolving a fix — the commit speaks for itself.

If multiple fixes are independent, batch them into one logical commit per theme rather than one-commit-per-comment (keeps the PR history readable). Group by file/feature, not by bot comment.

## Step 5b: Reply for IGNORE / DEFER

Replies differ by comment type.

### Reply to an inline review thread

Use the REST reply-to-review-comment endpoint. You need the `databaseId` of the **first (top-level) CodeRabbit comment** in the thread (the `id` from `comments[0].databaseId` in the GraphQL result):

```bash
gh api -X POST \
  "repos/$OWNER/$REPO/pulls/$PR/comments/$COMMENT_DATABASE_ID/replies" \
  -f body="$(cat <<'EOF'
Thanks — skipping this one because <one-sentence reason grounded in the code>.

<optional: link to the convention, prior decision, or follow-up issue>
EOF
)"
```

### Reply to a conversation (issue) comment

Issue comments don't have "replies" — post a new issue comment that quotes or links back:

```bash
gh api -X POST \
  "repos/$OWNER/$REPO/issues/$PR/comments" \
  -f body="$(cat <<'EOF'
Re: <coderabbit comment html_url>

Skipping because <reason>.
EOF
)"
```

### Reply tone

- Be specific. "Not applicable" is not enough — say **why**, referencing the code or convention.
- One or two sentences. No apology, no filler.
- If deferring, link to a follow-up issue or say you'll open one.

## Step 6: Wait for CodeRabbit and handle pushback

CodeRabbit often replies to IGNORE justifications:

- **Acknowledgement** (e.g. "Understood, thanks for the context") → proceed to resolve.
- **Pushback** (it restates the concern with new evidence) → re-verify with the new info:
  - If the pushback has a point, switch to FIX.
  - If it's still wrong, reply once more with more detail, then resolve anyway — don't get stuck in a loop. Two rounds max.

Re-fetch the thread after a short wait, or on the next run of this skill:

```bash
gh api graphql -F owner="$OWNER" -F repo="$REPO" -F pr=$PR -f query='<same query as Step 2>'
```

Look for new comments in the thread authored by `coderabbitai` after your reply timestamp.

## Step 7: Resolve the thread

Inline review threads only — issue comments have no resolve concept.

```bash
gh api graphql -F threadId="$THREAD_ID" -f query='
mutation($threadId:ID!) {
  resolveReviewThread(input:{threadId:$threadId}) {
    thread { id isResolved }
  }
}'
```

Resolve when:
- **FIX**: immediately after the commit is pushed.
- **IGNORE**: after CodeRabbit has acknowledged, or after your second (final) reply if it keeps pushing back on a clear false positive.
- **DEFER**: after posting the deferral reply.

Never resolve a thread without a corresponding commit or reply — leave an audit trail.

## Step 8: Final sweep

After processing all threads:

```bash
# Re-fetch to confirm nothing is left
gh api graphql -F owner="$OWNER" -F repo="$REPO" -F pr=$PR -f query='<Step 2 query>' \
  | jq '.data.repository.pullRequest.reviewThreads.nodes
        | map(select(.isResolved == false
                     and (.comments.nodes[0].author.login | startswith("coderabbitai"))))
        | length'
```

Report to the user:
- Count of threads **fixed** (with the commit SHA(s)).
- Count **ignored** (with one-line reasons).
- Count **deferred** (with follow-up links).
- Count **still open** (waiting on CodeRabbit reply or requiring human decision).

## Anti-patterns

- **Do NOT** blindly apply every CodeRabbit suggestion. Many are stylistic and conflict with repo conventions.
- **Do NOT** resolve a thread without replying or committing — reviewers need to see why.
- **Do NOT** amend earlier commits on a pushed branch to fold in CodeRabbit fixes; create new commits.
- **Do NOT** `--force` push to address CodeRabbit. Normal push only.
- **Do NOT** open new issues/PRs or send Slack messages as part of this skill unless the user asks.
- **Do NOT** bundle unrelated refactors into a "CodeRabbit fix" commit — keep the diff tight and on-topic.
- **Do NOT** reply with empty or generic text like "won't fix" — always state the reason.

## Permissions needed

This skill shells out to `gh` and `git`. The user may need to approve:

- `Bash(gh api:*)`
- `Bash(gh pr view:*)`
- `Bash(git add:*)`, `Bash(git commit:*)`, `Bash(git push:*)`

Do not request `git push --force` or `--no-verify` — those are denied by policy.
