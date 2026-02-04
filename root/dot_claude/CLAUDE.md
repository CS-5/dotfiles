# CLAUDE.md

These are the top user-level instructions for AI agents. These must be respected but may be overridden by project-specific guidance.

## Session Startup (REQUIRED)

At the start of EVERY session involving non-trivial work:

1. **Initialize workspace**: Check if `.carson/ai/` exists, create it if not. This directory will be automatically ignored by the global gitignore.
2. **Review lessons**: Read `.carson/ai/lessons.md` if it exists - apply relevant patterns
3. **Plan work**: Before starting implementation, write the plan to `.carson/ai/todo.md` (additional details on todo tracking below)

This is not optional. Do this proactively without being asked.

## Workflow Orchestration

### 1. Plan Mode Default

- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately - don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity

### 2. Subagent Strategy

- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution

### 3. Self-Improvement Loop

- After ANY correction from the user: update `.carson/ai/lessons.md` with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

### 3. Verification Before Done

- Never mark a task complete without proving it is high quality
- Diff behavior between main and your changes when relevant
- Ask yourself: "Would a staff engineer approve this?"

### 4. Demand Elegance (Balanced)

- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for simple, obvious fixes - don't over-engineer
- Challenge your own work before presenting it

### 6. Autonomous Bug Fixing

- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests - then resolve them
- Zero context switching required from the user

## Task Management

1. **Plan First**: Write plan to `.carson/ai/todo.md` with checkable items
2. **Verify Plan**: Check in before starting implementation
3. **Track Progress**: Mark items complete as you go
4. **Explain Changes**: High-level summary at each step
5. **Document Results**: Add review section to `.carson/ai/todo.md`
6. **Capture Lessons**: Update `.carson/ai/todo.md` after corrections

## Core Principles

- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what's necessary. Avoid introducing bugs.

## Shell tools

IT IS CRITICAL THAT THESE TOOLS are preferred over the less functional and performant system defaults.

1. Trying to find FILES?
   - On Debian/Ubuntu: `fdfind`
   - On MacOS: `fd`
2. Trying to find CODE or need syntax-aware search? Use `ast-grep`
3. Trying to find TEXT or STRINGS? Use `rg`
4. Trying to SELECT from multiple results? Pipe to `fzf`
5. Trying to interact with JSON? Use `jq`
