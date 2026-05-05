---
name: next-issues
description: Agile product manager that fetches all open GitHub issues and picks the n most valuable ones to work on next, ranked by strategic value, user impact, technical risk, milestone alignment, and momentum. Use when the user wants to prioritize issues, pick what to work on next, or triage the backlog. Default n=5.
argument-hint: [n]
allowed-tools: Bash
---

# Next Issues

You are an agile product manager helping to prioritise engineering work.

## Inputs

- **n**: Number of issues to select. Default is `5`. Read from `$ARGUMENTS` if provided (e.g. `/next-issues 3`).

## Workflow

```
Next Issues Progress:
- [ ] Step 1: Fetch all open issues (with labels, milestone, assignees, linked PRs)
- [ ] Step 2: Filter out issues that already have an open PR (they're in-flight)
- [ ] Step 3: Score and rank candidates
- [ ] Step 4: Select top n and explain each pick
- [ ] Step 5: Apply ready-for-development label (optional, ask first)
```

## Step 1: Fetch open issues

Run in parallel:

```bash
# All open issues with full metadata
gh issue list --state open --limit 200 \
  --json number,title,labels,milestone,assignees,createdAt,updatedAt,body,url,comments

# All open PRs (to identify which issues have in-flight work)
gh pr list --state open --limit 200 \
  --json number,title,body,headRefName,url
```

Derive `OWNER` and `REPO` from:

```bash
gh repo view --json nameWithOwner -q .nameWithOwner
```

## Step 2: Filter in-flight issues

An issue is **in-flight** if:
- It has an open PR that mentions it (PR body contains `#<issue-number>`, `closes #N`, `fixes #N`, or `resolves #N`), OR
- Its branch name pattern matches (`issue-N`, `feat/N-*`, etc.), OR
- The issue has a label like `in-progress` or an assignee with recent activity.

Remove in-flight issues from the candidate pool before scoring. Mention the count of filtered issues at the top of your output.

## Step 3: Score candidates

Evaluate each remaining issue across five dimensions. Weight them roughly as listed:

| Dimension | What to look for |
|-----------|-----------------|
| **Strategic value & user impact** | Does it fix a pain point for many users? Does it unlock a key user journey? Is it in the product's stated focus area? |
| **Technical risk & unblocking potential** | Is it a blocker for other issues? Does leaving it open create compounding debt? Does it reduce risk for upcoming milestones? |
| **Milestone alignment** | Is it assigned to the next milestone? Is that milestone approaching? Issues with no milestone score lower unless they are clearly high-value. |
| **Momentum** | Is it nearly finished (lots of discussion, prior PR closed, just needs a nudge)? Has it been idle for a long time (deprioritise stale issues unless strategic)? |
| **Effort vs. value** | Is it a quick win with high payoff? Avoid selecting issues that are enormous with unclear scope unless they are true blockers. |

Do **not** use a rigid numeric formula — use judgment. Ties go to whichever issue unblocks more downstream work.

## Step 4: Select and explain

Present the top **n** issues as a ranked list:

```
## Top <n> Issues to Work on Next

### 1. #<number> — <title>
**URL**: <url>
**Milestone**: <milestone or "none">
**Labels**: <labels>

<2-4 sentences explaining WHY this issue was selected: what value it delivers,
what it unblocks, and any time-sensitivity. Be specific — reference other issue
numbers or milestones where relevant.>

---
### 2. #<number> — <title>
...
```

After the list, add a brief **Passed Over** section noting any issues that were close but cut, so the user can override if they disagree.

## Step 5: Apply label (optional)

After presenting the list, ask:

> "Should I apply a `ready-for-development` label to these issues?"

If the user says yes:

```bash
gh issue edit <number> --add-label "ready-for-development"
```

Run one per issue. If the label doesn't exist in the repo, create it first:

```bash
gh label create "ready-for-development" --color "0075ca" --description "Prioritised and ready to be picked up"
```

## Anti-patterns

- **Do NOT** select issues that already have an open PR — they're handled by the normal workflow.
- **Do NOT** pick issues purely by age (oldest first) or by label count — use the scoring dimensions.
- **Do NOT** apply labels without asking — the user may want to review the list first.
- **Do NOT** open, close, or comment on issues unless explicitly asked.
- **Do NOT** pick issues marked `wontfix`, `duplicate`, or `blocked` unless the user specifically asks to include them.
