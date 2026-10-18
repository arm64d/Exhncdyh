local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local CONFIG = {
    IntroText = "ynth",
    IntroFont = Enum.Font.Michroma,
    IntroTextSize = 30,
    ToggleKey = Enum.KeyCode.RightShift,
    GirlTransparency = 0.8,
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

local B64 = {}
for i = 1, 64 do B64[("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"):byte(i)] = i - 1 end

local function b64decode(str)
    str = str:gsub("%s", "")
    local out, n = {}, 0
    for i = 1, #str, 4 do
        local c1, c2, c3, c4 = str:byte(i, i + 3)
        local v3, v4 = B64[c3], B64[c4]
        local v = B64[c1] * 262144 + B64[c2] * 4096 + (v3 or 0) * 64 + (v4 or 0)
        n = n + 1
        out[n] = string.char(floor(v / 65536) % 256)
        if v3 then
            n = n + 1
            out[n] = string.char(floor(v / 256) % 256)
        end
        if v4 then
            n = n + 1
            out[n] = string.char(v % 256)
        end
    end
    return table.concat(out)
end

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
    Divider = Color3.fromRGB(60, 44, 50),
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

local TopBar = new("CanvasGroup", {
    Name = "TopBar", Size = UDim2.new(1, 0, 0, 56), AnchorPoint = CENTER,
    Position = UDim2.new(0.5, 0, 0, 28), BackgroundTransparency = 1, BorderSizePixel = 0,
}, Inner)
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

local Sidebar = new("CanvasGroup", {
    Name = "Sidebar", Size = UDim2.new(0, 155, 1, -58), AnchorPoint = CENTER,
    Position = UDim2.new(0, 91.5, 0, 270), BackgroundTransparency = 1, BorderSizePixel = 0,
}, Inner)

local GirlImage = new("ImageLabel", {
    Name = "Girl", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0),
    Size = UDim2.new(0, 159, 0, 340), BackgroundTransparency = 1,
    ImageTransparency = CONFIG.GirlTransparency, ScaleType = Enum.ScaleType.Fit,
    ZIndex = 0, Visible = false,
}, Sidebar)

local SideList = new("Frame", {Name = "List", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1}, Sidebar)
new("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, SideList)

local function applyGirl(data)
    local getAsset = getcustomasset or getsynasset
    if not (writefile and getAsset) then return end
    pcall(function()
        writefile("zynth_girl.png", b64decode(data))
        GirlImage.Image = getAsset("zynth_girl.png")
        GirlImage.Visible = true
    end)
end

local activeTab

local function addCategory(name, order)
    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20), LayoutOrder = order, BackgroundTransparency = 1,
        Text = "   " .. name:upper(), Font = Enum.Font.GothamBold, TextSize = 9,
        TextColor3 = THEME.TextDim, TextXAlignment = Enum.TextXAlignment.Left,
    }, SideList)
end

local function addSidebarItem(name, iconId, active, order)
    local btn = new("TextButton", {
        Size = UDim2.new(1, -4, 0, 29), LayoutOrder = order,
        BackgroundColor3 = active and THEME.SidebarActive or THEME.Background,
        BackgroundTransparency = active and 0 or 1, Text = "", AutoButtonColor = false,
    }, SideList)
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

local ContentGroup = new("CanvasGroup", {
    Name = "ContentGroup", Size = UDim2.new(1, -195, 1, -74), AnchorPoint = CENTER,
    Position = UDim2.new(0, 478.5, 0, 268), BackgroundTransparency = 1, BorderSizePixel = 0,
}, Inner)

local Content = new("ScrollingFrame", {
    Name = "Content", Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
    ScrollBarImageColor3 = THEME.BorderActive, CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
    ElasticBehavior = Enum.ElasticBehavior.Never,
}, ContentGroup)

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

local function makeSwitch(parent, position, state)
    local switch = new("Frame", {
        Size = UDim2.new(0, 28, 0, 16), AnchorPoint = Vector2.new(1, 0.5), Position = position,
        BackgroundColor3 = state and THEME.Accent or THEME.ToggleOff, BorderSizePixel = 0,
    }, parent)
    corner(switch, 8)
    local knob = new("Frame", {
        Size = UDim2.new(0, 12, 0, 12),
        Position = state and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6),
        BackgroundColor3 = state and THEME.KnobOn or THEME.KnobOff, BorderSizePixel = 0,
    }, switch)
    corner(knob, 6)
    return function(on)
        tw(switch, TWEEN_FAST, {BackgroundColor3 = on and THEME.Accent or THEME.ToggleOff})
        tw(knob, TWEEN_FAST, {
            BackgroundColor3 = on and THEME.KnobOn or THEME.KnobOff,
            Position = on and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6),
        })
    end
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

    local on = default and true or false
    local setSwitch = makeSwitch(row, UDim2.new(1, -12, 0.5, 0), on)

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

    row.MouseButton1Click:Connect(function()
        on = not on
        play(on and "ToggleOn" or "ToggleOff")
        setSwitch(on)
        if callback then callback(on) end
    end)

    local entry = {Name = name:lower(), Frame = row, Card = card}
    entry.Set = function(v)
        on = v
        setSwitch(v)
    end
    table.insert(rows, entry)
    return entry
end

local function addSettings(card, entry, items)
    rowCount[card] = rowCount[card] + 1
    local height = #items * 26 + 4

    local panel = new("Frame", {
        Name = "Settings", Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1,
        ClipsDescendants = true, LayoutOrder = rowCount[card],
    }, card)
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}, panel)
    new("UIPadding", {PaddingTop = UDim.new(0, 2)}, panel)
    entry.Panel = panel

    for i, item in ipairs(items) do
        local opt = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Text = "",
            AutoButtonColor = false, LayoutOrder = i,
        }, panel)
        new("TextLabel", {
            Position = UDim2.new(0, 24, 0, 0), Size = UDim2.new(1, -90, 1, 0), BackgroundTransparency = 1,
            Text = item.label, Font = Enum.Font.GothamMedium, TextSize = 10,
            TextColor3 = THEME.TextMuted, TextXAlignment = Enum.TextXAlignment.Left,
        }, opt)
        local state = item.default
        local setOpt = makeSwitch(opt, UDim2.new(1, -12, 0.5, 0), state)
        opt.MouseButton1Click:Connect(function()
            state = not state
            play(state and "ToggleOn" or "ToggleOff")
            setOpt(state)
            item.onChange(state)
        end)
    end

    local gearBtn = new("TextButton", {
        Size = UDim2.new(0, 26, 0, 26), AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -46, 0.5, 0), BackgroundTransparency = 1, Text = "",
    }, entry.Frame)
    local gear = new("Frame", {
        Size = UDim2.new(0, 14, 0, 14), AnchorPoint = CENTER, Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundTransparency = 1,
    }, gearBtn)
    local parts = {}
    for _, r in ipairs({0, 45, 90, 135}) do
        table.insert(parts, new("Frame", {
            Size = UDim2.new(0, 14, 0, 3), AnchorPoint = CENTER, Position = UDim2.new(0.5, 0, 0.5, 0),
            Rotation = r, BackgroundColor3 = THEME.TextMuted, BorderSizePixel = 0,
        }, gear))
    end
    local body = new("Frame", {
        Size = UDim2.new(0, 10, 0, 10), AnchorPoint = CENTER, Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundColor3 = THEME.TextMuted, BorderSizePixel = 0,
    }, gear)
    corner(body, 5)
    table.insert(parts, body)
    corner(new("Frame", {
        Size = UDim2.new(0, 4, 0, 4), AnchorPoint = CENTER, Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundColor3 = THEME.CardBg, BorderSizePixel = 0,
    }, gear), 2)

    local open = false
    gearBtn.MouseButton1Click:Connect(function()
        open = not open
        play("Click")
        tw(gear, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Rotation = open and 180 or 0})
        for _, part in ipairs(parts) do
            tw(part, TWEEN_FAST, {BackgroundColor3 = open and THEME.Accent or THEME.TextMuted})
        end
        tw(panel, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, 0, 0, open and height or 0),
        })
    end)
end

SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
    local query = SearchInput.Text:lower()
    for _, item in ipairs(rows) do
        local match = query == "" or string.find(item.Name, query, 1, true) ~= nil
        item.Frame.Visible = match
        if item.Panel then item.Panel.Visible = match end
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

local ANIME_DIR = "ZynthAnime/"
local ANIME_REF_H = 1.46
local ANIME = {
    {"Head", 0, -0.0013, 1.3799, 0.0222, 2.1096, 2.4829, 2.3100},
    {"Head", 1, -0.0002, 1.3691, 0.0225, 1.8655, 2.2769, 2.0335},
    {"UpperTorso", 0, 0.0002, 1.1150, -0.0203, 2.4607, 3.3522, 1.9418},
    {"LowerTorso", 0, -0.0021, 0.8256, 0.0115, 3.7125, 3.1855, 2.7229},
    {"LeftUpperArm", 0, -0.0897, 1.0661, 0.0056, 1.1181, 2.0610, 1.1263},
    {"LeftLowerArm", 0, -0.0956, 0.9049, 0.0065, 0.5741, 2.2623, 0.7068},
    {"LeftHand", 0, -0.0946, 0.7324, -0.0275, 0.3763, 1.3502, 1.0667},
    {"RightUpperArm", 0, 0.0904, 1.0668, 0.0055, 1.1182, 2.0589, 1.1262},
    {"RightLowerArm", 0, 0.0964, 0.9057, 0.0063, 0.5742, 2.2620, 0.7081},
    {"RightHand", 0, 0.0955, 0.7333, -0.0278, 0.3766, 1.3502, 1.0669},
    {"LeftUpperLeg", 0, -0.0750, 0.6494, 0.0075, 1.3721, 3.4634, 1.5569},
    {"LeftLowerLeg", 0, -0.0547, 0.2866, 0.0297, 0.8074, 4.3856, 1.2320},
    {"LeftFoot", 0, -0.0470, 0.0530, -0.0259, 0.8120, 1.0688, 2.0155},
    {"RightUpperLeg", 0, 0.0751, 0.6494, 0.0074, 1.3718, 3.4639, 1.5570},
    {"RightLowerLeg", 0, 0.0551, 0.2867, 0.0297, 0.8070, 4.3858, 1.2321},
    {"RightFoot", 0, 0.0475, 0.0531, -0.0259, 0.8120, 1.0690, 2.0156},
}
local R6_MAP = {
    Head = "Head", UpperTorso = "Torso", LowerTorso = "Torso",
    LeftUpperArm = "Left Arm", LeftLowerArm = "Left Arm", LeftHand = "Left Arm",
    RightUpperArm = "Right Arm", RightLowerArm = "Right Arm", RightHand = "Right Arm",
    LeftUpperLeg = "Left Leg", LeftLowerLeg = "Left Leg", LeftFoot = "Left Leg",
    RightUpperLeg = "Right Leg", RightLowerLeg = "Right Leg", RightFoot = "Right Leg",
}

local Toast = new("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46),
    AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(0, 0, 0, 0), BackgroundColor3 = THEME.Background,
    BorderSizePixel = 0, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = THEME.TextPrimary,
    TextWrapped = true, Text = "", Visible = false, ZIndex = 60,
}, ScreenGui)
corner(Toast, 8)
stroke(Toast, THEME.BorderActive, 1)
new("UIPadding", {
    PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
    PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
}, Toast)
new("UISizeConstraint", {MaxSize = Vector2.new(420, 200)}, Toast)

local toastId = 0
local function notify(text)
    toastId = toastId + 1
    local id = toastId
    Toast.Text = text
    Toast.Visible = true
    task.delay(4, function()
        if id == toastId then Toast.Visible = false end
    end)
end

local animeOn = false
local animeFolder, animeConn
local hidden = {}

local function animeAsset(file)
    return (getcustomasset or getsynasset)(ANIME_DIR .. file)
end

local function pieceFile(p)
    return p[1] .. (p[2] == 1 and "_a" or "_s") .. ".mesh"
end

local function animeFilesReady()
    if not (isfile and (getcustomasset or getsynasset)) then return false end
    if not isfile(ANIME_DIR .. "atlas.png") then return false end
    for _, p in ipairs(ANIME) do
        if not isfile(ANIME_DIR .. pieceFile(p)) then return false end
    end
    return true
end

local function hideOne(inst)
    if animeFolder and inst:IsDescendantOf(animeFolder) then return end
    if inst:FindFirstAncestorOfClass("Tool") then return end
    if inst:IsA("BasePart") or inst:IsA("Decal") then
        if hidden[inst] == nil then hidden[inst] = inst.Transparency end
        inst.Transparency = 1
    end
end

local function removeAnime()
    if animeConn then
        animeConn:Disconnect()
        animeConn = nil
    end
    if animeFolder then
        animeFolder:Destroy()
        animeFolder = nil
    end
    for inst, value in pairs(hidden) do
        pcall(function() inst.Transparency = value end)
    end
    hidden = {}
end

local function restTable(char, hrp)
    local rel, motors = {[hrp] = CFrame.new()}, {}
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("Motor6D") and d.Part0 and d.Part1 then table.insert(motors, d) end
    end
    local changed = true
    while changed do
        changed = false
        for _, m in ipairs(motors) do
            if rel[m.Part0] and not rel[m.Part1] then
                rel[m.Part1] = rel[m.Part0] * m.C0 * m.C1:Inverse()
                changed = true
            end
        end
    end
    return rel
end

local function newPiece(meshAsset, atlas, alpha, size, scale)
    local piece
    pcall(function()
        local mp = Instance.new("MeshPart")
        mp.MeshId = meshAsset
        mp.Size = size
        if mp.MeshId ~= "" then piece = mp end
    end)
    if piece then
        pcall(function()
            piece.RenderFidelity = Enum.RenderFidelity.Precise
            new("SurfaceAppearance", {
                ColorMap = atlas,
                AlphaMode = alpha and Enum.AlphaMode.Transparency or Enum.AlphaMode.Opaque,
            }, piece)
        end)
    else
        piece = new("Part", {Size = Vector3.new(0.2, 0.2, 0.2)})
        new("SpecialMesh", {
            MeshType = Enum.MeshType.FileMesh, MeshId = meshAsset, TextureId = atlas,
            Scale = Vector3.new(scale, scale, scale),
        }, piece)
    end
    piece.Anchored = false
    piece.CanCollide = false
    piece.CanTouch = false
    piece.CanQuery = false
    piece.Massless = true
    piece.Color = Color3.new(1, 1, 1)
    piece.Material = Enum.Material.SmoothPlastic
    return piece
end

local function applyAnime()
    local char = LocalPlayer.Character
    if not char then return false, "no character" end
    local hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 5)
    if not hrp then return false, "no HumanoidRootPart" end

    local isR15 = char:FindFirstChild("UpperTorso") ~= nil
    local foot = char:FindFirstChild(isR15 and "LeftFoot" or "Left Leg")
    local head = char:FindFirstChild("Head")
    if not (foot and head) then return false, "body parts not found" end
    removeAnime()

    local rel = restTable(char, hrp)
    for _, d in ipairs(char:GetChildren()) do
        if d:IsA("BasePart") and not rel[d] then rel[d] = hrp.CFrame:ToObjectSpace(d.CFrame) end
    end

    local footBottom = rel[foot].Position.Y - foot.Size.Y / 2
    local headTop = rel[head].Position.Y + head.Size.Y / 2
    local scale = (headTop - footBottom) / ANIME_REF_H
    local atlas = animeAsset("atlas.png")

    animeFolder = new("Folder", {Name = "ZynthAnime"}, char)
    animeConn = char.DescendantAdded:Connect(hideOne)
    for _, inst in ipairs(char:GetDescendants()) do hideOne(inst) end

    for _, p in ipairs(ANIME) do
        local part = char:FindFirstChild(isR15 and p[1] or R6_MAP[p[1]])
        if part and rel[part] then
            local localCF = CFrame.new(Vector3.new(0, footBottom, 0) + Vector3.new(p[3], p[4], p[5]) * scale)
            local piece = newPiece(animeAsset(pieceFile(p)), atlas, p[2] == 1, Vector3.new(p[6], p[7], p[8]) * (scale / 10), scale / 10)
            piece.Name = p[1]
            piece.CFrame = hrp.CFrame * localCF
            piece.Parent = animeFolder
            new("Weld", {Part0 = part, Part1 = piece, C0 = rel[part]:Inverse() * localCF}, piece)
        end
    end
    return true
end

local animeEntry
local model = createCard(Col1, "Model", 3)
animeEntry = addToggle(model, "Anime Model", "Replaces your avatar with a 3D model", false, nil, function(on)
    if on then
        if not animeFilesReady() then
            notify("Anime Model: put the ZynthAnime folder into your executor's workspace folder")
            animeEntry.Set(false)
            return
        end
        animeOn = true
        task.spawn(function()
            local ran, ok, reason = pcall(applyAnime)
            if not (ran and ok) then
                animeOn = false
                animeEntry.Set(false)
                removeAnime()
                notify("Anime Model: " .. tostring(ran and reason or ok))
            end
        end)
    else
        animeOn = false
        removeAnime()
    end
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    if not animeOn then return end
    char:WaitForChild("HumanoidRootPart", 10)
    char:WaitForChild("Humanoid", 10)
    task.wait(1)
    if animeOn then applyAnime() end
end)

local WM_ORDER = {"Name", "Nickname", "FPS", "Ping", "Time", "Players"}
local WM_LABELS = {
    Name = "Script name", Nickname = "Nickname", FPS = "FPS",
    Ping = "Ping", Time = "Time", Players = "Players",
}
local WM = {Name = true, Nickname = true, FPS = true, Ping = true, Time = false, Players = false}
local wmEnabled = true
local fps, ping = 60, 0
local MUTED = 'rgb(120,110,115)'

local function getPing()
    local ok, v = pcall(function()
        return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if ok and v then return floor(v + 0.5) end
    local ok2, p = pcall(function() return LocalPlayer:GetNetworkPing() * 1000 end)
    return ok2 and floor(p + 0.5) or 0
end

local WM_TEXT = {
    Name = function() return '<font color="rgb(246,92,82)">Zynth</font>' end,
    Nickname = function() return LocalPlayer.Name end,
    FPS = function() return fps .. '<font color="' .. MUTED .. '"> fps</font>' end,
    Ping = function() return ping .. '<font color="' .. MUTED .. '"> ms</font>' end,
    Time = function() return os.date("%H:%M") end,
    Players = function() return #Players:GetPlayers() .. "/" .. Players.MaxPlayers end,
}

local Watermark = new("Frame", {
    Name = "Watermark", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 26),
    AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10),
    BackgroundColor3 = THEME.Background, BackgroundTransparency = 0.08, BorderSizePixel = 0,
    Visible = false, ZIndex = 5,
}, ScreenGui)
corner(Watermark, 7)
stroke(Watermark, THEME.BorderActive, 1)
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
}, Watermark)
new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, Watermark)
buildZ(Watermark, 12).LayoutOrder = 0
makeDraggable(Watermark, Watermark)

local wmLabels = {}

local function rebuildWatermark()
    for _, c in ipairs(Watermark:GetChildren()) do
        if c:GetAttribute("seg") then c:Destroy() end
    end
    wmLabels = {}
    local order = 0
    for _, key in ipairs(WM_ORDER) do
        if WM[key] then
            order = order + 1
            new("Frame", {
                Size = UDim2.new(0, 1, 0, 12), BackgroundColor3 = THEME.Divider,
                BorderSizePixel = 0, LayoutOrder = order * 2 - 1,
            }, Watermark):SetAttribute("seg", true)
            local label = new("TextLabel", {
                AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), BackgroundTransparency = 1,
                RichText = true, Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = THEME.TextPrimary,
                Text = WM_TEXT[key](), LayoutOrder = order * 2,
            }, Watermark)
            label:SetAttribute("seg", true)
            wmLabels[key] = label
        end
    end
end
rebuildWatermark()

do
    local frames, acc = 0, 0
    local conn = RunService.Heartbeat:Connect(function(dt)
        frames = frames + 1
        acc = acc + dt
        if acc >= 0.5 then
            fps = floor(frames / acc + 0.5)
            frames, acc = 0, 0
            ping = getPing()
            if Watermark.Visible then
                for key, label in pairs(wmLabels) do label.Text = WM_TEXT[key]() end
            end
        end
    end)
    ScreenGui.Destroying:Connect(function() conn:Disconnect() end)
end

local interface = createCard(Col2, "Interface", 3)
local wmEntry = addToggle(interface, "Watermark", nil, true, nil, function(on)
    wmEnabled = on
    Watermark.Visible = on
end)

local wmItems = {}
for _, key in ipairs(WM_ORDER) do
    table.insert(wmItems, {
        label = WM_LABELS[key], default = WM[key],
        onChange = function(on)
            WM[key] = on
            rebuildWatermark()
        end,
    })
end
addSettings(interface, wmEntry, wmItems)

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

local blocks = {TopBar, Sidebar, ContentGroup}
local finals = {}
for _, b in ipairs(blocks) do finals[b] = b.Position end
local CENTER_POS = UDim2.new(0.5, 0, 0.5, 0)

local function openMenu()
    if menuOpen or busy then return end
    busy, menuOpen = true, true
    play("Open")

    for _, b in ipairs(blocks) do
        b.Position = CENTER_POS
        b.GroupTransparency = 1
    end
    Main.Size = CLOSED_SIZE
    Holder.Visible = true

    local info = TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    tw(Main, info, {Size = OPEN_SIZE}).Completed:Connect(function() busy = false end)
    for _, b in ipairs(blocks) do
        tw(b, info, {Position = finals[b], GroupTransparency = 0})
    end
    task.delay(0.8, function() busy = false end)
end

local function closeMenu()
    if not menuOpen or busy then return end
    busy, menuOpen = true, false
    play("Close")

    local info = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    for _, b in ipairs(blocks) do
        tw(b, info, {Position = CENTER_POS, GroupTransparency = 1})
    end
    tw(Main, info, {Size = CLOSED_SIZE}).Completed:Connect(function()
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
    Watermark.Visible = wmEnabled
    FloatBtn.Visible = true
    tw(FloatScale, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Scale = 1})
    openMenu()
end)

applyGirl([=[
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
Blif4/eYEMhu4HEgcAAAAASUVORK5CYII=
]=])
