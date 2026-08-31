# Which shell is sourcing these drop-ins. Set once here so the later files can
# hand the right name to `starship init`, `mise activate` and friends instead of
# each re-deriving it.
if [ -n "${ZSH_VERSION:-}" ]; then
    DOTFILES_SHELL=zsh
elif [ -n "${BASH_VERSION:-}" ]; then
    DOTFILES_SHELL=bash
else
    DOTFILES_SHELL=sh
fi
