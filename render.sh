#!/bin/bash

# render.sh - Render a chezmoi template to stdout for testing.
#
# Drives the real .chezmoi.toml.tmpl so the output matches what `chezmoi apply`
# would produce — no duplicated data block to drift.
#
# Work identity is detected from ~/work.email. To exercise that without touching
# the real home, this script writes a temp work.email and points the template at
# it via DOTFILES_WORK_EMAIL_FILE (HOME is left intact, so signing-key and other
# homeDir-derived paths stay faithful to the host).
#
# Usage: ./render.sh [--identity personal|journalytic|kirbtech] [--work-email <addr>] [--dc] [--codespaces] <template-file>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Usage: $0 [--identity personal|journalytic|kirbtech] [--work-email <addr>] [--dc] [--codespaces] <template-file>"
    echo ""
    echo "Renders a chezmoi template file to stdout"
    echo ""
    echo "Options:"
    echo "  --identity     Convenience for a known identity, written to ~/work.email"
    echo "                 (personal => no file; default: personal)"
    echo "  --work-email   Arbitrary work email written to ~/work.email (wins over"
    echo "                 --identity; use for edge cases like unknown domains)"
    echo "  --dc           Simulate a dev container environment"
    echo "  --codespaces   Simulate a GitHub Codespaces environment"
    echo ""
    echo "Examples:"
    echo "  $0 root/dot_gitconfig.tmpl"
    echo "  $0 --identity journalytic root/dot_gitconfig.tmpl"
    echo "  $0 --identity kirbtech --dc root/dot_gitconfig.tmpl"
    echo "  $0 --work-email me@example.com root/.chezmoi.toml.tmpl"
}

# Canonical emails for the --identity convenience flag. personal => no file.
identity_email() {
    case "$1" in
    personal) echo "" ;;
    journalytic) echo "carson@journalytic.com" ;;
    kirbtech) echo "carson.seese@kirbtech.com" ;;
    *)
        echo "Error: invalid identity '$1' (personal|journalytic|kirbtech)" >&2
        exit 1
        ;;
    esac
}

IDENTITY_EMAIL=""
WORK_EMAIL=""
WORK_EMAIL_SET=false

while [[ $# -gt 0 ]]; do
    case $1 in
    --identity)
        IDENTITY_EMAIL="$(identity_email "$2")"
        shift 2
        ;;
    --work-email)
        WORK_EMAIL="$2"
        WORK_EMAIL_SET=true
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

# Seed a temp work.email and point the template at it (instead of ~/work.email),
# so detection is exercised without writing to the real home. --work-email wins
# over --identity; absent both, the file stays absent => personal.
if $WORK_EMAIL_SET; then
    EFFECTIVE_EMAIL="$WORK_EMAIL"
else
    EFFECTIVE_EMAIL="$IDENTITY_EMAIL"
fi
export DOTFILES_WORK_EMAIL_FILE="$TEMP_DIR/work.email"
[[ -n "$EFFECTIVE_EMAIL" ]] && printf '%s' "$EFFECTIVE_EMAIL" >"$DOTFILES_WORK_EMAIL_FILE"

# Render the real config template (--init: this is the init-phase config), then
# execute the target against it. The target render omits --init on purpose: in
# init mode chezmoi does not read source state, so .chezmoitemplates partials
# and .chezmoidata are unavailable. Without --init both load, and the rendered
# config's [data] is still supplied via --config.
chezmoi execute-template --init --source="$SCRIPT_DIR/root" \
    < "$SCRIPT_DIR/root/.chezmoi.toml.tmpl" > "$TEMP_DIR/chezmoi.toml"

chezmoi execute-template --config="$TEMP_DIR/chezmoi.toml" --source="$SCRIPT_DIR/root" \
    < "$SCRIPT_DIR/$TEMPLATE_FILE"
