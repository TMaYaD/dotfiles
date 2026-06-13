---
name: pr-watch
description: Watch one or more open GitHub PRs and act on actionable feedback — CI failures, unaddressed review comments, merge conflicts. Concedes by fixing + pushing + resolving; combats with a 1-2 sentence rebut and leaves the marker off so the human can push back. Use when the user wants to monitor PRs (a specific list, all open on a repo, or by author), set up a scheduled remote routine, or run a one-shot pass on the current branch's PR.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent
---

# PR Watch

Watches open PRs on a repo and acts on actionable feedback. Can run as a one-shot pass in the current session, or be installed as a recurring remote routine.

## When to use

- User asks to "watch / monitor / babysit PRs", "shepherd the PRs", "keep an eye on the review loop".
- User wants a recurring routine that handles CI failures and reviewer feedback automatically.
- User asks for a one-shot status pass on one or more PRs.

## Required inputs

Ask only for what's missing — don't guess.

- **REPO** — `owner/name` (e.g. `acme/webapp`). Default to the current working directory's `gh repo view --json nameWithOwner -q .nameWithOwner`.
- **SCOPE** — one of:
  - `all-open` — every open PR on the repo
  - `author:<login>` — open PRs authored by `<login>` (e.g. `author:my-coding-bot`)
  - `list:<n>,<n>,<n>` — specific PR numbers
- **BOT_IDENTITY** — the GitHub login the agent commits / reacts as. Default to `gh api user -q .login`.
- **MODE** — `routine` (create a scheduled remote agent) or `one-shot` (run a single tick now in this session).
- **BUILD_CMDS** — the project's build/test command pipeline. Examples:
  - Flutter: `cd app && fvm flutter pub get && fvm dart run build_runner build --delete-conflicting-outputs && fvm flutter analyze && fvm flutter test`
  - Rails: `bin/setup && bin/rubocop && bin/rspec`
  - Node: `npm ci && npm run lint && npm test`
- **CONSTRAINTS** — repo-specific rules (default to: `conventional commits; no model identifiers in commit messages; no --no-verify; no force-push; no push to main`).
- **ALL_DONE_TARGET** *(routine mode only)* — optional issue URL where the routine should post a one-line "all watched PRs merged" note when the scope empties out.

## Modes

### `routine` mode — create a recurring remote agent

1. Confirm CONFIG values with the user (one `AskUserQuestion` if anything is unclear).
2. Generate a fresh UUID: `uuidgen | tr A-Z a-z`.
3. Call `RemoteTrigger` action `create` with:
   - `name: pr-watch-<repo>-<scope-hint>` (e.g. `pr-watch-acme-all-open`)
   - `cron_expression: 0 * * * *` (hourly is the floor — confirm with user if they want less frequent)
   - `enabled: true`
   - `job_config.ccr.environment_id`: confirm via the schedule skill conventions or ask
   - `session_context.model: claude-sonnet-4-6`
   - `session_context.sources`: `[{git_repository: {url: https://github.com/<REPO>}}]`
   - `session_context.allowed_tools: [Bash, Read, Write, Edit, Glob, Grep, Agent]`
   - `events[].data.message.content`: the [Tick prompt template](#tick-prompt-template) below with CONFIG block filled in
4. Output the routine ID and `https://claude.ai/code/routines/<id>` dashboard URL.

### `one-shot` mode — run a single tick in this session

1. Resolve SCOPE → list of open PR numbers.
2. For each PR, follow the [Per-tick procedure](#per-tick-procedure) below.
3. For each actionable PR, spawn an `Agent` (general-purpose, isolation: worktree) with a brief covering the specific signal and the [Disposition protocol](#disposition-protocol).
4. Report a concise summary to the user: which PRs were touched, which shepherds were spawned.

## Disposition protocol — EXACTLY ONE marker per item

For every piece of feedback, choose EXACTLY ONE disposition and produce EXACTLY ONE marker. Never both, never neither, never the wrong marker for the disposition.

| Channel | CONCEDE marker | COMBAT marker |
|---|---|---|
| Inline review thread | Push fix → reply linking commit → `resolveReviewThread` GraphQL mutation. **Do not** leave the thread open. | Reply with 1–2 sentence rebut. **Do not** resolve. |
| Conversation comment (PR / issue) | 🚀 reaction on the ORIGINAL comment via `gh api -X POST repos/$REPO/issues/comments/<id>/reactions -f content=rocket`. **Do not** post any reply. | `Re: <comment_url>` reply comment (see [format below](#combat-reply-format-on-conversation-comments)). **Do not** add 🚀. |
| PR review submission (review body) | 🚀 reaction on the review via `gh api -X POST repos/$REPO/pulls/<N>/reviews/<id>/reactions -f content=rocket`, once all inline threads are resolved. **Do not** post any reply. If endpoint rejects, fall back to a summary reply (combat semantics) and move on. | Reply comment summarising disposition. **Do not** add 🚀. |

### Forbidden combinations

Observed in the wild and produce ambiguity. Refuse to do them:

- **Concede + reply comment** — e.g. a `Re: <url>` body saying "Conceded in `<sha>`". WRONG. The fix commit and 🚀 are the entire signal.
- **Combat + 🚀** — rebut by reply only. 🚀 implies you've resolved the disagreement.
- **Concede + leave inline thread open** — resolve after the fix lands.

If you want to add a "for the record" note after concede, stop. The commit message is the record.

### Tri-state per feedback item

The agent acts only on state 3.

1. **Resolved** — thread `isResolved: true`, or comment/review carries $BOT_IDENTITY's 🚀. Skip.
2. **Combat-pending** — unresolved/unreacted, latest activity is $BOT_IDENTITY's rebut. Skip; awaiting human response.
   - Inline threads: latest thread comment is by $BOT_IDENTITY.
   - Conversation comments: $BOT_IDENTITY has a later conversation comment on this PR whose first line is `Re: <this_comment_url>`.
3. **Actionable** — anything else.

When the human (or anyone non-bot) replies after the rebut, the item flips back to actionable on the next tick.

### Combat reply format on conversation comments

Conversation comments aren't threaded on GitHub. Open every conversation-comment rebut with this exact first line:

```
Re: https://github.com/$REPO/issues/<N>#issuecomment-<id>
```

Then a blank line, then 1–2 sentences of reasoning. Next tick's parser uses this to recognise combat-pending state.

## Per-tick procedure

1. **Resolve scope** → list of open PR numbers.
   - `all-open`: `gh pr list -R $REPO --state open --json number,headRefName,author,isDraft,mergeable --limit 100`
   - `author:<login>`: same query, filter by `.author.login == "<login>"`
   - `list:<n>,<n>,<n>`: fetch each by number, skip merged/closed
2. **For each open PR `N`**:
   - `gh pr view $N -R $REPO --json state,isDraft,mergeable,mergeStateStatus,headRefOid,updatedAt`
   - `gh pr checks $N -R $REPO` — collect failed/pending
   - Inline threads via GraphQL `reviewThreads` — actionable iff unresolved AND last comment author ≠ $BOT_IDENTITY
   - Conversation comments via `gh api repos/$REPO/issues/$N/comments` — for each non-$BOT_IDENTITY comment: skip if it carries 🚀 from $BOT_IDENTITY, skip if $BOT_IDENTITY has a later comment whose first line is `Re: <comment_url>`, otherwise actionable
   - PR reviews (body): actionable iff body non-empty AND no 🚀 from $BOT_IDENTITY AND no actionable inline threads remain
   - `ACTIONABLE for this PR` = any of: CI failure, actionable threads/comments/reviews, `mergeable: CONFLICTING`, formal change request from a human reviewer
3. **For each actionable PR**: spawn an `Agent` (`general-purpose`, `isolation: worktree`) briefed with the PR number/branch, the specific signal, the [Disposition protocol](#disposition-protocol), `$BUILD_CMDS` to run before each commit, and `$CONSTRAINTS`. Do **not** post a "ready for review" tag from the shepherd — marker semantics are the signal.
4. **All-done** *(routine mode)*: if scope is empty AND `$ALL_DONE_TARGET` is set, check that target's existing comments. If no $BOT_IDENTITY comment mentions "routine can be disabled", post once: `All watched PRs are merged or closed. This routine can be disabled at https://claude.ai/code/routines.`
5. **Otherwise** exit silently. No heartbeat comments.

## Robustness rules

- If `$BOT_IDENTITY` doesn't match the authenticated `gh api user`, use the authenticated login and log a warning. Don't crash.
- Treat any `gh` / GraphQL error as "don't escalate this PR this tick" rather than aborting.
- Don't spawn more than one shepherd per PR per tick. If a worktree for that PR's branch already exists, skip.

## Tick prompt template

When creating a routine, paste this as `events[0].data.message.content` after filling in the CONFIG block:

````
# PR Watch — <fill in scope>

## CONFIG (edit per use)

```yaml
REPO: <owner/name>
BOT_IDENTITY: <github-login>
SCOPE: <all-open | author:<login> | list:n,n,n>
ALL_DONE_TARGET: <optional issue URL>
BUILD_CMDS: |
  <project build/test command pipeline>
CONSTRAINTS: |
  <repo-specific rules>
```

If a field is unset, treat it as empty / skip the dependent step. Re-read this block at every tick — don't cache assumptions.

<paste the Disposition protocol, Tri-state section, Per-tick procedure, and Robustness rules from this skill here, with $REPO / $BOT_IDENTITY / $SCOPE / etc. as literal placeholders the agent reads from the CONFIG block>
````

## Reference

- The active reference implementation is routine `pr-watch-template` (disabled) at `https://claude.ai/code/routines/trig_014xUWQ1T6SnzQVmcWwEkaeH` — clone its prompt, swap CONFIG values, enable.
- The CodeRabbit-specific variant of the same disposition loop lives in the `coderabbit-review` skill.
