# Guarded on the activation, not just on `command -v mise`: something earlier in
# the conf.d pass may already have activated it (Omarchy's omarchy-fish does,
# from fish's vendor_conf.d). Re-activating is harmless — mise's script
# deactivates first and guards __MISE_ORIG_PATH — but it costs another
# subprocess on every shell start. `mise` becomes a function once activated, and
# functions are per-shell, so a nested fish still activates properly.
if command -v mise >/dev/null 2>&1; and not functions -q mise
    if status is-interactive
        mise activate fish | source
    else
        mise activate fish --shims | source
    end
end
