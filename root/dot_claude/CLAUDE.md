# CLAUDE.md

These are the top user-level instructions for AI agents. These MUST be respected and followed exactly. They may be supplemented by project-specific guidance.

## `.carson` Directory

Project-local scratchpad at `<repo-root>/.carson/`. Ignored by global gitignore — do NOT add to the repo's `.gitignore`. Create on-demand only.

- `.carson/docs/` — User-curated reference docs. Check here before web searches. Read-only.
- `.carson/scratchpad/` — One-off tools, temp files, and implementation plans for the current project. Not for throwaway code the user would never review.

## Workflow Orchestration

### 1. Plan Mode Default

- Enter plan mode for tasks with architectural decisions or unclear scope
- Simple, well-specified tasks (clear what + where + how) can skip plan mode
- If something goes sideways, STOP and re-plan immediately — do not keep pushing

### 2. Subagent Strategy

- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution

### 3. Self-Improvement Loop

- After ANY correction from the user: commit the lesson to memory
- Write rules that prevent the same mistake from recurring
- Ruthlessly iterate on these lessons until mistake rate drops

### 4. Verification Before Done

- NEVER mark a task complete without proving it is high quality
- Diff behavior between main and your changes when relevant
- Ask yourself: "Would a staff engineer approve this?"

### 5. Demand Elegance (Balanced)

- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for simple, obvious fixes — don't over-engineer
- Challenge your own work before presenting it

### 6. Autonomous Bug Fixing

- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests — then resolve them
- Zero context switching required from the user

## Core Principles

- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what's necessary. Avoid introducing bugs.

## Shell Tools

When running Bash commands for search or file operations, ALWAYS prefer these tools over less functional defaults:

1. Finding FILES → `fd` (macOS) / `fdfind` (Debian/Ubuntu)
2. Syntax-aware CODE search → `ast-grep` / `sg`
3. Finding TEXT or STRINGS → `rg`
4. Selecting from multiple results → pipe to `fzf`
5. Interacting with JSON → `jq`

Note: Claude Code's built-in Grep, Glob, and Read tools are acceptable for simple, single-shot searches. Use the shell tools above when you need advanced features (e.g., multi-line patterns, syntax-aware matching, complex filtering, or piped workflows).
