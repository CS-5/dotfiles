# CLAUDE.md

These are the top user-level instructions for AI agents. These must be respected but may be overridden by project-specific guidance.

## Tooling for shell interactions

The following tools are available on the local system. These tools will make navigating the filesystem and searching files significantly faster, so you should prefer to use these when possible.

- Trying to find FILES? Use `fd`
- Trying to find TEXT or STRINGS? Use `rg`
- Trying to find CODE or need syntax-aware search? Use `ast-grep`
- Trying to SELECT from multiple results? Pipe to `fzf`
- Trying to interact with JSON? Use `jq`

