# CLAUDE.md

These are the top user-level instructions for AI agents. These must be respected but may be overridden by project-specific guidance.

## Tools

### `ast-grep`

You run in an environment where `ast-grep` is available; whenever a search requires syntax-aware or structural matching, default to `ast-grep --lang go -p '<pattern>'` (or set --lang appropriately) and avoid falling back to text-only tools like `rg` or `grep` unless I explicitly request a plain-text search.
