#!/bin/bash

# render.sh - Simple chezmoi template renderer
# Usage: ./render.sh [template-file]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Usage: $0 [template-file]"
    echo ""
    echo "Renders a chezmoi template file to stdout"
    echo ""
    echo "Examples:"
    echo "  $0 root/.chezmoi.toml.tmpl"
    echo "  $0 root/dot_gitconfig.tmpl"
}

if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

TEMPLATE_FILE="$1"

if [[ ! -f "$SCRIPT_DIR/$TEMPLATE_FILE" ]]; then
    echo "Error: Template file not found: $TEMPLATE_FILE" >&2
    exit 1
fi

# Create a temporary directory for safe rendering
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Copy the entire dotfiles structure
cp -r "$SCRIPT_DIR"/* "$TEMP_DIR/"

# Create a temporary home directory
mkdir -p "$TEMP_DIR/temp_home/.config/chezmoi"
mkdir -p "$TEMP_DIR/temp_home/.local/share/chezmoi"

# Copy source files to the temporary chezmoi source directory
cp -r "$TEMP_DIR/root"/* "$TEMP_DIR/temp_home/.local/share/chezmoi/"

# Set up environment
export HOME="$TEMP_DIR/temp_home"
export CHEZMOI_SOURCE_DIR="$TEMP_DIR/temp_home/.local/share/chezmoi"

# Set some default variables that might be missing
export DOTFILES_SOURCE_DIR="$TEMP_DIR/temp_home/.local/share/chezmoi"

# Change to temp directory and render
cd "$TEMP_DIR/temp_home"

# Initialize chezmoi in the temp directory
chezmoi init --source="$TEMP_DIR/temp_home/.local/share/chezmoi" 2>/dev/null || true

# Render the template
chezmoi execute-template < "$SCRIPT_DIR/$TEMPLATE_FILE"