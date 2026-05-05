---
description: Save this conversation's visible turns (user input + assistant text replies) to a markdown file
argument-hint: <output-filename>
---

Run the following bash command exactly and report stdout to the user:

CLAUDE_SESSION_ID="${CLAUDE_SESSION_ID}" ~/.dotfiles/claude/bin/save-transcript "$ARGUMENTS"
