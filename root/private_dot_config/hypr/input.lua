-- Managed by chezmoi. Only the overrides on top of Omarchy's defaults
-- ($OMARCHY_PATH/default/hypr/input.lua) live here; per-machine tweaks such as
-- pointer sensitivity go in ~/.config/local/hypr.lua (see looknfeel.lua).

-- Caps Lock is Escape. This replaces Omarchy's kb_options
-- ("omarchy:shift_caps_compose"), so Shift + Caps Lock is no longer compose.
hl.config({
  input = {
    kb_options = "caps:escape",
  },
})

-- Touchpad only, so inert on machines without one: macOS-style "natural"
-- scrolling (content follows your fingers), tap-and-drag with a short grace
-- period to lift and reposition mid-drag. disable_while_typing stays at its
-- default (on); it keeps the cursor from jumping mid-sentence.
hl.config({
  input = {
    touchpad = {
      natural_scroll = true,
      tap_and_drag = true,
      drag_lock = 2,
    },
  },
})

-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
