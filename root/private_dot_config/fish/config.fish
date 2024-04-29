##### Aliases #####
source ~/.config/fish/alias.fish

##### Add paths #####
fish_add_path ~/.local/bin

##### Syntax Highlighting #####
set -g fish_color_autosuggestion '555'  'brblack'
set -g fish_color_cancel -r
set -g fish_color_command --bold
set -g fish_color_comment red
set -g fish_color_cwd green
set -g fish_color_cwd_root red
set -g fish_color_end brmagenta
set -g fish_color_error brred
set -g fish_color_escape 'bryellow'  '--bold'
set -g fish_color_history_current --bold
set -g fish_color_host normal
set -g fish_color_match --background=brblue
set -g fish_color_normal normal
set -g fish_color_operator bryellow
set -g fish_color_param cyan
set -g fish_color_quote yellow
set -g fish_color_redirection brblue
set -g fish_color_search_match 'bryellow'  '--background=brblack'
set -g fish_color_selection 'white'  '--bold'  '--background=brblack'
set -g fish_color_user brgreen
set -g fish_color_valid_path --underline

##### Setup Plugins #####
fundle plugin 'joseluisq/gitnow'
fundle plugin 'edc/bass'
fundle plugin 'PatrickF1/fzf.fish'
fundle plugin 'jorgebucaran/autopair.fish'

fundle init

##### Init Tools #####
if status is-interactive
    starship init fish | source
end