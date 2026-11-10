#!/bin/bash

# Shared logging utilities for dotfiles scripts.
# Usage: source "$SCRIPT_DIR/lib.sh", with SCRIPT_DIR set to this directory.

RED='\033[0;31m'
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

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_progress() {
    echo -e "${YELLOW}==> $1${NC}"
}
