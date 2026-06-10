#!/bin/bash

# Ensure an SSH commit-signing key exists at ~/.ssh/git_signing.
#
# For real hosts (WSL, VMs, bare-metal Linux) that own their signing key on
# disk. Dev containers don't need this — they sign via the host's forwarded
# SSH agent. Idempotent: a no-op if the key already exists.
#
# chezmoi reads the public key into `gitSigningPubKey` and the private key
# path into `gitSigningKeyFile` at apply time, so run this BEFORE applying.

set -eufo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

KEY_PATH="${HOME}/.ssh/git_signing"

if [[ -f "$KEY_PATH" ]]; then
    log_info "Signing key already exists at $KEY_PATH"
    exit 0
fi

mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"

log_info "Generating SSH commit-signing key at $KEY_PATH"
# Passphrase-less so signing needs no agent; protected by filesystem perms.
ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "git signing ($(hostname))"
chmod 600 "$KEY_PATH"
chmod 644 "${KEY_PATH}.pub"
log_success "Signing key generated"

# Upload to GitHub automatically when gh is installed and authenticated.
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    if gh ssh-key add "${KEY_PATH}.pub" --type signing --title "git signing ($(hostname))"; then
        log_success "Uploaded signing key to GitHub"
        exit 0
    fi
    log_warn "Automatic upload failed — add the key manually:"
fi

echo
log_warn "Add this PUBLIC key to GitHub as a Signing Key:"
log_warn "  https://github.com/settings/ssh/new  (Key type: Signing Key)"
echo
cat "${KEY_PATH}.pub"
echo
