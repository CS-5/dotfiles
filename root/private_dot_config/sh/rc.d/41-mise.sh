if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate "$DOTFILES_SHELL" --shims)"
fi
