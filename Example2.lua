--[[
    Centrl UI (Lib2) — example script
    ---------------------------------
    Shows every element the library exposes. Loads on desktop and mobile:
    on a phone the panel scales to the viewport, the columns stack into one,
    and a draggable floating button opens and closes it.
]]

local Centrl = loadstring(game:HttpGet('https://raw.githubusercontent.com/iamdookie1/Ui/main/Lib2.lua'))()

local Window = Centrl:Window({
    Title = 'centrl',
    SubTitle = 'v2',
    Folder = 'centrl',
    ToggleKey = Enum.KeyCode.RightShift,
    Accent = Color3.fromRGB(227, 255, 42),
})

--// Legit -------------------------------------------------------------------

local Legit = Window:Tab({ Title = 'legit', Icon = 'rbxassetid://6034509993' })

local Aimbot = Legit:Section({ Title = 'aimbot', Side = 'left' })

Aimbot:Toggle({
    Title = 'enabled',
    Flag = 'aim_enabled',
    Default = false,
    Callback = function(state)
        print('aimbot', state)
    end,
})

Aimbot:Slider({
    Title = 'smoothing',
    Flag = 'aim_smoothing',
    Min = 0,
    Max = 100,
    Increment = 1,
    Default = 35,
    Suffix = '%',
})

Aimbot:Slider({
    Title = 'fov',
    Flag = 'aim_fov',
    Min = 10,
    Max = 400,
    Default = 120,
})

Aimbot:Dropdown({
    Title = 'target part',
    Flag = 'aim_part',
    Options = { 'Head', 'UpperTorso', 'HumanoidRootPart' },
    Default = 'Head',
})

Aimbot:Keybind({
    Title = 'aim key',
    Flag = 'aim_key',
    Default = Enum.KeyCode.E,
    Callback = function()
        print('aim key held')
    end,
})

local Checks = Legit:Section({ Title = 'checks', Side = 'right' })

Checks:Dropdown({
    Title = 'ignore',
    Flag = 'aim_ignore',
    Multi = true,
    Options = { 'Team', 'Knocked', 'Invisible', 'Behind Wall' },
    Default = { 'Team' },
})

Checks:Toggle({ Title = 'visible check', Flag = 'aim_visible', Default = true })
Checks:Toggle({ Title = 'sticky target', Flag = 'aim_sticky' })
Checks:Divider({ Title = 'fov circle' })
Checks:Toggle({ Title = 'draw circle', Flag = 'aim_circle', Default = true })
Checks:Colorpicker({
    Title = 'circle color',
    Flag = 'aim_circle_color',
    Default = Color3.fromRGB(227, 255, 42),
})

--// Visuals -----------------------------------------------------------------

local Visuals = Window:Tab({ Title = 'visuals', Icon = 'rbxassetid://6034684949' })

local Esp = Visuals:Section({ Title = 'players', Side = 'left' })

Esp:Toggle({ Title = 'boxes', Flag = 'esp_boxes', Default = true })
Esp:Toggle({ Title = 'names', Flag = 'esp_names' })
Esp:Toggle({ Title = 'health bars', Flag = 'esp_health' })
Esp:Colorpicker({ Title = 'box color', Flag = 'esp_box_color', Default = Color3.fromRGB(255, 255, 255) })
Esp:Slider({ Title = 'max distance', Flag = 'esp_distance', Min = 50, Max = 2000, Increment = 25, Default = 500, Suffix = 'm' })

local World = Visuals:Section({ Title = 'world', Side = 'right' })

World:Slider({ Title = 'fov', Flag = 'world_fov', Min = 70, Max = 120, Default = 70 })
World:Textbox({ Title = 'time of day', Flag = 'world_time', Placeholder = '14:00' })
World:Paragraph({
    Title = 'note',
    Text = 'Cards grow to whatever their contents measure, so long text never overlaps the element under it.',
})
World:Button({
    Title = 'reset lighting',
    Callback = function()
        Centrl:Notify({ Title = 'visuals', Content = 'Lighting restored.', Type = 'success' })
    end,
})

--// Misc --------------------------------------------------------------------

local Misc = Window:Tab({ Title = 'misc', Icon = 'rbxassetid://6035047377' })

local Movement = Misc:Section({ Title = 'movement', Side = 'left' })

Movement:Toggle({ Title = 'speed', Flag = 'misc_speed' })
Movement:Slider({ Title = 'walk speed', Flag = 'misc_walkspeed', Min = 16, Max = 200, Default = 16 })
Movement:Keybind({ Title = 'fly key', Flag = 'misc_fly_key', Default = Enum.KeyCode.F })

local Notifications = Misc:Section({ Title = 'notifications', Side = 'right' })

for _, kind in ipairs({ 'success', 'error', 'warning', 'info' }) do
    Notifications:Button({
        Title = kind,
        Callback = function()
            Centrl:Notify({
                Title = kind,
                Content = 'This is a ' .. kind .. ' notification.',
                Type = kind,
                Duration = 4,
            })
        end,
    })
end

local Watermark = Centrl:Watermark({ Text = 'centrl' })

Notifications:Toggle({
    Title = 'watermark',
    Flag = 'misc_watermark',
    Default = true,
    IgnoreSaved = true,
    Callback = function(state)
        Watermark:SetVisible(state)
    end,
})

Window:Load()

Centrl:Notify({
    Title = 'centrl',
    Content = 'Loaded. Press RightShift (or the floating button on mobile).',
    Type = 'info',
    Duration = 6,
})
