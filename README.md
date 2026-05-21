# StacklineAerospace.spoon

Stack-position indicators for [AeroSpace](https://github.com/nikitabobko/AeroSpace) accordion containers, inspired by [stackline](https://github.com/AdamWagner/stackline) (which is yabai-only).

Draws small pills just outside the focused window (above the top edge for horizontal accordions, left of the left edge for vertical) showing how many windows are in its stack and which one is focused.

## Requirements

- [AeroSpace](https://github.com/nikitabobko/AeroSpace) (tested with 0.20.3-Beta)
- [Hammerspoon](https://www.hammerspoon.org/)
- `accordion-padding >= 1` in `~/.aerospace.toml` (see [Limitations](#limitations))

## Installation

```sh
git clone https://github.com/dexteresc/StacklineAerospace.spoon \
  ~/.hammerspoon/Spoons/StacklineAerospace.spoon
```

Then in `~/.hammerspoon/init.lua`:

```lua
hs.loadSpoon("StacklineAerospace")
spoon.StacklineAerospace:start()
```

Reload Hammerspoon. Switch a workspace to accordion (`alt-comma` by default) with two or more windows and focus one of them.

## Configuration

Override defaults after `loadSpoon` and before `:start()`:

```lua
hs.loadSpoon("StacklineAerospace")
spoon.StacklineAerospace.pillThickness = 4
spoon.StacklineAerospace.pillLength = 18
spoon.StacklineAerospace.cornerInset = 16
spoon.StacklineAerospace.focusedColor = { red = 0.4, green = 0.8, blue = 1.0, alpha = 1.0 }
spoon.StacklineAerospace:start()
```

| Option | Default | Meaning |
|---|---|---|
| `aerospace` | `/opt/homebrew/bin/aerospace` | path to the `aerospace` CLI |
| `pollInterval` | `2.0` | fallback poll interval (seconds) |
| `debounceMs` | `60` | coalesce window-event bursts |
| `pillThickness` | `3` | pill short dimension |
| `pillLength` | `14` | pill long dimension |
| `pillGap` | `4` | gap between pills |
| `cornerInset` | `10` | gap between the indicator and the window edge |
| `backdropPadding` | `5` | padding inside the backdrop |
| `backdropCornerRadius` | `4` | |
| `backdropColor` | dark, ~40% alpha | backdrop fill |
| `focusedColor` | white | focused pill |
| `unfocusedColor` | white, ~35% alpha | other pills |

## How it works

Subscribes to Hammerspoon's window filter for focus/move/create/destroy events and polls `aerospace list-windows --workspace focused` asynchronously (via `hs.task`) on change. Groups consecutive windows whose parent layout is `h_accordion` or `v_accordion` into stacks, sorts them by frame position, then draws pills just outside the focused window's edge (above for horizontal, left for vertical).

## Limitations

- **Requires `accordion-padding >= 1`.** AeroSpace's CLI doesn't expose tree position for a window, so visual order is recovered from each window's accessibility frame coordinates. With `accordion-padding = 0`, sibling windows share identical coordinates and the order can't be recovered. A value of `1` gives an effectively-invisible peek that's still enough to sort by.
- Multiple sibling accordion containers in the same workspace visually merge into one indicator strip; AeroSpace doesn't expose container identifiers to disambiguate them.
- No per-window app icons.

## License

MIT
