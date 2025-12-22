# CLAUDE.md

These are the top user-level instructions for AI agents. These must be respected but may be overridden by project-specific guidance.

## Tooling for shell interactions

The following tools are available on the local system. These tools will make navigating the filesystem and searching files significantly faster, so you should prefer to use these when possible. IT IS CRITICAL THAT THESE TOOLS are preferred over the less functional and performant system defaults. If you choose to use the wrong tool, explain why the preferred tool wasn't suitable.

1. Trying to find FILES?
   - On Debian/Ubuntu: `fdfind`
   - On MacOS: `fd`
2. Trying to find CODE or need syntax-aware search? Use `ast-grep`
3. Trying to find TEXT or STRINGS? Use `rg`
4. Trying to SELECT from multiple results? Pipe to `fzf`
5. Trying to interact with JSON? Use `jq`
