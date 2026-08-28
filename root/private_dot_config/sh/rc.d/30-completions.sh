# zsh needs compinit before anything that registers completions.
if [ "$DOTFILES_SHELL" = zsh ]; then
    autoload -U compinit && compinit
fi
