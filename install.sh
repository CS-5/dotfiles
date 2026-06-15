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
if [[ -n "$WORK_EMAIL" ]]; then
    "$SCRIPT_DIR/install-dotfiles.sh" --work-email "$WORK_EMAIL"
else
    "$SCRIPT_DIR/install-dotfiles.sh"
fi
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
