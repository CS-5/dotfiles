function zj --description "Attach to project-scoped zellij session"
    set -l session_name (basename (git rev-parse --show-toplevel 2>/dev/null; or pwd))
    set session_name (string replace -ra '[^a-zA-Z0-9_-]' '-' -- $session_name)
    zellij attach --create $session_name $argv
end
