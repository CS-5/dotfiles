# CLAUDE.md

These are the top user-level instructions for AI agents. These MUST be respected and followed exactly. They may be supplemented by project-specific guidance.

## Session Start

At the beginning of each session, check for `.carson/ai/lessons.md` and `.carson/ai/todo.md` at the repo root. If either exists, read and internalize them before proceeding.

## `.carson` Directory

`.carson` is a persistent local directory, ignored by the system's global `.gitignore`. DO NOT ADD IT TO THE REPO's `.gitignore`. It will not be checked into the repo. Only create subdirectories when you have content to write.

### `.carson/docs`

User-supplied documentation for AI agents to reference. The user may place docs here for packages, libraries, APIs, or tools used by the project. When researching how to use a dependency or tool:

1. **Check `.carson/docs` first** — it is curated and more reliable than web searches
2. Fall back to web searches only for topics not covered there
3. Note: this directory will not have comprehensive docs for everything — use judgment on when to look elsewhere

Do not write to this directory. It is maintained by the user.

### `.carson/ai`

AI agent workspace. Use it for:

- `lessons.md` — patterns, mistakes, and rules to prevent them
- `todo.md` — task tracking for multi-step work (use INSTEAD of built-in TaskCreate tools)

### `.carson/ai/scratchpad`

Workspace for AI-generated artifacts that have lasting value: analysis scripts, data processing output, generated reports, or reference material worth keeping. Use this when:

- You produce a script or output the user may want to review or reuse
- Analysis results should persist beyond the current conversation
- You need a place to write files that are not part of the project source

Do NOT use this for throwaway/temporary code. If the user would never need to see it, keep it ephemeral.

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

- After ANY correction from the user: ALWAYS update `.carson/ai/lessons.md`
- Write rules for yourself that prevent the same mistake
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

## Task Management

For multi-step tasks, use `.carson/ai/todo.md` (NOT the built-in TaskCreate/TaskUpdate tools):

1. **Plan First**: Write plan with checkable items
2. **Verify Plan**: Check in before starting implementation
3. **Track Progress**: Mark items complete as you go
4. **Explain Changes**: High-level summary at each step
5. **Document Results**: Add review section
6. **Capture Lessons**: Update `.carson/ai/lessons.md` after corrections

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
