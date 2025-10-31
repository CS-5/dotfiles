#!/bin/bash

# Note: This file is named `install.sh` for compatibility reasons, to ensure it 
# works by default with GitHub Codespaces and VSCode Dev Containers.

set -eufo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

WORK_MODE=false
if [[ "${GITHUB_REPOSITORY:-}" != "" && "${GITHUB_REPOSITORY%%/*}" == "journalytic" ]]; then
    WORK_MODE=true
fi

DOTFILES_BIN_DIR="${HOME}/.local/bin"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
    --work)
        WORK_MODE=true
        shift
        ;;
    -h | --help)
        echo "Usage: $0 [--work]"
        echo "  --work    Configure for work environment"
        exit 0
        ;;
    *)
        echo "Unknown option $1"
        exit 1
        ;;
    esac
done

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
if [[ -z "${REMOTE_CONTAINERS_IPC:-}" && "${USER:-}" != "vscode" && "${CODESPACES:-}" != "true" ]]; then
    log_error "This script is intended for dev container environments only"
    exit 1
fi

# Create necessary directories
mkdir -p "$DOTFILES_BIN_DIR" ~/.config/fish/{conf.d,completions}

# Set environment for this session
if [[ "$WORK_MODE" == "true" ]]; then
    export DOTFILES_WORK_DC=true
    log_info "Setting up work dev container"
else
    log_info "Setting up non-work dev container"
fi

export PATH="$HOME/.local/bin:$PATH"
sudo apt-get update
sudo apt-get install -y curl git wget

#### Chezmoi Setup ####
show_progress "Installing chezmoi and dotfiles"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts"
export DOTFILES_SOURCE_DIR="$SCRIPT_DIR"
"$SCRIPT_DIR/install-dotfiles.sh"
log_success "Dotfiles installed and applied"

#### Tools ####
show_progress "Installing additional tools"
sudo apt-get install -y \
    gnupg \
    hyperfine \
    duf \
    fd-find \
    fzf \
    asciinema \
    unzip \
    jq \
    ripgrep \
    fish \
    lsd \
    neovim 

"$DOTFILES_BIN_DIR"/eget --to ~/.local/bin https://github.com/jesseduffield/lazygit
"$DOTFILES_BIN_DIR"/eget --to ~/.local/bin https://github.com/jesseduffield/lazydocker

"$SCRIPT_DIR/install-zellij.sh"

log_success "Tools installed"

#### GH CLI ####
show_progress "Installing GitHub CLI"
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/etc/apt/trusted.gpg.d/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/trusted.gpg.d/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
sudo apt update
sudo apt install -y gh
log_success "GitHub CLI installed"

show_progress "Installing Claude Code"
curl -fsSL https://claude.ai/install.sh | bash
log_success "Claude Code installed"

#### Shell ####
show_progress "Setting up shell"
fish -c "fundle install"
if [[ "$SHELL" != *"fish"* ]]; then
    log_info "Changing default shell to fish"
    sudo chsh -s "$(which fish)" "$USER"
fi
log_success "Shell setup complete"

log_success "Dev container setup complete"
