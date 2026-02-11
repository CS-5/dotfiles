#!/bin/bash

set -eufo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts"
source "$SCRIPT_DIR/lib.sh"

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
