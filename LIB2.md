# Centrl UI (`Lib2.lua`)

A code-built recreation of the Centrl panel, with mobile support. Independent of
`Library.lua` — the two libraries share nothing and can be loaded side by side.

Dark theme with a deliberately layered palette — background, rail, topbar,
section, element and element-hover are all visibly distinct steps rather than
one flat dark grey — plus a faint top-down gradient sheen on the topbar and the
window's own base fill, so surfaces read as lit rather than painted flat.

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
    IconApi    = 'https://your-deployment.vercel.app',  -- Lucide icon API
})

local Tab = Window:Tab({ Title = 'legit', Icon = 'crosshair' })
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

## Icons

Anywhere an `Icon` is accepted you can pass a [Lucide](https://lucide.dev) name
(`'house'`, `'ArrowRight'`, `'arrow-right'`), a bare asset id (`'6034509993'`) or a
full `rbxassetid://` string. Asset ids are set directly; Lucide names hit the icon
API in [`iamdookie1/web3`](https://github.com/iamdookie1/web3) —
`GET /icon?name=house&size=64&format=alpha8` — and the response is turned into a
real icon like this:

1. `payload.data` (base64) is decoded into raw bytes — one coverage byte per pixel,
   row-major, top-left origin, exactly as the API describes it.
2. `payload.width` / `payload.height` — **read from the response, not assumed** —
   size the `EditableImage`, so a mismatched or clamped server-side size (the API
   clamps to 1–1024) still renders correctly instead of reading out of bounds.
3. Each byte becomes one pixel's alpha channel in an RGBA buffer, RGB left white,
   and the buffer is written to the image in one `WritePixelsBuffer` call.
4. The `ImageLabel`/`ImageButton` gets `ImageContent = Content.fromObject(image)`.

Every icon in the panel is tinted via `ImageColor3` rather than baked into the
fetch, so the same white source image serves every accent colour and every theme
change — no re-fetch, just a property flip.

### What `size` changes

`GET /icon?name=house&size=64` renders the icon at exactly 64×64 source pixels —
`size` is the rendered resolution of what gets fetched, not the size it displays
at on screen; those are set independently (the `ImageLabel`'s own `Size`).
Requesting **larger** than the display size costs more bytes (`byteLength` grows
with the square of `size`) for no visible gain — downscaling a big source to a
small frame looks identical to requesting the small size directly, since Roblox
filters on the way down. Requesting **smaller** than the display size is the one
that actually costs quality: the source gets stretched up to fill the frame and
visibly blurs / pixelates, exactly as the `iamdookie1/web3` README warns.

The panel exploits the first half of that trade-off for crispness headroom: every
built-in icon (tabs, the topbar logo, minimise/close, the mobile button) requests
**roughly twice its on-screen size**, not a flat default. The window's own
`UIScale` can run up to 2×, so a 16px tab icon requests at 32px — big enough to
stay sharp at maximum zoom, without fetching a wastefully large 64px source for
something that never displays past 32px. `Padding` scales down to match (the
API's 4–6px suggestion is sized for 64px icons and would eat a visible chunk out
of a 16px one), so small glyphs don't shrink inside their own frame.

```lua
Centrl:SetIconSource('https://your-deployment.vercel.app')  -- or Window{ IconApi = ... }
Centrl.Icons.Size = 64        -- default render resolution for calls that don't override it
Centrl.Icons.StrokeWidth = 2
Centrl.Icons.Padding = 4      -- keeps round caps off the frame edge
Centrl.Icons.Enabled = false  -- ignore Lucide names entirely
Centrl:ApplyIcon(myImageLabel, 'sword')                        -- never yields
Centrl:ApplyIcon(myImageLabel, 'sword', { Size = 48 })         -- override per call
Centrl:GetIcon('sword')                                        -- yields, returns the EditableImage
```

Results are cached per name + size + stroke + padding, so calling the same icon at
the same options twice — including the automatic tab/control sizing above — costs
one fetch, not two.

### Live changes

`Library.Icons` is a live proxy, not a plain table: writing any key on it —
`Size`, `StrokeWidth`, `Padding`, `Enabled`, `BaseUrl` (directly or via
`SetIconSource`) — restyles every icon already on screen on the spot, deferred one
frame so setting several in a row costs one refresh pass, not one per assignment.
Nothing needs the script rerun for a setting change to show up:

```lua
Centrl.Icons.Size = 96          -- every icon that relies on the default re-fetches at 96px
Centrl.Icons.Enabled = false    -- every Lucide-backed icon on screen blanks immediately
Centrl.Icons.Enabled = true     -- ...and comes back, re-fetching whatever it needs
Centrl:SetIconSource('https://my-fork.vercel.app')  -- everything switches deployment live
```

Every target `ApplyIcon` has ever touched is remembered (weakly — a destroyed
target just falls out on its own) specifically so this works, including the
panel's own tabs, topbar logo, minimise/close and mobile button — they all repaint
along with anything your own script applied an icon to.

Fetching happens on the client — an executor has HTTP there, so there's no
`RemoteFunction` hop like the `roblox/LucideIcons.lua` module in that repo needs.
It needs `AssetService:CreateEditableImage`; where that's unavailable, or when the
API can't be reached, the icon is skipped with one warning and everything else
still works. `Centrl:ClearIconCache()` (also called automatically by
`SetIconSource` and `Unload`) destroys every cached `EditableImage` rather than
just dropping the table, so switching deployments or tearing down the UI doesn't
leak instances.

`Icons.BaseUrl` defaults to `https://web3-six-beta.vercel.app`, the deployment this
library ships against. Point it elsewhere with `Icons.BaseUrl`/`IconApi` if you run
your own.

The topbar's own minimise (`chevron-up`/`chevron-down`, flips with state) and close
(`x`) controls are Lucide icons too, not the placeholder text glyphs from the first
cut of this library.

## Configs

Flags auto-save per game to `<Folder>/<GameId>.json` whenever a value changes, and
`Window:Load()` reads them back through each element's own setter. Named configs go
to `<Folder>/configs/<name>.json` and are managed from the settings tab. Color and
keycode flags are boxed so they survive the JSON round trip.

## Position

The window is anchored top-left rather than centered, so collapsing to the topbar
and expanding again leave the header exactly where it was — a centered anchor moves
the top edge by half of every height change, which is what made the panel creep up
the screen each time it reopened. Minimising and closing are also tracked as two
separate, independent states (`Open` vs `Visible`): hiding the panel and reshowing
it restores whichever of the two it was actually left in, instead of always
snapping back open.

Clamping to the viewport isn't event-driven — it's wired to the window's own
`AbsoluteSize` and `Position`, so it fires on every single change to either one:
every frame of a drag, every frame of the open/collapse tween (not just once it
lands), a scale change, a viewport resize. Nothing can put the panel off-screen
even momentarily, because there's no path that changes its size or position without
also running the clamp immediately afterward. The floating mobile button is wired
the same way. Neither can end up off screen, instantly or otherwise.

### Show / hide

Showing and hiding the whole panel (the toggle key, the mobile button, `x`,
`Window:SetVisible`) is a fade + scale "pop" on an inner layer, kept entirely
separate from the outer frame that `SetOpen` (minimise) resizes and that
`ClampToScreen` measures. Earlier builds ran both through the same size tween, so
opening the panel meant visibly shrinking it down into its own topbar and then
growing it back out — closing looked like the window was being crushed flat. Now
the window's footprint never changes on show/hide at all: it just fades and scales
in place, in whatever expanded or minimised state it already had, so minimising
and then closing don't fight over the same animation.

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
  toggles, dragging it moves it, and it shrinks slightly on press for tactile
  feedback. Its icon defaults to the Lucide `menu` icon — override with
  `Window{ MobileButtonIcon = 'name' }`. Keybind elements say so instead of hanging
  when there's no keyboard to listen for.

## Notes

- Works in executors (`gethui`, `cloneref`, file API) and degrades in Studio, where
  configs simply don't persist.
- `Centrl:Notify({ Title, Content, Type = 'success' | 'error' | 'warning' | 'info', Duration })`.
