# Brainrot Bakery — Doughnut Dash (v6, baseplate + cylinder fix)

A 3D Roblox brainrot game for make.fun's roblox-brainrot-01: a warm bakery
plaza in midday light, an oven-line conveyor rolling fresh brainrot pastries
past four stalls, and a Burn Wave that sweeps the map and makes you drop what
you carry unless you dash home. Steal a Brainrot's loop, baked fresh.

This is the v6 baseplate + cylinder build. The v5 ran clean (no Output error,
Rolling Pin in the hotbar) but the player walked up to the belt and found
nothing there. An independent check pulled the scripts out of the v5 place
file and found two real bugs in `BakeryWorld`:

- **Baseplate:** the place's Baseplate is 512x20x512, and its top face sat at
  Y=10, burying the whole bakery (plaza, belt, pedestals, brainrots riding at
  Y~2.7). Fixed here: `World.build()` sinks the Baseplate so its top face is
  at Y=0, whatever the place ships. The belt is also raised so its top sits
  clearly above the plaza disc (belt top Y=1.6, brainrots ride on it), instead
  of hiding inside the plaza at the same height.
- **Cylinders:** a Roblox Cylinder part's axis is its X axis, not Y (the v4
  "cylinder rule" comment was wrong). The v5 built the plaza, pedestal bases
  and tops, barrels, hat brims/crowns and candle sticks as if the axis were Y,
  so they were oriented wrong. Fixed here with an `upright()` helper that swaps
  a part's X/Y size and rolls it 90 degrees about Z so its axis points up,
  applied to the plaza, every pedestal base/top, the barrel, the hat brim and
  crown, and the candle stick. The brainrot body with a Cylinder shape keeps
  its single 90-degree roll (it was already upright).

Kept from v5: the init requires `script.*` (Rojo makes the server folder the
Script itself), the slap is client-driven (the Rolling Pin is a plain Tool with
only a Handle; nothing writes `.Source` anywhere), midday light, the warm tan
belt, and 8 pedestals per plot.
