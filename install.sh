#!/bin/bash

# Bootstrap script for Linux environments (dev containers, WSL, Ubuntu hosts).
# Named `install.sh` for compatibility with GitHub Codespaces and VSCode Dev Containers.

set -eufo pipefail

# Discover dev container workspace if present (/workspaces/<repo-name> convention).
# Uses find rather than a glob because `set -f` disables pathname expansion.
WORKSPACE_DIR=""
if [[ -d "/workspaces" ]]; then
    WORKSPACE_DIR="$(find /workspaces -maxdepth 1 -mindepth 1 -type d 2>/dev/null | head -n1)"
fi

# Dev containers sign commits via the host's forwarded SSH agent; real hosts
# (WSL, VMs, bare metal) own a signing key on disk.
IS_DC=false
if [[ -n "${REMOTE_CONTAINERS_IPC:-}" || "${USER:-}" == "vscode" || "${CODESPACES:-}" == "true" || -n "$WORKSPACE_DIR" ]]; then
    IS_DC=true
fi

# Auto-detect identity from repository context (work orgs only). Personal and
# unknown contexts leave IDENTITY empty so they fall through to the prompt
# (interactive) or the required --identity flag (non-interactive) below.
IDENTITY=""
if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
    case "${GITHUB_REPOSITORY%%/*}" in
    journalytic) IDENTITY="journalytic" ;;
    kirbtech) IDENTITY="kirbtech" ;;
    esac
elif [[ -n "$WORKSPACE_DIR" ]]; then
    repo_url=$(git -C "$WORKSPACE_DIR" remote get-url origin 2>/dev/null || true)
    case "$repo_url" in
    *journalytic*) IDENTITY="journalytic" ;;
    *kirbtech*) IDENTITY="kirbtech" ;;
    esac
fi

DOTFILES_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_SOURCE_DIR
SCRIPT_DIR="$DOTFILES_SOURCE_DIR/scripts"

source "$SCRIPT_DIR/lib.sh"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
    --identity)
        IDENTITY="$2"
        shift 2
        ;;
    -h | --help)
        echo "Usage: $0 [--identity personal|journalytic|kirbtech]"
        echo "  --identity    Work identity. Auto-detected from the repo org when"
        echo "                possible; otherwise prompted (interactive) or required"
        echo "                (non-interactive)."
        exit 0
        ;;
    *)
        echo "Unknown option $1"
        exit 1
        ;;
    esac
done

# Resolve identity: flag/auto-detect already set it; otherwise prompt when
# running interactively, or require the flag when not (cloud-init, CI, hooks).
if [[ -z "$IDENTITY" ]]; then
    if [[ -t 0 ]]; then
        PS3="Select identity: "
        select choice in personal journalytic kirbtech; do
            [[ -n "$choice" ]] && IDENTITY="$choice" && break
            echo "Invalid selection, try again." >&2
        done
    else
        log_error "No identity detected. Pass --identity personal|journalytic|kirbtech"
        exit 1
    fi
fi

case "$IDENTITY" in
personal | journalytic | kirbtech) ;;
*)
    log_error "Invalid identity '$IDENTITY' (must be personal, journalytic, or kirbtech)"
    exit 1
    ;;
esac

# Create necessary directories
mkdir -p ~/.local/bin ~/.config/fish/{conf.d,completions}

log_info "Setting up environment (identity: $IDENTITY)"

export PATH="$HOME/.local/bin:$PATH"

#### Bootstrap Dependencies ####
show_progress "Installing bootstrap dependencies"
sudo apt-get update
sudo apt-get install -y curl git wget unzip gnupg fish neovim
log_success "Bootstrap dependencies installed"

#### Mise ####
show_progress "Installing mise"
curl https://mise.run | sh
if [[ -n "$WORKSPACE_DIR" ]]; then
    mise trust --cd="$WORKSPACE_DIR" --quiet
fi
log_success "mise installed"

#### Signing Key ####
# Must run before chezmoi applies so the key is detected at render time.
if [[ "$IS_DC" != "true" ]]; then
    show_progress "Ensuring commit signing key"
    "$SCRIPT_DIR/generate-signing-key.sh"
    log_success "Signing key ready"
fi

#### Chezmoi Setup ####
show_progress "Installing chezmoi and dotfiles"
"$SCRIPT_DIR/install-dotfiles.sh" --identity "$IDENTITY"
log_success "Dotfiles installed and applied"

#### Shell ####
show_progress "Setting up shell"
fish -c "fundle install"
if [[ "$SHELL" != *"fish"* ]]; then
    log_info "Changing default shell to fish"
    sudo chsh -s "$(which fish)" "$USER"
fi
log_success "Shell setup complete"

#### Claude Code ####
show_progress "Installing Claude Code"
curl -fsSL https://claude.ai/install.sh | bash
log_success "Claude Code installed"

log_success "Setup complete"
