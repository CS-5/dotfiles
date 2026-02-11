#!/bin/bash

set -eufo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

show_progress() {
    echo -e "${YELLOW}==> $1${NC}"
}

#### System Packages ####
show_progress "Updating system packages"
case "$(uname -s)" in
Darwin)
    brew update && brew upgrade && brew cleanup
    ;;
Linux)
    if command -v apt-get >/dev/null; then
        sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoremove -y && sudo apt-get clean
    fi
    ;;
esac
log_success "System packages updated"

#### Mise ####
show_progress "Updating mise"
mise self-update --yes
log_success "mise updated"

show_progress "Updating mise tools"
mise upgrade
log_success "mise tools updated"

#### Chezmoi ####
show_progress "Updating chezmoi"
chezmoi upgrade
log_success "chezmoi updated"
