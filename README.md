# dotfiles

My personal dotfiles, managed with [chezmoi](https://www.chezmoi.io/).

## Install

### Linux (Debian/Ubuntu) — dev containers, WSL, cloud VMs

Clone and run the bootstrap script. It installs mise, chezmoi, fish, and Claude
Code, then applies the dotfiles:

```sh
git clone https://github.com/CS-5/dotfiles.git ~/.local/share/chezmoi
~/.local/share/chezmoi/install.sh [--work-email <address>]
```

The work identity comes from a single file, `~/work.email`, containing just your
work email address; its domain selects the identity (e.g. `…@kirbtech.com`). No
file means a personal machine. `--work-email` writes that file before applying;
omit it for personal setups. Cloud VMs can provision unattended via
[`cloud-init.yaml`](cloud-init.yaml).

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
