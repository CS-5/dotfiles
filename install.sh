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

DOTFILES_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_SOURCE_DIR
SCRIPT_DIR="$DOTFILES_SOURCE_DIR/scripts"

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

IS_LXC=false
if grep -qa 'container=lxc' /proc/1/environ 2>/dev/null; then
    IS_LXC=true
fi

if [[ "$IS_LXC" != "true" && -z "${REMOTE_CONTAINERS_IPC:-}" && "${USER:-}" != "vscode" && "${CODESPACES:-}" != "true" ]]; then
    log_error "This script is intended for dev container/LXC environments only"
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

#### Bootstrap Dependencies ####
show_progress "Installing bootstrap dependencies"
sudo apt-get update
sudo apt-get install -y curl git wget unzip gnupg fish
log_success "Bootstrap dependencies installed"

#### Mise ####
show_progress "Installing mise"
curl https://mise.run | sh
log_success "mise installed"

#### Chezmoi Setup ####
show_progress "Installing chezmoi and dotfiles"
"$SCRIPT_DIR/install-dotfiles.sh"
log_success "Dotfiles installed and applied"

#### Claude Code ####
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
