#!/bin/bash

# render.sh - Render a chezmoi template to stdout for testing.
#
# Drives the real .chezmoi.toml.tmpl (via env overrides) so the output matches
# what `chezmoi apply` would produce — no duplicated data block to drift.
#
# Usage: ./render.sh [--identity personal|journalytic|kirbtech] [--dc] [--codespaces] <template-file>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Usage: $0 [--identity personal|journalytic|kirbtech] [--dc] [--codespaces] <template-file>"
    echo ""
    echo "Renders a chezmoi template file to stdout"
    echo ""
    echo "Options:"
    echo "  --identity     Work identity (default: personal)"
    echo "  --dc           Simulate a dev container environment"
    echo "  --codespaces   Simulate a GitHub Codespaces environment"
    echo ""
    echo "Examples:"
    echo "  $0 root/dot_gitconfig.tmpl"
    echo "  $0 --identity journalytic root/dot_gitconfig.tmpl"
    echo "  $0 --identity kirbtech --dc root/dot_gitconfig.tmpl"
}

export DOTFILES_IDENTITY="personal"

while [[ $# -gt 0 ]]; do
    case $1 in
    --identity)
        export DOTFILES_IDENTITY="$2"
        shift 2
        ;;
    --dc)
        export REMOTE_CONTAINERS_IPC=1
        shift
        ;;
    --codespaces)
        export CODESPACES=true
        shift
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        break
        ;;
    esac
done

if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

TEMPLATE_FILE="$1"

if [[ ! -f "$SCRIPT_DIR/$TEMPLATE_FILE" ]]; then
    echo "Error: Template file not found: $TEMPLATE_FILE" >&2
    exit 1
fi

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Render the real config template, then execute the target against it.
# --init registers the prompt* funcs (DOTFILES_IDENTITY bypasses the prompt).
chezmoi execute-template --init --source="$SCRIPT_DIR/root" \
    < "$SCRIPT_DIR/root/.chezmoi.toml.tmpl" > "$TEMP_DIR/chezmoi.toml"

chezmoi execute-template --init --config="$TEMP_DIR/chezmoi.toml" --source="$SCRIPT_DIR/root" \
    < "$SCRIPT_DIR/$TEMPLATE_FILE"
