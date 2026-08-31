# Before every tool below: starship, zoxide and mcfly can all be mise-managed,
# and mise's shim directory is not on PATH until this runs. Probing for them
# first would silently skip their setup on a host where mise is the only thing
# that provides them.
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate "$DOTFILES_SHELL" --shims)"
fi
