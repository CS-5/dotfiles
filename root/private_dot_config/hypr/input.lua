hl.config({
  input = {
    kb_options = "caps:escape",
  },
})

-- macOS-style "natural" touchpad scrolling: content follows your fingers.
hl.config({
  input = {
    touchpad = {
      natural_scroll = true,
    },
  },
})

-- Touchpad responsiveness on the T14 Gen 2i. The big accuracy win is the
-- RMI4/SMBus switch in /etc/modprobe.d/99-thinkpad-touchpad.conf (the PS/2
-- fallback reports coarse coordinates); this just sharpens the pointer on top
-- of it. `disable_while_typing` stays on deliberately, it's what keeps the
-- cursor from jumping mid-sentence.
hl.config({
  input = {
    sensitivity = 0.2,

    touchpad = {
      tap_and_drag = true,
      drag_lock = 2,
    },
  },
})

-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
