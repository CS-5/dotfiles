if command -v mise >/dev/null 2>&1
    if status is-interactive
        mise activate fish | source
    else
        mise activate fish --shims | source
    end
end
