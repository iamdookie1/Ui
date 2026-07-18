--[[
    Nury UI Library — expanded rewrite
    ----------------------------------
    A Roblox UI library styled after the original Nury/Allusive UI:
    dark glass window, acrylic blur, sidebar tabs with a moving pin,
    collapsible module cards with toggle + middle-click keybinds,
    and left/right scrolling sections.

    Extras over the original:
      - Buttons, dedicated keybind elements, full HSV color picker
      - Typed notifications (success / error / warning / info) with progress bars
      - Watermark (title / fps / ping)
      - Accent recoloring at runtime (set_accent)
      - Named config saves (save_config / load_config / list_configs)
      - Clean unload() that removes every instance and connection

    API is kept compatible with the original where possible:
      Library.new() / SendNotification / create_tab / create_module /
      create_slider / create_dropdown / create_checkbox / create_textbox /
      create_paragraph / create_text / create_divider / create_feature /
      change_visiblity / UIVisiblity / Update1Run
]]

local cloneref = cloneref or function(object)
    return object
end

local UserInputService = cloneref(game:GetService('UserInputService'))
local ContentProvider = cloneref(game:GetService('ContentProvider'))
local TweenService = cloneref(game:GetService('TweenService'))
local HttpService = cloneref(game:GetService('HttpService'))
local TextService = cloneref(game:GetService('TextService'))
local RunService = cloneref(game:GetService('RunService'))
local Lighting = cloneref(game:GetService('Lighting'))
local Players = cloneref(game:GetService('Players'))
local CoreGui = cloneref(game:GetService('CoreGui'))
local Stats = cloneref(game:GetService('Stats'))
local Debris = cloneref(game:GetService('Debris'))

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer and LocalPlayer:GetMouse()

local HAS_FILE_API = typeof(writefile) == 'function'
    and typeof(readfile) == 'function'
    and typeof(isfile) == 'function'
    and typeof(isfolder) == 'function'
    and typeof(makefolder) == 'function'

local function gui_parent()
    if typeof(gethui) == 'function' then
        local ok, hui = pcall(gethui)
        if ok and hui then
            return hui
        end
    end
    local ok = pcall(function()
        local probe = Instance.new('Folder')
        probe.Parent = CoreGui
        probe:Destroy()
    end)
    if ok then
        return CoreGui
    end
    return LocalPlayer:WaitForChild('PlayerGui')
end

--// Theme ------------------------------------------------------------------

local Theme = {
    Background = Color3.fromRGB(12, 13, 15),
    Module = Color3.fromRGB(22, 28, 38),
    Element = Color3.fromRGB(32, 38, 51),
    ElementHover = Color3.fromRGB(42, 50, 66),
    Stroke = Color3.fromRGB(52, 66, 89),
    Accent = Color3.fromRGB(152, 181, 255),
    AccentText = Color3.fromRGB(209, 222, 255),
    Text = Color3.fromRGB(255, 255, 255),
    SubText = Color3.fromRGB(180, 180, 180),
    ToggleOff = Color3.fromRGB(66, 80, 115),
    Success = Color3.fromRGB(87, 197, 134),
    Error = Color3.fromRGB(235, 87, 87),
    Warning = Color3.fromRGB(241, 196, 83),
}

-- Objects whose static properties should follow the accent color.
-- AccentRegistry[object] = { 'BackgroundColor3', 'TextColor3', ... }
local AccentRegistry = setmetatable({}, { __mode = 'k' })

local function register_accent(object, properties)
    AccentRegistry[object] = properties
end

--// Small helpers ----------------------------------------------------------

local function font(weight)
    return Font.new('rbxasset://fonts/families/GothamSSm.json', weight or Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
end

local function create(class, properties, children)
    local object = Instance.new(class)
    local parent = nil
    for property, value in properties do
        if property == 'Parent' then
            parent = value
        else
            object[property] = value
        end
    end
    if children then
        for _, child in children do
            child.Parent = object
        end
    end
    if parent then
        object.Parent = parent
    end
    return object
end

local function tween(object, properties, duration, style, direction)
    local animation = TweenService:Create(
        object,
        TweenInfo.new(duration or 0.5, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
        properties
    )
    animation:Play()
    return animation
end

local function text_width(text, size, weight)
    local params = Instance.new('GetTextBoundsParams')
    params.Text = text
    params.Font = font(weight)
    params.Size = size or 13
    params.Width = 10000
    local ok, bounds = pcall(function()
        return TextService:GetTextBoundsAsync(params)
    end)
    if ok then
        return bounds.X
    end
    return #text * (size or 13) * 0.6
end

local function keycode_name(keycode)
    return string.gsub(tostring(keycode), 'Enum%.KeyCode%.', '')
end

--// Connection manager -----------------------------------------------------

local Connections = {
    _named = {},
    _anonymous = {},
}

function Connections:set(name, connection)
    self:disconnect(name)
    self._named[name] = connection
end

function Connections:add(connection)
    table.insert(self._anonymous, connection)
    return connection
end

function Connections:disconnect(name)
    local connection = self._named[name]
    if connection then
        connection:Disconnect()
        self._named[name] = nil
    end
end

function Connections:disconnect_all()
    for name, connection in self._named do
        connection:Disconnect()
        self._named[name] = nil
    end
    for _, connection in self._anonymous do
        connection:Disconnect()
    end
    table.clear(self._anonymous)
end

--// Utility ----------------------------------------------------------------

local Util = {}

function Util.map(value, in_minimum, in_maximum, out_minimum, out_maximum)
    return (value - in_minimum) * (out_maximum - out_minimum) / (in_maximum - in_minimum) + out_minimum
end

function Util.viewport_point_to_world(location, distance)
    local unit_ray = workspace.CurrentCamera:ScreenPointToRay(location.X, location.Y)
    return unit_ray.Origin + unit_ray.Direction * distance
end

function Util.get_offset()
    local viewport_size_y = workspace.CurrentCamera.ViewportSize.Y
    return Util.map(viewport_size_y, 0, 2560, 8, 56)
end

--// Acrylic blur -----------------------------------------------------------

local AcrylicBlur = {}
AcrylicBlur.__index = AcrylicBlur

function AcrylicBlur.new(object)
    local self = setmetatable({
        _object = object,
        _folder = nil,
        _frame = nil,
        _root = nil,
    }, AcrylicBlur)
    self:setup()
    return self
end

function AcrylicBlur:create_folder()
    local old_folder = workspace.CurrentCamera:FindFirstChild('AcrylicBlur')
    if old_folder then
        Debris:AddItem(old_folder, 0)
    end
    self._folder = create('Folder', {
        Name = 'AcrylicBlur',
        Parent = workspace.CurrentCamera,
    })
end

function AcrylicBlur:create_depth_of_field()
    local depth_of_field = Lighting:FindFirstChild('AcrylicBlur') or Instance.new('DepthOfFieldEffect')
    depth_of_field.FarIntensity = 0
    depth_of_field.FocusDistance = 0.05
    depth_of_field.InFocusRadius = 0.1
    depth_of_field.NearIntensity = 1
    depth_of_field.Name = 'AcrylicBlur'
    depth_of_field.Parent = Lighting
    self._effect = depth_of_field
    for _, object in Lighting:GetChildren() do
        if not object:IsA('DepthOfFieldEffect') or object == depth_of_field then
            continue
        end
        Connections:add(object:GetPropertyChangedSignal('FarIntensity'):Connect(function()
            object.FarIntensity = 0
        end))
        object.FarIntensity = 0
    end
end

function AcrylicBlur:create_frame()
    self._frame = create('Frame', {
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Parent = self._object,
    })
end

function AcrylicBlur:create_root()
    local part = create('Part', {
        Name = 'Root',
        Color = Color3.new(0, 0, 0),
        Material = Enum.Material.Glass,
        Size = Vector3.new(1, 1, 0),
        Anchored = true,
        CanCollide = false,
        CanQuery = false,
        Locked = true,
        CastShadow = false,
        Transparency = 0.98,
        Parent = self._folder,
    })
    create('SpecialMesh', {
        MeshType = Enum.MeshType.Brick,
        Offset = Vector3.new(0, 0, -0.000001),
        Parent = part,
    })
    self._root = part
end

function AcrylicBlur:setup()
    self:create_depth_of_field()
    self:create_folder()
    self:create_root()
    self:create_frame()
    self:render(0.001)
    self:check_quality_level()
end

function AcrylicBlur:render(distance)
    local positions = {
        top_left = Vector2.new(),
        top_right = Vector2.new(),
        bottom_right = Vector2.new(),
    }
    local function update_positions(size, position)
        positions.top_left = position
        positions.top_right = position + Vector2.new(size.X, 0)
        positions.bottom_right = position + size
    end
    local function update()
        if not self._root then
            return
        end
        local top_left3d = Util.viewport_point_to_world(positions.top_left, distance)
        local top_right3d = Util.viewport_point_to_world(positions.top_right, distance)
        local bottom_right3d = Util.viewport_point_to_world(positions.bottom_right, distance)
        local width = (top_right3d - top_left3d).Magnitude
        local height = (top_right3d - bottom_right3d).Magnitude
        local camera_cframe = workspace.CurrentCamera.CFrame
        self._root.CFrame = CFrame.fromMatrix(
            (top_left3d + bottom_right3d) / 2,
            camera_cframe.XVector,
            camera_cframe.YVector,
            camera_cframe.ZVector
        )
        self._root.Mesh.Scale = Vector3.new(width, height, 0)
    end
    local function on_change()
        local offset = Util.get_offset()
        local size = self._frame.AbsoluteSize - Vector2.new(offset, offset)
        local position = self._frame.AbsolutePosition + Vector2.new(offset / 2, offset / 2)
        update_positions(size, position)
        task.spawn(update)
    end
    Connections:set('blur_cframe', workspace.CurrentCamera:GetPropertyChangedSignal('CFrame'):Connect(update))
    Connections:set('blur_viewport', workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(update))
    Connections:set('blur_fov', workspace.CurrentCamera:GetPropertyChangedSignal('FieldOfView'):Connect(update))
    Connections:set('blur_position', self._frame:GetPropertyChangedSignal('AbsolutePosition'):Connect(on_change))
    Connections:set('blur_size', self._frame:GetPropertyChangedSignal('AbsoluteSize'):Connect(on_change))
    on_change()
end

function AcrylicBlur:check_quality_level()
    local function read_quality()
        local ok, level = pcall(function()
            return UserSettings().GameSettings.SavedQualityLevel.Value
        end)
        return ok and level or 10
    end
    self:change_visiblity(read_quality() >= 8)
    local ok, signal = pcall(function()
        return UserSettings().GameSettings:GetPropertyChangedSignal('SavedQualityLevel')
    end)
    if ok then
        Connections:set('blur_quality', signal:Connect(function()
            self:change_visiblity(read_quality() >= 8)
        end))
    end
end

function AcrylicBlur:change_visiblity(state)
    if self._root then
        self._root.Transparency = state and 0.98 or 1
    end
end

function AcrylicBlur:destroy()
    if self._folder then
        self._folder:Destroy()
        self._folder = nil
    end
    if self._effect then
        self._effect:Destroy()
        self._effect = nil
    end
    self._root = nil
end

--// Config -----------------------------------------------------------------

local Config = {
    folder = 'Nury',
}

function Config:path(file_name)
    return self.folder .. '/' .. file_name .. '.json'
end

function Config:ensure_folder(path)
    if not HAS_FILE_API then
        return
    end
    if not isfolder(path) then
        makefolder(path)
    end
end

function Config:save(file_name, config)
    if not HAS_FILE_API then
        return
    end
    local ok, result = pcall(function()
        self:ensure_folder(self.folder)
        writefile(self:path(file_name), HttpService:JSONEncode(config))
    end)
    if not ok then
        warn('[Nury] failed to save config:', result)
    end
end

function Config:load(file_name)
    local result = nil
    if HAS_FILE_API then
        local ok, loaded = pcall(function()
            self:ensure_folder(self.folder)
            if not isfile(self:path(file_name)) then
                return nil
            end
            local raw = readfile(self:path(file_name))
            if not raw or raw == '' then
                return nil
            end
            return HttpService:JSONDecode(raw)
        end)
        if ok then
            result = loaded
        else
            warn('[Nury] failed to load config:', loaded)
        end
    end
    result = result or {}
    result._flags = result._flags or {}
    result._keybinds = result._keybinds or {}
    result._library = result._library or {}
    return result
end

--// Library ----------------------------------------------------------------

local Library = {
    _config = nil,
    _choosing_keybind = false,
    _device = nil,
    _ui_open = true,
    _ui_scale = 1,
    _ui_loaded = false,
    _ui = nil,
    _blur = nil,
    _notification_gui = nil,
    _watermark_gui = nil,
    _dragging = false,
    _drag_start = nil,
    _container_position = nil,
    Flags = nil,
}
Library.__index = Library

function Library:flag_type(flag, flag_type)
    if flag == nil or Library._config._flags[flag] == nil then
        return false
    end
    return typeof(Library._config._flags[flag]) == flag_type
end

function Library:set_flag(flag, value, skip_save)
    if flag == nil then
        return
    end
    Library._config._flags[flag] = value
    if not skip_save then
        Config:save(Library._config_name, Library._config)
    end
end

function Library:remove_table_value(source, target)
    for index = #source, 1, -1 do
        if source[index] == target then
            table.remove(source, index)
        end
    end
end

--// Notifications ----------------------------------------------------------

local NOTIFICATION_COLORS = {
    success = Theme.Success,
    error = Theme.Error,
    warning = Theme.Warning,
    info = Theme.Accent,
}

local function get_notification_container()
    if Library._notification_gui and Library._notification_gui.Parent then
        return Library._notification_gui:FindFirstChild('Container')
    end
    local gui = create('ScreenGui', {
        Name = 'NuryNotifications',
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = gui_parent(),
    })
    local container = create('Frame', {
        Name = 'Container',
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -10, 0, 10),
        Size = UDim2.new(0, 300, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = gui,
    }, {
        create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8),
        }),
    })
    Library._notification_gui = gui
    return container
end

function Library.SendNotification(settings)
    settings = settings or {}
    local duration = settings.duration or 5
    local accent = NOTIFICATION_COLORS[settings.type or 'info'] or Theme.Accent
    local container = get_notification_container()

    local holder = create('Frame', {
        Name = 'Notification',
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ClipsDescendants = false,
        Parent = container,
    })

    local inner = create('Frame', {
        Name = 'Inner',
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.new(0, 320, 0, 0),
        BackgroundColor3 = Theme.Element,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        Parent = holder,
    }, {
        create('UICorner', { CornerRadius = UDim.new(0, 5) }),
        create('UIStroke', {
            Color = Theme.Stroke,
            Transparency = 0.5,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }),
    })

    create('Frame', {
        Name = 'AccentBar',
        Size = UDim2.new(0, 3, 1, -10),
        Position = UDim2.new(0, 5, 0, 5),
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        Parent = inner,
    }, {
        create('UICorner', { CornerRadius = UDim.new(1, 0) }),
    })

    create('TextLabel', {
        Name = 'Title',
        Text = settings.title or 'Notification',
        TextColor3 = Color3.fromRGB(210, 210, 210),
        FontFace = font(Enum.FontWeight.SemiBold),
        TextSize = 13,
        Size = UDim2.new(1, -24, 0, 18),
        Position = UDim2.new(0, 16, 0, 6),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = true,
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = inner,
    })

    create('TextLabel', {
        Name = 'Body',
        Text = settings.text or '',
        TextColor3 = Theme.SubText,
        FontFace = font(Enum.FontWeight.Regular),
        TextSize = 12,
        Size = UDim2.new(1, -24, 0, 16),
        Position = UDim2.new(0, 16, 0, 26),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = inner,
    })

    create('Frame', {
        Name = 'Spacer',
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundTransparency = 1,
        Parent = inner,
    })

    local progress = create('Frame', {
        Name = 'Progress',
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = accent,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Parent = inner,
    }, {
        create('UICorner', { CornerRadius = UDim.new(1, 0) }),
    })

    task.spawn(function()
        tween(inner, { Position = UDim2.new(0, 0, 0, 0) }, 0.45)
        tween(progress, { Size = UDim2.new(0, 0, 0, 2) }, duration, Enum.EasingStyle.Linear)
        task.wait(duration)
        local out = tween(inner, { Position = UDim2.new(0, 320, 0, 0) }, 0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        out.Completed:Wait()
        holder:Destroy()
    end)
end

--// Watermark --------------------------------------------------------------

function Library:create_watermark(settings)
    settings = settings or {}
    if Library._watermark_gui then
        Library._watermark_gui:Destroy()
        Library._watermark_gui = nil
    end
    local gui = create('ScreenGui', {
        Name = 'NuryWatermark',
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = gui_parent(),
    })
    local frame = create('Frame', {
        Name = 'Watermark',
        Position = UDim2.new(0, 10, 0, 10),
        Size = UDim2.new(0, 0, 0, 24),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        Parent = gui,
    }, {
        create('UICorner', { CornerRadius = UDim.new(0, 5) }),
        create('UIStroke', {
            Color = Theme.Stroke,
            Transparency = 0.5,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }),
        create('UIPadding', {
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
        }),
    })
    local label = create('TextLabel', {
        Name = 'Label',
        Text = settings.text or 'Nury',
        RichText = true,
        TextColor3 = Theme.Text,
        TextTransparency = 0.2,
        FontFace = font(Enum.FontWeight.SemiBold),
        TextSize = 11,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = frame,
    })
    Library._watermark_gui = gui

    local base_text = settings.text or 'Nury'
    local show_stats = settings.show_stats ~= false
    local frame_count, elapsed, fps = 0, 0, 60
    if show_stats then
        Connections:set('watermark_update', RunService.Heartbeat:Connect(function(delta)
            frame_count += 1
            elapsed += delta
            if elapsed < 0.5 then
                return
            end
            fps = math.floor(frame_count / elapsed + 0.5)
            frame_count, elapsed = 0, 0
            local ping = ''
            pcall(function()
                ping = ' | ' .. math.floor(Stats.Network.ServerStatsItem['Data Ping']:GetValue() + 0.5) .. ' ms'
            end)
            label.Text = string.format('%s | %d fps%s', base_text, fps, ping)
        end))
    end

    local WatermarkManager = {}
    function WatermarkManager:set_visible(state)
        gui.Enabled = state
    end
    function WatermarkManager:set_text(text)
        base_text = text
        label.Text = text
    end
    return WatermarkManager
end

--// Named configs ----------------------------------------------------------

function Library:save_config(name)
    Config:ensure_folder(Config.folder .. '/configs')
    if not HAS_FILE_API then
        return false
    end
    local ok, result = pcall(function()
        writefile(Config.folder .. '/configs/' .. name .. '.json', HttpService:JSONEncode({
            _flags = Library._config._flags,
            _keybinds = Library._config._keybinds,
        }))
    end)
    if not ok then
        warn('[Nury] failed to save config:', result)
    end
    return ok
end

function Library:load_config(name)
    if not HAS_FILE_API then
        return false
    end
    local path = Config.folder .. '/configs/' .. name .. '.json'
    if not isfile(path) then
        return false
    end
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    if not ok or typeof(decoded) ~= 'table' then
        warn('[Nury] failed to load config:', decoded)
        return false
    end
    Library._config._flags = decoded._flags or {}
    Library._config._keybinds = decoded._keybinds or {}
    Library.Flags = Library._config._flags
    Config:save(Library._config_name, Library._config)
    return true
end

function Library:list_configs()
    local names = {}
    if not HAS_FILE_API or typeof(listfiles) ~= 'function' then
        return names
    end
    Config:ensure_folder(Config.folder .. '/configs')
    for _, path in listfiles(Config.folder .. '/configs') do
        local name = string.match(path, '([^/\\]+)%.json$')
        if name then
            table.insert(names, name)
        end
    end
    return names
end

--// Window -----------------------------------------------------------------

function Library.new(options)
    options = options or {}
    Config.folder = options.folder or 'Nury'
    if options.accent then
        Theme.Accent = options.accent
    end
    Library._config_name = tostring(options.config_name or game.GameId)
    Library._config = Config:load(Library._config_name)
    Library.Flags = Library._config._flags

    local self = setmetatable({
        _loaded = false,
        _tab = 0,
        _title = options.title or 'Nury',
        _icon = options.icon or 'rbxassetid://107819132007001',
        _toggle_key = options.toggle_key or Enum.KeyCode.Insert,
    }, Library)
    self:create_ui()
    return self
end

function Library:get_screen_scale()
    local viewport_size_x = workspace.CurrentCamera.ViewportSize.X
    self._ui_scale = viewport_size_x / 1400
end

function Library:get_device()
    local device = 'Unknown'
    if not UserInputService.TouchEnabled and UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
        device = 'PC'
    elseif UserInputService.TouchEnabled then
        device = 'Mobile'
    elseif UserInputService.GamepadEnabled then
        device = 'Console'
    end
    self._device = device
end

function Library:removed(action)
    self._ui.AncestryChanged:Once(action)
end

function Library:set_accent(color)
    Theme.Accent = color
    for object, properties in AccentRegistry do
        for _, property in properties do
            pcall(function()
                object[property] = color
            end)
        end
    end
end

function Library:set_toggle_key(keycode)
    self._toggle_key = keycode
end

function Library:unload()
    Connections:disconnect_all()
    if Library._blur then
        Library._blur:destroy()
        Library._blur = nil
    end
    if Library._notification_gui then
        Library._notification_gui:Destroy()
        Library._notification_gui = nil
    end
    if Library._watermark_gui then
        Library._watermark_gui:Destroy()
        Library._watermark_gui = nil
    end
    if self._ui then
        self._ui:Destroy()
        self._ui = nil
    end
    Library._ui_loaded = false
end

function Library:create_ui()
    local parent = gui_parent()
    local old_ui = parent:FindFirstChild('Nury')
    if old_ui then
        Debris:AddItem(old_ui, 0)
    end

    local screen_gui = create('ScreenGui', {
        Name = 'Nury',
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = parent,
    })

    local container = create('Frame', {
        Name = 'Container',
        ClipsDescendants = true,
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 0.05,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(0, 0),
        Active = true,
        BorderSizePixel = 0,
        Parent = screen_gui,
    }, {
        create('UICorner', { CornerRadius = UDim.new(0, 10) }),
        create('UIStroke', {
            Color = Theme.Stroke,
            Transparency = 0.5,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }),
    })

    local handler = create('Frame', {
        Name = 'Handler',
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(698, 479),
        BorderSizePixel = 0,
        Parent = container,
    })

    local tabs = create('ScrollingFrame', {
        Name = 'Tabs',
        ScrollBarImageTransparency = 1,
        ScrollBarThickness = 0,
        Size = UDim2.fromOffset(129, 401),
        Selectable = false,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.026, 0.111),
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Parent = handler,
    }, {
        create('UIListLayout', {
            Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    })

    local client_name = create('TextLabel', {
        Name = 'ClientName',
        FontFace = font(Enum.FontWeight.SemiBold),
        TextColor3 = Theme.Accent,
        TextTransparency = 0.2,
        Text = self._title,
        Size = UDim2.fromOffset(math.max(31, text_width(self._title, 13)), 13),
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0.056, 0.055),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        BorderSizePixel = 0,
        TextSize = 13,
        Parent = handler,
    }, {
        create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(155, 155, 155)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
            }),
        }),
    })
    register_accent(client_name, { 'TextColor3' })

    local pin = create('Frame', {
        Name = 'Pin',
        Position = UDim2.new(0.026, 0, 0, 65),
        Size = UDim2.fromOffset(2, 16),
        BorderSizePixel = 0,
        BackgroundColor3 = Theme.Accent,
        Parent = handler,
    }, {
        create('UICorner', { CornerRadius = UDim.new(1, 0) }),
    })
    register_accent(pin, { 'BackgroundColor3' })

    local title_icon = create('ImageLabel', {
        Name = 'Icon',
        ImageColor3 = Theme.Accent,
        ScaleType = Enum.ScaleType.Fit,
        AnchorPoint = Vector2.new(0, 0.5),
        Image = self._icon,
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.025, 0.055),
        Size = UDim2.fromOffset(18, 18),
        BorderSizePixel = 0,
        Parent = handler,
    })
    register_accent(title_icon, { 'ImageColor3' })

    create('Frame', {
        Name = 'Divider',
        BackgroundTransparency = 0.5,
        Position = UDim2.fromScale(0.235, 0),
        Size = UDim2.fromOffset(1, 479),
        BorderSizePixel = 0,
        BackgroundColor3 = Theme.Stroke,
        Parent = handler,
    })

    local sections = create('Folder', {
        Name = 'Sections',
        Parent = handler,
    })

    local minimize = create('TextButton', {
        Name = 'Minimize',
        Text = '',
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.02, 0.029),
        Size = UDim2.fromOffset(24, 24),
        BorderSizePixel = 0,
        Parent = handler,
    })

    local ui_scale = create('UIScale', { Parent = container })

    self._ui = screen_gui
    self._container = container
    self._handler = handler
    self._tabs_frame = tabs
    self._pin = pin
    self._sections = sections

    --// Dragging
    local function on_drag(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            self._dragging = true
            self._drag_start = input.Position
            self._container_position = container.Position
            Connections:set('container_input_ended', input.Changed:Connect(function()
                if input.UserInputState ~= Enum.UserInputState.End then
                    return
                end
                Connections:disconnect('container_input_ended')
                self._dragging = false
            end))
        end
    end
    local function update_drag(input)
        local delta = input.Position - self._drag_start
        local position = UDim2.new(
            self._container_position.X.Scale,
            self._container_position.X.Offset + delta.X,
            self._container_position.Y.Scale,
            self._container_position.Y.Offset + delta.Y
        )
        tween(container, { Position = position }, 0.2)
    end
    Connections:set('container_input_began', container.InputBegan:Connect(on_drag))
    Connections:set('input_changed', UserInputService.InputChanged:Connect(function(input)
        if not self._dragging then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            update_drag(input)
        end
    end))

    self:removed(function()
        self._ui = nil
        Connections:disconnect_all()
    end)

    --// Compat: adjust background transparency
    function self:Update1Run(value)
        if value == 'nil' then
            container.BackgroundTransparency = 0.05
        else
            pcall(function()
                container.BackgroundTransparency = tonumber(value)
            end)
        end
    end

    function self:UIVisiblity()
        screen_gui.Enabled = not screen_gui.Enabled
    end

    function self:change_visiblity(state)
        if state then
            tween(container, { Size = UDim2.fromOffset(698, 479) }, 0.5)
        else
            tween(container, { Size = UDim2.fromOffset(104, 52) }, 0.5)
        end
    end

    function self:load()
        local content = {}
        for _, object in screen_gui:GetDescendants() do
            if object:IsA('ImageLabel') then
                table.insert(content, object)
            end
        end
        pcall(function()
            ContentProvider:PreloadAsync(content)
        end)
        self:get_device()
        if self._device == 'Mobile' or self._device == 'Unknown' then
            self:get_screen_scale()
            ui_scale.Scale = self._ui_scale
            Connections:set('ui_scale', workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(function()
                self:get_screen_scale()
                ui_scale.Scale = self._ui_scale
            end))
        end
        tween(container, { Size = UDim2.fromOffset(698, 479) }, 0.5)
        Library._blur = AcrylicBlur.new(container)
        Library._ui_loaded = true
    end

    function self:update_tabs(selected_tab)
        for _, object in tabs:GetChildren() do
            if object.Name ~= 'Tab' then
                continue
            end
            if object == selected_tab then
                if object.BackgroundTransparency ~= 0.5 then
                    tween(pin, { Position = UDim2.new(0.026, 0, 0, 65 + object.LayoutOrder * 42 + 11) }, 0.5)
                    tween(object, { BackgroundTransparency = 0.5 }, 0.5)
                    tween(object.TextLabel, { TextTransparency = 0.2, TextColor3 = Theme.Accent }, 0.5)
                    tween(object.TextLabel.UIGradient, { Offset = Vector2.new(1, 0) }, 0.5)
                    tween(object.Icon, { ImageTransparency = 0.2, ImageColor3 = Theme.Accent }, 0.5)
                end
                continue
            end
            if object.BackgroundTransparency ~= 1 then
                tween(object, { BackgroundTransparency = 1 }, 0.5)
                tween(object.TextLabel, { TextTransparency = 0.7, TextColor3 = Theme.Text }, 0.5)
                tween(object.TextLabel.UIGradient, { Offset = Vector2.new(0, 0) }, 0.5)
                tween(object.Icon, { ImageTransparency = 0.8, ImageColor3 = Theme.Text }, 0.5)
            end
        end
    end

    function self:update_sections(left_section, right_section)
        for _, object in sections:GetChildren() do
            object.Visible = object == left_section or object == right_section
        end
    end

    --// Toggle keybind + minimize
    Connections:set('library_visiblity', UserInputService.InputBegan:Connect(function(input, process)
        if process then
            return
        end
        if input.KeyCode ~= self._toggle_key then
            return
        end
        self._ui_open = not self._ui_open
        self:change_visiblity(self._ui_open)
    end))
    minimize.MouseButton1Click:Connect(function()
        self._ui_open = not self._ui_open
        self:change_visiblity(self._ui_open)
    end)

    function self:SendNotification(settings)
        Library.SendNotification(settings)
    end

    return self
end

--// Tabs -------------------------------------------------------------------

function Library:create_tab(title, icon)
    local window = self
    local tabs = self._tabs_frame
    local sections = self._sections
    local TabManager = {}

    local title_size = text_width(title, 13)
    local first_tab = not tabs:FindFirstChild('Tab')

    local tab_button = create('TextButton', {
        Name = 'Tab',
        Text = '',
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(129, 38),
        BorderSizePixel = 0,
        BackgroundColor3 = Theme.Module,
        LayoutOrder = self._tab,
        Parent = tabs,
    }, {
        create('UICorner', { CornerRadius = UDim.new(0, 5) }),
    })

    create('TextLabel', {
        FontFace = font(Enum.FontWeight.SemiBold),
        TextColor3 = Theme.Text,
        TextTransparency = 0.7,
        Text = title,
        Size = UDim2.fromOffset(title_size, 16),
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0.24, 0.5),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        BorderSizePixel = 0,
        TextSize = 13,
        Parent = tab_button,
    }, {
        create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                ColorSequenceKeypoint.new(0.7, Color3.fromRGB(155, 155, 155)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(58, 58, 58)),
            }),
        }),
    })

    create('ImageLabel', {
        Name = 'Icon',
        ScaleType = Enum.ScaleType.Fit,
        ImageTransparency = 0.8,
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.1, 0.5),
        Image = icon or '',
        Size = UDim2.fromOffset(12, 12),
        BorderSizePixel = 0,
        Parent = tab_button,
    })

    local function make_section(name, x_scale)
        return create('ScrollingFrame', {
            Name = name,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 0,
            Size = UDim2.fromOffset(243, 445),
            Selectable = false,
            AnchorPoint = Vector2.new(0, 0.5),
            ScrollBarImageTransparency = 1,
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(x_scale, 0.5),
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            Visible = false,
            Parent = sections,
        }, {
            create('UIListLayout', {
                Padding = UDim.new(0, 11),
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            create('UIPadding', {
                PaddingTop = UDim.new(0, 1),
                PaddingBottom = UDim.new(0, 6),
            }),
        })
    end

    local left_section = make_section('LeftSection', 0.259)
    local right_section = make_section('RightSection', 0.629)

    self._tab += 1
    if first_tab then
        window:update_tabs(tab_button)
        window:update_sections(left_section, right_section)
    end
    tab_button.MouseButton1Click:Connect(function()
        window:update_tabs(tab_button)
        window:update_sections(left_section, right_section)
    end)

    --// Modules -------------------------------------------------------------

    function TabManager:create_module(settings)
        settings = settings or {}
        local element_order = 0
        local ModuleManager = {
            _state = false,
            _size = 0,
            _multiplier = 0,
        }
        local section = settings.section == 'right' and right_section or left_section

        local module_frame = create('Frame', {
            Name = 'Module',
            ClipsDescendants = true,
            BackgroundTransparency = 0.5,
            Size = UDim2.fromOffset(241, 93),
            BorderSizePixel = 0,
            BackgroundColor3 = Theme.Module,
            Parent = section,
        }, {
            create('UIListLayout', { SortOrder = Enum.SortOrder.LayoutOrder }),
            create('UICorner', { CornerRadius = UDim.new(0, 5) }),
            create('UIStroke', {
                Color = Theme.Stroke,
                Transparency = 0.5,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }),
        })

        local header = create('TextButton', {
            Name = 'Header',
            Text = '',
            AutoButtonColor = false,
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(241, 93),
            BorderSizePixel = 0,
            LayoutOrder = 0,
            Parent = module_frame,
        })

        local header_icon = create('ImageLabel', {
            Name = 'Icon',
            ImageColor3 = Theme.Accent,
            ScaleType = Enum.ScaleType.Fit,
            ImageTransparency = 0.7,
            AnchorPoint = Vector2.new(0, 0.5),
            Image = settings.icon or 'rbxassetid://79095934438045',
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(0.071, 0.82),
            Size = UDim2.fromOffset(15, 15),
            BorderSizePixel = 0,
            Parent = header,
        })
        register_accent(header_icon, { 'ImageColor3' })

        local module_name = create('TextLabel', {
            Name = 'ModuleName',
            FontFace = font(Enum.FontWeight.SemiBold),
            TextColor3 = Theme.Accent,
            TextTransparency = 0.2,
            Size = UDim2.fromOffset(205, 13),
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.fromScale(0.073, 0.24),
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            BorderSizePixel = 0,
            TextSize = 13,
            Parent = header,
        })
        if settings.rich then
            module_name.RichText = true
            module_name.Text = settings.richtext or settings.title or 'Module'
        else
            module_name.Text = settings.title or 'Module'
        end
        register_accent(module_name, { 'TextColor3' })

        local description = create('TextLabel', {
            Name = 'Description',
            FontFace = font(Enum.FontWeight.SemiBold),
            TextColor3 = Theme.Accent,
            TextTransparency = 0.7,
            Text = settings.description or '',
            Size = UDim2.fromOffset(205, 13),
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.fromScale(0.073, 0.42),
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            BorderSizePixel = 0,
            TextSize = 10,
            Parent = header,
        })
        register_accent(description, { 'TextColor3' })

        local toggle = create('Frame', {
            Name = 'Toggle',
            BackgroundTransparency = 0.7,
            Position = UDim2.fromScale(0.82, 0.757),
            Size = UDim2.fromOffset(25, 12),
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.new(0, 0, 0),
            Parent = header,
        }, {
            create('UICorner', { CornerRadius = UDim.new(1, 0) }),
        })

        local circle = create('Frame', {
            Name = 'Circle',
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundTransparency = 0.2,
            Position = UDim2.fromScale(0, 0.5),
            Size = UDim2.fromOffset(12, 12),
            BorderSizePixel = 0,
            BackgroundColor3 = Theme.ToggleOff,
            Parent = toggle,
        }, {
            create('UICorner', { CornerRadius = UDim.new(1, 0) }),
        })

        local keybind_frame = create('Frame', {
            Name = 'Keybind',
            BackgroundTransparency = 0.7,
            Position = UDim2.fromScale(0.15, 0.735),
            Size = UDim2.fromOffset(33, 15),
            BorderSizePixel = 0,
            BackgroundColor3 = Theme.Accent,
            Parent = header,
        }, {
            create('UICorner', { CornerRadius = UDim.new(0, 3) }),
        })
        register_accent(keybind_frame, { 'BackgroundColor3' })

        local keybind_label = create('TextLabel', {
            FontFace = font(Enum.FontWeight.SemiBold),
            TextColor3 = Theme.AccentText,
            Text = 'None',
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(25, 13),
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromScale(0.5, 0.5),
            BorderSizePixel = 0,
            TextSize = 10,
            Parent = keybind_frame,
        })

        create('Frame', {
            Name = 'Divider',
            AnchorPoint = Vector2.new(0.5, 0),
            BackgroundTransparency = 0.5,
            Position = UDim2.fromScale(0.5, 0.62),
            Size = UDim2.fromOffset(241, 1),
            BorderSizePixel = 0,
            BackgroundColor3 = Theme.Stroke,
            Parent = header,
        })
        create('Frame', {
            Name = 'Divider',
            AnchorPoint = Vector2.new(0.5, 0),
            BackgroundTransparency = 0.5,
            Position = UDim2.fromScale(0.5, 1),
            Size = UDim2.fromOffset(241, 1),
            BorderSizePixel = 0,
            BackgroundColor3 = Theme.Stroke,
            Parent = header,
        })

        local options = create('Frame', {
            Name = 'Options',
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(241, 8),
            BorderSizePixel = 0,
            LayoutOrder = 1,
            Parent = module_frame,
        }, {
            create('UIPadding', { PaddingTop = UDim.new(0, 8) }),
            create('UIListLayout', {
                Padding = UDim.new(0, 5),
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
        })

        -- Height bookkeeping: _size is the settled content height, _multiplier
        -- is the temporary extra height while a dropdown/picker is unfolded.
        function ModuleManager:_grow(amount)
            if self._size == 0 then
                self._size = 11
            end
            self._size += amount
            if self._state then
                module_frame.Size = UDim2.fromOffset(241, 93 + self._size + self._multiplier)
            end
            options.Size = UDim2.fromOffset(241, self._size)
        end

        function ModuleManager:_refresh(animated)
            local module_height = self._state and (93 + self._size + self._multiplier) or 93
            local options_height = self._size + self._multiplier
            if animated then
                tween(module_frame, { Size = UDim2.fromOffset(241, module_height) }, 0.5)
                tween(options, { Size = UDim2.fromOffset(241, options_height) }, 0.5)
            else
                module_frame.Size = UDim2.fromOffset(241, module_height)
                options.Size = UDim2.fromOffset(241, options_height)
            end
        end

        function ModuleManager:change_state(state)
            self._state = state
            if self._state then
                tween(module_frame, { Size = UDim2.fromOffset(241, 93 + self._size + self._multiplier) }, 0.5)
                tween(toggle, { BackgroundColor3 = Theme.Accent }, 0.5)
                tween(circle, { BackgroundColor3 = Theme.Accent, Position = UDim2.fromScale(0.53, 0.5) }, 0.5)
            else
                tween(module_frame, { Size = UDim2.fromOffset(241, 93) }, 0.5)
                tween(toggle, { BackgroundColor3 = Color3.new(0, 0, 0) }, 0.5)
                tween(circle, { BackgroundColor3 = Theme.ToggleOff, Position = UDim2.fromScale(0, 0.5) }, 0.5)
            end
            if settings.flag then
                Library:set_flag(settings.flag, self._state)
            end
            if settings.callback then
                settings.callback(self._state)
            end
        end

        function ModuleManager:connect_keybind()
            if not settings.flag or not Library._config._keybinds[settings.flag] then
                return
            end
            Connections:set(settings.flag .. '_keybind', UserInputService.InputBegan:Connect(function(input, process)
                if process then
                    return
                end
                if tostring(input.KeyCode) ~= Library._config._keybinds[settings.flag] then
                    return
                end
                self:change_state(not self._state)
            end))
        end

        function ModuleManager:scale_keybind(empty)
            if settings.flag and Library._config._keybinds[settings.flag] and not empty then
                local keybind_string = keycode_name(Library._config._keybinds[settings.flag])
                local width = text_width(keybind_string, 10)
                keybind_frame.Size = UDim2.fromOffset(width + 6, 15)
                keybind_label.Size = UDim2.fromOffset(width, 13)
            else
                keybind_frame.Size = UDim2.fromOffset(31, 15)
                keybind_label.Size = UDim2.fromOffset(25, 13)
            end
        end

        -- Restore state and keybind from config
        if Library:flag_type(settings.flag, 'boolean') and Library._config._flags[settings.flag] then
            ModuleManager._state = true
            if settings.callback then
                settings.callback(true)
            end
            toggle.BackgroundColor3 = Theme.Accent
            circle.BackgroundColor3 = Theme.Accent
            circle.Position = UDim2.fromScale(0.53, 0.5)
        end
        if settings.flag and Library._config._keybinds[settings.flag] then
            keybind_label.Text = keycode_name(Library._config._keybinds[settings.flag])
            ModuleManager:connect_keybind()
            ModuleManager:scale_keybind()
        end

        -- Middle-click on the header rebinds the module keybind
        if settings.flag then
            Connections:set(settings.flag .. '_input_began', header.InputBegan:Connect(function(input)
                if Library._choosing_keybind then
                    return
                end
                if input.UserInputType ~= Enum.UserInputType.MouseButton3 then
                    return
                end
                Library._choosing_keybind = true
                keybind_label.Text = '...'
                Connections:set('keybind_choose_start', UserInputService.InputBegan:Connect(function(key_input, process)
                    if process then
                        return
                    end
                    if key_input.UserInputType ~= Enum.UserInputType.Keyboard then
                        return
                    end
                    if key_input.KeyCode == Enum.KeyCode.Unknown then
                        return
                    end
                    Connections:disconnect('keybind_choose_start')
                    Library._choosing_keybind = false
                    if key_input.KeyCode == Enum.KeyCode.Backspace then
                        ModuleManager:scale_keybind(true)
                        Library._config._keybinds[settings.flag] = nil
                        Config:save(Library._config_name, Library._config)
                        keybind_label.Text = 'None'
                        Connections:disconnect(settings.flag .. '_keybind')
                        return
                    end
                    Library._config._keybinds[settings.flag] = tostring(key_input.KeyCode)
                    Config:save(Library._config_name, Library._config)
                    Connections:disconnect(settings.flag .. '_keybind')
                    ModuleManager:connect_keybind()
                    ModuleManager:scale_keybind()
                    keybind_label.Text = keycode_name(key_input.KeyCode)
                end))
            end))
        end

        header.MouseButton1Click:Connect(function()
            ModuleManager:change_state(not ModuleManager._state)
        end)

        --// Elements --------------------------------------------------------

        local function next_order()
            element_order += 1
            return element_order
        end

        function ModuleManager:create_paragraph(element_settings)
            element_settings = element_settings or {}
            local ParagraphManager = {}
            self:_grow(element_settings.customScale or 70)

            local paragraph = create('Frame', {
                Name = 'Paragraph',
                BackgroundColor3 = Theme.Element,
                BackgroundTransparency = 0.1,
                Size = UDim2.fromOffset(207, 30),
                BorderSizePixel = 0,
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = next_order(),
                Parent = options,
            }, {
                create('UICorner', { CornerRadius = UDim.new(0, 4) }),
            })

            local title_label = create('TextLabel', {
                FontFace = font(Enum.FontWeight.SemiBold),
                TextColor3 = Color3.fromRGB(210, 210, 210),
                Text = element_settings.title or 'Title',
                Size = UDim2.new(1, -10, 0, 20),
                Position = UDim2.fromOffset(5, 5),
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center,
                TextSize = 12,
                TextWrapped = true,
                AutomaticSize = Enum.AutomaticSize.Y,
                Parent = paragraph,
            })

            local body_label = create('TextLabel', {
                FontFace = font(Enum.FontWeight.Regular),
                TextColor3 = Theme.SubText,
                Size = UDim2.new(1, -10, 0, 20),
                Position = UDim2.fromOffset(5, 30),
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                TextSize = 11,
                TextWrapped = true,
                AutomaticSize = Enum.AutomaticSize.Y,
                Parent = paragraph,
            })
            if element_settings.rich then
                body_label.RichText = true
                body_label.Text = element_settings.richtext or element_settings.text or ''
            else
                body_label.Text = element_settings.text or ''
            end

            paragraph.MouseEnter:Connect(function()
                tween(paragraph, { BackgroundColor3 = Theme.ElementHover }, 0.3)
            end)
            paragraph.MouseLeave:Connect(function()
                tween(paragraph, { BackgroundColor3 = Theme.Element }, 0.3)
            end)

            function ParagraphManager:Set(new_settings)
                new_settings = new_settings or {}
                if new_settings.title then
                    title_label.Text = new_settings.title
                end
                if new_settings.rich then
                    body_label.RichText = true
                    body_label.Text = new_settings.richtext or new_settings.text or body_label.Text
                elseif new_settings.text then
                    body_label.Text = new_settings.text
                end
            end
            return ParagraphManager
        end

        function ModuleManager:create_text(element_settings)
            element_settings = element_settings or {}
            local TextManager = {}
            self:_grow(element_settings.customScale or 50)

            local text_frame = create('Frame', {
                Name = 'Text',
                BackgroundColor3 = Theme.Element,
                BackgroundTransparency = 0.1,
                Size = UDim2.fromOffset(207, element_settings.CustomYSize or 30),
                BorderSizePixel = 0,
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = next_order(),
                Parent = options,
            }, {
                create('UICorner', { CornerRadius = UDim.new(0, 4) }),
            })

            local body_label = create('TextLabel', {
                FontFace = font(Enum.FontWeight.Regular),
                TextColor3 = Theme.SubText,
                Size = UDim2.new(1, -10, 1, 0),
                Position = UDim2.fromOffset(5, 5),
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                TextSize = 10,
                TextWrapped = true,
                AutomaticSize = Enum.AutomaticSize.Y,
                Parent = text_frame,
            })
            if element_settings.rich then
                body_label.RichText = true
                body_label.Text = element_settings.richtext or element_settings.text or ''
            else
                body_label.Text = element_settings.text or ''
            end

            text_frame.MouseEnter:Connect(function()
                tween(text_frame, { BackgroundColor3 = Theme.ElementHover }, 0.3)
            end)
            text_frame.MouseLeave:Connect(function()
                tween(text_frame, { BackgroundColor3 = Theme.Element }, 0.3)
            end)

            function TextManager:Set(new_settings)
                new_settings = new_settings or {}
                if new_settings.rich then
                    body_label.RichText = true
                    body_label.Text = new_settings.richtext or new_settings.text or body_label.Text
                elseif new_settings.text then
                    body_label.Text = new_settings.text
                end
            end
            return TextManager
        end

        function ModuleManager:create_textbox(element_settings)
            element_settings = element_settings or {}
            local TextboxManager = { _text = '' }
            self:_grow(32)

            create('TextLabel', {
                FontFace = font(Enum.FontWeight.SemiBold),
                TextColor3 = Theme.Text,
                TextTransparency = 0.2,
                Text = element_settings.title or 'Enter text',
                Size = UDim2.fromOffset(207, 13),
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
                BorderSizePixel = 0,
                TextSize = 10,
                LayoutOrder = next_order(),
                Parent = options,
            })

            local textbox = create('TextBox', {
                Name = 'Textbox',
                FontFace = font(Enum.FontWeight.Regular),
                TextColor3 = Theme.Text,
                PlaceholderText = element_settings.placeholder or 'Enter text...',
                Text = (Library:flag_type(element_settings.flag, 'string') and Library._config._flags[element_settings.flag]) or '',
                Size = UDim2.fromOffset(207, 15),
                BorderSizePixel = 0,
                TextSize = 10,
                BackgroundColor3 = Theme.Accent,
                BackgroundTransparency = 0.9,
                ClearTextOnFocus = false,
                LayoutOrder = next_order(),
                Parent = options,
            }, {
                create('UICorner', { CornerRadius = UDim.new(0, 4) }),
            })
            register_accent(textbox, { 'BackgroundColor3' })

            function TextboxManager:update_text(text)
                self._text = text
                if element_settings.flag then
                    Library:set_flag(element_settings.flag, self._text)
                end
                if element_settings.callback then
                    element_settings.callback(self._text)
                end
            end

            function TextboxManager:set_value(text)
                textbox.Text = text
                self:update_text(text)
            end

            if Library:flag_type(element_settings.flag, 'string') then
                TextboxManager:update_text(Library._config._flags[element_settings.flag])
            end

            textbox.FocusLost:Connect(function()
                TextboxManager:update_text(textbox.Text)
            end)
            return TextboxManager
        end

        function ModuleManager:create_checkbox(element_settings)
            element_settings = element_settings or {}
            local CheckboxManager = { _state = false }
            self:_grow(20)

            local checkbox = create('TextButton', {
                Name = 'Checkbox',
                Text = '',
                AutoButtonColor = false,
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(207, 15),
                BorderSizePixel = 0,
                LayoutOrder = next_order(),
                Parent = options,
            })

            create('TextLabel', {
                Name = 'TitleLabel',
                FontFace = font(Enum.FontWeight.SemiBold),
                TextSize = 11,
                TextColor3 = Theme.Text,
                TextTransparency = 0.2,
                Text = element_settings.title or 'Checkbox',
                Size = UDim2.fromOffset(160, 13),
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.fromScale(0, 0.5),
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = checkbox,
            })

            local box = create('Frame', {
                Name = 'Box',
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundTransparency = 0.9,
                Position = UDim2.fromScale(1, 0.5),
                Size = UDim2.fromOffset(15, 15),
                BorderSizePixel = 0,
                BackgroundColor3 = Theme.Accent,
                Parent = checkbox,
            }, {
                create('UICorner', { CornerRadius = UDim.new(0, 4) }),
            })
            register_accent(box, { 'BackgroundColor3' })

            local fill = create('Frame', {
                Name = 'Fill',
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 0.2,
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(0, 0),
                BorderSizePixel = 0,
                BackgroundColor3 = Theme.Accent,
                Parent = box,
            }, {
                create('UICorner', { CornerRadius = UDim.new(0, 3) }),
            })
            register_accent(fill, { 'BackgroundColor3' })

            function CheckboxManager:change_state(state)
                self._state = state
                if self._state then
                    tween(box, { BackgroundTransparency = 0.7 }, 0.5)
                    tween(fill, { Size = UDim2.fromOffset(9, 9) }, 0.5)
                else
                    tween(box, { BackgroundTransparency = 0.9 }, 0.5)
                    tween(fill, { Size = UDim2.fromOffset(0, 0) }, 0.5)
                end
                if element_settings.flag then
                    Library:set_flag(element_settings.flag, self._state)
                end
                if element_settings.callback then
                    element_settings.callback(self._state)
                end
            end
            CheckboxManager.set_state = CheckboxManager.change_state

            if Library:flag_type(element_settings.flag, 'boolean') then
                CheckboxManager:change_state(Library._config._flags[element_settings.flag])
            elseif element_settings.default then
                CheckboxManager:change_state(true)
            end

            checkbox.MouseButton1Click:Connect(function()
                CheckboxManager:change_state(not CheckboxManager._state)
            end)
            return CheckboxManager
        end

        function ModuleManager:create_divider(element_settings)
            self:_grow(27)

            local outer = create('Frame', {
                Name = 'DividerHolder',
                Size = UDim2.fromOffset(207, 20),
                BackgroundTransparency = 1,
                LayoutOrder = next_order(),
                Parent = options,
            })

            if element_settings and element_settings.showtopic then
                create('TextLabel', {
                    FontFace = font(Enum.FontWeight.SemiBold),
                    TextColor3 = Theme.Text,
                    Text = element_settings.title or '',
                    Size = UDim2.fromOffset(153, 13),
                    Position = UDim2.fromScale(0.5, 0.501),
                    BackgroundTransparency = 1,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    BorderSizePixel = 0,
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    TextSize = 11,
                    ZIndex = 3,
                    TextStrokeTransparency = 0,
                    Parent = outer,
                })
            end

            if not element_settings or not element_settings.disableline then
                create('Frame', {
                    Name = 'Divider',
                    Size = UDim2.new(1, 0, 0, 1),
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderSizePixel = 0,
                    ZIndex = 2,
                    Position = UDim2.new(0, 0, 0.5, 0),
                    Parent = outer,
                }, {
                    create('UIGradient', {
                        Transparency = NumberSequence.new({
                            NumberSequenceKeypoint.new(0, 1),
                            NumberSequenceKeypoint.new(0.5, 0),
                            NumberSequenceKeypoint.new(1, 1),
                        }),
                    }),
                    create('UICorner', { CornerRadius = UDim.new(0, 2) }),
                })
            end
            return true
        end

        function ModuleManager:create_slider(element_settings)
            element_settings = element_settings or {}
            local SliderManager = { _value = element_settings.value or element_settings.minimum_value or 0 }
            self:_grow(27)

            local slider = create('TextButton', {
                Name = 'Slider',
                Text = '',
                AutoButtonColor = false,
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(207, 22),
                BorderSizePixel = 0,
                LayoutOrder = next_order(),
                Parent = options,
            })

            create('TextLabel', {
                FontFace = font(Enum.FontWeight.SemiBold),
                TextSize = 11,
                TextColor3 = Theme.Text,
                TextTransparency = 0.2,
                Text = element_settings.title or 'Slider',
                Size = UDim2.fromOffset(153, 13),
                Position = UDim2.fromScale(0, 0.05),
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
                BorderSizePixel = 0,
                Parent = slider,
            })

            local drag = create('Frame', {
                Name = 'Drag',
                AnchorPoint = Vector2.new(0.5, 1),
                BackgroundTransparency = 0.9,
                Position = UDim2.fromScale(0.5, 0.95),
                Size = UDim2.fromOffset(207, 4),
                BorderSizePixel = 0,
                BackgroundColor3 = Theme.Accent,
                Parent = slider,
            }, {
                create('UICorner', { CornerRadius = UDim.new(1, 0) }),
            })
            register_accent(drag, { 'BackgroundColor3' })

            local fill = create('Frame', {
                Name = 'Fill',
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundTransparency = 0.5,
                Position = UDim2.fromScale(0, 0.5),
                Size = UDim2.fromOffset(103, 4),
                BorderSizePixel = 0,
                BackgroundColor3 = Theme.Accent,
                Parent = drag,
            }, {
                create('UICorner', { CornerRadius = UDim.new(0, 3) }),
                create('UIGradient', {
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(79, 79, 79)),
                    }),
                }),
            })
            register_accent(fill, { 'BackgroundColor3' })

            create('Frame', {
                Name = 'Circle',
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.fromScale(1, 0.5),
                Size = UDim2.fromOffset(6, 6),
                BorderSizePixel = 0,
                BackgroundColor3 = Color3.new(1, 1, 1),
                Parent = fill,
            }, {
                create('UICorner', { CornerRadius = UDim.new(1, 0) }),
            })

            local value_label = create('TextLabel', {
                Name = 'Value',
                FontFace = font(Enum.FontWeight.SemiBold),
                TextColor3 = Theme.Text,
                TextTransparency = 0.2,
                Text = tostring(SliderManager._value),
                Size = UDim2.fromOffset(42, 13),
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.fromScale(1, 0),
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Right,
                BorderSizePixel = 0,
                TextSize = 10,
                Parent = slider,
            })

            local minimum = element_settings.minimum_value or 0
            local maximum = element_settings.maximum_value or 100

            function SliderManager:set_percentage(raw_value)
                local rounded = 0
                if element_settings.round_number then
                    rounded = math.floor(raw_value)
                else
                    rounded = math.floor(raw_value * 10) / 10
                end
                local clamped = math.clamp(rounded, minimum, maximum)
                local alpha = (clamped - minimum) / (maximum - minimum)
                local fill_size = math.clamp(alpha, 0.02, 1) * drag.Size.X.Offset
                self._value = clamped
                if element_settings.flag then
                    Library:set_flag(element_settings.flag, clamped, true)
                end
                value_label.Text = tostring(clamped)
                tween(fill, { Size = UDim2.fromOffset(fill_size, drag.Size.Y.Offset) }, 0.5)
                if element_settings.callback then
                    element_settings.callback(clamped)
                end
            end
            SliderManager.set_value = SliderManager.set_percentage

            function SliderManager:update()
                local alpha = math.clamp((Mouse.X - drag.AbsolutePosition.X) / drag.AbsoluteSize.X, 0, 1)
                self:set_percentage(minimum + (maximum - minimum) * alpha)
            end

            function SliderManager:input()
                self:update()
                Connections:set('slider_drag_' .. tostring(element_settings.flag or element_settings.title), Mouse.Move:Connect(function()
                    self:update()
                end))
                Connections:set('slider_input_' .. tostring(element_settings.flag or element_settings.title), UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
                        return
                    end
                    Connections:disconnect('slider_drag_' .. tostring(element_settings.flag or element_settings.title))
                    Connections:disconnect('slider_input_' .. tostring(element_settings.flag or element_settings.title))
                    if not element_settings.ignoresaved then
                        Config:save(Library._config_name, Library._config)
                    end
                end))
            end

            if Library:flag_type(element_settings.flag, 'number') and not element_settings.ignoresaved then
                SliderManager:set_percentage(Library._config._flags[element_settings.flag])
            else
                SliderManager:set_percentage(element_settings.value or minimum)
            end

            slider.MouseButton1Down:Connect(function()
                SliderManager:input()
            end)
            return SliderManager
        end

        function ModuleManager:create_dropdown(element_settings)
            element_settings = element_settings or {}
            local DropdownManager = {
                _state = false,
                _size = 0,
                _selected = {},
            }
            self:_grow(44)

            local dropdown = create('TextButton', {
                Name = 'Dropdown',
                Text = '',
                AutoButtonColor = false,
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(207, 39),
                BorderSizePixel = 0,
                LayoutOrder = next_order(),
                Parent = options,
            })

            local title_label = create('TextLabel', {
                FontFace = font(Enum.FontWeight.SemiBold),
                TextSize = 11,
                TextColor3 = Theme.Text,
                TextTransparency = 0.2,
                Text = element_settings.title or 'Dropdown',
                Size = UDim2.fromOffset(207, 13),
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
                BorderSizePixel = 0,
                Parent = dropdown,
            })

            local box = create('Frame', {
                Name = 'Box',
                ClipsDescendants = true,
                AnchorPoint = Vector2.new(0.5, 0),
                BackgroundTransparency = 0.9,
                Position = UDim2.fromScale(0.5, 1.2),
                Size = UDim2.fromOffset(207, 22),
                BorderSizePixel = 0,
                BackgroundColor3 = Theme.Accent,
                Parent = title_label,
            }, {
                create('UICorner', { CornerRadius = UDim.new(0, 4) }),
                create('UIListLayout', { SortOrder = Enum.SortOrder.LayoutOrder }),
            })
            register_accent(box, { 'BackgroundColor3' })

            local box_header = create('Frame', {
                Name = 'Header',
                AnchorPoint = Vector2.new(0.5, 0),
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(207, 22),
                BorderSizePixel = 0,
                Parent = box,
            })

            local current_option = create('TextLabel', {
                Name = 'CurrentOption',
                FontFace = font(Enum.FontWeight.SemiBold),
                TextColor3 = Theme.Text,
                TextTransparency = 0.2,
                Text = '',
                Size = UDim2.fromOffset(161, 13),
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.fromScale(0.05, 0.5),
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
                BorderSizePixel = 0,
                TextSize = 10,
                Parent = box_header,
            }, {
                create('UIGradient', {
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0),
                        NumberSequenceKeypoint.new(0.704, 0),
                        NumberSequenceKeypoint.new(0.872, 0.363),
                        NumberSequenceKeypoint.new(1, 1),
                    }),
                }),
            })

            local arrow = create('ImageLabel', {
                Name = 'Arrow',
                AnchorPoint = Vector2.new(0, 0.5),
                Image = 'rbxassetid://84232453189324',
                BackgroundTransparency = 1,
                Position = UDim2.fromScale(0.91, 0.5),
                Size = UDim2.fromOffset(8, 8),
                BorderSizePixel = 0,
                Parent = box_header,
            })

            local option_list = create('ScrollingFrame', {
                Name = 'Options',
                Active = true,
                ScrollBarImageTransparency = 1,
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollBarThickness = 0,
                Size = UDim2.fromOffset(207, 0),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                CanvasSize = UDim2.new(0, 0, 0, 0),
                Parent = box,
            }, {
                create('UIListLayout', { SortOrder = Enum.SortOrder.LayoutOrder }),
                create('UIPadding', {
                    PaddingLeft = UDim.new(0, 10),
                }),
            })

            local function option_name(option)
                return (typeof(option) == 'string' and option) or tostring(option.Name)
            end

            local function refresh_highlight()
                for _, object in option_list:GetChildren() do
                    if object.Name ~= 'Option' then
                        continue
                    end
                    if table.find(DropdownManager._selected, object.Text) then
                        object.TextTransparency = 0.2
                    else
                        object.TextTransparency = 0.6
                    end
                end
            end

            local function commit()
                current_option.Text = table.concat(DropdownManager._selected, ', ')
                refresh_highlight()
                if element_settings.flag then
                    if element_settings.multi_dropdown then
                        Library:set_flag(element_settings.flag, table.clone(DropdownManager._selected))
                    else
                        Library:set_flag(element_settings.flag, DropdownManager._selected[1])
                    end
                end
            end

            function DropdownManager:update(option)
                local name = option_name(option)
                if element_settings.multi_dropdown then
                    if table.find(self._selected, name) then
                        Library:remove_table_value(self._selected, name)
                    else
                        table.insert(self._selected, name)
                    end
                else
                    self._selected = { name }
                end
                commit()
                if element_settings.callback then
                    element_settings.callback(option)
                end
            end

            function DropdownManager:set_value(value)
                if typeof(value) == 'table' then
                    self._selected = table.clone(value)
                else
                    self._selected = { option_name(value) }
                end
                commit()
            end

            function DropdownManager:unfold_settings()
                self._state = not self._state
                if self._state then
                    ModuleManager._multiplier += self._size
                    tween(arrow, { Rotation = 180 }, 0.5)
                    tween(dropdown, { Size = UDim2.fromOffset(207, 39 + self._size) }, 0.5)
                    tween(box, { Size = UDim2.fromOffset(207, 22 + self._size) }, 0.5)
                else
                    ModuleManager._multiplier -= self._size
                    tween(arrow, { Rotation = 0 }, 0.5)
                    tween(dropdown, { Size = UDim2.fromOffset(207, 39) }, 0.5)
                    tween(box, { Size = UDim2.fromOffset(207, 22) }, 0.5)
                end
                ModuleManager:_refresh(true)
            end

            local function build_options(option_values)
                for _, object in option_list:GetChildren() do
                    if object.Name == 'Option' then
                        object:Destroy()
                    end
                end
                DropdownManager._size = 3
                local maximum_options = element_settings.maximum_options or 6
                for index, value in option_values do
                    local option_button = create('TextButton', {
                        Name = 'Option',
                        FontFace = font(Enum.FontWeight.SemiBold),
                        Active = false,
                        TextTransparency = 0.6,
                        TextSize = 10,
                        Size = UDim2.fromOffset(186, 16),
                        TextColor3 = Theme.Text,
                        Text = option_name(value),
                        AutoButtonColor = false,
                        BackgroundTransparency = 1,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Selectable = false,
                        BorderSizePixel = 0,
                        LayoutOrder = index,
                        Parent = option_list,
                    }, {
                        create('UIGradient', {
                            Transparency = NumberSequence.new({
                                NumberSequenceKeypoint.new(0, 0),
                                NumberSequenceKeypoint.new(0.704, 0),
                                NumberSequenceKeypoint.new(0.872, 0.363),
                                NumberSequenceKeypoint.new(1, 1),
                            }),
                        }),
                    })
                    option_button.MouseButton1Click:Connect(function()
                        DropdownManager:update(value)
                    end)
                    if index <= maximum_options then
                        DropdownManager._size += 16
                    end
                end
                option_list.Size = UDim2.fromOffset(207, DropdownManager._size)
            end

            function DropdownManager:set_options(option_values)
                local was_open = self._state
                if was_open then
                    self:unfold_settings()
                end
                element_settings.options = option_values
                build_options(option_values)
                for index = #self._selected, 1, -1 do
                    local still_exists = false
                    for _, value in option_values do
                        if option_name(value) == self._selected[index] then
                            still_exists = true
                            break
                        end
                    end
                    if not still_exists then
                        table.remove(self._selected, index)
                    end
                end
                commit()
            end
            DropdownManager.New = DropdownManager.set_options

            build_options(element_settings.options or {})

            -- Restore saved selection
            local saved = element_settings.flag and Library._config._flags[element_settings.flag]
            if typeof(saved) == 'table' and element_settings.multi_dropdown then
                DropdownManager._selected = table.clone(saved)
                commit()
            elseif typeof(saved) == 'string' then
                DropdownManager._selected = { saved }
                commit()
            elseif element_settings.options and element_settings.options[1] and not element_settings.multi_dropdown then
                DropdownManager:update(element_settings.options[1])
            end

            dropdown.MouseButton1Click:Connect(function()
                DropdownManager:unfold_settings()
            end)
            return DropdownManager
        end

        function ModuleManager:create_button(element_settings)
            element_settings = element_settings or {}
            local ButtonManager = {}
            self:_grow(23)

            local button = create('TextButton', {
                Name = 'Button',
                FontFace = font(Enum.FontWeight.SemiBold),
                TextSize = 11,
                Size = UDim2.fromOffset(207, 18),
                BackgroundColor3 = Theme.Element,
                BackgroundTransparency = 0.1,
                TextColor3 = Color3.fromRGB(210, 210, 210),
                TextTransparency = 0.2,
                Text = element_settings.title or 'Button',
                AutoButtonColor = false,
                BorderSizePixel = 0,
                LayoutOrder = next_order(),
                Parent = options,
            }, {
                create('UICorner', { CornerRadius = UDim.new(0, 4) }),
                create('UIStroke', {
                    Color = Theme.Stroke,
                    Transparency = 0.5,
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                }),
            })

            button.MouseEnter:Connect(function()
                tween(button, { BackgroundColor3 = Theme.ElementHover }, 0.3)
            end)
            button.MouseLeave:Connect(function()
                tween(button, { BackgroundColor3 = Theme.Element }, 0.3)
            end)
            button.MouseButton1Click:Connect(function()
                tween(button, { BackgroundTransparency = 0.5 }, 0.1)
                task.delay(0.1, function()
                    tween(button, { BackgroundTransparency = 0.1 }, 0.2)
                end)
                if element_settings.callback then
                    element_settings.callback()
                end
            end)

            function ButtonManager:set_title(title)
                button.Text = title
            end
            return ButtonManager
        end

        function ModuleManager:create_keybind(element_settings)
            element_settings = element_settings or {}
            local KeybindManager = { _key = nil }
            self:_grow(20)

            local row = create('Frame', {
                Name = 'KeybindRow',
                Size = UDim2.fromOffset(207, 15),
                BackgroundTransparency = 1,
                LayoutOrder = next_order(),
                Parent = options,
            })

            create('TextLabel', {
                FontFace = font(Enum.FontWeight.SemiBold),
                TextSize = 11,
                TextColor3 = Theme.Text,
                TextTransparency = 0.2,
                Text = element_settings.title or 'Keybind',
                Size = UDim2.fromOffset(160, 13),
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.fromScale(0, 0.5),
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row,
            })

            local key_button = create('TextButton', {
                Name = 'KeyButton',
                FontFace = font(Enum.FontWeight.SemiBold),
                TextSize = 10,
                TextColor3 = Theme.AccentText,
                Text = '...',
                AutoButtonColor = false,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.fromScale(1, 0.5),
                Size = UDim2.fromOffset(33, 15),
                BackgroundColor3 = Theme.Accent,
                BackgroundTransparency = 0.7,
                BorderSizePixel = 0,
                Parent = row,
            }, {
                create('UICorner', { CornerRadius = UDim.new(0, 3) }),
            })
            register_accent(key_button, { 'BackgroundColor3' })

            local function scale_button()
                local width = text_width(key_button.Text, 10)
                key_button.Size = UDim2.fromOffset(math.max(width + 10, 25), 15)
            end

            local function apply_key(key_name)
                KeybindManager._key = key_name
                key_button.Text = key_name or '...'
                scale_button()
                if element_settings.flag then
                    Library._config._keybinds[element_settings.flag] = key_name and ('Enum.KeyCode.' .. key_name) or nil
                    Config:save(Library._config_name, Library._config)
                end
                if element_settings.changed_callback then
                    element_settings.changed_callback(key_name)
                end
            end

            key_button.MouseButton1Click:Connect(function()
                if Library._choosing_keybind then
                    return
                end
                Library._choosing_keybind = true
                key_button.Text = '...'
                local choose_connection
                choose_connection = UserInputService.InputBegan:Connect(function(input, process)
                    if process then
                        return
                    end
                    if input.UserInputType == Enum.UserInputType.MouseButton3 then
                        choose_connection:Disconnect()
                        Library._choosing_keybind = false
                        apply_key(nil)
                        return
                    end
                    if input.UserInputType ~= Enum.UserInputType.Keyboard then
                        return
                    end
                    if input.KeyCode == Enum.KeyCode.Unknown then
                        return
                    end
                    choose_connection:Disconnect()
                    Library._choosing_keybind = false
                    if input.KeyCode == Enum.KeyCode.Backspace then
                        apply_key(nil)
                        return
                    end
                    apply_key(input.KeyCode.Name)
                end)
            end)

            -- Fire the callback while the key is pressed
            Connections:set('keybind_element_' .. tostring(element_settings.flag or element_settings.title), UserInputService.InputBegan:Connect(function(input, process)
                if process or not KeybindManager._key then
                    return
                end
                if input.UserInputType ~= Enum.UserInputType.Keyboard then
                    return
                end
                if input.KeyCode.Name == KeybindManager._key and element_settings.callback then
                    element_settings.callback(KeybindManager._key)
                end
            end))

            -- Restore
            if element_settings.flag and Library._config._keybinds[element_settings.flag] then
                local key_name = keycode_name(Library._config._keybinds[element_settings.flag])
                KeybindManager._key = key_name
                key_button.Text = key_name
                scale_button()
            elseif element_settings.default then
                apply_key(typeof(element_settings.default) == 'EnumItem' and element_settings.default.Name or tostring(element_settings.default))
            end

            function KeybindManager:set_key(key_name)
                apply_key(key_name)
            end
            return KeybindManager
        end

        function ModuleManager:create_colorpicker(element_settings)
            element_settings = element_settings or {}
            local EXPAND_SIZE = 96
            local ColorpickerManager = {
                _state = false,
                _hue = 0.6,
                _saturation = 0.5,
                _value = 1,
            }
            self:_grow(22)

            local picker = create('TextButton', {
                Name = 'Colorpicker',
                Text = '',
                AutoButtonColor = false,
                ClipsDescendants = true,
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(207, 17),
                BorderSizePixel = 0,
                LayoutOrder = next_order(),
                Parent = options,
            })

            create('TextLabel', {
                FontFace = font(Enum.FontWeight.SemiBold),
                TextSize = 11,
                TextColor3 = Theme.Text,
                TextTransparency = 0.2,
                Text = element_settings.title or 'Color',
                Size = UDim2.fromOffset(160, 13),
                Position = UDim2.fromOffset(0, 2),
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = picker,
            })

            local swatch = create('Frame', {
                Name = 'Swatch',
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, 0, 0, 1),
                Size = UDim2.fromOffset(25, 14),
                BorderSizePixel = 0,
                BackgroundColor3 = Color3.fromHSV(0.6, 0.5, 1),
                Parent = picker,
            }, {
                create('UICorner', { CornerRadius = UDim.new(0, 4) }),
                create('UIStroke', {
                    Color = Theme.Stroke,
                    Transparency = 0.3,
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                }),
            })

            local sv_box = create('Frame', {
                Name = 'SVBox',
                Position = UDim2.fromOffset(0, 22),
                Size = UDim2.fromOffset(207, 62),
                BorderSizePixel = 0,
                BackgroundColor3 = Color3.fromHSV(0.6, 1, 1),
                Parent = picker,
            }, {
                create('UICorner', { CornerRadius = UDim.new(0, 4) }),
            })

            create('Frame', {
                Name = 'SatOverlay',
                Size = UDim2.fromScale(1, 1),
                BorderSizePixel = 0,
                BackgroundColor3 = Color3.new(1, 1, 1),
                Parent = sv_box,
            }, {
                create('UICorner', { CornerRadius = UDim.new(0, 4) }),
                create('UIGradient', {
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0),
                        NumberSequenceKeypoint.new(1, 1),
                    }),
                }),
            })

            create('Frame', {
                Name = 'ValOverlay',
                Size = UDim2.fromScale(1, 1),
                BorderSizePixel = 0,
                BackgroundColor3 = Color3.new(0, 0, 0),
                Parent = sv_box,
            }, {
                create('UICorner', { CornerRadius = UDim.new(0, 4) }),
                create('UIGradient', {
                    Rotation = 90,
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 1),
                        NumberSequenceKeypoint.new(1, 0),
                    }),
                }),
            })

            local sv_cursor = create('Frame', {
                Name = 'Cursor',
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0),
                Size = UDim2.fromOffset(6, 6),
                BorderSizePixel = 0,
                BackgroundColor3 = Color3.new(1, 1, 1),
                ZIndex = 3,
                Parent = sv_box,
            }, {
                create('UICorner', { CornerRadius = UDim.new(1, 0) }),
                create('UIStroke', {
                    Color = Color3.new(0, 0, 0),
                    Transparency = 0.5,
                }),
            })

            local hue_bar = create('Frame', {
                Name = 'HueBar',
                Position = UDim2.fromOffset(0, 92),
                Size = UDim2.fromOffset(207, 8),
                BorderSizePixel = 0,
                BackgroundColor3 = Color3.new(1, 1, 1),
                Parent = picker,
            }, {
                create('UICorner', { CornerRadius = UDim.new(1, 0) }),
                create('UIGradient', {
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
                        ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
                        ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
                        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
                        ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
                        ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
                    }),
                }),
            })

            local hue_cursor = create('Frame', {
                Name = 'Cursor',
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.6, 0.5),
                Size = UDim2.fromOffset(3, 12),
                BorderSizePixel = 0,
                BackgroundColor3 = Color3.new(1, 1, 1),
                ZIndex = 3,
                Parent = hue_bar,
            }, {
                create('UICorner', { CornerRadius = UDim.new(1, 0) }),
                create('UIStroke', {
                    Color = Color3.new(0, 0, 0),
                    Transparency = 0.5,
                }),
            })

            local function current_color()
                return Color3.fromHSV(ColorpickerManager._hue, ColorpickerManager._saturation, ColorpickerManager._value)
            end

            local function refresh_visuals()
                local color = current_color()
                swatch.BackgroundColor3 = color
                sv_box.BackgroundColor3 = Color3.fromHSV(ColorpickerManager._hue, 1, 1)
                sv_cursor.Position = UDim2.fromScale(ColorpickerManager._saturation, 1 - ColorpickerManager._value)
                hue_cursor.Position = UDim2.fromScale(ColorpickerManager._hue, 0.5)
            end

            local function apply(save)
                refresh_visuals()
                local color = current_color()
                if element_settings.flag then
                    Library:set_flag(element_settings.flag, {
                        R = math.floor(color.R * 255 + 0.5),
                        G = math.floor(color.G * 255 + 0.5),
                        B = math.floor(color.B * 255 + 0.5),
                    }, not save)
                end
                if element_settings.callback then
                    element_settings.callback(color)
                end
            end

            function ColorpickerManager:set_color(color, skip_save)
                local hue, saturation, value = color:ToHSV()
                self._hue, self._saturation, self._value = hue, saturation, value
                apply(not skip_save)
            end

            function ColorpickerManager:get_color()
                return current_color()
            end

            function ColorpickerManager:unfold_settings()
                self._state = not self._state
                if self._state then
                    ModuleManager._multiplier += EXPAND_SIZE
                    tween(picker, { Size = UDim2.fromOffset(207, 17 + EXPAND_SIZE) }, 0.5)
                else
                    ModuleManager._multiplier -= EXPAND_SIZE
                    tween(picker, { Size = UDim2.fromOffset(207, 17) }, 0.5)
                end
                ModuleManager:_refresh(true)
            end

            local function begin_sv_drag()
                local function update_sv()
                    local absolute_position = sv_box.AbsolutePosition
                    local absolute_size = sv_box.AbsoluteSize
                    ColorpickerManager._saturation = math.clamp((Mouse.X - absolute_position.X) / absolute_size.X, 0, 1)
                    ColorpickerManager._value = 1 - math.clamp((Mouse.Y - absolute_position.Y) / absolute_size.Y, 0, 1)
                    apply(false)
                end
                update_sv()
                Connections:set('colorpicker_sv_drag', Mouse.Move:Connect(update_sv))
                Connections:set('colorpicker_sv_end', UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
                        return
                    end
                    Connections:disconnect('colorpicker_sv_drag')
                    Connections:disconnect('colorpicker_sv_end')
                    apply(true)
                end))
            end

            local function begin_hue_drag()
                local function update_hue()
                    local absolute_position = hue_bar.AbsolutePosition
                    local absolute_size = hue_bar.AbsoluteSize
                    ColorpickerManager._hue = math.clamp((Mouse.X - absolute_position.X) / absolute_size.X, 0, 1)
                    apply(false)
                end
                update_hue()
                Connections:set('colorpicker_hue_drag', Mouse.Move:Connect(update_hue))
                Connections:set('colorpicker_hue_end', UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
                        return
                    end
                    Connections:disconnect('colorpicker_hue_drag')
                    Connections:disconnect('colorpicker_hue_end')
                    apply(true)
                end))
            end

            sv_box.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    begin_sv_drag()
                end
            end)
            hue_bar.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    begin_hue_drag()
                end
            end)
            picker.MouseButton1Click:Connect(function()
                ColorpickerManager:unfold_settings()
            end)

            -- Restore saved color, or apply default
            local saved = element_settings.flag and Library._config._flags[element_settings.flag]
            if typeof(saved) == 'table' and saved.R then
                ColorpickerManager:set_color(Color3.fromRGB(saved.R, saved.G, saved.B), true)
            elseif element_settings.default then
                ColorpickerManager:set_color(element_settings.default, true)
            else
                refresh_visuals()
            end

            return ColorpickerManager
        end

        function ModuleManager:create_feature(element_settings)
            element_settings = element_settings or {}
            local checked = false
            self:_grow(20)

            local feature_container = create('Frame', {
                Size = UDim2.fromOffset(207, 16),
                BackgroundTransparency = 1,
                LayoutOrder = next_order(),
                Parent = options,
            }, {
                create('UIListLayout', {
                    FillDirection = Enum.FillDirection.Horizontal,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }),
            })

            local feature_button = create('TextButton', {
                FontFace = font(Enum.FontWeight.SemiBold),
                TextSize = 11,
                Size = UDim2.new(1, -35, 0, 16),
                BackgroundColor3 = Theme.Element,
                TextColor3 = Color3.fromRGB(210, 210, 210),
                Text = ' ' .. (element_settings.title or 'Feature'),
                AutoButtonColor = false,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTransparency = 0.2,
                Parent = feature_container,
            })

            local right_container = create('Frame', {
                Size = UDim2.fromOffset(45, 16),
                BackgroundTransparency = 1,
                Parent = feature_container,
            }, {
                create('UIListLayout', {
                    Padding = UDim.new(0.1, 0),
                    FillDirection = Enum.FillDirection.Horizontal,
                    HorizontalAlignment = Enum.HorizontalAlignment.Right,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }),
            })

            local keybind_box = create('TextLabel', {
                FontFace = font(Enum.FontWeight.SemiBold),
                Size = UDim2.fromOffset(15, 15),
                BackgroundColor3 = Theme.Accent,
                TextColor3 = Theme.Text,
                TextSize = 11,
                BackgroundTransparency = 1,
                LayoutOrder = 2,
                Parent = right_container,
            }, {
                create('UICorner', { CornerRadius = UDim.new(0, 3) }),
                create('UIStroke', {
                    Color = Theme.Accent,
                    Thickness = 1,
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                }),
            })
            register_accent(keybind_box, { 'BackgroundColor3' })

            local keybind_button = create('TextButton', {
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                TextTransparency = 1,
                Text = '',
                Parent = keybind_box,
            })

            if not Library._config._flags[element_settings.flag] then
                Library._config._flags[element_settings.flag] = {
                    checked = false,
                    BIND = element_settings.default or 'Unknown',
                }
            end
            local flag_data = Library._config._flags[element_settings.flag]
            checked = flag_data.checked
            keybind_box.Text = flag_data.BIND == 'Unknown' and '...' or flag_data.BIND

            local activate
            if not element_settings.disablecheck then
                local check_button = create('TextButton', {
                    Size = UDim2.fromOffset(15, 15),
                    BackgroundColor3 = checked and Theme.Accent or Theme.Element,
                    Text = '',
                    LayoutOrder = 1,
                    Parent = right_container,
                }, {
                    create('UIStroke', {
                        Color = Theme.Accent,
                        Thickness = 1,
                        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                    }),
                    create('UICorner', { CornerRadius = UDim.new(0, 3) }),
                })
                local function toggle_state()
                    checked = not checked
                    check_button.BackgroundColor3 = checked and Theme.Accent or Theme.Element
                    flag_data.checked = checked
                    Config:save(Library._config_name, Library._config)
                    if element_settings.callback then
                        element_settings.callback(checked)
                    end
                end
                activate = toggle_state
                check_button.MouseButton1Click:Connect(toggle_state)
            else
                activate = function()
                    if element_settings.button_callback then
                        element_settings.button_callback()
                    end
                end
            end

            keybind_button.MouseButton1Click:Connect(function()
                keybind_box.Text = '...'
                local input_connection
                input_connection = UserInputService.InputBegan:Connect(function(input, process)
                    if process then
                        return
                    end
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        local new_key = input.KeyCode.Name
                        flag_data.BIND = new_key
                        if new_key ~= 'Unknown' then
                            keybind_box.Text = new_key
                        end
                        Config:save(Library._config_name, Library._config)
                        input_connection:Disconnect()
                    elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
                        flag_data.BIND = 'Unknown'
                        keybind_box.Text = '...'
                        Config:save(Library._config_name, Library._config)
                        input_connection:Disconnect()
                    end
                end)
                Connections:set('keybind_input_' .. tostring(element_settings.flag), input_connection)
            end)

            Connections:set('keybind_press_' .. tostring(element_settings.flag), UserInputService.InputBegan:Connect(function(input, process)
                if process then
                    return
                end
                if input.UserInputType ~= Enum.UserInputType.Keyboard then
                    return
                end
                if input.KeyCode.Name == flag_data.BIND then
                    activate()
                end
            end))

            feature_button.MouseButton1Click:Connect(function()
                if element_settings.button_callback then
                    element_settings.button_callback()
                end
            end)

            if not element_settings.disablecheck and element_settings.callback then
                element_settings.callback(checked)
            end
            return feature_container
        end

        -- Friendlier alias
        ModuleManager.create_toggle = ModuleManager.create_checkbox

        return ModuleManager
    end

    return TabManager
end

return Library
