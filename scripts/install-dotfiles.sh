#!/bin/bash

set -eufo pipefail

DOTFILES_BIN_DIR="${HOME}/.local/bin"

if ! chezmoi="$(command -v chezmoi)"; then
  chezmoi="${DOTFILES_BIN_DIR}/chezmoi"
  echo "Installing chezmoi to '${chezmoi}'" >&2

  if command -v curl >/dev/null; then
    chezmoi_install_script="$(curl -fsSL https://chezmoi.io/get)"
  elif command -v wget >/dev/null; then
    chezmoi_install_script="$(wget -qO- https://chezmoi.io/get)"
  else
    echo "To install chezmoi, you must have curl or wget installed." >&2
    exit 1
  fi
  
  sh -c "${chezmoi_install_script}" -- -b "${DOTFILES_BIN_DIR}"
  unset chezmoi_install_script
fi

if [ -z "${DOTFILES_SOURCE_DIR:-}" ]; then
  DOTFILES_SOURCE_DIR="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)/.."
  export DOTFILES_SOURCE_DIR
fi

set -- init --apply --source="${DOTFILES_SOURCE_DIR}"

echo "Running 'chezmoi $*'" >&2

exec "$chezmoi" "$@"