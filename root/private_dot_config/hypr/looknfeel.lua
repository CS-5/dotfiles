-- Managed by chezmoi. Only the overrides on top of Omarchy's defaults
-- ($OMARCHY_PATH/default/hypr/looknfeel.lua) live here.

-- Tighter margins around windows (Omarchy's defaults are gaps_in 5 /
-- gaps_out 10), without butting windows straight up against the bar.
hl.config({
  general = {
    gaps_in = 2,
    gaps_out = 4,
  },

  -- Softer corners. Rounding has to stay a little larger than border_size or
  -- the border reads as a hard notch at the corner.
  decoration = {
    rounding = 8,
  },
})

-- Per-machine overrides, never managed by the dotfiles: ~/.config/local/hypr.lua.
-- Loaded here because this is the last managed file hyprland.lua requires, so
-- it can override input.lua as well. Cleared first so `hyprctl reload` re-runs
-- it; Omarchy's bootstrap only clears modules under its own prefixes.
package.loaded["local.hypr"] = nil
require("default.hypr.require_optional").module("local.hypr")
