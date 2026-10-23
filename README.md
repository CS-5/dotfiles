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

Commits are signed with an SSH key, picked at `chezmoi init` time:

1. If `~/.ssh/git_signing` exists, git signs directly from that file (no agent
   needed). On real hosts (WSL, VMs, bare metal), `install.sh` generates one.
2. Otherwise, on work machines where Bitwarden is the SSH agent, git signs
   through Bitwarden with the "GitHub Signing" key stored in the vault. Nothing
   is kept on disk; Bitwarden must be running and unlocked to commit.
3. Otherwise, commits are not signed.

Signing is always disabled in Codespaces (GitHub signs those server-side).

## Link routing (macOS)

On macOS, the dotfiles configure [Brouter](https://github.com/CS-5/Brouter) at
`~/.config/brouter/config.toml`. Install the app yourself from its
[releases](https://github.com/CS-5/Brouter/releases) and let it become the
default browser. The routing rules are described in `AGENTS.md`.
