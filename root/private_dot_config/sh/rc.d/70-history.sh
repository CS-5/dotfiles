if [ "$DOTFILES_SHELL" = zsh ]; then
    HISTFILE=~/.zsh_history
    HISTSIZE=20000
    SAVEHIST=20000
    setopt HIST_IGNORE_DUPS
    setopt HIST_IGNORE_ALL_DUPS
    setopt HIST_IGNORE_SPACE
    setopt HIST_SAVE_NO_DUPS
    setopt APPEND_HISTORY
    setopt SHARE_HISTORY
elif [ "$DOTFILES_SHELL" = bash ]; then
    HISTFILE=~/.bash_history
    HISTSIZE=20000
    HISTFILESIZE=20000
    HISTCONTROL=ignoreboth:erasedups
    shopt -s histappend
    shopt -s cmdhist
fi
