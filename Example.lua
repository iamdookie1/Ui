--[[
    Nury UI Library — full showcase
    --------------------------------
    Every element the library provides, with every option it accepts.
    Callbacks just print, so you can drop this in as-is and click around.

    Insert toggles the menu. Middle-click a module header to bind a key to it.
]]

local Library = loadstring(game:HttpGet('https://raw.githubusercontent.com/iamdookie1/Ui/main/Library.lua'))()

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')

--==========================================================================--
-- Window
--==========================================================================--

local Window = Library.new({
    title = 'Nury',
    folder = 'Nury',                         -- config folder on disk
    config_name = game.GameId,               -- per-game flag file (default)
    toggle_key = Enum.KeyCode.Insert,        -- show/hide key
    accent = Color3.fromRGB(152, 181, 255),  -- optional accent override
    icon = 'rbxassetid://107819132007001',
})

local Watermark = Window:create_watermark({
    text = 'Nury',
    show_stats = true, -- appends fps + ping after a divider
})

--==========================================================================--
-- Combat
--==========================================================================--

local CombatTab = Window:create_tab('Combat', 'rbxassetid://107819132007001')

local Aimbot = CombatTab:create_module({
    title = 'Aimbot',
    description = 'Locks onto the closest target',
    section = 'left',
    flag = 'aimbot',
    callback = function(state) print('[aimbot]', state) end,
})

Aimbot:create_slider({
    title = 'Field of view',
    flag = 'aimbot_fov',
    minimum_value = 0,
    maximum_value = 500,
    value = 120,
    round_number = true, -- whole numbers; omit for one decimal place
    callback = function(value) print('[aimbot] fov', value) end,
})

Aimbot:create_slider({
    title = 'Smoothing',
    flag = 'aimbot_smoothing',
    minimum_value = 0,
    maximum_value = 100,
    value = 35,
    round_number = true,
    callback = function(value) print('[aimbot] smoothing', value) end,
})

Aimbot:create_slider({
    title = 'Prediction',
    flag = 'aimbot_prediction',
    minimum_value = 0,
    maximum_value = 5,
    value = 1.5, -- without round_number, sliders step in tenths
    callback = function(value) print('[aimbot] prediction', value) end,
})

Aimbot:create_dropdown({
    title = 'Target part',
    flag = 'aimbot_part',
    options = { 'Head', 'HumanoidRootPart', 'UpperTorso', 'LowerTorso' },
    maximum_options = 4, -- rows visible before the list scrolls
    callback = function(option) print('[aimbot] part', option) end,
})

Aimbot:create_checkbox({
    title = 'Team check',
    flag = 'aimbot_teamcheck',
    default = true, -- used only when nothing is saved yet
    callback = function(state) print('[aimbot] teamcheck', state) end,
})

Aimbot:create_checkbox({
    title = 'Visibility check',
    flag = 'aimbot_vischeck',
    callback = function(state) print('[aimbot] vischeck', state) end,
})

Aimbot:create_keybind({
    title = 'Hold to aim',
    flag = 'aimbot_key',
    default = 'E',
    callback = function(key) print('[aimbot] key held', key) end,
    changed_callback = function(key) print('[aimbot] key rebound to', key) end,
})

local Triggerbot = CombatTab:create_module({
    title = 'Triggerbot',
    description = 'Fires when a target crosses your cursor',
    section = 'right',
    flag = 'triggerbot',
    callback = function(state) print('[triggerbot]', state) end,
})

Triggerbot:create_slider({
    title = 'Delay (ms)',
    flag = 'trigger_delay',
    minimum_value = 0,
    maximum_value = 500,
    value = 80,
    round_number = true,
    callback = function(value) print('[triggerbot] delay', value) end,
})

Triggerbot:create_dropdown({
    title = 'Fire modes',
    flag = 'trigger_modes',
    multi_dropdown = true, -- select any number; click again to deselect
    options = { 'Hipfire', 'Aiming', 'Crouched' },
    callback = function(option) print('[triggerbot] toggled', option) end,
})

--==========================================================================--
-- Visuals
--==========================================================================--

local VisualsTab = Window:create_tab('Visuals', 'rbxassetid://107819132007001')

local ESP = VisualsTab:create_module({
    title = 'Player ESP',
    description = 'Boxes, names and health bars',
    section = 'left',
    flag = 'esp',
    callback = function(state) print('[esp]', state) end,
})

ESP:create_colorpicker({
    title = 'Box color',
    flag = 'esp_box_color',
    default = Color3.fromRGB(152, 181, 255),
    callback = function(color) print('[esp] box color', color) end,
})

ESP:create_colorpicker({
    title = 'Name color',
    flag = 'esp_name_color',
    default = Color3.fromRGB(255, 255, 255),
    callback = function(color) print('[esp] name color', color) end,
})

ESP:create_divider({ showtopic = true, title = 'Elements' })

ESP:create_checkbox({
    title = 'Boxes',
    flag = 'esp_boxes',
    default = true,
    callback = function(state) print('[esp] boxes', state) end,
})
ESP:create_checkbox({
    title = 'Names',
    flag = 'esp_names',
    callback = function(state) print('[esp] names', state) end,
})
ESP:create_checkbox({
    title = 'Health bars',
    flag = 'esp_health',
    callback = function(state) print('[esp] health bars', state) end,
})

ESP:create_slider({
    title = 'Max distance',
    flag = 'esp_distance',
    minimum_value = 50,
    maximum_value = 2000,
    value = 750,
    round_number = true,
    callback = function(value) print('[esp] distance', value) end,
})

local World = VisualsTab:create_module({
    title = 'World',
    description = 'Lighting and atmosphere',
    section = 'right',
    flag = 'world',
    callback = function(state) print('[world]', state) end,
})

World:create_slider({
    title = 'Brightness',
    flag = 'world_brightness',
    minimum_value = 0,
    maximum_value = 5,
    value = 2,
    callback = function(value) print('[world] brightness', value) end,
})

World:create_dropdown({
    title = 'Time of day',
    flag = 'world_time',
    options = { 'Default', 'Midday', 'Sunset', 'Midnight' },
    callback = function(option) print('[world] time', option) end,
})

World:create_colorpicker({
    title = 'Ambient',
    flag = 'world_ambient',
    default = Color3.fromRGB(70, 70, 90),
    callback = function(color) print('[world] ambient', color) end,
})

--==========================================================================--
-- Player
--==========================================================================--

local PlayerTab = Window:create_tab('Player', 'rbxassetid://107819132007001')

local Movement = PlayerTab:create_module({
    title = 'Movement',
    description = 'Speed, jump and flight',
    section = 'left',
    flag = 'movement',
    callback = function(state) print('[movement]', state) end,
})

Movement:create_slider({
    title = 'Walk speed',
    flag = 'walk_speed',
    minimum_value = 16,
    maximum_value = 200,
    value = 16,
    round_number = true,
    callback = function(value) print('[movement] speed', value) end,
})

Movement:create_slider({
    title = 'Jump power',
    flag = 'jump_power',
    minimum_value = 50,
    maximum_value = 300,
    value = 50,
    round_number = true,
    callback = function(value) print('[movement] jump', value) end,
})

-- create_feature is a compact row: a label, an optional checkbox, and a
-- keybind box. Click the keybind box, then press a key to bind it.
local Misc = PlayerTab:create_module({
    title = 'Utility',
    description = 'One-shot actions and bindable toggles',
    section = 'right',
    flag = 'utility',
    callback = function(state) print('[utility]', state) end,
})

Misc:create_feature({
    title = 'Infinite jump',
    flag = 'inf_jump',
    default = 'J', -- starting keybind
    callback = function(checked) print('[utility] infinite jump', checked) end,
})

Misc:create_feature({
    title = 'Rejoin server',
    flag = 'rejoin',
    disablecheck = true, -- no checkbox: acts as a bindable button
    button_callback = function() print('[utility] rejoining') end,
})

Misc:create_button({
    title = 'Reset character',
    callback = function()
        print('[utility] reset')
        Library.SendNotification({ title = 'Utility', text = 'Character reset.', type = 'info' })
    end,
})

--==========================================================================--
-- Components — every remaining element type
--==========================================================================--

local ComponentsTab = Window:create_tab('Components', 'rbxassetid://107819132007001')

local Inputs = ComponentsTab:create_module({
    title = 'Inputs',
    description = 'Textbox, keybind, button',
    section = 'left',
    flag = 'demo_inputs',
    callback = function() end,
})

local NameBox = Inputs:create_textbox({
    title = 'Display name',
    placeholder = 'Type and press enter...',
    flag = 'demo_name',
    callback = function(text) print('[textbox]', text) end,
})

Inputs:create_keybind({
    title = 'Panic key',
    flag = 'demo_panic',
    default = 'P',
    callback = function() print('[keybind] panic') end,
})

Inputs:create_button({
    title = 'Fill textbox',
    callback = function() NameBox:set_value('Set from a button') end,
})

Inputs:create_divider({ disableline = true }) -- pure spacing, no rule

local Readouts = ComponentsTab:create_module({
    title = 'Readouts',
    description = 'Paragraph, text, dividers',
    section = 'right',
    flag = 'demo_readouts',
    callback = function() end,
})

local Notes = Readouts:create_paragraph({
    title = 'Paragraph',
    text = 'A title and a body that wrap to as many lines as they need. The card grows to fit.',
})

Readouts:create_divider({ showtopic = true, title = 'Live' })

local LiveText = Readouts:create_text({ text = 'Waiting for data...' })

Readouts:create_divider({ showtopic = true, title = 'Rich text' })

Readouts:create_paragraph({
    title = 'Formatted',
    rich = true,
    richtext = 'Rich text supports <b>bold</b>, <i>italics</i> and <font color="rgb(152,181,255)">color</font>.',
})

Readouts:create_button({
    title = 'Rewrite the paragraph',
    callback = function()
        Notes:Set({ title = 'Updated', text = 'Rewritten at ' .. os.date('%H:%M:%S') .. '.' })
    end,
})

-- A dropdown whose options are rebuilt at runtime.
local Dynamic = ComponentsTab:create_module({
    title = 'Dynamic options',
    description = 'Rebuilt whenever the server roster changes',
    section = 'left',
    flag = 'demo_dynamic',
    callback = function() end,
})

local function player_names()
    local names = {}
    for _, player in ipairs(Players:GetPlayers()) do
        table.insert(names, player.Name)
    end
    return names
end

local PlayerDropdown = Dynamic:create_dropdown({
    title = 'Target player',
    flag = 'demo_target',
    options = player_names(),
    maximum_options = 6,
    callback = function(option) print('[dynamic] target', option) end,
})

Players.PlayerAdded:Connect(function() PlayerDropdown:set_options(player_names()) end)
Players.PlayerRemoving:Connect(function()
    task.defer(function() PlayerDropdown:set_options(player_names()) end)
end)

--==========================================================================--
-- Settings
--==========================================================================--

local SettingsTab = Window:create_tab('Settings', 'rbxassetid://107819132007001')

local Interface = SettingsTab:create_module({
    title = 'Interface',
    description = 'Accent, watermark and transparency',
    section = 'left',
    flag = 'settings_interface',
    callback = function() end,
})

-- Theme controls pass ignoresaved so the look never persists between
-- sessions - the panel always starts on its default accent.
Interface:create_colorpicker({
    title = 'Accent color',
    flag = 'ui_accent',
    ignoresaved = true,
    default = Color3.fromRGB(152, 181, 255),
    callback = function(color)
        Window:set_accent(color) -- recolors the whole UI live
    end,
})

Interface:create_slider({
    title = 'Background opacity',
    flag = 'ui_opacity',
    ignoresaved = true,
    minimum_value = 0,
    maximum_value = 1,
    value = 0.05,
    callback = function(value) Window:Update1Run(value) end,
})

Interface:create_checkbox({
    title = 'Show watermark',
    flag = 'ui_watermark',
    ignoresaved = true,
    default = true,
    callback = function(state) Watermark:set_visible(state) end,
})

Interface:create_checkbox({
    title = 'Show fps / ping',
    flag = 'ui_watermark_stats',
    ignoresaved = true,
    default = true,
    callback = function(state) Watermark:set_stats_visible(state) end,
})

Interface:create_dropdown({
    title = 'Menu key',
    flag = 'ui_toggle_key',
    ignoresaved = true,
    options = { 'Insert', 'RightShift', 'RightControl', 'F4' },
    callback = function(option)
        Window:set_toggle_key(Enum.KeyCode[option])
    end,
})

local Configs = SettingsTab:create_module({
    title = 'Configs',
    description = 'Save and restore named presets',
    section = 'right',
    flag = 'settings_configs',
    callback = function() end,
})

local config_name = 'default'
local selected_config = 'default'

Configs:create_textbox({
    title = 'Config name',
    placeholder = 'default',
    flag = 'config_name',
    callback = function(text)
        config_name = text ~= '' and text or 'default'
    end,
})

local ConfigList = Configs:create_dropdown({
    title = 'Saved configs',
    flag = 'config_selected',
    options = Library:list_configs(),
    maximum_options = 5,
    callback = function(option)
        selected_config = option
        print('[config] selected', option)
    end,
})

Configs:create_button({
    title = 'Save',
    callback = function()
        local name = config_name
        if Library:save_config(name) then
            ConfigList:set_options(Library:list_configs())
            Library.SendNotification({ title = 'Config', text = 'Saved "' .. name .. '".', type = 'success' })
        else
            Library.SendNotification({ title = 'Config', text = 'No file access in this environment.', type = 'error' })
        end
    end,
})

Configs:create_button({
    title = 'Load',
    callback = function()
        if Library:load_config(selected_config) then
            Library.SendNotification({ title = 'Config', text = 'Loaded "' .. selected_config .. '". Reload to apply.', type = 'success' })
        else
            Library.SendNotification({ title = 'Config', text = 'No config named "' .. selected_config .. '".', type = 'warning' })
        end
    end,
})

Configs:create_button({
    title = 'Print all flags',
    callback = function()
        -- Library.Flags is the live table every element writes into
        for flag, value in pairs(Library.Flags) do
            print(flag, '=', value)
        end
    end,
})

Configs:create_divider({ showtopic = true, title = 'Danger zone' })

Configs:create_button({
    title = 'Unload UI',
    callback = function()
        Library.SendNotification({ title = 'Nury', text = 'Unloading.', type = 'warning', duration = 2 })
        task.delay(2, function() Window:unload() end)
    end,
})

--==========================================================================--
-- Show the window, then demo the notification types
--==========================================================================--

Window:load()

Library.SendNotification({
    title = 'Nury loaded',
    text = 'Press Insert to hide the menu.',
    duration = 6,
    type = 'success',
})

task.spawn(function()
    for _, demo in ipairs({
        { type = 'info', title = 'Info', text = 'The default notification style.' },
        { type = 'warning', title = 'Warning', text = 'Something needs attention.' },
        { type = 'error', title = 'Error', text = 'Something went wrong.' },
    }) do
        task.wait(1.2)
        Library.SendNotification({ title = demo.title, text = demo.text, type = demo.type, duration = 5 })
    end
end)

-- Live text element, updated once a second
local fps = 60
do
    local frames, elapsed = 0, 0
    RunService.Heartbeat:Connect(function(delta)
        frames += 1
        elapsed += delta
        if elapsed >= 0.5 then
            fps = math.floor(frames / elapsed + 0.5)
            frames, elapsed = 0, 0
        end
    end)
end

task.spawn(function()
    while task.wait(1) do
        if not Window._ui then
            break -- unloaded
        end
        LiveText:Set({
            rich = true,
            richtext = string.format(
                '<font color="rgb(152,181,255)">%d</font> players  ·  <font color="rgb(152,181,255)">%d</font> fps',
                #Players:GetPlayers(),
                fps
            ),
        })
    end
end)
