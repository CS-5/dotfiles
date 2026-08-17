# Dynamic completions for worktrunk (clap COMPLETE protocol): the registered
# completer queries the binary live, so nothing to regenerate on upgrades.
if status is-interactive; and command -q wt
    COMPLETE=fish wt | source
end
