# Centrl UI (`Lib2.lua`)

A code-built recreation of the Centrl panel, with mobile support. Independent of
`Library.lua` — the two libraries share nothing and can be loaded side by side.

```lua
local Centrl = loadstring(game:HttpGet('https://raw.githubusercontent.com/iamdookie1/Ui/main/Lib2.lua'))()

local Window = Centrl:Window({
    Title      = 'centrl',
    SubTitle   = 'v2',
    Folder     = 'centrl',                       -- config folder
    ToggleKey  = Enum.KeyCode.RightShift,
    Accent     = Color3.fromRGB(227, 255, 42),
    Scale      = 1,                              -- multiplies the auto-fit scale
    SettingsTab = true,                          -- built-in settings tab
    MobileButton = true,                         -- floating open/close button on touch
})

local Tab = Window:Tab({ Title = 'legit', Icon = 'rbxassetid://6034509993' })
local Sec = Tab:Section({ Title = 'aimbot', Side = 'left' })  -- 'left' | 'right'

Sec:Toggle({ Title = 'enabled', Flag = 'aim', Callback = function(state) end })

Window:Load()
```

See [`Example2.lua`](Example2.lua) for a script that uses every element.

## Window

| Method | Description |
|---|---|
| `Window:Tab({ Title, Icon })` | Adds a rail tab, returns a Tab |
| `Window:Load()` | Loads the saved config and opens the window |
| `Window:SetVisible(bool)` | Show / hide the whole panel |
| `Window:SetOpen(bool)` | Expand / collapse to the topbar |
| `Window:SetToggleKey(keycode)` | Change the show/hide key |
| `Window:SetTitle(text)` | Rename the header |
| `Window:Destroy()` | Remove the UI and every connection |

Library-level: `Centrl:SetAccent(color)`, `Centrl:SetScale(n)`, `Centrl:Notify{}`,
`Centrl:Watermark{}`, `Centrl:SaveConfig(name)`, `Centrl:LoadConfig(name)`,
`Centrl:ListConfigs()`, `Centrl:DeleteConfig(name)`, `Centrl.Flags`.

## Elements

All live on a Section and all accept `Title`, `Flag` and `Callback`.

| Element | Extra options |
|---|---|
| `Section:Toggle{}` | `Default` |
| `Section:Slider{}` | `Min`, `Max`, `Increment`, `Default`, `Suffix` |
| `Section:Dropdown{}` | `Options`, `Default`, `Multi`; `:SetOptions{}` |
| `Section:Textbox{}` | `Placeholder`, `Default`, `ClearOnFocus` |
| `Section:Keybind{}` | `Default`, `ChangedCallback` |
| `Section:Colorpicker{}` | `Default` — SV square, hue bar, HEX + RGB entry, rainbow, copy |
| `Section:Button{}` | — |
| `Section:Label{}` / `Section:Paragraph{}` / `Section:Divider{}` | `Text` |

Every element returns a manager with `:Set(value)` and `:Get()`. Pass
`IgnoreSaved = true` to keep an element out of the config file.

Option keys are read case-insensitively across common spellings (`Title`/`title`,
`Callback`/`callback`, `Min`/`minimum_value`, …), and the old lowercase call names
(`create_toggle`, `create_slider`, …) are aliased to the new ones.

## Configs

Flags auto-save per game to `<Folder>/<GameId>.json` whenever a value changes, and
`Window:Load()` reads them back through each element's own setter. Named configs go
to `<Folder>/configs/<name>.json` and are managed from the settings tab. Color and
keycode flags are boxed so they survive the JSON round trip.

## Mobile

- The panel scales itself to the viewport on every device and never scales up.
  Touch devices target a smaller share of the screen than desktop, because a phone
  viewport is wide enough in GUI pixels to "fit" the panel at an unusable size.
- Columns stack into a single full-width column on touch, and rows, checkboxes,
  slider bars and hit targets all grow.
- Sliders and the color picker read the input's own position, not `Mouse.X`, so a
  finger drags them exactly like a mouse. Reading the mouse would peg them to their
  minimum on every tap.
- One control owns a drag at a time, so a finger sliding down the panel can't pick
  up every slider it crosses. Ownership is force-released on input end, so a finger
  that leaves a control's bounds before lifting doesn't wedge the panel.
- The window drags from the topbar and the tab rail only; scrolling regions sink
  touch input so a drag over content scrolls instead of moving the window.
- Dropdown and colorpicker bodies expand inline rather than floating, so nothing
  gets clipped by the scrolling column and the page still scrolls while they're open.
- A draggable floating button opens the panel where there's no keyboard; tapping it
  toggles, dragging it moves it. Keybind elements say so instead of hanging when
  there's no keyboard to listen for.

## Notes

- Works in executors (`gethui`, `cloneref`, file API) and degrades in Studio, where
  configs simply don't persist.
- `Centrl:Notify({ Title, Content, Type = 'success' | 'error' | 'warning' | 'info', Duration })`.
