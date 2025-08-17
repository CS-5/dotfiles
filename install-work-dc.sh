#!/bin/bash

set -eufo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_progress() {
    echo -e "${YELLOW}==> $1${NC}"
}

# Check if we're in a dev container
# TODO: User check here is probably not the most reliable, but it works for me, for now.
if [[ -z "${REMOTE_CONTAINERS_IPC:-}" && "${USER:-}" != "vscode" ]]; then
    log_error "This script is intended for dev container environments only"
    exit 1
fi

# Create necessary directories
mkdir -p ~/.local/bin ~/.config/fish/{conf.d,completions}

# Set environment for this session
export DOTFILES_WORK_DC=true
export PATH="$HOME/.local/bin:$PATH"

show_progress "Installing minimal dependencies for dotfiles setup"

# Update package list and install only essential packages needed for install script
sudo apt-get update
sudo apt-get install -y curl git wget

log_success "Essential packages installed"

show_progress "Installing chezmoi and dotfiles"

# Use the existing install script to set up chezmoi and dotfiles
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_SOURCE_DIR="$SCRIPT_DIR"

log_info "Running dotfiles install script"
"$SCRIPT_DIR/install.sh"

log_success "Dotfiles installed and applied"

show_progress "Installing additional system packages"

# Install remaining system packages
sudo apt-get install -y \
    gnupg \
    hyperfine \
    duf \
    fd-find \
    fzf \
    asciinema \
    httpie \
    unzip \
    jq \
    ripgrep \
    fish

log_success "System packages installed"

show_progress "Installing GitHub CLI"

# Install GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/etc/apt/trusted.gpg.d/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/trusted.gpg.d/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install -y gh

log_success "GitHub CLI installed"

show_progress "Setting up shell"

# Change default shell to fish if not already set
if [[ "$SHELL" != *"fish"* ]]; then
    log_info "Changing default shell to fish"
    sudo chsh -s "$(which fish)" "$USER"
fi

log_success "Shell setup complete"

show_progress "Final setup steps"

log_success "Work dev container setup complete!"
echo
log_info "You may need to restart your terminal or run 'exec fish' to fully activate the new environment"
echo
log_info "Available tools:"
log_info "  - Fish shell with custom configuration and aliases"
log_info "  - GitHub CLI for repository management"
log_info "  - Various CLI utilities (ripgrep, fd, jq, hyperfine, etc.)"