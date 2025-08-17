#!/bin/bash

set -eufo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
WORK_MODE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --work)
            WORK_MODE=true
            shift
            ;;
        -h|--help)
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
if [[ -z "${REMOTE_CONTAINERS_IPC:-}" && "${USER:-}" != "vscode" ]]; then
    log_error "This script is intended for dev container environments only"
    exit 1
fi

# Create necessary directories
mkdir -p ~/.local/bin ~/.config/fish/{conf.d,completions}

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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_SOURCE_DIR="$SCRIPT_DIR"
"$SCRIPT_DIR/install.sh"
log_success "Dotfiles installed and applied"

#### System packages ####
show_progress "Installing additional system packages"
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

#### GH CLI ####
show_progress "Installing GitHub CLI (work mode)"
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/etc/apt/trusted.gpg.d/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/trusted.gpg.d/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install -y gh
log_success "GitHub CLI installed"

#### Shell ####
show_progress "Setting up shell"
if [[ "$SHELL" != *"fish"* ]]; then
    log_info "Changing default shell to fish"
    sudo chsh -s "$(which fish)" "$USER"
fi
fish -c "fundle install"
log_success "Shell setup complete"

log_success "Dev container setup complete"