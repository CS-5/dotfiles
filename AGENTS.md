# AGENTS.md

## Repository Overview

This is a personal dotfiles repository managed with [chezmoi](https://www.chezmoi.io/). It contains configuration files for various development tools including Git, Fish shell, SSH, Docker, and development environments.

## Key Scripts

### Installation Scripts

- `./scripts/install-dotfiles.sh` - Standard installation script; prompts for identity interactively
- `./install.sh [--identity personal|journalytic|kirbtech]` - Dev container install with auto-detected or explicit identity

### Development Scripts  

- `./render.sh [--identity IDENTITY] [--dc] [--codespaces] <template-file>` - Renders chezmoi templates to stdout for testing. Drives the real `.chezmoi.toml.tmpl` via env overrides so output matches a live apply

## Architecture

### Template System

- All configuration files are in `root/` directory as chezmoi templates (`.tmpl` extension)
- `.chezmoi.toml.tmpl` defines data variables and environment detection
- Templates use Go template syntax with conditional logic for different environments

### Environment Detection

The dotfiles adapt based on environment variables:

- `REMOTE_CONTAINERS_IPC` - Detects dev container environment
- `CODESPACES` - Detects GitHub Codespaces environment
- `DOTFILES_SOURCE_DIR` - Override source directory (defaults to current directory for install.sh)

### Identity System

The `identity` data variable drives work-specific configuration. It is set once via `promptStringOnce` during `chezmoi init` and stored in the local chezmoi config.

Valid values: `personal`, `journalytic`, `kirbtech`

- **personal** — no work context; no `.gitconfig-work` included
- **journalytic** — uses `carson@journalytic.com` as work email
- **kirbtech** — uses `carson.seese@kirbtech.com` as work email

On non-DC machines with a work identity, `.gitconfig-work` is included only for repos under `~/dev/work/` (via `includeIf`). On dev containers, it is included unconditionally.

**Install script usage:**
```bash
./install.sh --identity kirbtech   # explicit
./install.sh                       # auto-detect from repo org; else prompt (TTY)
```

`install.sh` resolves identity in this order: explicit `--identity` flag → auto-detection from the repo org (`GITHUB_REPOSITORY` / workspace remote, work orgs only) → interactive `select` prompt when stdin is a TTY → error requiring `--identity` when non-interactive (cloud-init, CI, dev container hooks).

### Git Signing

Commits are signed with an SSH key. The signing **public** key resolves at `chezmoi init` time with this precedence: `DOTFILES_SIGNING_KEY` env var → `~/.ssh/git_signing.pub` (per-host override) → a committed canonical default. Because the public key is non-secret and always available, signing works out of the box on every machine — including dev containers, which sign using the host's forwarded SSH agent (no local key file needed).

The `gitSign` data flag gates all signing config (`dot_gitconfig.tmpl`, `allowed_signers.tmpl`). It is true everywhere **except Codespaces**, where GitHub signs commits server-side with its own web-flow key and the forwarded signing key is unavailable. The matching **private** key must be loaded in the SSH agent wherever commits are made.

On real hosts (WSL, VMs, bare metal), `install.sh` runs `scripts/generate-signing-key.sh` to create a per-host `~/.ssh/git_signing` key before applying. When that private key file is present, `dot_gitconfig.tmpl` sets `signingkey` to the file path (`gitSigningKeyFile`) and signs directly from disk with no agent; otherwise it falls back to the `key::` public-key literal and the forwarded agent.

### Tool Management

CLI tools are managed by [mise](https://mise.jdx.dev/) via `root/private_dot_config/mise/config.toml.tmpl`. Language SDKs (go, node, bun) are conditionally included only outside dev containers (`not .isDc`). Tools are installed automatically during `chezmoi apply` via the `run_onchange_after_01-mise-install.sh.tmpl` script.

### Chezmoi Automation Scripts

Post-install scripts in `root/.chezmoiscripts/` run automatically during `chezmoi apply`:

- `run_onchange_after_01-mise-install.sh.tmpl` - Installs mise tools when config changes
- `run_after_install-claude-config.sh.tmpl` - Syncs Claude Code configuration
- `run_onchange_after_02-install-completions.sh.tmpl` - Generates fish completions for `gh` and `docker`

### Environment Variables

Simple key-value environment variables (e.g., `VISUAL`, `HOMEBREW_NO_AUTO_UPDATE`) are centralized in template partials under `root/.chezmoitemplates/`. Each partial renders the same variables in the syntax for its target shell:

| Partial | Syntax | Consumed by |
| --- | --- | --- |
| `env-posix` | `export VAR=val` | `dot_bashrc.tmpl`, `dot_zshrc.tmpl` |
| `env-fish` | `set -gx VAR val` | `config.fish.tmpl` |
| `env-powershell` | `$env:VAR = "val"` | `Microsoft.PowerShell_profile.ps1.tmpl` |
| `env-windows-persist` | `[Environment]::SetEnvironmentVariable(...)` | `run_onchange_after_03-windows-env.ps1.tmpl` |

**To add a new env var:** Add one line in the appropriate syntax to each partial that should receive it. Use chezmoi template guards (e.g., `{{ if .isMac }}`) for conditional vars. Not all vars need to appear in every partial — add only to the shells/platforms where the var applies.

**Complex setup** (PATH manipulation, `brew shellenv`, tool activations like mise/starship/zoxide, SSH agent) belongs in each shell's own config file or `conf.d/` files — not in the centralized partials.

On Windows, `run_onchange_after_03-windows-env.ps1.tmpl` persists env vars from `env-windows-persist` to the User registry via `[Environment]::SetEnvironmentVariable()`. It re-runs automatically when the partial's content changes.

### External File Management

- `root/.chezmoiexternal.toml.tmpl` - Pulls external dependencies (fundle, eget binaries)
- `root/.chezmoiignore.tmpl` - Controls which files chezmoi ignores per environment

### Key Files

- `root/.chezmoi.toml.tmpl` - Main chezmoi configuration with environment variables
- `root/dot_gitconfig.tmpl` - Git configuration with conditional work includes
- `root/dot_gitconfig-work.tmpl` - Work-specific git configuration
- `root/private_dot_config/fish/config.fish.tmpl` - Fish shell configuration
- `root/dot_bashrc.tmpl` - Bash configuration (Homebrew, starship, mise, zoxide, mcfly)
- `root/dot_zshrc.tmpl` - Zsh configuration

## Common Commands

```bash
# Install dotfiles
./scripts/install-dotfiles.sh

# Install tools + dotfiles in dev container
./install.sh

# Test template rendering
./render.sh root/dot_gitconfig.tmpl

# Manual chezmoi operations (after install)
chezmoi diff                 # Show pending changes
chezmoi apply               # Apply changes
chezmoi status              # Show status
```

## Development Guidelines

### Change Management

1. **Changes must be extremely thoughtful** - Ensure any modification is thoroughly tested and validated before considering it final. No mistakes are acceptable.

2. **Keep changes simple and maintainable** - If a change grows in complexity, ask for feedback/instruction or suggest ways to refine the scope to remain simple and maintainable.

3. **Documentation maintenance** - Regularly check and update documentation (including AGENTS.md) for stale content when patterns or configurations change.

4. **Template formatting** - Template files containing Go template strings must be formatted carefully to preserve correct whitespace and avoid trimming issues.

5. **NEVER test on host machine** - Changes must never be tested on the host machine. `chezmoi apply` should be considered dangerous unless run within a Docker container.
