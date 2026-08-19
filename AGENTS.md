# AGENTS.md

## Repository Overview

This is a personal dotfiles repository managed with [chezmoi](https://www.chezmoi.io/). It contains configuration files for various development tools including Git, Fish shell, SSH, Docker, and development environments.

## Key Scripts

### Installation Scripts

- `./scripts/install-dotfiles.sh [--work-email <addr>]` - Standard installation script; `--work-email` writes `~/work.email` before applying
- `./install.sh [--work-email <addr>]` - Dev container / Linux bootstrap; `--work-email` writes `~/work.email` for non-interactive work setups

### Development Scripts  

- `./render.sh [--identity IDENTITY] [--work-email <addr>] [--dc] [--codespaces] [--data <json>] <template-file>` - Renders chezmoi templates to stdout for testing. Drives the real `.chezmoi.toml.tmpl` (supplying the identity via `DOTFILES_WORK_EMAIL` while neutralizing any real `~/work.email` via `DOTFILES_WORK_EMAIL_FILE`) so output matches a live apply. `--data` passes a JSON object to chezmoi's `--override-data` to force `[data]` values (e.g. `'{"isMac":true}'` to preview macOS renders from Linux)

### User Commands

Shell-agnostic commands applied by chezmoi to `~/.local/bin` (source: `root/dot_local/bin/`), so one bash implementation serves fish, bash, and zsh. Not applied on Windows (ignored via `.chezmoiignore.tmpl`):

- `update` - Updates everything: system packages (apt or pacman on Linux, brew on macOS), mise itself, chezmoi, then `chezmoi update` (pull latest dotfiles + apply), then `mise upgrade` for the freshly pulled tool pins. The mise step is skipped over when mise is package-managed — the system-package step above already covered it
- `clean` - Prunes what `update` leaves behind: orphaned system packages and caches (`apt-get autoremove --purge`/`clean`, `pacman -Rns` of `-Qtdq` orphans + `-Sc`, `brew autoremove`/`cleanup --prune=all`), mise tool versions no longer referenced by any config (`mise prune`), and mise's download cache
- `set-work-email <addr>` - Writes `~/work.email` and re-runs `chezmoi init --apply` so the work identity takes effect (Windows gets a PowerShell function equivalent in the profile)

## Architecture

### Template System

- All configuration files are in `root/` directory as chezmoi templates (`.tmpl` extension)
- `.chezmoi.toml.tmpl` defines data variables and environment detection
- Templates use Go template syntax with conditional logic for different environments

### Environment Detection

The dotfiles adapt based on environment variables:

- `REMOTE_CONTAINERS_IPC` - Detects dev container environment
- `CODESPACES` - Detects GitHub Codespaces environment
- A `/workspaces` directory - Also treated as a dev container signal (matches install.sh; covers containers whose user isn't `vscode` and where `REMOTE_CONTAINERS_IPC` isn't set at install time)
- `DOTFILES_SOURCE_DIR` - Override source directory (defaults to current directory for install.sh)
- `DOTFILES_WORK_EMAIL` - Work email fallback when `~/work.email` is absent (the file wins; Codespaces user secrets surface as env vars)
- `DOTFILES_WORK_EMAIL_FILE` - Relocates the work-email file from `~/work.email` (used by render.sh; unset in normal use)

### Identity System

The work identity is driven by a single file, **`~/work.email`**, whose only contents are one work email address (no other text or formatting). This mirrors the per-host signing-key file pattern (`~/.ssh/git_signing.pub`). When the file is absent, the **`DOTFILES_WORK_EMAIL`** env var is consulted as a fallback (the file always wins when both exist) — this is how Codespaces get a work identity, since user secrets surface there as env vars. `.chezmoi.toml.tmpl` reads the email at render time and derives the `identity`, `isWork`, `isPersonal`, and `workEmail` data variables. The email's **domain** selects the identity:

| `~/work.email` | `identity` | `isWork` | `workEmail` |
| --- | --- | --- | --- |
| absent | `personal` | false | (empty) |
| `…@kirbtech.com` | `kirbtech` | true | the address |
| `…@journalytic.com` | `journalytic` | true | the address |
| unrecognized domain | `personal` | false | (empty) |

Add a new job by adding a `domain → identity` entry to the `$identities` dict in `.chezmoi.toml.tmpl`.

On non-DC machines with a work identity, `.gitconfig-work` is included only for repos under `~/dev/work/` (via `includeIf`). On dev containers, it is included unconditionally.

**Creating `~/work.email`:** write it directly (`printf '%s' you@work.com > ~/work.email`), use the `set-work-email` command (writes the file, then re-runs `chezmoi init --apply` — the post-install path for an already-provisioned machine or Codespace; works from any shell, with a PowerShell function on Windows), or let the install scripts do it via `--work-email`:
```bash
./install.sh --work-email carson.seese@kirbtech.com   # writes ~/work.email, then applies
./install.sh                                           # no file written => personal
set-work-email carson.seese@kirbtech.com               # after install: write file + re-apply
```

There is no auto-detection or prompt: the file (or its env-var fallback) is the source of truth. Non-interactive environments (cloud-init, CI, dev containers) either pass `--work-email`, provision `~/work.email` out-of-band (e.g. cloud-init `write_files`), or set a `DOTFILES_WORK_EMAIL` secret (Codespaces). On macOS/Windows (which apply chezmoi directly, no install script), create `~/work.email` manually before `chezmoi init` for a work identity.

### Git Signing

Commits are signed with an SSH key. The signing **public** key resolves at `chezmoi init` time with this precedence: `DOTFILES_SIGNING_KEY` env var → `~/.ssh/git_signing.pub` (per-host override) → a committed canonical default. Because the public key is non-secret and always available, signing works out of the box on every machine — including dev containers, which sign using the host's forwarded SSH agent (no local key file needed).

The `gitSign` data flag gates all signing config (`dot_gitconfig.tmpl`, `allowed_signers.tmpl`). It is true everywhere **except Codespaces**, where GitHub signs commits server-side with its own web-flow key and the forwarded signing key is unavailable. The matching **private** key must be loaded in the SSH agent wherever commits are made.

On real hosts (WSL, VMs, bare metal), `install.sh` runs `scripts/generate-signing-key.sh` to create a per-host `~/.ssh/git_signing` key before applying. When that private key file is present, `dot_gitconfig.tmpl` sets `signingkey` to the file path (`gitSigningKeyFile`) and signs directly from disk with no agent; otherwise it falls back to the `key::` public-key literal and the forwarded agent.

### Tool Management

CLI tools are managed by [mise](https://mise.jdx.dev/) via `root/private_dot_config/mise/config.toml.tmpl`. Language SDKs (go, node, bun) are conditionally included only outside dev containers (`not .isDc`). Tools are installed automatically during `chezmoi apply` via the `run_onchange_after_01-mise-install.sh.tmpl` script.

### Chezmoi Automation Scripts

Post-install scripts in `root/.chezmoiscripts/` run automatically during `chezmoi apply`:

- `run_onchange_after_01-mise-install.sh.tmpl` - Installs mise tools when config changes
- `run_after_mise-update.sh.tmpl` / `.ps1.tmpl` - Runs `mise self-update`. Failure is reported and stepped over rather than aborting the apply: packagers can disable self-update so mise is updated through the package manager instead (Homebrew, Arch's `mise`, distro and scoop/winget packages), and those builds exit nonzero — as does a root-owned mise an unprivileged user can't replace. Updating mise there belongs to whatever installed it
- `run_after_install-claude-config.sh.tmpl` - Syncs Claude Code configuration
- `run_onchange_after_02-install-completions.sh.tmpl` - Generates fish completions for every installed tool that supports it (gh, docker, mise, rg, fd, ast-grep, zellij, herdr, starship, pnpm); re-runs when the mise config changes so completions track tool versions. worktrunk uses dynamic completions instead (`conf.d/wt.fish` sources `COMPLETE=fish wt` at shell startup)
- `run_onchange_after_04-claude-plugins.sh.tmpl` - Installs/enables Claude Code plugins when the plugin list changes (see Claude Plugin Management)

### Claude Plugin Management

Claude Code plugins and marketplaces are declared in a single source-only file,
**`root/.chezmoidata/claude.toml`**. Because it lives under `.chezmoidata/`, it
is loaded into chezmoi's template data (`.claude`) but is **never applied to
`$HOME`** — the list is a component of the dotfiles, not a user file. It drives
two consumers:

- **`dot_claude/settings.json.tmpl`** renders `enabledPlugins` from
  `.claude.plugins` (each listed spec becomes `"spec": true`).
- **`run_onchange_after_04-claude-plugins.sh.tmpl`** runs `claude plugin
  marketplace add` for each `.claude.marketplaces` entry, then `claude plugin
  install` for each `.claude.plugins` entry. Enabling a plugin in settings does
  not install it, so this script closes that gap; both commands are idempotent.

The `.toml` holds two arrays: `plugins` (specs `"plugin@marketplace"`) and
`marketplaces` (GitHub `"owner/repo"`). Built-in marketplaces like
`claude-plugins-official` are always available and need not be listed.

**To add** a plugin/marketplace, add a line to the relevant array. **To remove**
one, delete its line: the plugin drops out of `enabledPlugins` and stops loading
on the next apply (removal is handled declaratively by settings regeneration; the
script never force-uninstalls). The provisioner re-runs whenever the file's hash
changes, following the same `run_onchange` pattern as the mise script.

The script skips cleanly when the `claude` CLI is not yet installed (e.g. the
first `install.sh` run, which installs Claude Code after `chezmoi apply`) and
picks the plugins up on the next apply. Hand-authored skills under
`dot_claude/skills/` are unrelated — those are files applied directly to
`~/.claude/skills/`.

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

- `root/.chezmoiignore.tmpl` - Controls which files chezmoi ignores per environment
- There is no `.chezmoiexternal` file: fundle is vendored at `root/private_dot_config/fish/functions/fundle.fish` (update it by copying a newer upstream release in, preserving the MIT license header at the top of the file), and binaries like eget install through mise

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

# Day-to-day maintenance (applied to ~/.local/bin, any shell)
update                      # System packages + mise + chezmoi + dotfiles + tools
clean                       # Prune orphaned packages, old tool versions, caches
```

## Development Guidelines

### Change Management

1. **Changes must be extremely thoughtful** - Ensure any modification is thoroughly tested and validated before considering it final. No mistakes are acceptable.

2. **Keep changes simple and maintainable** - If a change grows in complexity, ask for feedback/instruction or suggest ways to refine the scope to remain simple and maintainable.

3. **Documentation maintenance** - Regularly check and update documentation (including AGENTS.md) for stale content when patterns or configurations change.

4. **Template formatting** - Template files containing Go template strings must be formatted carefully to preserve correct whitespace and avoid trimming issues.

5. **NEVER test on host machine** - Changes must never be tested on the host machine. `chezmoi apply` should be considered dangerous unless run within a Docker container.
