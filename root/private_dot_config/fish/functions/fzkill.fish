function fzkill
  ps -eo pid,args,%mem,%cpu | fzf --multi --header-lines=1 | awk '{print $1}' | xargs kill $argv
end