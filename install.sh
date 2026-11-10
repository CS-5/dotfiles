#!/bin/bash

# Bootstrap script for Linux environments (dev containers, WSL, Debian/Ubuntu and Arch hosts).
# Named `install.sh` for compatibility with GitHub Codespaces and VSCode Dev Containers.

set -eufo pipefail

# Discover dev container workspace if present (/workspaces/<repo-name> convention).
# Uses find rather than a glob because `set -f` disables pathname expansion.
#
# Codespaces names the folder outright in CODESPACE_VSCODE_FOLDER, so prefer it.
# The find fallback has to skip dotdirs and sort: Codespaces also mounts
# /workspaces/.codespaces, and find emits filesystem order, so an unsorted
# `head -n1` picks .codespaces over the repo — and `mise trust` then trusts a
# directory with no config in it.
WORKSPACE_DIR="${CODESPACE_VSCODE_FOLDER:-}"
if [[ -n "$WORKSPACE_DIR" && ! -d "$WORKSPACE_DIR" ]]; then
    WORKSPACE_DIR=""
fi
if [[ -z "$WORKSPACE_DIR" && -d "/workspaces" ]]; then
    WORKSPACE_DIR="$(find /workspaces -maxdepth 1 -mindepth 1 -type d ! -name '.*' 2>/dev/null | sort | head -n1)"
fi

# Work identity is detected from ~/work.email at chezmoi render time. Pass
# --work-email to write that file here (non-interactive provisioning); leave it
# unset to keep any existing ~/work.email (no file => personal identity).
WORK_EMAIL=""

DOTFILES_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_SOURCE_DIR
SCRIPT_DIR="$DOTFILES_SOURCE_DIR/scripts"

source "$SCRIPT_DIR/lib.sh"

# Omarchy installs and updates packages through its own entrypoints (a libalpm
# hook aborts a direct `pacman -Syu`) and keeps bash as the shell.
IS_OMARCHY=false
if [[ -r /etc/os-release ]] && grep -qx 'ID=omarchy' /etc/os-release; then
    IS_OMARCHY=true
fi

# Omarchy's mise config provides most coding-agent CLIs itself (and keeps them
# current), unless this user opted out of Omarchy's default tools.
omarchy_provides() {
    [[ "$IS_OMARCHY" == "true" ]] && command -v omarchy-mise-default-tools >/dev/null 2>&1 &&
        omarchy-mise-default-tools declares "$1"
}

while [[ $# -gt 0 ]]; do
    case $1 in
    --work-email)
        WORK_EMAIL="$2"
        shift 2
        ;;
    -h | --help)
        echo "Usage: $0 [--work-email <address>]"
        echo "  --work-email  Work email address. Written to ~/work.email, which"
        echo "                drives the work identity. Omit on personal machines."
        exit 0
        ;;
    *)
        echo "Unknown option $1"
        exit 1
        ;;
    esac
done

mkdir -p ~/.local/bin
if [[ "$IS_OMARCHY" != "true" ]]; then
    mkdir -p ~/.config/fish/{conf.d,completions}
fi

log_info "Setting up environment${WORK_EMAIL:+ (work email: $WORK_EMAIL)}"

export PATH="$HOME/.local/bin:$PATH"

#### Bootstrap Dependencies ####
show_progress "Installing bootstrap dependencies"
# Same package names in Debian/Ubuntu and Arch repos.
BOOTSTRAP_PKGS=(curl git wget unzip gnupg fish neovim)
if [[ "$IS_OMARCHY" == "true" ]]; then
    # No fish (bash is the shell here). chezmoi comes from the Arch repos rather
    # than its curl installer, so `omarchy update` keeps it current.
    # `omarchy pkg add` installs only what is missing, without a -Syu.
    omarchy pkg add curl git wget unzip gnupg neovim chezmoi
elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y "${BOOTSTRAP_PKGS[@]}"
elif command -v pacman >/dev/null 2>&1; then
    # -Syu, not -Sy: Arch doesn't support partial upgrades, so installing
    # against a synced-but-not-upgraded system can break shared libs.
    # --needed skips packages already present.
    sudo pacman -Syu --needed --noconfirm "${BOOTSTRAP_PKGS[@]}"
else
    log_error "No supported package manager found (apt-get or pacman)."
    log_error "Install these manually, then re-run: ${BOOTSTRAP_PKGS[*]}"
    exit 1
fi
log_success "Bootstrap dependencies installed"

#### Mise ####
# Leave an existing mise alone. Dev container images commonly install a pinned
# mise and assert the pin at build time; reinstalling from mise.run would replace
# it with latest and silently defeat that. Same shape as the guards in
# .chezmoiscripts/*mise*.
if command -v mise >/dev/null 2>&1; then
    log_info "mise $(mise --version | cut -d' ' -f1) already installed, leaving it as-is"
else
    show_progress "Installing mise"
    curl -fsSL https://mise.run | sh
    log_success "mise installed"
fi
if [[ -n "$WORKSPACE_DIR" ]]; then
    mise trust --cd="$WORKSPACE_DIR" --quiet
fi

#### Chezmoi Setup ####
show_progress "Installing chezmoi and dotfiles"
"$SCRIPT_DIR/install-dotfiles.sh" ${WORK_EMAIL:+--work-email "$WORK_EMAIL"}
log_success "Dotfiles installed and applied"

#### Shell ####
# Omarchy keeps bash: its own ~/.bashrc layering is what the dotfiles extend.
if [[ "$IS_OMARCHY" != "true" ]]; then
    show_progress "Setting up shell"
    fish -c "fundle install"
    if [[ "${SHELL:-}" != *"fish"* ]]; then
        log_info "Changing default shell to fish"
        sudo chsh -s "$(which fish)" "${USER:-$(id -un)}"
    fi
    log_success "Shell setup complete"
fi

#### Coding-agent CLIs ####
# Each with its vendor's installer, so it can self-update (see `update`),
# except where Omarchy's mise config already provides it.

#### Claude Code ####
if omarchy_provides claude; then
    log_info "Claude Code is provided by Omarchy"
else
    show_progress "Installing Claude Code"
    curl -fsSL https://claude.ai/install.sh | bash
    log_success "Claude Code installed"
fi

#### Codex ####
# CODEX_NON_INTERACTIVE: the installer otherwise offers to launch codex via
# /dev/tty, which would stall an unattended bootstrap.
if omarchy_provides codex; then
    log_info "Codex is provided by Omarchy"
else
    show_progress "Installing Codex"
    curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh
    log_success "Codex installed"
fi

#### Antigravity CLI ####
if omarchy_provides antigravity-cli; then
    log_info "Antigravity CLI is provided by Omarchy"
else
    show_progress "Installing Antigravity CLI"
    curl -fsSL https://antigravity.google/cli/install.sh | bash
    log_success "Antigravity CLI installed"
fi

#### GitHub Copilot CLI ####
# PREFIX pins ~/.local/bin; the installer would pick /usr/local when run as root.
if omarchy_provides copilot; then
    log_info "GitHub Copilot CLI is provided by Omarchy"
else
    show_progress "Installing GitHub Copilot CLI"
    curl -fsSL https://gh.io/copilot-install | PREFIX="$HOME/.local" bash
    log_success "GitHub Copilot CLI installed"
fi

#### opencode ####
# --no-modify-path: the installer would otherwise append to chezmoi-managed
# shell configs, which already put ~/.opencode/bin on PATH.
if omarchy_provides opencode; then
    log_info "opencode is provided by Omarchy"
else
    show_progress "Installing opencode"
    curl -fsSL https://opencode.ai/v2/install | bash -s -- --no-modify-path
    log_success "opencode installed"
fi

log_success "Setup complete"
