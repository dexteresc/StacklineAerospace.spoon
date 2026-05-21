# StacklineAerospace.spoon

Stack-position indicators for [AeroSpace](https://github.com/nikitabobko/AeroSpace) accordion containers, inspired by [stackline](https://github.com/AdamWagner/stackline) (which is yabai-only).

Draws small pills near the top-left of the focused window showing how many windows are in its accordion stack and which one is focused.

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
| `edgeMargin` | `4` | minimum space required between the indicator and the window edge before it floats outside |
| `backdropPadding` | `5` | padding inside the backdrop |
| `backdropCornerRadius` | `4` | |
| `backdropColor` | dark, ~40% alpha | backdrop fill |
| `focusedColor` | white | focused pill |
| `unfocusedColor` | white, ~35% alpha | other pills |

## How it works

The interesting part is that AeroSpace's CLI does not expose a window's position within its parent container. `aerospace list-windows` returns rows sorted alphabetically by `(app name, window title)`, and no `%{...}` format variable exists for tree, DFS, or sibling index. That means an external tool has no direct way to ask AeroSpace "where in the stack is this window?"

This Spoon recovers visual order indirectly. On each window event it:

1. Runs `aerospace list-windows --workspace focused` (async, via `hs.task`) to enumerate windows and their parent-container layouts.
2. Runs `aerospace list-windows --focused` (a second async call) to ask AeroSpace which window has focus — `hs.window.focusedWindow()` doesn't always agree with AeroSpace for same-app windows.
3. Groups consecutive rows whose parent layout is `h_accordion` or `v_accordion` into stacks.
4. For each stack, looks up every member's screen coordinates via `hs.window.get(id):frame()` and sorts by x (h_accordion) or y (v_accordion). The Hammerspoon window IDs match AeroSpace's `window-id`, which is the macOS CGWindowID.
5. Draws a small rounded backdrop with one pill per stack member, anchored just outside the focused window's edge if there is room (above for h_accordion, left for v_accordion) or otherwise inside its top-left corner. Position recomputes on each render so the indicator follows window resizes and workspace switches.

Window events are coalesced through a 60ms debounce (`debounceMs`), and a 2-second timer (`pollInterval`) catches anything the window filter missed.

## Limitations and tradeoffs

- **Requires `accordion-padding >= 1` in `~/.aerospace.toml`.** Step 4 above is the key: visual order is inferred from each window's pixel coordinates. With `accordion-padding = 0`, every sibling in an accordion shares the exact same frame, so there is no signal to sort by and the highlighted pill no longer corresponds to the focused window. A value of `1` gives an effectively-invisible peek that the Spoon can still sort against; higher values are fine too if you like the peek.
- **Outside-the-window placement needs an outer gap on the relevant axis.** If you set `outer.top` or `outer.left` in AeroSpace's `[gaps]` block to a value ≥ backdrop size + `edgeMargin`, the indicator floats in that empty strip (top for h_accordion, left for v_accordion). Otherwise it falls back to drawing inside the focused window's top-left corner, overlapping a small amount of content. AeroSpace gaps are static and global, so this is an all-or-nothing tradeoff per axis — they cannot be made layout- or workspace-conditional.
- **Multiple sibling accordion containers in the same workspace visually merge into one indicator strip.** AeroSpace exposes no container ID, so the Spoon can't distinguish separate accordion groups that happen to be adjacent in the listing.
- **No per-window app icons.** Stackline-for-yabai shows app icons in its pills; that would require a separate AeroSpace-id ↔ AX-window mapping and is not implemented here.
- **Two `aerospace` shell-outs per event (~30-50ms each).** A previous parallel-task attempt sometimes left one of the callbacks unfired, stalling the in-flight guard and freezing updates; the sequential version is reliable. If event latency becomes noticeable, the cheaper wins are higher `debounceMs` and a less aggressive event filter.
- **Window filter intentionally drops `windowMoved`.** It fired on every drag/resize/re-layout pixel and the indicator already updates from focused/created/destroyed events plus the polling fallback. If you have a use case where moves matter, re-add it in `start()`.
- **Same-app focus tracking depends on AeroSpace's own focused-window query.** `hs.window.focusedWindow()` can lag or pick the wrong window when an app has multiple windows in one stack; that is why step 2 above is a separate `aerospace` call rather than a Hammerspoon lookup.

## License

MIT
