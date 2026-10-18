local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local CONFIG = {
    IntroText = "ynth",
    IntroFont = Enum.Font.Michroma,
    IntroTextSize = 30,
    ToggleKey = Enum.KeyCode.RightShift,
    CustomSounds = {},
}

local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end

local function tw(obj, info, props)
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

local function corner(parent, r)
    return new("UICorner", {CornerRadius = UDim.new(0, r)}, parent)
end

local function stroke(parent, color, thickness, transparency)
    return new("UIStroke", {Color = color, Thickness = thickness, Transparency = transparency or 0}, parent)
end

local SR, TAU = 32000, math.pi * 2
local exp, sin, floor, min = math.exp, math.sin, math.floor, math.min
local rng = Random.new(7)

local function gen(d, fn)
    local out = {}
    for i = 1, floor(SR * d) do out[i] = fn((i - 1) / SR) end
    return out
end

local function lp(x, fc)
    local a, s, y = exp(-TAU * fc / SR), 0, {}
    for i = 1, #x do
        s = (1 - a) * x[i] + a * s
        y[i] = s
    end
    return y
end

local function hp(x, fc)
    local l = lp(x, fc)
    for i = 1, #x do l[i] = x[i] - l[i] end
    return l
end

local function add(a, b)
    for i = 1, #a do a[i] = a[i] + (b[i] or 0) end
    return a
end

local function mix(d, parts)
    return gen(d, function(t)
        local v = 0
        for _, p in ipairs(parts) do v = v + p[1](t) * p[2] end
        return v
    end)
end

local function burst(d, fc, tau, gain, low)
    local n = gen(d, function() return (rng:NextNumber() * 2 - 1) * 1.73 end)
    n = low and lp(n, fc) or hp(n, fc)
    for i = 1, #n do n[i] = n[i] * exp(-((i - 1) / SR) / tau) * gain end
    return n
end

local function tone(f, tau, att)
    att = att or 0.001
    return function(t) return sin(TAU * f * t) * exp(-t / tau) * min(1, t / att) end
end

local function chirp(f0, f1, tau)
    return function(t)
        local ph = f0 * t + (f1 - f0) * (t < 0.04 and t * t / 0.08 or t - 0.02)
        return sin(TAU * ph) * exp(-t / tau) * min(1, t / 0.001)
    end
end

local function bell(f, tau)
    local a, b, c = tone(f, tau, 0.004), tone(f * 2.01, tau * 0.6, 0.004), tone(f * 3.98, tau * 0.3, 0.004)
    return function(t) return a(t) + 0.35 * b(t) + 0.12 * c(t) end
end

local function at(fn, delay, gain)
    return function(t) return t >= delay and fn(t - delay) * gain or 0 end
end

local function u16(v) return string.char(v % 256, floor(v / 256)) end
local function u32(v) return string.char(v % 256, floor(v / 256) % 256, floor(v / 65536) % 256, floor(v / 16777216) % 256) end

local function wav(x)
    local n, fi, fo, peak = #x, floor(SR * 0.003), floor(SR * 0.008), 1e-9
    for i = 1, n do
        if i <= fi then x[i] = x[i] * (i - 1) / fi end
        if i > n - fo then x[i] = x[i] * (n - i) / fo end
        peak = math.max(peak, math.abs(x[i]))
    end
    local parts = {}
    for i = 1, n do
        local s = floor(x[i] / peak * 0.85 * 32767 + 0.5)
        if s < 0 then s = s + 65536 end
        parts[i] = u16(s)
    end
    local data = table.concat(parts)
    return "RIFF" .. u32(36 + #data) .. "WAVEfmt " .. u32(16) .. u16(1) .. u16(1) .. u32(SR) .. u32(SR * 2) .. u16(2) .. u16(16) .. "data" .. u32(#data) .. data
end

local SOUND_DEFS = {
    Click = function()
        local x = mix(0.09, {{tone(1850, 0.005), 0.7}, {tone(920, 0.009), 0.45}, {tone(3700, 0.002), 0.2}})
        return lp(add(x, burst(0.09, 2500, 0.0009, 0.5)), 9000)
    end,
    ToggleOn = function()
        local x = mix(0.12, {{chirp(900, 1500, 0.022), 0.8}, {tone(3000, 0.004), 0.15}})
        return lp(add(x, burst(0.12, 3000, 0.0008, 0.35)), 10000)
    end,
    ToggleOff = function()
        local x = mix(0.12, {{chirp(1300, 700, 0.024), 0.8}, {tone(1500, 0.004), 0.12}})
        return lp(add(x, burst(0.12, 2500, 0.0008, 0.3)), 8000)
    end,
    Tab = function()
        local x = mix(0.12, {{tone(480, 0.02), 0.8}, {tone(240, 0.035), 0.6}, {tone(960, 0.008), 0.25}})
        return lp(add(x, burst(0.12, 3500, 0.003, 0.6, true)), 7000)
    end,
    Open = function()
        return mix(0.9, {{bell(523.25, 0.16), 1}, {at(bell(784, 0.14), 0.07, 1), 0.8}, {at(bell(1046.5, 0.12), 0.14, 1), 0.5}})
    end,
    Close = function()
        return mix(0.7, {{bell(784, 0.11), 0.8}, {at(bell(523.25, 0.13), 0.07, 1), 1}})
    end,
    Intro = function()
        local bells = {
            at(bell(220, 0.45), 0, 0.5), at(bell(329.63, 0.45), 0.05, 0.5),
            at(bell(440, 0.45), 0.1, 0.45), at(bell(659.25, 0.45), 0.18, 0.35),
        }
        local function src(t)
            if t < 0 or t >= 1.8 then return 0 end
            local v = sin(TAU * (45 * t + 3.6 * (1 - exp(-t / 0.06)))) * exp(-t / 0.28) * min(1, t / 0.004) * 0.9
            for _, b in ipairs(bells) do v = v + b(t) end
            return v
        end
        return gen(2.31, function(t)
            local v = 0
            for r = 0, 3 do v = v + 0.35 ^ r * src(t - 0.17 * r) end
            return v
        end)
    end,
    Slide = function()
        return gen(0.6, function(t)
            local ph = TAU * (330 * t + 193.25 * (t - 0.2 * (1 - exp(-t / 0.2))))
            return (sin(ph) + 0.4 * sin(1.5 * ph)) * sin(math.pi * min(1, t / 0.6)) ^ 2 * 0.5
        end)
    end,
}

local SOUND_VOL = {
    Intro = 0.75, Slide = 0.35, Open = 0.65, Close = 0.5,
    Click = 0.6, ToggleOn = 0.6, ToggleOff = 0.6, Tab = 0.65,
}
local SOUND_VARY = {Click = true, ToggleOn = true, ToggleOff = true, Tab = true}
local soundIds = {}

local function prepareSounds()
    local getAsset = getcustomasset or getsynasset
    if writefile and getAsset then
        for _, name in ipairs({"Intro", "Slide", "Open", "Close", "Click", "ToggleOn", "ToggleOff", "Tab"}) do
            pcall(function()
                local path = "zynth_" .. name .. ".wav"
                writefile(path, wav(SOUND_DEFS[name]()))
                soundIds[name] = getAsset(path)
            end)
            task.wait()
        end
    end
    for name, id in pairs(CONFIG.CustomSounds) do soundIds[name] = id end
end

local function play(name, speedMul)
    local id = soundIds[name]
    if not id then return end
    pcall(function()
        local speed = speedMul or 1
        if SOUND_VARY[name] then speed = speed * (0.96 + math.random() * 0.09) end
        local s = new("Sound", {SoundId = id, Volume = SOUND_VOL[name] or 0.6, PlaybackSpeed = speed}, SoundService)
        s:Play()
        Debris:AddItem(s, 6)
    end)
end

local ZW, ZH, SL = 403, 446, -0.714
local Z_COLOR = Color3.fromRGB(254, 82, 70)
local ZPIECES = {
    {48, 120, 31, 0, 352, SL},
    {120, 446, 318, SL, 352, SL},
    {0, 318, 366, SL, 402, SL},
    {318, 396, 366, SL, 340, 0},
}

local function buildZ(parent, height)
    local width = floor(height * ZW / ZH + 0.5)
    local g = new("CanvasGroup", {
        Name = "ZLogo", Size = UDim2.new(0, width, 0, height),
        BackgroundTransparency = 1, BorderSizePixel = 0,
    }, parent)
    for _, p in ipairs(ZPIECES) do
        local y = p[1]
        while y < p[2] do
            local h = min(4, p[2] - y)
            local ym = y + h / 2
            local x1, x2 = p[3] + p[4] * ym, p[5] + p[6] * ym
            new("Frame", {
                BorderSizePixel = 0, BackgroundColor3 = Z_COLOR,
                Position = UDim2.new(x1 / ZW, 0, y / ZH, 0),
                Size = UDim2.new((x2 - x1) / ZW, 0, (h + 1.2) / ZH, 0),
            }, g)
            y = y + h
        end
    end
    return g, width
end

local function safeGethui()
    local ok, h = pcall(function() return gethui and gethui() end)
    return ok and h or nil
end

for _, c in ipairs({CoreGui, safeGethui() or CoreGui, LocalPlayer:FindFirstChildOfClass("PlayerGui") or CoreGui}) do
    pcall(function()
        local old = c:FindFirstChild("ZynthUI")
        if old then old:Destroy() end
    end)
end

local ScreenGui = new("ScreenGui", {
    Name = "ZynthUI", ResetOnSpawn = false, IgnoreGuiInset = true,
    DisplayOrder = 999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
pcall(function() if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end end)
if not pcall(function() ScreenGui.Parent = safeGethui() or CoreGui end) or not ScreenGui.Parent then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local THEME = {
    Background = Color3.fromRGB(12, 9, 11),
    CardBg = Color3.fromRGB(18, 13, 16),
    SidebarActive = Color3.fromRGB(27, 16, 19),
    Border = Color3.fromRGB(36, 24, 28),
    BorderActive = Color3.fromRGB(90, 36, 42),
    Accent = Color3.fromRGB(246, 92, 82),
    TextPrimary = Color3.fromRGB(235, 235, 235),
    TextMuted = Color3.fromRGB(120, 110, 115),
    TextDim = Color3.fromRGB(72, 64, 68),
    BadgeBg = Color3.fromRGB(25, 18, 22),
    ToggleOff = Color3.fromRGB(36, 28, 32),
    KnobOff = Color3.fromRGB(78, 68, 73),
    KnobOn = Color3.fromRGB(255, 255, 255),
}

local ICONS = {
    Search = "rbxassetid://7733911828",
    More = "rbxassetid://7734021300",
    Menu = "rbxassetid://7733993211",
    Combat = "rbxassetid://7734053426",
    Movement = "rbxassetid://7733799901",
    Visuals = "rbxassetid://7733774602",
    Player = "rbxassetid://7733954760",
    Misc = "rbxassetid://7734056411",
    Presets = "rbxassetid://7733964719",
    AutoBuy = "rbxassetid://7733942651",
    Accounts = "rbxassetid://7733765307",
}

local TWEEN_FAST = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CENTER = Vector2.new(0.5, 0.5)

local function makeDraggable(handle, target, onTap)
    local dragging, dragInput, dragStart, startPos, moved = false, nil, nil, nil, false

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, moved = true, false
            dragStart, startPos = input.Position, target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if not moved and onTap then onTap() end
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local d = input.Position - dragStart
            if d.Magnitude > 6 then moved = true end
            if moved then
                target.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + d.X,
                    startPos.Y.Scale, startPos.Y.Offset + d.Y
                )
            end
        end
    end)
end

local Holder = new("Frame", {
    Name = "Holder", Size = UDim2.new(0, 790, 0, 490), AnchorPoint = CENTER,
    Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundTransparency = 1, Visible = false,
}, ScreenGui)

local FitScale = new("UIScale", {}, Holder)

local function updateFit()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    if vp.X < 100 or vp.Y < 100 then return end
    FitScale.Scale = math.max(math.min(1, (vp.X - 20) / 790, (vp.Y - 20) / 490), 0.35)
end

do
    local conn
    local function hook()
        if conn then conn:Disconnect() end
        local cam = workspace.CurrentCamera
        if cam then conn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateFit) end
        updateFit()
    end
    hook()
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hook)
end

local CLOSED_SIZE, OPEN_SIZE = UDim2.new(0, 6, 0, 6), UDim2.new(1, 0, 1, 0)

local Main = new("Frame", {
    Name = "MainFrame", Size = CLOSED_SIZE, AnchorPoint = CENTER,
    Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundColor3 = THEME.Background,
    BorderSizePixel = 0, ClipsDescendants = true,
}, Holder)
corner(Main, 12)
stroke(Main, THEME.Border, 1.2)

local Inner = new("Frame", {
    Name = "Inner", Size = UDim2.new(0, 790, 0, 490), AnchorPoint = CENTER,
    Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundTransparency = 1,
}, Main)

local TopBar = new("Frame", {Name = "TopBar", Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1}, Inner)
makeDraggable(TopBar, Holder)

buildZ(TopBar, 34).Position = UDim2.new(0, 62, 0, 11)

local SearchBox = new("Frame", {
    Size = UDim2.new(0, 250, 0, 26), Position = UDim2.new(0, 185, 0, 15),
    BackgroundColor3 = THEME.CardBg, BorderSizePixel = 0,
}, TopBar)
corner(SearchBox, 6)
stroke(SearchBox, THEME.Border, 0.8)

new("ImageLabel", {
    Size = UDim2.new(0, 13, 0, 13), Position = UDim2.new(0, 9, 0.5, -6.5),
    BackgroundTransparency = 1, Image = ICONS.Search, ImageColor3 = THEME.TextMuted,
}, SearchBox)

local SearchInput = new("TextBox", {
    PlaceholderText = "Search something", PlaceholderColor3 = THEME.TextMuted, Text = "",
    ClearTextOnFocus = false, TextColor3 = THEME.TextPrimary, Font = Enum.Font.Gotham,
    TextSize = 11, Position = UDim2.new(0, 30, 0, 0), Size = UDim2.new(1, -36, 1, 0),
    BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
}, SearchBox)

local MenuBtn = new("ImageButton", {
    Size = UDim2.new(0, 17, 0, 17), Position = UDim2.new(1, -32, 0.5, -8.5),
    BackgroundTransparency = 1, Image = ICONS.Menu, ImageColor3 = THEME.TextMuted,
}, TopBar)

MenuBtn.MouseEnter:Connect(function() tw(MenuBtn, TWEEN_FAST, {ImageColor3 = THEME.TextPrimary}) end)
MenuBtn.MouseLeave:Connect(function() tw(MenuBtn, TWEEN_FAST, {ImageColor3 = THEME.TextMuted}) end)

local Sidebar = new("Frame", {
    Name = "Sidebar", Size = UDim2.new(0, 155, 1, -58), Position = UDim2.new(0, 14, 0, 54),
    BackgroundTransparency = 1,
}, Inner)
new("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, Sidebar)

local activeTab

local function addCategory(name, order)
    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20), LayoutOrder = order, BackgroundTransparency = 1,
        Text = "   " .. name:upper(), Font = Enum.Font.GothamBold, TextSize = 9,
        TextColor3 = THEME.TextDim, TextXAlignment = Enum.TextXAlignment.Left,
    }, Sidebar)
end

local function addSidebarItem(name, iconId, active, order)
    local btn = new("TextButton", {
        Size = UDim2.new(1, -4, 0, 29), LayoutOrder = order,
        BackgroundColor3 = active and THEME.SidebarActive or THEME.Background,
        BackgroundTransparency = active and 0 or 1, Text = "", AutoButtonColor = false,
    }, Sidebar)
    corner(btn, 6)

    local st = stroke(btn, active and THEME.BorderActive or Color3.new(0, 0, 0), 1, active and 0 or 1)

    local icon = new("ImageLabel", {
        Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(0, 9, 0.5, -7), BackgroundTransparency = 1,
        Image = iconId, ImageColor3 = active and THEME.Accent or THEME.TextMuted,
    }, btn)

    local title = new("TextLabel", {
        Size = UDim2.new(1, -32, 1, 0), Position = UDim2.new(0, 30, 0, 0), BackgroundTransparency = 1,
        Text = name, Font = Enum.Font.GothamMedium, TextSize = 11,
        TextColor3 = active and THEME.TextPrimary or THEME.TextMuted, TextXAlignment = Enum.TextXAlignment.Left,
    }, btn)

    local me = {Btn = btn, Icon = icon, Title = title, Stroke = st}
    if active then activeTab = me end

    btn.MouseEnter:Connect(function()
        if activeTab.Btn ~= btn then
            tw(title, TWEEN_FAST, {TextColor3 = THEME.TextPrimary})
            tw(icon, TWEEN_FAST, {ImageColor3 = THEME.TextPrimary})
        end
    end)
    btn.MouseLeave:Connect(function()
        if activeTab.Btn ~= btn then
            tw(title, TWEEN_FAST, {TextColor3 = THEME.TextMuted})
            tw(icon, TWEEN_FAST, {ImageColor3 = THEME.TextMuted})
        end
    end)

    btn.MouseButton1Click:Connect(function()
        if activeTab.Btn == btn then return end
        play("Tab")
        local old = activeTab
        tw(old.Btn, TWEEN_FAST, {BackgroundTransparency = 1})
        tw(old.Stroke, TWEEN_FAST, {Transparency = 1})
        tw(old.Icon, TWEEN_FAST, {ImageColor3 = THEME.TextMuted})
        tw(old.Title, TWEEN_FAST, {TextColor3 = THEME.TextMuted})
        tw(btn, TWEEN_FAST, {BackgroundTransparency = 0, BackgroundColor3 = THEME.SidebarActive})
        tw(st, TWEEN_FAST, {Transparency = 0, Color = THEME.BorderActive})
        tw(icon, TWEEN_FAST, {ImageColor3 = THEME.Accent})
        tw(title, TWEEN_FAST, {TextColor3 = THEME.TextPrimary})
        activeTab = me
    end)
end

addCategory("Modules", 1)
addSidebarItem("Combat", ICONS.Combat, true, 2)
addSidebarItem("Movement", ICONS.Movement, false, 3)
addSidebarItem("Visuals", ICONS.Visuals, false, 4)
addSidebarItem("Player", ICONS.Player, false, 5)
addSidebarItem("Misc", ICONS.Misc, false, 6)
addCategory("Config", 7)
addSidebarItem("Presets", ICONS.Presets, false, 8)
addSidebarItem("AutoBuy", ICONS.AutoBuy, false, 9)
addSidebarItem("Accounts", ICONS.Accounts, false, 10)

local Content = new("ScrollingFrame", {
    Name = "Content", Position = UDim2.new(0, 181, 0, 60), Size = UDim2.new(1, -195, 1, -74),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
    ScrollBarImageColor3 = THEME.BorderActive, CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
    ElasticBehavior = Enum.ElasticBehavior.Never,
}, Inner)

local function makeColumn(name, pos)
    local col = new("Frame", {
        Name = name, Position = pos, Size = UDim2.new(0.5, -6, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
    }, Content)
    new("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, col)
    return col
end

local Col1 = makeColumn("Col1", UDim2.new(0, 0, 0, 0))
local Col2 = makeColumn("Col2", UDim2.new(0.5, 6, 0, 0))

local rows, cards, rowCount = {}, {}, {}

local function createCard(parent, title, order)
    local card = new("Frame", {
        Name = title, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = THEME.CardBg, BorderSizePixel = 0, LayoutOrder = order,
    }, parent)
    corner(card, 8)
    stroke(card, THEME.Border, 1)
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}, card)
    new("UIPadding", {PaddingBottom = UDim.new(0, 6)}, card)

    local header = new("Frame", {Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = 0}, card)
    new("TextLabel", {
        Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -44, 1, 0), BackgroundTransparency = 1,
        Text = title, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = THEME.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)
    new("ImageLabel", {
        Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(1, -26, 0.5, -7), BackgroundTransparency = 1,
        Image = ICONS.More, ImageColor3 = THEME.TextMuted,
    }, header)

    rowCount[card] = 0
    table.insert(cards, card)
    return card
end

local function addToggle(card, name, desc, default, bind, callback)
    rowCount[card] = rowCount[card] + 1

    local row = new("TextButton", {
        Name = name, Size = UDim2.new(1, 0, 0, desc and 40 or 30), BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false, LayoutOrder = rowCount[card],
    }, card)

    new("TextLabel", {
        BackgroundTransparency = 1, Text = name, Font = Enum.Font.GothamMedium, TextSize = 11,
        TextColor3 = THEME.TextPrimary, TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 12, 0, desc and 5 or 0), Size = UDim2.new(1, -96, 0, desc and 16 or 30),
    }, row)

    if desc then
        new("TextLabel", {
            BackgroundTransparency = 1, Text = desc, Font = Enum.Font.Gotham, TextSize = 9,
            TextColor3 = THEME.TextMuted, TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.new(0, 12, 0, 21), Size = UDim2.new(1, -96, 0, 14),
        }, row)
    end

    local switch = new("Frame", {
        Size = UDim2.new(0, 28, 0, 16), AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0), BackgroundColor3 = THEME.ToggleOff, BorderSizePixel = 0,
    }, row)
    corner(switch, 8)

    local knob = new("Frame", {
        Size = UDim2.new(0, 12, 0, 12), Position = UDim2.new(0, 2, 0.5, -6),
        BackgroundColor3 = THEME.KnobOff, BorderSizePixel = 0,
    }, switch)
    corner(knob, 6)

    if bind then
        local badge = new("Frame", {
            AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 16),
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -48, 0.5, 0),
            BackgroundColor3 = THEME.BadgeBg, BorderSizePixel = 0,
        }, row)
        corner(badge, 4)
        stroke(badge, THEME.Border, 1)
        new("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)}, badge)
        new("TextLabel", {
            AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), BackgroundTransparency = 1,
            Text = bind, Font = Enum.Font.GothamMedium, TextSize = 9, TextColor3 = THEME.TextMuted,
        }, badge)
    end

    local on = default and true or false
    if on then
        switch.BackgroundColor3 = THEME.Accent
        knob.BackgroundColor3 = THEME.KnobOn
        knob.Position = UDim2.new(1, -14, 0.5, -6)
    end

    row.MouseButton1Click:Connect(function()
        on = not on
        play(on and "ToggleOn" or "ToggleOff")
        tw(switch, TWEEN_FAST, {BackgroundColor3 = on and THEME.Accent or THEME.ToggleOff})
        tw(knob, TWEEN_FAST, {
            BackgroundColor3 = on and THEME.KnobOn or THEME.KnobOff,
            Position = on and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6),
        })
        if callback then callback(on) end
    end)

    table.insert(rows, {Name = name:lower(), Frame = row, Card = card})
end

SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
    local query = SearchInput.Text:lower()
    for _, item in ipairs(rows) do
        item.Frame.Visible = query == "" or string.find(item.Name, query, 1, true) ~= nil
    end
    for _, card in ipairs(cards) do
        local any = false
        for _, item in ipairs(rows) do
            if item.Card == card and item.Frame.Visible then any = true break end
        end
        card.Visible = any
    end
end)

local fighting = createCard(Col1, "Fighting", 1)
addToggle(fighting, "Attack Aura", nil, false, nil)
addToggle(fighting, "No Velocity", nil, false, nil)
addToggle(fighting, "Trigger Bot", nil, false, nil)
addToggle(fighting, "Aim Assist", nil, false, "F1")
addToggle(fighting, "Auto Explosion", nil, false, nil)

local base = createCard(Col1, "Base", 2)
addToggle(base, "Auto Swap", nil, true, nil)
addToggle(base, "Item Release", nil, false, nil)

local tools = createCard(Col2, "Tools", 1)
addToggle(tools, "Sprint Reset", nil, false, nil)
addToggle(tools, "Tape Mouse", nil, false, nil)
addToggle(tools, "Aim Assist", "Helps to Focus on Entities", false, nil)
addToggle(tools, "Web Trap", nil, false, nil)

local other = createCard(Col2, "Other", 2)
addToggle(other, "No Slot Change", nil, false, nil)
addToggle(other, "Anti Bot", nil, false, nil)
addToggle(other, "No Friend Damage", nil, true, nil)

local FloatBtn = new("TextButton", {
    Name = "ZynthButton", Size = UDim2.new(0, 52, 0, 52), AnchorPoint = CENTER,
    Position = UDim2.new(0, 46, 0.4, 0), BackgroundColor3 = Color3.fromRGB(8, 8, 8),
    Text = "", AutoButtonColor = false, Visible = false, ZIndex = 10,
}, ScreenGui)
corner(FloatBtn, 16)
stroke(FloatBtn, THEME.Border, 1.2)

local FloatScale = new("UIScale", {Scale = 0}, FloatBtn)

do
    local logo = buildZ(FloatBtn, 28)
    logo.AnchorPoint = CENTER
    logo.Position = UDim2.new(0.5, 0, 0.5, 0)
    logo.ZIndex = 11
end

local menuOpen, busy = false, false

local function openMenu()
    if menuOpen or busy then return end
    busy, menuOpen = true, true
    play("Open")
    Main.Size = CLOSED_SIZE
    Holder.Visible = true
    tw(Main, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = OPEN_SIZE}).Completed:Connect(function()
        busy = false
    end)
    task.delay(0.8, function() busy = false end)
end

local function closeMenu()
    if not menuOpen or busy then return end
    busy, menuOpen = true, false
    play("Close")
    tw(Main, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = CLOSED_SIZE}).Completed:Connect(function()
        if not menuOpen then Holder.Visible = false end
        busy = false
    end)
    task.delay(0.6, function() busy = false end)
end

local function toggleMenu()
    if menuOpen then closeMenu() else openMenu() end
end

makeDraggable(FloatBtn, FloatBtn, toggleMenu)
MenuBtn.MouseButton1Click:Connect(closeMenu)

UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == CONFIG.ToggleKey then toggleMenu() end
end)

local function runIntro()
    local Intro = new("Frame", {
        Name = "Intro", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0, BorderSizePixel = 0, Active = true, ZIndex = 50,
    }, ScreenGui)

    pcall(function()
        prepareSounds()

        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(800, 400)

        local Group = new("Frame", {
            AnchorPoint = CENTER, Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(0, 500, 0, 200), BackgroundTransparency = 1, ZIndex = 51,
        }, Intro)
        new("UIScale", {Scale = math.clamp(math.min(vp.X / 400, vp.Y / 190), 0.5, 1.5)}, Group)

        local gap = 12
        local logo, lw = buildZ(Group, 120)
        logo.AnchorPoint = CENTER
        logo.Position = UDim2.new(0.5, 0, 0.5, 0)
        logo.GroupTransparency = 1
        logo.ZIndex = 54
        local logoScale = new("UIScale", {Scale = 0.5}, logo)

        local tws = TextService:GetTextSize(CONFIG.IntroText, CONFIG.IntroTextSize, CONFIG.IntroFont, Vector2.new(1000, 200)).X + 6
        local total = lw + gap + tws
        local logoEnd = -total / 2 + lw / 2
        local wordEnd = -total / 2 + lw + gap
        local wordStart = -lw * 0.2

        local Word = new("TextLabel", {
            AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, wordStart, 0.5, 0),
            Size = UDim2.new(0, tws, 0, CONFIG.IntroTextSize + 16), BackgroundTransparency = 1,
            Text = CONFIG.IntroText, Font = CONFIG.IntroFont, TextSize = CONFIG.IntroTextSize,
            TextColor3 = Color3.new(1, 1, 1), TextTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 53,
        }, Group)

        task.wait(0.25)
        play("Intro")
        tw(logo, TweenInfo.new(0.7, Enum.EasingStyle.Quad), {GroupTransparency = 0})
        tw(logoScale, TweenInfo.new(0.9, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Scale = 1})
        task.wait(1.3)

        play("Slide")
        local slide = TweenInfo.new(1.0, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
        tw(logo, slide, {Position = UDim2.new(0.5, logoEnd, 0.5, 0)})
        task.delay(0.15, function()
            tw(Word, slide, {Position = UDim2.new(0.5, wordEnd, 0.5, 0), TextTransparency = 0})
        end)
        task.wait(2.1)

        play("Slide", 0.85)
        tw(Word, slide, {Position = UDim2.new(0.5, wordStart, 0.5, 0), TextTransparency = 1})
        task.delay(0.15, function()
            tw(logo, slide, {Position = UDim2.new(0.5, 0, 0.5, 0)})
        end)
        task.wait(1.3)

        local fade = TweenInfo.new(0.6, Enum.EasingStyle.Quad)
        tw(Intro, fade, {BackgroundTransparency = 1})
        tw(logo, fade, {GroupTransparency = 1})
        task.wait(0.6)
    end)

    Intro:Destroy()
end

task.spawn(function()
    runIntro()
    FloatBtn.Visible = true
    tw(FloatScale, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Scale = 1})
    openMenu()
end)
