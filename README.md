# dotfiles

My personal dotfiles, managed with [chezmoi](https://www.chezmoi.io/).

## Install

### Linux (Debian/Ubuntu/Arch/Omarchy) — dev containers, WSL, cloud VMs, desktops

Clone and run the bootstrap script. It installs mise, chezmoi and fish, then
applies the dotfiles — which is what installs the CLI tools, Claude Code
included:

```sh
git clone https://github.com/CS-5/dotfiles.git ~/.local/share/chezmoi
~/.local/share/chezmoi/install.sh [--work-email <address>]
```

On [Omarchy](https://omarchy.org) the same command also brings up the desktop:
Hyprland config, the Omarchy shell layout, the custom theme, declared packages
and shell plugins, and the ThinkPad keyboard-backlight daemon. It defers to
Omarchy wherever Omarchy already owns something — packages go through `omarchy
pkg add`, chezmoi comes from the Arch repos, and Claude Code is left to
Omarchy's own mise wrapper. Expect one sudo prompt, then log out and back in.

The work identity comes from a single file, `~/work.email`, containing just your
work email address; its domain selects the identity (e.g. `…@kirbtech.com`). No
file means a personal machine. `--work-email` writes that file before applying;
omit it for personal setups. Cloud VMs can provision unattended via
[`cloud-init.yaml`](cloud-init.yaml).

When the file is absent, the `DOTFILES_WORK_EMAIL` env var is used as a
fallback — set it as a Codespaces user secret (scoped to work repos) to get the
work identity in Codespaces automatically. On an already-provisioned machine or
Codespace, `set-work-email you@work.com` writes the file and re-applies in one
step (the file wins over the env var).

### macOS / Windows — chezmoi only

These platforms apply the dotfiles directly (no bootstrap script). For a work
machine, create `~/work.email` (containing just your work email address) before
running; otherwise it's treated as personal:

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply CS-5
```

```powershell
iex "&{$(irm 'https://get.chezmoi.io/ps1')} init --apply CS-5"
```

Everything the dotfiles can do for themselves happens during that apply — mise
tools, fish plugins, completions, Claude Code and its plugins. Two things a
bootstrap script does on Linux have no equivalent here:

- **A per-host signing key.** Without one, commits sign through the SSH agent
  using the committed public key, which works. To get a key on disk instead,
  run `scripts/generate-signing-key.sh` **before** `chezmoi init` — the key path
  is read when the config template renders, so generating it afterwards has no
  effect until the next `chezmoi init`.
- **Making fish the login shell** (`chsh -s $(which fish)` on macOS).

## Commit signing

Commits are signed with an SSH key. The signing **public** key is baked into the
config, so signing works out of the box everywhere — including dev containers,
which sign using the host's forwarded SSH agent. Signing is disabled in
Codespaces (GitHub signs those server-side).

On real hosts (WSL, VMs, bare metal), `install.sh` generates a per-host
`~/.ssh/git_signing` key and git signs directly from that file (no agent
needed). You can also override the public key by dropping it at
`~/.ssh/git_signing.pub`, or by setting `DOTFILES_SIGNING_KEY`. The matching
**private** key must be available (a local key file, or loaded in your SSH
agent) wherever you commit.
