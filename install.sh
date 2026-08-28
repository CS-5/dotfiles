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

# Dev containers sign commits via the host's forwarded SSH agent; real hosts
# (WSL, VMs, bare metal) own a signing key on disk.
IS_DC=false
if [[ -n "${REMOTE_CONTAINERS_IPC:-}" || "${USER:-}" == "vscode" || "${CODESPACES:-}" == "true" || -n "$WORKSPACE_DIR" ]]; then
    IS_DC=true
fi

# Omarchy (ID=omarchy in /etc/os-release) provides several of the things this
# script would otherwise install, and blocks others outright: a libalpm hook
# refuses any direct `pacman -Syu`. Matches the isOmarchy flag the chezmoi
# templates key on.
IS_OMARCHY=false
if [[ -r /etc/os-release ]] && grep -q '^ID=omarchy$' /etc/os-release; then
    IS_OMARCHY=true
fi

# Work identity is detected from ~/work.email at chezmoi render time. Pass
# --work-email to write that file here (non-interactive provisioning); leave it
# unset to keep any existing ~/work.email (no file => personal identity).
WORK_EMAIL=""

DOTFILES_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_SOURCE_DIR
SCRIPT_DIR="$DOTFILES_SOURCE_DIR/scripts"

source "$SCRIPT_DIR/lib.sh"

# Parse command line arguments
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

# Create necessary directories
mkdir -p ~/.local/bin ~/.config/fish/{conf.d,completions}

log_info "Setting up environment${WORK_EMAIL:+ (work email: $WORK_EMAIL)}"

export PATH="$HOME/.local/bin:$PATH"

#### Bootstrap Dependencies ####
show_progress "Installing bootstrap dependencies"
# Same package names in Debian/Ubuntu and Arch repos.
BOOTSTRAP_PKGS=(curl git wget unzip gnupg fish neovim)
if [[ "$IS_OMARCHY" == "true" ]]; then
    # `omarchy pkg add` installs only what is missing, and avoids the -Syu that
    # Omarchy's libalpm update-guard hook aborts.
    omarchy pkg add "${BOOTSTRAP_PKGS[@]}"
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

#### Signing Key ####
# Must run before chezmoi applies so the key is detected at render time.
if [[ "$IS_DC" != "true" ]]; then
    show_progress "Ensuring commit signing key"
    "$SCRIPT_DIR/generate-signing-key.sh"
    log_success "Signing key ready"
fi

#### Chezmoi ####
# On Omarchy, take chezmoi from the repos rather than the curl installer, so it
# is upgraded by `omarchy update` along with everything else (extra/ carries
# 2.72, comfortably past .chezmoiversion). install-dotfiles.sh only fetches a
# binary when chezmoi is absent, so putting it on PATH here is enough.
if [[ "$IS_OMARCHY" == "true" ]] && ! command -v chezmoi >/dev/null 2>&1; then
    show_progress "Installing chezmoi from the Arch repos"
    omarchy pkg add chezmoi
    log_success "chezmoi installed"
fi

#### Chezmoi Setup ####
show_progress "Installing chezmoi and dotfiles"
if [[ -n "$WORK_EMAIL" ]]; then
    "$SCRIPT_DIR/install-dotfiles.sh" --work-email "$WORK_EMAIL"
else
    "$SCRIPT_DIR/install-dotfiles.sh"
fi
log_success "Dotfiles installed and applied"

#### Shell ####
# Fish plugins are installed by .chezmoiscripts/run_onchange_after_08-fish-plugins.sh,
# which just ran as part of the apply above — it lives there rather than here so
# that macOS, which applies chezmoi directly with no bootstrap script, gets them
# too.
show_progress "Setting up shell"
if [[ "${SHELL:-}" != *"fish"* ]]; then
    log_info "Changing default shell to fish"
    sudo chsh -s "$(which fish)" "${USER:-$(id -un)}"
fi
log_success "Shell setup complete"

log_success "Setup complete"
