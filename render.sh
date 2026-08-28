#!/bin/bash

# render.sh - Render a chezmoi template to stdout for testing.
#
# Drives the real .chezmoi.toml.tmpl so the output matches what `chezmoi apply`
# would produce — no duplicated data block to drift.
#
# Work identity is detected from ~/work.email, falling back to the
# DOTFILES_WORK_EMAIL env var. To exercise that without touching the real
# home, this script points the file check at a nonexistent temp path (via
# DOTFILES_WORK_EMAIL_FILE) and supplies the email through the env var, so
# the template's real detection logic (env fallback + domain mapping) runs
# (HOME is left intact, so signing-key and other homeDir-derived paths stay
# faithful to the host).
#
# Usage: ./render.sh [--identity IDENTITY] [--work-email <addr>] [--dc] [--codespaces] [--data <json>] <template-file>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Usage: $0 [--identity personal|journalytic|kirbtech] [--work-email <addr>] [--dc] [--codespaces] [--data <json>] <template-file>"
    echo ""
    echo "Renders a chezmoi template file to stdout"
    echo ""
    echo "Options:"
    echo "  --identity     Convenience for a known identity, supplied via"
    echo "                 DOTFILES_WORK_EMAIL (personal => none; default: personal)"
    echo "  --work-email   Arbitrary work email, supplied via DOTFILES_WORK_EMAIL"
    echo "                 (wins over --identity; use for edge cases like unknown"
    echo "                 domains)"
    echo "  --dc           Simulate a dev container environment"
    echo "  --codespaces   Simulate a GitHub Codespaces environment"
    echo "  --data         JSON object of [data] overrides passed to chezmoi's"
    echo "                 --override-data (e.g. '{\"isMac\":true}' to preview the"
    echo "                 macOS render from any platform)"
    echo ""
    echo "Examples:"
    echo "  $0 root/dot_gitconfig.tmpl"
    echo "  $0 --identity journalytic root/dot_gitconfig.tmpl"
    echo "  $0 --identity kirbtech --dc root/dot_gitconfig.tmpl"
    echo "  $0 --work-email me@example.com root/.chezmoi.toml.tmpl"
    echo "  $0 --data '{\"isMac\":true}' root/dot_zshrc.tmpl"
}

# Canonical emails for the --identity convenience flag. personal => no email.
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
OVERRIDE_DATA=""

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
    --data)
        OVERRIDE_DATA="$2"
        shift 2
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

# Neutralize the host's real ~/work.email by pointing the file check at a
# path that never exists, then supply the requested email via the env var
# fallback. --work-email wins over --identity; absent both, the env var is
# cleared => personal.
export DOTFILES_WORK_EMAIL_FILE="$TEMP_DIR/work.email"
if $WORK_EMAIL_SET; then
    EFFECTIVE_EMAIL="$WORK_EMAIL"
else
    EFFECTIVE_EMAIL="$IDENTITY_EMAIL"
fi
if [[ -n "$EFFECTIVE_EMAIL" ]]; then
    export DOTFILES_WORK_EMAIL="$EFFECTIVE_EMAIL"
else
    unset DOTFILES_WORK_EMAIL
fi

# Render the real config template (--init: this is the init-phase config), then
# execute the target against it. The target render omits --init on purpose: in
# init mode chezmoi does not read source state, so .chezmoitemplates partials
# and .chezmoidata are unavailable. Without --init both load, and the rendered
# config's [data] is still supplied via --config.
chezmoi execute-template --init --source="$SCRIPT_DIR/root" \
    <"$SCRIPT_DIR/root/.chezmoi.toml.tmpl" >"$TEMP_DIR/chezmoi.toml"

# --override-data (chezmoi >= 2.66) applies last, on top of the rendered
# config's [data], so --data can force values like isMac or isDc directly.
OVERRIDE_ARGS=()
if [[ -n "$OVERRIDE_DATA" ]]; then
    OVERRIDE_ARGS=(--override-data "$OVERRIDE_DATA")
fi

chezmoi execute-template --config="$TEMP_DIR/chezmoi.toml" --source="$SCRIPT_DIR/root" \
    ${OVERRIDE_ARGS[@]+"${OVERRIDE_ARGS[@]}"} <"$SCRIPT_DIR/$TEMPLATE_FILE"
