# Nury UI Library (Rewrite)

A Roblox UI library styled after the original Nury/Allusive UI — same dark glass look,
acrylic blur, sidebar tabs with a moving pin indicator, and collapsible module cards —
rebuilt with cleaner code and more components.

## Loading

```lua
local Library = loadstring(game:HttpGet('https://raw.githubusercontent.com/iamdookie1/ui/main/Library.lua'))()

local Window = Library.new({
    title = 'Nury',
    folder = 'Nury',                  -- config save folder
    toggle_key = Enum.KeyCode.Insert, -- show/hide key
    accent = Color3.fromRGB(152, 181, 255), -- optional accent override
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
| Feature row | `Module:create_feature({ title, flag, callback, button_callback, disablecheck })` |

Most managers expose setters: `Slider:set_value(n)`, `Checkbox:set_state(bool)`,
`Dropdown:set_value(...)` / `Dropdown:set_options({...})`, `Colorpicker:set_color(color)`,
`Keybind:set_key('F')`, `Textbox:set_value('text')`.

## Notifications

```lua
Library.SendNotification({
    title = 'Hello',
    text = 'Something happened',
    duration = 5,
    type = 'success', -- success | error | warning | info
})
```

Notifications slide in from the right with a colored accent bar and a progress bar.

## Watermark

```lua
local Watermark = Library:create_watermark({ text = 'Nury' }) -- shows "Nury | 60 fps | 45 ms"
Watermark:set_visible(false)
Watermark:set_text('New title')
```

## Configs

Flags and keybinds auto-save per game (`<folder>/<GameId>.json`). Named configs:

```lua
Library:save_config('legit')
Library:load_config('legit')  -- applies on next UI load
Library:list_configs()        -- { 'legit', ... }
Library.Flags                 -- live flag table
```

## Notes

- Works in executors (uses `cloneref`, `gethui`, file API when available) and degrades
  gracefully in Studio/LocalScripts (no config persistence without a file API).
- The acrylic blur automatically disables below graphics quality level 8, matching the
  original library's behavior.
