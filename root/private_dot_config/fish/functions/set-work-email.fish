function set-work-email --description "Write ~/work.email and re-apply dotfiles with the work identity"
    if test (count $argv) -ne 1
        echo "Usage: set-work-email <address>" >&2
        echo "Writes ~/work.email and re-runs 'chezmoi init --apply' so the" >&2
        echo "work identity takes effect (e.g. inside a fresh Codespace)." >&2
        return 1
    end
    printf '%s' $argv[1] >~/work.email
    chezmoi init --apply
end
