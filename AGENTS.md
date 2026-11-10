# AGENTS.md

## Repository Overview

This is a personal dotfiles repository managed with [chezmoi](https://www.chezmoi.io/). It contains configuration files for various development tools including Git, Fish shell, SSH, Docker, and development environments.

## Key Scripts

### Installation Scripts

- `./scripts/install-dotfiles.sh [--work-email <addr>]` - Installs chezmoi if missing, then runs `chezmoi init --apply` from this checkout (called by `install.sh`); `--work-email` writes `~/work.email` before applying
- `./install.sh [--work-email <addr>]` - Dev container / Linux bootstrap (Debian/Ubuntu, Arch, Omarchy); `--work-email` writes `~/work.email` for non-interactive work setups

### Development Scripts

- `./render.sh [--identity IDENTITY] [--work-email <addr>] [--dc] [--codespaces] [--data <json>] <template-file>` - Renders chezmoi templates to stdout for testing. Drives the real `.chezmoi.toml.tmpl` (supplying the identity via `DOTFILES_WORK_EMAIL` while neutralizing any real `~/work.email` via `DOTFILES_WORK_EMAIL_FILE`) so output matches a live apply. `--data` passes a JSON object to chezmoi's `--override-data` to force `[data]` values (e.g. `'{"isMac":true}'` to preview macOS renders from Linux)

### User Commands

Shell-agnostic commands applied by chezmoi to `~/.local/bin` (source: `root/dot_local/bin/`), so one bash implementation serves fish, bash, and zsh. Not applied on Windows (ignored via `.chezmoiignore.tmpl`):

- `update` - Updates everything: system packages (apt or pacman on Linux, `omarchy update -y` on Omarchy, brew on macOS), mise itself, chezmoi, then `chezmoi update --init` (pull latest dotfiles, regenerate the config from `.chezmoi.toml.tmpl`, apply), then `mise upgrade` for the freshly pulled tool pins, then each coding-agent CLI's own updater (`claude update`, `codex update`, `copilot update`, `agy update`, `opencode upgrade`) for whichever are installed — `install.sh` installs these with their vendor installers, not mise, so they can self-update; a failure is reported and skipped. On Omarchy, a CLI that Omarchy's mise config provides is left to Omarchy (see Omarchy). The mise and chezmoi self-updates are skipped over when the binary is package-managed — the system-package step above already covered it
- `clean` - Prunes what `update` leaves behind: orphaned system packages and caches (`apt-get autoremove --purge`/`clean`, `pacman -Rns` of `-Qtdq` orphans + `-Sc`, `brew autoremove`/`cleanup --prune=all`), mise tool versions no longer referenced by any config (`mise prune`), and mise's download cache. On Omarchy the system-package step is skipped: `omarchy update` already removes orphans and prunes the cache down to two versions per package, its offline rollback path
- `bitwarden-ssh-sock` - Prints the SSH agent socket on machines where Bitwarden is the agent (see SSH Agent); `--forwarded` exits 0 only inside an SSH session with a forwarded agent. Applied only when `bitwardenSshAgent` is true (everywhere except dev containers, WSL and Windows)
- `git-signing-agent` - Dev containers: turns commit signing on when the forwarded SSH agent holds a key registered with GitHub as a signing key, and off otherwise (see Git Signing). Shells run it at startup with `--quiet`; run it by hand after (re)connecting an agent. Applied only when `isDc` and `gitSign` are true
- `set-work-email <addr>` - Writes `~/work.email` and re-runs `chezmoi init --apply` so the work identity takes effect (Windows gets a PowerShell function equivalent in the profile)
- `fzkill [kill args]` - Picks processes in fzf and kills them, passing any arguments to `kill` (e.g. `fzkill -9`); selecting nothing kills nothing

## Architecture

### Template System

- All configuration files are in `root/` directory as chezmoi templates (`.tmpl` extension)
- `.chezmoi.toml.tmpl` defines data variables and environment detection
- Templates use Go template syntax with conditional logic for different environments

### Environment Detection

The dotfiles adapt based on environment variables:

- `REMOTE_CONTAINERS_IPC` - Detects dev container environment
- `USER=vscode` - Also treated as a dev container signal (the default user of the dev container images)
- `CODESPACES` - Detects GitHub Codespaces environment
- A `/workspaces` directory - Also treated as a dev container signal (covers containers whose user isn't `vscode` and where `REMOTE_CONTAINERS_IPC` isn't set at install time)
- `DOTFILES_SOURCE_DIR` - Override source directory (`install.sh` and `install-dotfiles.sh` set it to the checkout; `.chezmoi.toml.tmpl` falls back to `~/.local/share/chezmoi` when unset)
- `DOTFILES_WORK_EMAIL` - Work email fallback when `~/work.email` is absent (the file wins; Codespaces user secrets surface as env vars)
- `DOTFILES_WORK_EMAIL_FILE` - Relocates the work-email file from `~/work.email` (used by render.sh; unset in normal use)
- `ID=omarchy` in `/etc/os-release` - Sets `isOmarchy` (see Omarchy). Keyed on the distro ID, so it is false by construction on WSL, dev containers, macOS and Windows

### Identity System

The work identity is driven by a single file, **`~/work.email`**, whose only contents are one work email address (no other text or formatting). When the file is absent, the **`DOTFILES_WORK_EMAIL`** env var is consulted as a fallback (the file always wins when both exist) — this is how Codespaces get a work identity, since user secrets surface there as env vars. `.chezmoi.toml.tmpl` reads the email at render time and derives the `identity`, `isWork`, `isPersonal`, and `workEmail` data variables. The email's **domain** selects the identity:

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

Each machine signs with its own key file, `~/.ssh/git_signing` (ed25519, no passphrase, so signing never prompts and works for unattended coding agents), which `dot_gitconfig.tmpl` names as `signingkey`. No key lives in the repo, so a new machine needs no commit here: `run_after_09-git-signing.sh.tmpl` (`.ps1.tmpl` on Windows; keep the two in step) does the per-machine work on every apply:

1. Creates the key if it is missing, and registers it with GitHub as a signing key (`gh ssh-key add --type signing`, titled with the hostname) when it isn't in the account's list yet. That needs `gh` logged in as `githubUser` with the `admin:ssh_signing_key` scope; from a terminal the script runs `gh auth refresh` for the scope itself, otherwise it prints the command and the next apply (e.g. `update`) retries. When `GH_TOKEN` or `GITHUB_TOKEN` is set, gh uses that token instead of its stored login and won't refresh the login's scopes, so if the token can't add the key the script retries with both cleared. Until then the machine's signatures show as Unverified on GitHub
2. Writes `~/.ssh/allowed_signers` (for `git log --show-signature`) from GitHub's public list of the account's signing keys, plus the machine's own key, under the personal and work emails. When GitHub is unreachable the existing file is kept

Dev containers get no key of their own. They sign with a key from the host's forwarded agent (Bitwarden or a plain ssh-agent), but only one that is in `allowed_signers`, i.e. registered with GitHub: any other key would sign but show as Unverified. git has no "sign if possible" setting, so `git-signing-agent` decides ahead of time, on apply and at every shell startup: with a match it writes `~/.local/state/git-signing.gitconfig` (the key and `gpgSign = true`), which `.gitconfig` includes; without one it removes the file and commits go unsigned. If the agent goes away after that check, commits fail with an agent error until the next shell or a manual `git-signing-agent`. The "Signing" key in Bitwarden stays registered on GitHub so that Bitwarden hosts can sign in dev containers.

Removing a machine means deleting its key in GitHub's settings (Settings → SSH and GPG keys); its past commits then show as Unverified.

The `gitSign` data flag gates all signing config and the script. It is always false in **Codespaces**, where GitHub signs commits server-side with its own web-flow key.

### SSH Agent

`bitwardenSshAgent` is true everywhere except dev containers, WSL and Windows, and there the Bitwarden desktop app is the only SSH agent. A headless box reaches it through a forwarded agent (`ssh -A`, or VS Code Remote-SSH, which forwards by default). Without Bitwarden or a forwarded agent, ssh still authenticates with key files on disk (on macOS `UseKeychain` supplies their passphrases). Commit signing doesn't use the agent (see Git Signing). Dev containers keep the host's forwarded agent. On WSL the app runs on the Windows side, where its Unix socket is unreachable, so fish starts a local agent shared across WSL shells (`fish_ssh_agent`) and ssh keeps `AddKeysToAgent`/`IdentitiesOnly`.

A forwarded agent only lives as long as the SSH session: a zellij or tmux session left running after you disconnect can't reach it, nor after you reconnect, since the session keeps the old socket path. That affects ssh only; commits keep signing with the box's own key.

Sandboxed installs put the socket inside their container, so `.chezmoi.toml.tmpl` renders an ordered per-OS candidate list, `bitwardenSshSocks` (macOS App Store; Linux snap, flatpak), always ending with the native install path `~/.bitwarden-ssh-agent.sock` as the fallback. The first socket that exists at runtime wins, and a forwarded agent in an SSH session (a work VM reached with `ssh -A`) wins over all of them. The same order is applied by two consumers:

- `dot_ssh/config.tmpl` - `Match exec` blocks set `IdentityAgent` for anything that runs OpenSSH, whatever its environment. `IdentitiesOnly` and `AddKeysToAgent` are dropped, since the keys live only in the agent and Bitwarden doesn't accept added keys
- `~/.local/bin/bitwarden-ssh-sock` - prints the socket for tools that read `SSH_AUTH_SOCK` instead (`ssh-add`, `ssh-keygen -Y sign`, VS Code agent forwarding). fish, bash and zsh export it, and on macOS the `local.bitwarden-ssh-auth-sock` LaunchAgent hands it to GUI apps via `launchctl setenv` at login

Bitwarden leaves its socket file on disk after quitting, so the check stays stable while the app isn't running. `Match exec` runs through `$SHELL`, adding a few tens of milliseconds per ssh invocation when that shell is fish.

### Tool Management

CLI tools are managed by [mise](https://mise.jdx.dev/) via `root/private_dot_config/mise/conf.d/10-dotfiles.toml.tmpl`, applied as a `conf.d` drop-in. Language SDKs and package managers (go, node, bun, python, pnpm) are conditionally included only outside dev containers (`not .isDc`). On Omarchy, tools Omarchy installs as system packages (starship, lazygit, fd, fzf, jq, ripgrep, zoxide, usage, herdr) are left out. Tools are installed automatically during `chezmoi apply` via the `run_onchange_after_01-mise-install.sh.tmpl` script.

`~/.config/mise/config.toml` is deliberately not managed: it belongs to `mise use -g`, whether you run it or Omarchy's agent wrappers fall back to it, so a managed copy would be reverted and rewritten on every apply. A tool pinned there outranks the drop-in's pin. `modify_config.toml` only removes a `config.toml` that an older version of the dotfiles wrote (recognized by its top-level `minimum_release_age`/`idiomatic_version_file_enable_tools` settings, which `mise use -g` never writes); anything else passes through untouched.

### Chezmoi Automation Scripts

Post-install scripts in `root/.chezmoiscripts/` run automatically during `chezmoi apply`:

- `run_onchange_after_01-mise-install.sh.tmpl` / `.ps1.tmpl` - Installs mise tools when config changes
- `run_onchange_after_02-install-completions.sh.tmpl` - Generates fish completions for every installed tool that supports it (gh, docker, mise, rg, fd, ast-grep, zellij, herdr, starship, pnpm); re-runs when the mise config changes so completions track tool versions. worktrunk uses dynamic completions instead (`conf.d/wt.fish` sources `COMPLETE=fish wt` at shell startup). Not on Omarchy, where fish isn't used
- `run_onchange_after_03-windows-env.ps1.tmpl` - Windows: persists the vars in the `env-windows-persist` partial to the User registry and adds `~/.local/bin` to the User `Path`; re-runs when the partial changes (see Environment Variables)
- `run_onchange_after_04-claude-plugins.sh.tmpl` - Installs/enables Claude Code plugins when the plugin list changes (see Claude Plugin Management)
- `run_onchange_after_05-bitwarden-ssh-agent.sh.tmpl` - macOS: (re)loads the Bitwarden `SSH_AUTH_SOCK` LaunchAgent when it changes, so GUI apps pick it up without a re-login (see SSH Agent)
- `run_onchange_after_06-codex-plugins.sh.tmpl` - Installs Codex plugins when the plugin list changes (see Codex Plugin Management)
- `run_onchange_after_07-omarchy-theme.sh.tmpl` - Omarchy: runs `omarchy theme refresh` when a managed theme's `colors.toml` changes and that theme is the active one (see Omarchy)
- `run_after_08-omarchy-packages.sh.tmpl` - Omarchy: installs whatever `.chezmoidata/omarchy.toml` lists that is missing (see Omarchy)
- `run_after_09-git-signing.sh.tmpl` / `.ps1.tmpl` - Creates and registers the machine's signing key, writes `allowed_signers` from GitHub, and in dev containers runs `git-signing-agent` (see Git Signing)
- `run_after_10-install-claude-config.sh.tmpl` - When `CLAUDE_CONFIG_DIR` points somewhere other than `~/.claude`, copies `CLAUDE.md`, `settings.json` and `skills/` from `~/.claude` into it
- `run_after_11-mise-update.sh.tmpl` / `.ps1.tmpl` - Runs `mise self-update`. Failure is reported and stepped over rather than aborting the apply: packagers can disable self-update so mise is updated through the package manager instead (Homebrew, Arch's `mise`, distro and scoop/winget packages), and those builds exit nonzero — as does a root-owned mise an unprivileged user can't replace. Updating mise there belongs to whatever installed it

### Claude Plugin Management

Claude Code plugins and marketplaces are declared in a single source-only file,
**`root/.chezmoidata/claude.toml`**. Because it lives under `.chezmoidata/`, it
is loaded into chezmoi's template data (`.claude`) but is **never applied to
`$HOME`** — the list is a component of the dotfiles, not a user file. It drives
two consumers:

- **`.chezmoitemplates/claude-settings.json`** (the settings body, applied via
  `dot_claude/modify_settings.json`) renders `enabledPlugins` from the plugin
  specs (each becomes `"spec": true`) and `extraKnownMarketplaces` from the
  marketplaces.
- **`run_onchange_after_04-claude-plugins.sh.tmpl`** runs `claude plugin
  marketplace add` for each marketplace, then `claude plugin install` for each
  plugin. Enabling a plugin in settings does not install it, so this script
  closes that gap; both commands are idempotent.

The `.toml` holds `plugins` (an array of `"plugin@marketplace"` specs) and
`marketplaces` (a table of marketplace name → GitHub `"owner/repo"`; the name is
the one in the repo's `.claude-plugin/marketplace.json`, i.e. the part after `@`
in a spec). `[claude.identities.<identity>]` holds the same two keys for entries
added only on that identity (e.g. a private work marketplace). Built-in
marketplaces like `claude-plugins-official` are always available and need not be
listed. Marketplaces must be declared in settings, not just added by the script:
`claude plugin marketplace add --scope user` writes them to
`extraKnownMarketplaces`, and an undeclared entry would show up as drift.

**To add** a plugin/marketplace, add an entry. **To remove** one, delete it: the
plugin drops out of `enabledPlugins` and stops loading on the next apply (removal
is handled declaratively by settings regeneration; the script never
force-uninstalls). The provisioner re-runs whenever the file's hash
changes, following the same `run_onchange` pattern as the mise script.

The script renders empty, and so neither runs nor is recorded, until the
`claude` CLI is on `PATH` (`lookPath`). The first `install.sh` run installs
Claude Code after `chezmoi apply`, so the plugins are picked up on the next
apply (e.g. `update`). Hand-authored skills under
`dot_claude/skills/` are unrelated — those are files applied directly to
`~/.claude/skills/`.

Claude Code rewrites `settings.json` in its own key order, so it is a
`modify_` template: it keeps the live file untouched when it parses to the same
JSON as the managed settings, and writes the managed version otherwise. Settings
changed in the Claude Code UI still show up as a diff and are overwritten on
apply; put anything you want kept into the partial.

### Codex Plugin Management

Codex plugins are declared the same way in **`root/.chezmoidata/codex.toml`**
(same `plugins` / `marketplaces` / `[codex.identities.<identity>]` schema), and
**`run_onchange_after_06-codex-plugins.sh.tmpl`** runs `codex plugin marketplace
add` and `codex plugin add` for each entry. Both are idempotent, and the script
renders empty until `codex` is on `PATH`, like the Claude one.

Codex reads Claude-format marketplaces (`.claude-plugin/marketplace.json`), so
the list is the subset of the Claude plugins that work in Codex. Codex loads a
plugin's skills and MCP servers but not its agents, LSP servers or hooks, so
`code-simplifier`, the `*-lsp` plugins and `plannotator` stay Claude-only. Codex
has no built-in `claude-plugins-official`, so it is declared as a marketplace
(`anthropics/claude-plugins-official`). Plugins update themselves at Codex
startup; `codex plugin marketplace upgrade` refreshes the marketplaces by hand.

Differences from Claude: `~/.codex/config.toml` is not managed by chezmoi (the
`codex plugin` commands write their own `[marketplaces]` and `[plugins]` entries
to it), so **removing** an entry from `codex.toml` does not uninstall it; also run
`codex plugin remove <plugin@marketplace>`.

### Link Routing (macOS)

[Brouter](https://github.com/CS-5/Brouter), a menu-bar app set as the default browser, sends each clicked link to a browser, a browser container, or a native app. Its config, `root/private_dot_config/brouter/config.toml.tmpl` (applied to `~/.config/brouter/config.toml`), is applied only on macOS; Brouter reloads it as soon as chezmoi writes it. The app itself is installed by hand from its GitHub releases, not by the dotfiles.

- **All Macs**: Linear and Teams deep links (`teams.microsoft.com/l/*`) open in their native apps, via a scheme swap (`linear://`, `msteams://`). Brouter doesn't skip a rule whose app isn't installed, so each rule renders only when its app is in `/Applications` or `~/Applications` at apply time; without it, the links fall through to the rules below (a kirbtech Linear link goes to Edge on a Mac without Linear). Re-apply (or run `update`) after installing one. Slack has no rule: its app links need team and channel IDs a scheme swap can't produce, so Slack links go to a browser, which offers to open the app
- **Kirbtech Mac** (`isMac` and identity `kirbtech`): default Chrome. Any URL containing `kirbtech`, and the listed Zubie, Cloudflare, Claude, ChatGPT, Microsoft and Bitwarden domains, open in Edge
- **Other Macs**: default Zen. URLs containing `scstem` open in Zen's `Robotics` container and `journalytic` in its `Work` container (needs Zen's "Open external links in a container" extension)

Rules are checked top to bottom and the first match wins, so native apps come first. To add a domain, add it to the relevant rule's `host` list (a host also matches its subdomains).

### Omarchy

On [Omarchy](https://omarchy.org/) (`isOmarchy`), the dotfiles layer on top of Omarchy rather than replace it, and install and update through its own entrypoints. Omarchy's defaults live read-only in `/usr/share/omarchy`; read them before changing anything here.

- **Who owns what** - Omarchy themes and migrates the ghostty, starship and herdr configs, so `.chezmoiignore.tmpl` leaves them (and the unused fish config) to it there. In `~/.config/hypr`, only `input.lua` and `looknfeel.lua` are managed, and they hold just the overrides on top of Omarchy's defaults. Omarchy's migrations rewrite a user file only while it still matches a stock version, so a managed file that differs is never contested, while a managed stock file would be. `monitors.lua`, `bindings.lua`, `autostart.lua` and `~/.config/omarchy/shell.json` stay per-machine. Only manage a file that differs from its `$OMARCHY_PATH/config` default
- **Shell** - bash, Omarchy's shell; `install.sh` installs neither fish nor changes the login shell. `.bashrc` keeps Omarchy's own structure (env-bootstrap above the interactivity guard, then `$OMARCHY_PATH/default/bash/rc`, which sets up the prompt, mise, zoxide, fzf and history) and adds only what is ours below it
- **Git** - `.chezmoiremove.tmpl` removes Omarchy's `~/.config/git/config`: git reads it beneath `~/.gitconfig`, so its `init.defaultBranch = master` and personal email would leak through on keys we leave unset. Its useful defaults are carried in `dot_gitconfig.tmpl`
- **Packages** - `.chezmoidata/omarchy.toml` lists repo packages (`omarchy pkg add`), AUR packages (`omarchy pkg aur add`), Omarchy installers (`omarchy install <route>`, preferred whenever one exists because they also wire the app into Omarchy; each has a sentinel package that decides whether it still needs to run) and third-party shell plugins (`omarchy plugin add`, installed but never enabled, since `shell.json` is per-machine). `run_after_08-omarchy-packages.sh.tmpl` runs on every apply but does nothing once everything is present; failures only warn, and without a terminal for sudo it says what it skipped. Removing an entry never uninstalls anything
- **Themes** - custom theme definitions live in `private_dot_config/omarchy/themes/<name>/` (`colors.toml`, `backgrounds/`) and appear in Omarchy's theme switcher; nothing here selects the active theme. Claude Code's settings use `"theme": "custom:omarchy"`, the theme file Omarchy regenerates on every theme change
- **Updates** - `update` runs `omarchy update -y` (Omarchy blocks a direct `pacman -Syu` with a libalpm hook), and `install.sh` installs with `omarchy pkg add` and takes chezmoi from the Arch repos. Omarchy's mise config (`/etc/mise/conf.d/omarchy-tools.toml`) provides most coding-agent CLIs lazily, so `install.sh` and `update` skip their vendor installers/updaters for any CLI it declares (`omarchy-mise-default-tools declares <tool>`), unless the user opted out of Omarchy's default tools

### Shell Abbreviations

`root/.chezmoidata/shell.toml` holds one list of command abbreviations for every shell. fish renders it as abbreviations (`conf.d/abbreviations.fish.tmpl`); bash and zsh render it as aliases (the `shell-abbreviations` partial). Add one with a line in that file. fish-only aliases (`ls` → lsd and friends) stay in `conf.d/alias.fish`.

### Local Overrides

`~/.config/local/` holds per-machine overrides that the dotfiles never manage. Each managed config loads its file there only if it exists, last, so it wins:

| File | Loaded by |
| --- | --- |
| `shell.sh` | `.bashrc`, `.zshrc` |
| `shell.fish` | `config.fish` |
| `gitconfig` | `.gitconfig` (`[include]`) |
| `hypr.lua` | `~/.config/hypr/looknfeel.lua` (Omarchy; re-read on `hyprctl reload`) |

To add another, have the managed config load `~/.config/local/<file>` when it exists.

### Environment Variables

Simple key-value environment variables (e.g., `VISUAL`, `HOMEBREW_NO_AUTO_UPDATE`) are centralized in template partials under `root/.chezmoitemplates/`. Each partial renders the same variables in the syntax for its target shell:

| Partial | Syntax | Consumed by |
| --- | --- | --- |
| `env-posix` | `export VAR=val` | `dot_bashrc.tmpl`, `dot_zshrc.tmpl` |
| `env-fish` | `set -gx VAR val` | `config.fish.tmpl` |
| `env-powershell` | `$env:VAR = "val"` | `Microsoft.PowerShell_profile.ps1.tmpl` |
| `env-windows-persist` | `[Environment]::SetEnvironmentVariable(...)` | `run_onchange_after_03-windows-env.ps1.tmpl` |

**To add a new env var:** Add one line in the appropriate syntax to each partial that should receive it. Use chezmoi template guards (e.g., `{{ if .isMac }}`) for conditional vars. Not all vars need to appear in every partial — add only to the shells/platforms where the var applies.

**Complex setup** (PATH manipulation, `brew shellenv`, tool activations like mise/starship/zoxide, SSH agent) belongs in each shell's own config file or `conf.d/` files — not in the centralized partials. The one exception is the `posix-agents` partial, which holds the `SSH_AUTH_SOCK` export (via `bitwarden-ssh-sock`) and the dev-container `git-signing-agent --quiet` call that `dot_bashrc.tmpl` and `dot_zshrc.tmpl` share verbatim.

On Windows, `run_onchange_after_03-windows-env.ps1.tmpl` persists env vars from `env-windows-persist` to the User registry via `[Environment]::SetEnvironmentVariable()`. It re-runs automatically when the partial's content changes.

### External File Management

- `root/.chezmoiignore.tmpl` - Controls which files chezmoi ignores per environment
- There is no `.chezmoiexternal` file: fundle is vendored at `root/private_dot_config/fish/functions/fundle.fish` (update it by copying a newer upstream release in, preserving the MIT license header at the top of the file), and binaries like eget install through mise

### Key Files

- `root/.chezmoi.toml.tmpl` - Main chezmoi configuration with environment variables
- `root/dot_gitconfig.tmpl` - Git configuration with conditional work includes
- `root/dot_gitconfig-work.tmpl` - Work-specific git configuration
- `root/private_dot_config/fish/config.fish.tmpl` - Fish shell configuration
- `root/dot_bashrc.tmpl` - Bash configuration (Homebrew, starship, mise, zoxide, mcfly; on Omarchy, layered on Omarchy's rc)
- `root/dot_zshrc.tmpl` - Zsh configuration
- `root/private_dot_config/brouter/config.toml.tmpl` - Brouter link-routing rules (macOS)
- `root/private_dot_config/mise/conf.d/10-dotfiles.toml.tmpl` - mise tool pins and settings
- `root/.chezmoidata/shell.toml` - Shell abbreviations for every shell
- `root/.chezmoidata/omarchy.toml` - Omarchy packages, installers and shell plugins
- `root/private_dot_config/hypr/` - Hyprland overrides (Omarchy)

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
