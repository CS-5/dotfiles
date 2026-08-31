if [ "$TERM_PROGRAM" = "vscode" ] && command -v code >/dev/null 2>&1; then
    . "$(code --locate-shell-integration-path "$DOTFILES_SHELL")"
fi
