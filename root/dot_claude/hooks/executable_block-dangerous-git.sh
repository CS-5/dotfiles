#!/bin/bash

# Based on https://www.aihero.dev/this-hook-stops-claude-code-running-dangerous-git-commands
# Blocks potentially dangerous git commands from being executed by Claude.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

DANGEROUS_PATTERNS=(
  # Pushing (any form)
  "git push"
  # Destructive resets
  "git reset --hard"
  # Cleaning untracked files
  "git clean -f"
  # Force-deleting branches
  "git branch -D"
  # Discarding all working tree changes
  "git checkout \."
  "git restore \."
  # Dropping stashes
  "git stash drop"
  "git stash clear"
)

# Only match a pattern when it begins an actual command — at the start of the
# string or right after a shell separator (; & | ( newline). This avoids false
# positives when a dangerous phrase appears inside a quoted argument, e.g.
#   git commit -m "document the git push flow"
BOUNDARY='(^|[;&|(]|&&|\|\|)[[:space:]]*'

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "${BOUNDARY}${pattern}"; then
    echo "BLOCKED: '$COMMAND' matches dangerous pattern '$pattern'. The user has prevented you from doing this." >&2
    exit 2
  fi
done

exit 0