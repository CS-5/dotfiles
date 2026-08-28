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

- `update` - Updates everything: system packages (apt or pacman on Linux, brew on macOS), mise itself, chezmoi, then `chezmoi update` (pull latest dotfiles + apply), then `mise upgrade` for the freshly pulled tool pins. On Omarchy the system-package step is `omarchy update -y` and it runs **last** instead of first: that command ends in a `gum confirm` reboot prompt which `-y` does not suppress (it exports `OMARCHY_UPDATE_UNATTENDED`, which nothing reads), so going first meant a kernel upgrade could reboot the machine before the dotfiles were ever pulled. The mise step is skipped over when mise is package-managed — the system-package step above already covered it. `chezmoi upgrade` is likewise skipped when the binary is not writable by the user, which is the real precondition for an in-place self-upgrade and covers every packager (Omarchy/Arch `extra/`, Homebrew) at once
- `clean` - Prunes what `update` leaves behind: orphaned system packages and caches (`apt-get autoremove --purge`/`clean`, `pacman -Rns` of `-Qtdq` orphans + `-Sc`, `brew autoremove`/`cleanup --prune=all`), mise tool versions no longer referenced by any config (`mise prune`), and mise's download cache. On Omarchy both package steps differ and the difference is destructive if ignored — see the Omarchy notes below
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

Two data flags are derived from the machine itself rather than from env vars:

- **`isOmarchy`** - true when `/etc/os-release` has `ID=omarchy`. [Omarchy](https://omarchy.org) is an opinionated Arch/Hyprland distribution that owns a large part of `$HOME`. Because the check is on the distro ID, it is false by construction in WSL (`ID=arch`/`ubuntu`), dev containers, macOS and Windows, so no Omarchy-only file can leak onto another host. Preview an Omarchy render from anywhere with `./render.sh --data '{"isOmarchy":true}' <template>`
- **`isThinkPad`** - true when `/sys/class/dmi/id/product_family` starts with `ThinkPad`. Gates the hardware-specific pieces (keyboard-backlight daemon, touchpad modprobe drop-in) so a future Omarchy desktop does not get a laptop keyboard-LED service

### Working with Omarchy

Omarchy provisions `$HOME` on first run and keeps it current through migrations, so the governing rule is: **only manage a file that differs from its `$OMARCHY_PATH/config` default.** A file that matches the default is left to Omarchy, which keeps its own tooling (`omarchy font set`, `omarchy refresh`, the theme system) working with zero drift — and, as the hypr note below explains, keeps Omarchy's migrations from fighting the next apply.

Every Omarchy-only path is listed in one block in `.chezmoiignore.tmpl` so the rule stays auditable, and every Omarchy-only script in `.chezmoiscripts/` opens with `{{ if .isOmarchy -}}` so it renders empty elsewhere (the same pattern as the existing Windows guards).

Things worth knowing before changing anything here:

- **Only manage a hypr file that you have actually customized.** This one is not tidiness, it is how Omarchy's migrations decide what to touch: a migration that improves a user's Hyprland config hashes the file first and rewrites it *only when it still matches a known stock checksum* (see `$OMARCHY_PATH/migrations/1781485962.sh` and its `stock_input_sha` / `stock_bindings_sha` constants). So a **stock** file under chezmoi is a standing conflict — Omarchy rewrites it, the next apply reverts it, every update — while a **customized** file is skipped by the migration and chezmoi is its only writer. `~/.config/hypr` therefore holds only `input.lua`, `looknfeel.lua` and `monitors.lua`; the stock files are byte-identical to what Omarchy installs, so a rebuilt machine gets them from Omarchy anyway. The same reasoning is why `~/.config/ghostty/config` is unmanaged there.
- **Never `pacman -Syu`.** Omarchy's `00-omarchy-update-guard` libalpm hook aborts any direct system upgrade. `update` hands the whole step to `omarchy update -y` (last, see above), and `install.sh` bootstraps with `omarchy pkg add` (which installs only what is missing and needs no `-Syu`).
- **Never `pacman -Sc` and never bulk-remove orphans.** Omarchy's package cache is its *only* offline downgrade path, so it keeps two versions per package (`omarchy-update-pkg-prune` runs `paccache -rk2`); emptying it removes the ability to roll back a bad update. Orphans are reviewed rather than assumed — `omarchy-update-orphan-pkgs` lists them and asks, defaulting to no. `clean` branches for both.
- **`omarchy update -y` can still block and can still reboot.** `-y` sets `OMARCHY_UPDATE_UNATTENDED`, but grep `$OMARCHY_PATH` and nothing reads it; `omarchy-update-restart` calls `gum confirm` unconditionally and reboots on yes. Never put work you need to finish after it.
- **mise wrappers.** Omarchy's first run provisions ~13 wrappers in `~/.local/bin` via `omarchy mise install`; each runs `mise use -g <tool>` on *every invocation*, rewriting `~/.config/mise/config.toml`. That file is Omarchy's — the dotfiles use `conf.d/10-dotfiles.toml` instead. `env-bootstrap` also puts the mise shim dir on PATH, so a tool declared to mise is served by its shim regardless of what sits in `~/.local/bin`.
- **Compile before files.** `run_before_*` scripts run before chezmoi writes anything, so anything that can fail a build belongs there: a failed compile then aborts the apply with nothing half-written. `run_before` scripts cannot read `~/.local/src`, which chezmoi has not written yet — build from `{{ .chezmoi.sourceDir }}` instead.
- **Privilege escalation** in scripts: `sudo` when there is a TTY, `pkexec` otherwise (an apply triggered from the bar widget has no terminal, and Omarchy's polkit agent puts up a dialog). Always compare before escalating so a no-op apply never prompts.
- **`/etc`** is out of chezmoi's reach ($HOME only). Root-owned files live in `system/etc/` at the repo root and are installed by `run_onchange_after_05-omarchy-etc.sh.tmpl`.
- **Third-party plugins and packages** are declared in `root/.chezmoidata/omarchy.toml` and installed by `run_before_00-omarchy-packages.sh.tmpl`. See the manifest's own header comment.
- **The sync widget.** `carson.dotfiles` surfaces chezmoi drift on the bar. Its data comes from `dotfiles-status`, which is also what `dotfiles-sync` and the menu's Dotfiles submenu read, so the three cannot disagree. The distinction that matters: `chezmoi status` column 2 is a pending apply, column 1 is a target edited *outside* chezmoi (an Omarchy migration, `omarchy refresh`, a hand edit) which chezmoi will not overwrite unprompted — that is the state the widget colours urgent.

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

CLI tools are managed by [mise](https://mise.jdx.dev/) via `root/private_dot_config/mise/conf.d/10-dotfiles.toml.tmpl`. Language SDKs (go, node, bun) are conditionally included only outside dev containers (`not .isDc`). Tools are installed automatically during `chezmoi apply` via the `run_onchange_after_01-mise-install.sh.tmpl` script.

**Anything mise can install, mise installs.** A tool with a mise backend does not get a bespoke curl-into-bash installer, on any platform — one declaration in the tool list replaces an install step, a version that nobody tracks, and an update path that differs per machine. Claude Code (`aqua:anthropics/claude-code`) is managed this way rather than through `claude.ai/install.sh`. The two deliberate exceptions are the bootstrappers that have to exist before the tool list can be read: **mise itself**, and **chezmoi** (installed from `pacman` on Omarchy, else the official installer — `update` refreshes it in place only when the binary is user-writable). System packages that must exist before mise runs, or that a login shell depends on (fish, neovim, git), stay with the platform package manager.

Before adding an installer for anything, check `mise registry <tool>`.

### Chezmoi Automation Scripts

Post-install scripts in `root/.chezmoiscripts/` run automatically during `chezmoi apply`:

- `run_once_before_00-migrate-mise-config.sh.tmpl` / `.ps1.tmpl` - One-time move of a pre-existing dotfiles-owned `~/.config/mise/config.toml` aside, now that the tool pins live in a `conf.d` drop-in. `config.toml` outranks `conf.d`, so a leftover copy would keep winning; the `minimum_release_age` line identifies the file as ours, leaving a `mise use -g` config untouched
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

The script still skips cleanly when the `claude` CLI is absent, but that is now
a fallback rather than the normal first-run path: Claude Code is a mise tool, so
`run_onchange_after_01-mise-install.sh.tmpl` has installed it by the time this
script runs. Hand-authored skills under
`dot_claude/skills/` are unrelated — those are files applied directly to
`~/.claude/skills/`.

### Shell Configuration: drop-in directories

Configuration is organized around **drop-in directories** wherever the tool
supports one, so that a file another owner also writes to (a distro's rc file,
`mise use -g`'s config) never has to be contested. The rule is uniform: one
numbered file per concern, loaded in sorted order, from a predictable location.

| Consumer | Drop-in directory | Loaded by |
| --- | --- | --- |
| bash, zsh | `~/.config/sh/rc.d/*.sh` | a four-line loop in `~/.bashrc` / `~/.zshrc` (partial: `.chezmoitemplates/shell-rcd`) |
| fish | `~/.config/fish/conf.d/*.fish` | fish, natively |
| mise | `~/.config/mise/conf.d/*.toml` | mise, natively |
| systemd (user) | `~/.config/systemd/user/` | systemd, natively |

`~/.bashrc` and `~/.zshrc` are therefore **thin loaders that should not need to
change again**. Everything shell-agnostic lives in `root/private_dot_config/sh/rc.d/`,
where `00-shell.sh` sets `DOTFILES_SHELL` (`bash`|`zsh`) and later files use it
to pick the right argument for `starship init`, `mise activate` and friends. One
drop-in per concern is what lets a single `.chezmoiignore` line disable exactly
the pieces a given host already provides — on Omarchy, `40-starship.sh`,
`41-mise.sh`, `42-zoxide.sh` and `70-history.sh` are ignored because Omarchy's
own `default/bash/rc` already does all four.

To add a shell setting, add a numbered file to `sh/rc.d/` (or the fish `conf.d/`
equivalent). Only reach for `~/.bashrc` itself when the thing genuinely must run
before the interactivity guard.

**mise** uses a `conf.d` drop-in for the same reason: Omarchy's tool wrappers run
`mise use -g` on every invocation, which rewrites `~/.config/mise/config.toml`.
chezmoi owns `conf.d/10-dotfiles.toml` and mise structurally refuses to write
into `conf.d`, so the two can never clobber each other. The trade-off is
precedence — within a global config dir `config.toml` **outranks** `conf.d`, so
the Omarchy branch of that template drops every tool Omarchy already provides
rather than pinning a version that would be silently ignored.

### Environment Variables

Simple key-value environment variables (e.g., `VISUAL`, `HOMEBREW_NO_AUTO_UPDATE`) are centralized in template partials under `root/.chezmoitemplates/`. Each partial renders the same variables in the syntax for its target shell:

| Partial | Syntax | Consumed by |
| --- | --- | --- |
| `env-posix` | `export VAR=val` | `private_dot_config/sh/rc.d/20-env.sh.tmpl` |
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
- `root/dot_bashrc.tmpl` / `root/dot_zshrc.tmpl` - Thin loaders for `~/.config/sh/rc.d/`
- `root/private_dot_config/sh/rc.d/` - The actual bash/zsh configuration, one numbered file per concern
- `root/private_dot_config/mise/conf.d/10-dotfiles.toml.tmpl` - mise tool pins

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
