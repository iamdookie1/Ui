# Nury UI Library (Rewrite)

A Roblox UI library styled after the original Nury/Allusive UI — same dark glass look,
acrylic blur, sidebar tabs with a moving pin indicator, and collapsible module cards —
rebuilt with cleaner code and more components.

## Loading

```lua
local Library = loadstring(game:HttpGet('https://raw.githubusercontent.com/iamdookie1/Ui/main/Library.lua'))()

local Window = Library.new({
    title = 'Nury',
    folder = 'Nury',                  -- config save folder
    toggle_key = Enum.KeyCode.Insert, -- show/hide key
    accent = Color3.fromRGB(152, 181, 255), -- optional accent override
    scale = 1,                        -- multiplies the auto-fit scale
})

-- ... build tabs/modules ...

Window:load() -- animates the window in and enables the blur
```

See [`Example.lua`](Example.lua) for a full working script.

## Window

| Method | Description |
|---|---|
| `Window:create_tab(title, icon)` | Adds a sidebar tab, returns a Tab |
| `Window:load()` | Opens the window (call after building the UI) |
| `Window:change_visiblity(bool)` | Expand / collapse the window |
| `Window:UIVisiblity()` | Toggle the whole ScreenGui |
| `Window:set_accent(color)` | Recolor the accent everywhere at runtime |
| `Window:set_toggle_key(keycode)` | Change the show/hide key |
| `Window:set_scale(n)` | Multiply the automatic scale (0.25–2) |
| `Window:unload()` | Destroy everything (UI, blur, connections) |
| `Window:Update1Run(value)` | Compat: set background transparency |

## Modules

A module is a collapsible card with its own enable toggle. **Middle-click the module
header** to bind a toggle key; Backspace while binding clears it.

```lua
local Module = Tab:create_module({
    title = 'Aimbot',
    description = 'Locks onto the closest target',
    section = 'left',        -- 'left' or 'right' column
    flag = 'aimbot_enabled', -- saved to the config file
    callback = function(state) end,
})
```

## Elements

| Element | Call |
|---|---|
| Slider | `Module:create_slider({ title, flag, minimum_value, maximum_value, value, round_number, callback })` |
| Dropdown | `Module:create_dropdown({ title, flag, options, multi_dropdown, maximum_options, callback })` |
| Checkbox / Toggle | `Module:create_checkbox({ title, flag, default, callback })` |
| Textbox | `Module:create_textbox({ title, placeholder, flag, callback })` |
| Button *(new)* | `Module:create_button({ title, callback })` |
| Keybind *(new)* | `Module:create_keybind({ title, flag, default, callback, changed_callback })` |
| Color picker *(new)* | `Module:create_colorpicker({ title, flag, default, callback })` |
| Paragraph | `Module:create_paragraph({ title, text })` — returns `:Set{}` |
| Text | `Module:create_text({ text })` — returns `:Set{}` |
| Divider | `Module:create_divider({ showtopic, title, disableline })` |
| Feature row | `Module:create_feature({ title, flag, default, callback, button_callback, disablecheck })` |

`create_checkbox` is also available as `create_toggle`. Feature rows require a `flag`
— they store their checked state and keybind under it. Pass `disablecheck = true` to
drop the checkbox and use the row as a bindable button via `button_callback`.

Sliders, checkboxes, dropdowns and color pickers all accept `ignoresaved = true`,
which keeps that element out of the config file — it starts on its `default`/`value`
every session. Use it for anything cosmetic (accent, opacity, watermark toggles) so
the panel's look never persists.

Most managers expose setters: `Slider:set_value(n)`, `Checkbox:set_state(bool)`,
`Dropdown:set_value(...)` / `Dropdown:set_options({...})`, `Colorpicker:set_color(color)`,
`Keybind:set_key('F')`, `Textbox:set_value('text')`.

## Sizing and scrolling

Module cards measure themselves from their actual contents, so you never have to
reserve height for an element. A paragraph with three lines of text and one with
thirty both fit — the card grows to whatever the wrapped text really measures, and
the tab column scrolls once the cards exceed the window.

Paragraph and text elements stack their title and body in a layout, so a long title
pushes the body down instead of overlapping it. The same applies to notifications.

If you're migrating from the original library, `customScale` and `CustomYSize` are no
longer needed — they're accepted and ignored (`CustomYSize` still acts as a minimum
height). Delete them and the elements will size themselves correctly.

## Notifications

```lua
Library.SendNotification({
    title = 'Hello',
    text = 'Something happened',
    duration = 5,
    type = 'success', -- success | error | warning | info
})
```

Notifications slide in from the right and are built like module cards — module
background, accent title, the same 2px accent pill the sidebar uses — with a 1px
timer draining along the bottom. The `type` only changes the tint.

## Watermark

```lua
local Watermark = Library:create_watermark({ text = 'Nury' })
Watermark:set_visible(false)
Watermark:set_text('New title')
Watermark:set_stats_visible(false) -- title only, no fps/ping
```

Styled like the window's own header: accent pill, accent title, a 1px divider, then
dimmed stats. Pass `show_stats = false` to omit the divider and stats entirely.

## Configs

Flags and keybinds auto-save per game (`<folder>/<GameId>.json`). Named configs:

```lua
Library:save_config('legit')
Library:load_config('legit')  -- applies on next UI load
Library:list_configs()        -- { 'legit', ... }
Library.Flags                 -- live flag table
```

## Mobile

- Sliders and the color picker track the input's own position, so dragging works
  under touch. (Reading `Mouse.X` would peg them to their minimum on every tap.)
- The tab column and both content columns sink input, so a touch-drag scrolls the
  column instead of dragging the window. Drag the window from its header or the
  sidebar background.
- The window scales itself to the viewport on every device, never upward. Touch
  devices target a smaller share of the screen than desktop, because a phone
  viewport is wide enough in GUI pixels to "fit" the panel at a size that's
  unusable on a physically small screen. Override with `scale` or `set_scale`.
- Notifications and the watermark scale with the window rather than staying
  desktop-sized.
- A drag is owned by one control at a time, so a finger sliding down the panel
  can't pick up every slider it crosses.
- Rebinding a module key is middle-click, which has no touch equivalent yet.

## Notes

- Works in executors (uses `cloneref`, `gethui`, file API when available) and degrades
  gracefully in Studio/LocalScripts (no config persistence without a file API).
- The acrylic blur automatically disables below graphics quality level 8, matching the
  original library's behavior.
