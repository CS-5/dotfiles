# dotfiles

My personal dotfiles, managed with [chezmoi](https://www.chezmoi.io/).

## Install

### Linux (Debian/Ubuntu/Arch/Omarchy) — dev containers, WSL, cloud VMs

Clone and run the bootstrap script. It installs mise, chezmoi, fish, Claude
Code, Codex, Antigravity CLI, GitHub Copilot CLI, and opencode, then applies the
dotfiles. On [Omarchy](https://omarchy.org/) it installs through Omarchy's own
commands instead, keeps bash as the shell, and leaves the coding-agent CLIs that
Omarchy already provides to Omarchy:

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

Each machine signs commits with its own key, `~/.ssh/git_signing`, which
`chezmoi apply` creates (no passphrase, so signing never prompts) and registers
with GitHub as a signing key through `gh`. Registering needs `gh` logged in
with the `admin:ssh_signing_key` scope. Applying from a terminal asks for it;
otherwise apply prints the command, and the next apply (or `update`) finishes
the job. Until then the machine's commits show as Unverified on GitHub. To
retire a machine, delete its key under GitHub's SSH and GPG keys settings.

Dev containers sign only when the host's forwarded SSH agent holds a key that
is registered with GitHub (such as the "Signing" key in Bitwarden), and
otherwise commit unsigned. Run `git-signing-agent` after connecting an agent
to pick it up without opening a new shell.

Signing is always disabled in Codespaces (GitHub signs those server-side).

## Link routing (macOS)

On macOS, the dotfiles configure [Brouter](https://github.com/CS-5/Brouter) at
`~/.config/brouter/config.toml`. Install the app yourself from its
[releases](https://github.com/CS-5/Brouter/releases) and let it become the
default browser. The routing rules are described in `AGENTS.md`.

## Per-machine overrides

Anything that should apply to one machine only goes in `~/.config/local/`,
which the dotfiles never touch: `shell.sh` (bash/zsh), `shell.fish`,
`gitconfig`, and `hypr.lua` (Omarchy). Each is loaded last, if it exists.
