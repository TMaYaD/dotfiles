---
name: next-epics
description: Agile product manager that fetches all open GitHub issues, clusters related ones into groups that must be picked up together, and ranks the n most valuable groups. Use when the user wants to prioritise work as coherent streams rather than isolated tickets, pick the next epic, or triage a backlog where issues share a primitive, a decision, or an ordering. Default n=5.
argument-hint: [n] [exclusions]
allowed-tools: Bash
---

# Next Epics

You are an agile product manager helping to prioritise engineering work **as groups**.

`/next-issues` ranks tickets in isolation. That is the wrong unit when issues share a
class, a primitive, or a decision: picking one member of a class and fixing it locally
is exactly the drift the other members exist to prevent. This skill picks **groups**.
When the operator picks a group, they pick every issue in it.

## Inputs

- **n**: Number of groups to select. Default `5`. Read from `$ARGUMENTS` (e.g. `/next-epics 3`).
- **exclusions**: Free-text in `$ARGUMENTS` naming issues, epics, or areas to leave out
  (e.g. "exclude #715 and its children, and #440 which is in flight"). Honour them, and
  say at the top what you excluded and why. An excluded epic excludes its children.

## Workflow

```
Next Epics Progress:
- [ ] Step 1: Fetch open issues (incl. parent/sub-issue links) and open PRs
- [ ] Step 2: Filter in-flight and operator-excluded issues
- [ ] Step 3: Build the relatedness graph
- [ ] Step 4: Form groups and apply the bonding test
- [ ] Step 5: Weigh each group as a single unit
- [ ] Step 6: Present top n groups with entry point and internal order
- [ ] Step 7: Apply ready-for-development label (optional, ask first)
```

## Step 1: Fetch

```bash
gh repo view --json nameWithOwner -q .nameWithOwner
```

```bash
gh issue list --state open --limit 300 \
  --json number,title,labels,milestone,assignees,createdAt,updatedAt,url,body
```

```bash
gh pr list --state open --limit 200 --json number,title,body,headRefName,url
```

GitHub's native sub-issue links are the strongest grouping signal available and are **not**
in the list payload. Fetch them for anything that looks like a parent (an `epic` label, an
`[Epic]` title) and for the issues you end up grouping:

```bash
gh issue view <number> --json number,title,parent,subIssues,subIssuesSummary \
  | jq -r '"#\(.number) parent=\(.parent.number // "-") subs: \([.subIssues.nodes[] | select(.state == "OPEN") | .number] | join(","))"'
```

Note the shape: `subIssues` is `{nodes: [...]}`, not a bare array, so `.subIssues[]` fails
with `Cannot index array with string`. Pipe to an external `jq` rather than using `gh --jq`,
which errors unhelpfully on this payload. Expect `subIssuesSummary.total` to be `0` for most
issues — in practice native links exist only on deliberately-authored epics, so the
cross-reference and shared-primitive signals below carry most of the grouping.

Extract the cross-reference graph from issue bodies in one pass rather than reading each
body serially:

```bash
gh issue list --state open --limit 300 --json number,body \
  -q '.[] | "\(.number)>\(.body // "" | [scan("#[0-9]+")] | unique | join(" "))"'
```

Then read the full bodies of the candidates that survive Step 4 — grouping decisions rest
on *why* issues reference each other, and the reference graph alone cannot tell you that.

## Step 2: Filter

Remove from the pool:

- Issues with an open PR referencing them (`#N`, `closes/fixes/resolves #N`) or a matching
  branch name (`issue-N`, `feat/N-*`).
- Issues the operator excluded, plus the children of any excluded epic.
- `wontfix`, `duplicate`, `blocked` — unless asked to include them.

Report the filtered count at the top of your output. If a filtered issue is a member of a
group you present, **keep the group and mark that member as in-flight** — the operator needs
to know the group is already partly moving.

## Step 3: Build the relatedness graph

Signals, strongest first:

| Signal | How to read it |
|---|---|
| **Native sub-issue / parent link** | Authoritative. A parent and its children are one group unless the parent is a milestone-sized container. |
| **Shared primitive or shared fix** | Issues that each say "survey the class", "adopt the same rule", "whichever lands first establishes the pattern". The strongest non-native bond. |
| **Explicit ordering** | "Order this after #N", "#N should land first so its result informs this". |
| **Shared decision or ADR** | Two issues that cannot both be resolved without agreeing one thing (a predicate, a contract, a vocabulary term). |
| **Shared origin** | Deferred from the same PR review, split out of the same triage. Weak on its own — a common origin is not a common fix. |
| **Same file or DAO** | Weakest. Corroborates a bond; never establishes one. |

## Step 4: Form groups, then apply the bonding test

A set of issues is a group only if it passes **all three**:

1. **Shared deliverable.** There is one artefact — a primitive, a contract, a decision, a
   canonical component — that every member adopts. Name it. If you cannot name it in a
   sentence, this is a theme, not a group.
2. **Drift cost.** Picking one member alone produces a worse outcome than picking none:
   two half-migrated call sites, two rules for one problem, a decision taken twice. State
   that cost concretely.
3. **One appetite.** The group is plausibly one stream of work by one owner. A group that
   needs three quarters is a milestone; split it or leave it in the backlog.

Anti-patterns that look like groups and are not:

- **Label buckets.** Every `bug` is not a group. Neither is every `tech-debt`.
- **Subsystem buckets.** "Everything touching the sync layer" is a map region, not a pick.
- **Milestone buckets.** A milestone is a schedule, not a shared deliverable.
- **Chronology.** Filed the same day, or deferred from the same PR, without a shared fix.
- **Same screen.** Two issues in one flow are not one pick. A planning step hosts several
  independent concerns; landing in the same file is not adopting the same artefact.
- **Consumer relationships.** "B's results should display using A's component" makes B a
  *consumer* of A, not a co-author of it. A can ship without B and B adopts whatever A
  produced. That is an ordering note, not a bond — record it as sequencing and keep them
  apart.

### Do not force grouping

Grouping is a claim that these issues must move together. Over-grouping is not a harmless
rounding error — it hands the operator a bigger, vaguer pick than the work actually is, and
buries a tight two-issue stream inside a loose four-issue one.

- **Prefer two tight groups to one loose one.** When a set passes the bonding test only by
  appealing to a broad theme ("the planning surfaces", "the sync layer"), look for the seam.
  Usually there are two shared deliverables, not one. Split there and rank both.
- **A group of one is a legitimate result.** Some issues genuinely stand alone, and a
  standalone issue can outrank a four-issue group. Present it in the ranked list as a group
  of one — do not pad it with loosely-related work to justify a slot, and do not demote it
  to a footnote because it lacks company.
- **Never split a group to hit `n`, and never merge to fill it.** Present fewer or more
  groups instead; `n` is the operator's appetite, not a quota to satisfy.

## Step 5: Weigh each group as one unit

Score the group, not its members. Use judgment, not a formula.

| Dimension | What to look for at group scale |
|---|---|
| **Strategic value & user impact** | What does the *whole* group deliver that no member delivers alone? A flow that works end to end beats three tickets that each improve a step. |
| **Compounding risk** | Does leaving it open let the drift keep spreading? A class with new members arriving every month is more urgent than a static one. |
| **Unblocking potential** | Does the group's shared deliverable unblock issues outside it? A primitive three other groups will lean on scores high. |
| **Momentum & context freshness** | Was the surrounding work just merged? Groups whose context is still warm cost far less than ones that need re-derivation. |
| **Decision debt** | Does the group need an operator decision before work can start? Say so — that is a prerequisite, not a blocker, and the operator can clear it in a sentence. |
| **Appetite vs payoff** | Total size across all members against what the group delivers. A four-issue group with one cheap entry point beats a two-issue group that is uniformly expensive. |

Ties go to the group whose shared deliverable more other work depends on.

## Step 6: Present

State the filtered count and any exclusions first. Then, for each group:

```
### 1. <Group name — the shared deliverable, not a theme>
**Issues**: #A, #B, #C  (<total size: S / M / L>)
**Milestone**: <milestone, or "none" — say so plainly if the group's value is
independent of milestones rather than penalising it>
**Shared deliverable**: <the one artefact every member adopts, in a sentence>
**Entry point**: #<number> — <why this one lands first>

<2-5 sentences: what the group delivers as a whole, why now, and what the
freshest context is. Be specific — cite issue numbers, files, ADRs.>

**If you pick only one**: <the concrete drift cost — what goes wrong if this is
picked apart. This is the justification for the group existing.>

**Internal order**: #A (establishes X) → #B (adopts it at N call sites) → #C (design
decision, cheaper once A has landed)

---
```

For a **group of one**, keep the same slot and shape but drop the two fields that only
mean something for a set — replace *If you pick only one* with a one-line note on why it
bonds with nothing, and omit *Internal order*. Do not apologise for it being one issue.

Where two groups are sequenced but not bonded — one consumes what the other produces —
say so in each entry. It tells the operator that taking them in order is cheaper, without
implying they must be taken together.

After the ranked groups:

- **Also ungrouped** — singletons that did not make the cut, one line each. These are
  candidates the operator may want instead of a ranked pick, not a lesser tier of work.
- **Passed over** — groups that were formed and cut, one line each, so the operator can
  override. Include any group you rejected at the bonding test and why — especially one
  you initially formed and then split or dissolved, since that is the reasoning most worth
  showing.

## Step 7: Apply label (optional)

Ask before labelling, and name the consequence if the label is a live automation trigger
in this repo:

> "Should I apply `ready-for-development` to the issues in group(s) N?"

On a yes, label **every issue in the chosen group**, not just the entry point — the group
is the unit:

```bash
gh issue edit <number> --add-label "ready-for-development"
```

If the label does not exist:

```bash
gh label create "ready-for-development" --color "0075ca" --description "Prioritised and ready to be picked up"
```

## Anti-patterns

- **Do NOT** present a group you cannot state a shared deliverable for.
- **Do NOT** pad a group. A group of one that stands on its own beats a group of four with
  two passengers.
- **Do NOT** merge two tight groups because they share a screen, a flow, or a consumer
  relationship — that buries both.
- **Do NOT** dissolve a genuine group because one member is large — report the size and let
  the operator scope it.
- **Do NOT** split or merge groups to fit `n`. Present however many the backlog actually has.
- **Do NOT** pick issues that already have an open PR — but do flag in-flight members of
  groups you present.
- **Do NOT** apply labels without asking.
- **Do NOT** open, close, or comment on issues unless explicitly asked.
