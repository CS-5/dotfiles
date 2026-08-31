-- Tighter margins around windows. Omarchy defaults are gaps_in 5 / gaps_out 10;
-- these reclaim screen space on the T14's 14" panel without butting windows
-- straight up against the bar.
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
