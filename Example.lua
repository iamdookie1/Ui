--// Example usage of the Nury UI Library rewrite
local Library = loadstring(game:HttpGet('https://raw.githubusercontent.com/iamdookie1/ui/main/Library.lua'))()

local Window = Library.new({
    title = 'Nury',
    folder = 'Nury',                       -- config folder name
    toggle_key = Enum.KeyCode.Insert,      -- show/hide key
    -- accent = Color3.fromRGB(152, 181, 255),
    -- icon = 'rbxassetid://107819132007001',
})

--// Watermark (title | fps | ping)
Library:create_watermark({ text = 'Nury' })

--// Notifications
Library.SendNotification({
    title = 'Loaded',
    text = 'Welcome back!',
    duration = 5,
    type = 'success', -- success | error | warning | info
})

--// Tabs
local CombatTab = Window:create_tab('Combat', 'rbxassetid://107819132007001')
local VisualsTab = Window:create_tab('Visuals', 'rbxassetid://107819132007001')
local SettingsTab = Window:create_tab('Settings', 'rbxassetid://107819132007001')

--// A module is a collapsible card with its own enable toggle + middle-click keybind
local Aimbot = CombatTab:create_module({
    title = 'Aimbot',
    description = 'Locks onto the closest target',
    section = 'left',
    flag = 'aimbot_enabled',
    callback = function(state)
        print('Aimbot:', state)
    end,
})

Aimbot:create_slider({
    title = 'Smoothness',
    flag = 'aimbot_smoothness',
    minimum_value = 0,
    maximum_value = 100,
    value = 50,
    round_number = true,
    callback = function(value)
        print('Smoothness:', value)
    end,
})

Aimbot:create_dropdown({
    title = 'Target part',
    flag = 'aimbot_part',
    options = { 'Head', 'HumanoidRootPart', 'Torso' },
    maximum_options = 6,
    callback = function(option)
        print('Target part:', option)
    end,
})

Aimbot:create_checkbox({
    title = 'Team check',
    flag = 'aimbot_teamcheck',
    callback = function(state)
        print('Team check:', state)
    end,
})

local ESP = VisualsTab:create_module({
    title = 'ESP',
    description = 'Draws boxes and names',
    section = 'left',
    flag = 'esp_enabled',
    callback = function(state) print('ESP:', state) end,
})

ESP:create_colorpicker({
    title = 'Box color',
    flag = 'esp_color',
    default = Color3.fromRGB(152, 181, 255),
    callback = function(color)
        print('ESP color:', color)
    end,
})

ESP:create_keybind({
    title = 'Toggle key',
    flag = 'esp_key',
    callback = function(key)
        print('ESP key pressed:', key)
    end,
})

ESP:create_divider({ showtopic = true, title = 'Extras' })

ESP:create_textbox({
    title = 'Custom label',
    placeholder = 'Type here...',
    flag = 'esp_label',
    callback = function(text) print('Label:', text) end,
})

local Settings = SettingsTab:create_module({
    title = 'Config',
    description = 'Save and load settings',
    section = 'left',
    flag = 'settings_module',
    callback = function() end,
})

Settings:create_button({
    title = 'Save config',
    callback = function()
        Library:save_config('default')
        Library.SendNotification({ title = 'Config', text = 'Saved "default"', type = 'success' })
    end,
})

Settings:create_button({
    title = 'Load config',
    callback = function()
        Library:load_config('default')
        Library.SendNotification({ title = 'Config', text = 'Loaded "default" (reload UI to apply)', type = 'info' })
    end,
})

Settings:create_button({
    title = 'Unload UI',
    callback = function()
        Window:unload()
    end,
})

Settings:create_paragraph({
    title = 'Info',
    text = 'Middle-click a module header to bind a key. Press Insert to hide the menu.',
})

--// Finally, animate the window in
Window:load()
