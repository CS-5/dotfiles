function fzkill
  ps -eo cmd,%mem,%cpu,comm | fzf --multi --header-lines=1 | awk '{print $1}' | xargs kill $argv
end