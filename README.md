# dotfiles

My personal dotfiles, managed with [chezmoi](https://www.chezmoi.io/).

## Install

### Linux (Debian/Ubuntu/Arch) — dev containers, WSL, cloud VMs

Clone and run the bootstrap script. It installs mise, chezmoi, fish, Claude
Code, Codex, Antigravity CLI, GitHub Copilot CLI, and opencode, then applies the
dotfiles:

```sh
git clone https://github.com/CS-5/dotfiles.git ~/.local/share/chezmoi
~/.local/share/chezmoi/install.sh [--work-email <address>]
```

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

Machines without `~/.ssh/git_signing` (macOS, which skips `install.sh`) sign
through their SSH agent. On work machines that's Bitwarden, so store the private
half of the baked-in public key in Bitwarden. No per-machine git config is
needed.

## Link routing (macOS)

On macOS, the dotfiles configure [Brouter](https://github.com/CS-5/Brouter) at
`~/.config/brouter/config.toml`. Install the app yourself from its
[releases](https://github.com/CS-5/Brouter/releases) and let it become the
default browser. The routing rules are described in `AGENTS.md`.
