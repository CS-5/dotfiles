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

# Create a temporary directory and config
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Render the config template using the repo's version
chezmoi execute-template --source="$SCRIPT_DIR/root" < "$SCRIPT_DIR/root/.chezmoi.toml.tmpl" > "$TEMP_DIR/chezmoi.toml"

# Use the rendered config to execute the template
chezmoi execute-template --config="$TEMP_DIR/chezmoi.toml" --source="$SCRIPT_DIR/root" < "$SCRIPT_DIR/$TEMPLATE_FILE"