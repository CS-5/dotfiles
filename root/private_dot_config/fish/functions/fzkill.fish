function fzkill
  set -l selected_pids (ps -eo pid,args,%mem,%cpu | fzf --multi --header-lines=1 | awk '{print $1}')
  if test -n "$selected_pids"
    echo $selected_pids | xargs kill $argv
  end
end