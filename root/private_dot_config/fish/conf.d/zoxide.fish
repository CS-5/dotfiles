# See mise.fish for why this checks the activation rather than just the binary.
if command -v zoxide >/dev/null 2>&1; and not functions -q __zoxide_z
    zoxide init fish | source
end
