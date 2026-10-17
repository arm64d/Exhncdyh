--[[
    ZYNTH  |  Roblox MM2  |  только меню (без функций)
    Под Delta / телефон: тач-драг, авто-масштаб, плавающая кнопка Z.
]]

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService      = game:GetService("TextService")
local SoundService     = game:GetService("SoundService")
local Debris           = game:GetService("Debris")
local CoreGui          = game:GetService("CoreGui")
local Players          = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- =============================================================================
-- НАСТРОЙКИ
-- =============================================================================
local CONFIG = {
    -- Z + IntroText = слово в интро. "ynth" -> получается Zynth.
    -- Если хочешь, чтобы появлялась надпись целиком, поставь "Zynth".
    IntroText = "ynth",
    ToggleKey = Enum.KeyCode.RightShift, -- для ПК, на телефоне есть кнопка Z
}

-- Звуки: {источник, громкость, скорость}
-- Источник: "rbxassetid://ID"  или  "rbxasset://sounds/..."  или  ссылка "https://...mp3"
-- (ссылку скрипт скачает сам и подключит через getcustomasset, если Delta это поддерживает)
local SOUNDS = {
    Intro     = {"rbxasset://sounds/bass.mp3",                 0.7, 1.15},
    Slide     = {"rbxasset://sounds/snap.mp3",                 0.6, 0.7},
    Open      = {"rbxasset://sounds/electronicpingshort.wav",  0.8, 0.8},
    Close     = {"rbxasset://sounds/electronicpingshort.wav",  0.7, 0.55},
    Click     = {"rbxasset://sounds/switch.wav",               0.7, 1.2},
    ToggleOn  = {"rbxasset://sounds/electronicpingshort.wav",  0.6, 1.5},
    ToggleOff = {"rbxasset://sounds/electronicpingshort.wav",  0.6, 1.0},
    Tab       = {"rbxasset://sounds/snap.mp3",                 0.5, 1.6},
}

-- =============================================================================
-- ЗВУКИ
-- =============================================================================
local function resolveSound(src, name)
    if type(src) == "string" and src:sub(1, 4) == "http" then
        local ok, res = pcall(function()
            local fileName = "zynth_" .. name .. ".mp3"
            if not (isfile and isfile(fileName)) then
                writefile(fileName, game:HttpGet(src))
            end
            return (getcustomasset or getsynasset)(fileName)
        end)
        if ok and res then return res end
        return nil
    end
    return src
end

local soundIds = {}
for name, data in pairs(SOUNDS) do
    soundIds[name] = resolveSound(data[1], name)
end

local function play(name, speedMul)
    local data, id = SOUNDS[name], soundIds[name]
    if not data or not id then return end
    pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = id
        s.Volume = data[2]
        s.PlaybackSpeed = (data[3] or 1) * (speedMul or 1)
        s.Parent = SoundService
        s:Play()
        Debris:AddItem(s, 5)
    end)
end

-- =============================================================================
-- ЗАПУСК / ОЧИСТКА СТАРЫХ КОПИЙ
-- =============================================================================
local function safeGethui()
    local ok, h = pcall(function() return gethui and gethui() end)
    if ok then return h end
    return nil
end

local function getPlayerGui()
    return LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
end

for _, c in ipairs({CoreGui, safeGethui() or CoreGui, getPlayerGui() or CoreGui}) do
    pcall(function()
        local old = c:FindFirstChild("ZynthUI")
        if old then old:Destroy() end
    end)
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ZynthUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

pcall(function() if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end end)
local okParent = pcall(function() ScreenGui.Parent = safeGethui() or CoreGui end)
if not okParent or not ScreenGui.Parent then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- =============================================================================
-- ТЕМА (как в оригинале)
-- =============================================================================
local THEME = {
    Background    = Color3.fromRGB(12, 9, 11),
    CardBg        = Color3.fromRGB(18, 13, 16),
    PillBg        = Color3.fromRGB(16, 12, 14),
    SidebarActive = Color3.fromRGB(27, 16, 19),
    Border        = Color3.fromRGB(36, 24, 28),
    BorderActive  = Color3.fromRGB(90, 36, 42),
    Accent        = Color3.fromRGB(246, 92, 82),
    AccentSoft    = Color3.fromRGB(255, 165, 155),
    AccentDark    = Color3.fromRGB(130, 40, 42),
    TextPrimary   = Color3.fromRGB(235, 235, 235),
    TextMuted     = Color3.fromRGB(120, 110, 115),
    TextDim       = Color3.fromRGB(72, 64, 68),
    Divider       = Color3.fromRGB(48, 36, 40),
    BadgeBg       = Color3.fromRGB(25, 18, 22),
    ToggleOff     = Color3.fromRGB(36, 28, 32),
    KnobOff       = Color3.fromRGB(78, 68, 73),
    KnobOn        = Color3.fromRGB(255, 255, 255)
}

-- Красный для буквы Z
local Z_RED = ColorSequence.new({
    ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 110, 105)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(238, 38, 48)),
    ColorSequenceKeypoint.new(1.0, Color3.fromRGB(150, 12, 24)),
})

local ICONS = {
    Search   = "rbxassetid://7733911828",
    Chevron  = "rbxassetid://7733717447",
    More     = "rbxassetid://7734021300",
    Menu     = "rbxassetid://7733993211",
    Combat   = "rbxassetid://7734053426",
    Movement = "rbxassetid://7733799901",
    Visuals  = "rbxassetid://7733774602",
    Player   = "rbxassetid://7733954760",
    Misc     = "rbxassetid://7734056411",
    Presets  = "rbxassetid://7733964719",
    AutoBuy  = "rbxassetid://7733942651",
    Accounts = "rbxassetid://7733765307",
}

local GLOW_IMG = "rbxassetid://5028857084"

local TWEEN_FAST = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_SLOW = TweenInfo.new(0.35, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)

local function tw(obj, info, props)
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness
    s.Transparency = transparency or 0
    s.Parent = parent
    return s
end

-- Универсальное перетаскивание (мышь + тач). onTap вызывается, если не двигали.
local function makeDraggable(handle, target, onTap)
    local dragging, dragInput, dragStart, startPos, moved = false, nil, nil, nil, false

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = false
            dragStart = input.Position
            startPos = target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if not moved and onTap then onTap() end
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
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

-- =============================================================================
-- ГЛАВНОЕ ОКНО (790x490), без HUD-watermark
-- =============================================================================
local Holder = Instance.new("Frame")
Holder.Name = "Holder"
Holder.Size = UDim2.new(0, 790, 0, 490)
Holder.AnchorPoint = Vector2.new(0.5, 0.5)
Holder.Position = UDim2.new(0.5, 0, 0.5, 0)
Holder.BackgroundTransparency = 1
Holder.Visible = false
Holder.Parent = ScreenGui

-- Авто-масштаб под экран телефона
local FitScale = Instance.new("UIScale")
FitScale.Parent = Holder

local function updateFit()
    local vp = Camera.ViewportSize
    local s = math.min(1, (vp.X - 20) / 790, (vp.Y - 20) / 490)
    FitScale.Scale = math.max(s, 0.35)
end
updateFit()
Camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateFit)

local Main = Instance.new("Frame")
Main.Name = "MainFrame"
Main.Size = UDim2.new(1, 0, 1, 0)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.Position = UDim2.new(0.5, 0, 0.5, 0)
Main.BackgroundColor3 = THEME.Background
Main.BorderSizePixel = 0
Main.ClipsDescendants = false
Main.Parent = Holder

local MainScale = Instance.new("UIScale") -- анимация появления из пикселя
MainScale.Parent = Main

corner(Main, 12)
stroke(Main, THEME.Border, 1.2)

local GlowBackdrop = Instance.new("ImageLabel")
GlowBackdrop.Name = "GlowBackdrop"
GlowBackdrop.BackgroundTransparency = 1
GlowBackdrop.Position = UDim2.new(0, -45, 0, -45)
GlowBackdrop.Size = UDim2.new(1, 90, 1, 90)
GlowBackdrop.ZIndex = 0
GlowBackdrop.Image = GLOW_IMG
GlowBackdrop.ImageColor3 = THEME.AccentDark
GlowBackdrop.ImageTransparency = 0.83
GlowBackdrop.ScaleType = Enum.ScaleType.Slice
GlowBackdrop.SliceCenter = Rect.new(24, 24, 276, 276)
GlowBackdrop.Parent = Main

-- Top Bar (за него тащим окно)
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 56)
TopBar.BackgroundTransparency = 1
TopBar.Parent = Main

makeDraggable(TopBar, Holder)

-- Логотип: красная Z вместо N
local MainLogoHolder = Instance.new("Frame")
MainLogoHolder.Name = "LogoHolder"
MainLogoHolder.Size = UDim2.new(0, 64, 0, 64)
MainLogoHolder.Position = UDim2.new(0, 52, 0, -4)
MainLogoHolder.BackgroundTransparency = 1
MainLogoHolder.Parent = TopBar

local MainLogoHalo = Instance.new("ImageLabel")
MainLogoHalo.Name = "Halo"
MainLogoHalo.Size = UDim2.new(2.1, 0, 2.1, 0)
MainLogoHalo.Position = UDim2.new(-0.55, 0, -0.55, 0)
MainLogoHalo.BackgroundTransparency = 1
MainLogoHalo.Image = GLOW_IMG
MainLogoHalo.ImageColor3 = THEME.Accent
MainLogoHalo.ImageTransparency = 0.58
MainLogoHalo.ZIndex = 1
MainLogoHalo.Parent = MainLogoHolder

local MainLogoShadow = Instance.new("TextLabel")
MainLogoShadow.Name = "LogoShadow"
MainLogoShadow.Size = UDim2.new(1, 0, 1, 0)
MainLogoShadow.Position = UDim2.new(0, 2, 0, 2)
MainLogoShadow.BackgroundTransparency = 1
MainLogoShadow.Text = "Z"
MainLogoShadow.Font = Enum.Font.GothamBlack
MainLogoShadow.TextSize = 52
MainLogoShadow.TextColor3 = Color3.fromRGB(50, 10, 14)
MainLogoShadow.TextTransparency = 0.2
MainLogoShadow.ZIndex = 2
MainLogoShadow.Parent = MainLogoHolder

local MainLogoImg = Instance.new("TextLabel")
MainLogoImg.Name = "LogoMain"
MainLogoImg.Size = UDim2.new(1, 0, 1, 0)
MainLogoImg.BackgroundTransparency = 1
MainLogoImg.Text = "Z"
MainLogoImg.Font = Enum.Font.GothamBlack
MainLogoImg.TextSize = 52
MainLogoImg.TextColor3 = Color3.fromRGB(255, 255, 255)
MainLogoImg.ZIndex = 3
MainLogoImg.Parent = MainLogoHolder

local MainLogoGrad = Instance.new("UIGradient")
MainLogoGrad.Color = Z_RED
MainLogoGrad.Rotation = 90
MainLogoGrad.Parent = MainLogoImg

-- Search Bar
local SearchBox = Instance.new("Frame")
SearchBox.Size = UDim2.new(0, 250, 0, 26)
SearchBox.Position = UDim2.new(0, 185, 0, 15)
SearchBox.BackgroundColor3 = THEME.CardBg
SearchBox.BorderSizePixel = 0
SearchBox.Parent = TopBar
corner(SearchBox, 6)
stroke(SearchBox, THEME.Border, 0.8)

local SearchIcon = Instance.new("ImageLabel")
SearchIcon.Size = UDim2.new(0, 13, 0, 13)
SearchIcon.Position = UDim2.new(0, 9, 0.5, -6.5)
SearchIcon.BackgroundTransparency = 1
SearchIcon.Image = ICONS.Search
SearchIcon.ImageColor3 = THEME.TextMuted
SearchIcon.Parent = SearchBox

local SearchInput = Instance.new("TextBox")
SearchInput.PlaceholderText = "Search something"
SearchInput.PlaceholderColor3 = THEME.TextMuted
SearchInput.Text = ""
SearchInput.ClearTextOnFocus = false
SearchInput.TextColor3 = THEME.TextPrimary
SearchInput.Font = Enum.Font.Gotham
SearchInput.TextSize = 11
SearchInput.Position = UDim2.new(0, 30, 0, 0)
SearchInput.Size = UDim2.new(1, -36, 1, 0)
SearchInput.BackgroundTransparency = 1
SearchInput.TextXAlignment = Enum.TextXAlignment.Left
SearchInput.Parent = SearchBox

-- Кнопка меню справа сверху (закрывает меню)
local MenuBtn = Instance.new("ImageButton")
MenuBtn.Size = UDim2.new(0, 17, 0, 17)
MenuBtn.Position = UDim2.new(1, -32, 0.5, -8.5)
MenuBtn.BackgroundTransparency = 1
MenuBtn.Image = ICONS.Menu
MenuBtn.ImageColor3 = THEME.TextMuted
MenuBtn.Parent = TopBar

MenuBtn.MouseEnter:Connect(function()
    tw(MenuBtn, TWEEN_FAST, {ImageColor3 = THEME.TextPrimary})
end)
MenuBtn.MouseLeave:Connect(function()
    tw(MenuBtn, TWEEN_FAST, {ImageColor3 = THEME.TextMuted})
end)

-- Sidebar
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 155, 1, -58)
Sidebar.Position = UDim2.new(0, 14, 0, 54)
Sidebar.BackgroundTransparency = 1
Sidebar.Parent = Main

local SideList = Instance.new("UIListLayout")
SideList.Padding = UDim.new(0, 2)
SideList.SortOrder = Enum.SortOrder.LayoutOrder
SideList.Parent = Sidebar

local activeSidebarTab = nil

local function addCategory(name, order)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.LayoutOrder = order
    lbl.BackgroundTransparency = 1
    lbl.Text = "   " .. name:upper()
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 9
    lbl.TextColor3 = THEME.TextDim
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = Sidebar
end

local function addSidebarItem(name, iconId, isDefaultActive, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -4, 0, 29)
    btn.LayoutOrder = order
    btn.BackgroundColor3 = isDefaultActive and THEME.SidebarActive or THEME.Background
    btn.BackgroundTransparency = isDefaultActive and 0 or 1
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = Sidebar
    corner(btn, 6)

    local st = stroke(btn,
        isDefaultActive and THEME.BorderActive or Color3.fromRGB(0, 0, 0),
        1, isDefaultActive and 0 or 1)

    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, 14, 0, 14)
    icon.Position = UDim2.new(0, 9, 0.5, -7)
    icon.BackgroundTransparency = 1
    icon.Image = iconId
    icon.ImageColor3 = isDefaultActive and THEME.Accent or THEME.TextMuted
    icon.Parent = btn

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -32, 1, 0)
    title.Position = UDim2.new(0, 30, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = name
    title.Font = Enum.Font.GothamMedium
    title.TextSize = 11
    title.TextColor3 = isDefaultActive and THEME.TextPrimary or THEME.TextMuted
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = btn

    local me = {Btn = btn, Icon = icon, Title = title, Stroke = st}
    if isDefaultActive then activeSidebarTab = me end

    btn.MouseEnter:Connect(function()
        if activeSidebarTab.Btn ~= btn then
            tw(title, TWEEN_FAST, {TextColor3 = THEME.TextPrimary})
            tw(icon, TWEEN_FAST, {ImageColor3 = THEME.TextPrimary})
        end
    end)
    btn.MouseLeave:Connect(function()
        if activeSidebarTab.Btn ~= btn then
            tw(title, TWEEN_FAST, {TextColor3 = THEME.TextMuted})
            tw(icon, TWEEN_FAST, {ImageColor3 = THEME.TextMuted})
        end
    end)

    btn.MouseButton1Click:Connect(function()
        if activeSidebarTab.Btn == btn then return end
        play("Tab")

        local old = activeSidebarTab
        tw(old.Btn, TWEEN_FAST, {BackgroundTransparency = 1})
        tw(old.Stroke, TWEEN_FAST, {Transparency = 1})
        tw(old.Icon, TWEEN_FAST, {ImageColor3 = THEME.TextMuted})
        tw(old.Title, TWEEN_FAST, {TextColor3 = THEME.TextMuted})

        tw(btn, TWEEN_FAST, {BackgroundTransparency = 0, BackgroundColor3 = THEME.SidebarActive})
        tw(st, TWEEN_FAST, {Transparency = 0, Color = THEME.BorderActive})
        tw(icon, TWEEN_FAST, {ImageColor3 = THEME.Accent})
        tw(title, TWEEN_FAST, {TextColor3 = THEME.TextPrimary})

        activeSidebarTab = me
    end)
end

addCategory("Modules", 1)
addSidebarItem("Combat",   ICONS.Combat,   true,  2)
addSidebarItem("Movement", ICONS.Movement, false, 3)
addSidebarItem("Visuals",  ICONS.Visuals,  false, 4)
addSidebarItem("Player",   ICONS.Player,   false, 5)
addSidebarItem("Misc",     ICONS.Misc,     false, 6)
addCategory("Config", 7)
addSidebarItem("Presets",  ICONS.Presets,  false, 8)
addSidebarItem("AutoBuy",  ICONS.AutoBuy,  false, 9)
addSidebarItem("Accounts", ICONS.Accounts, false, 10)

-- Content (две колонки, прокрутка пальцем)
local Content = Instance.new("ScrollingFrame")
Content.Name = "Content"
Content.Position = UDim2.new(0, 181, 0, 60)
Content.Size = UDim2.new(1, -195, 1, -74)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 2
Content.ScrollBarImageColor3 = THEME.BorderActive
Content.CanvasSize = UDim2.new(0, 0, 0, 0)
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.ScrollingDirection = Enum.ScrollingDirection.Y
Content.Parent = Main

local function makeColumn(name, pos)
    local col = Instance.new("Frame")
    col.Name = name
    col.Position = pos
    col.Size = UDim2.new(0.5, -6, 0, 0)
    col.AutomaticSize = Enum.AutomaticSize.Y
    col.BackgroundTransparency = 1
    col.Parent = Content

    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, 10)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = col
    return col
end

local Col1 = makeColumn("Col1", UDim2.new(0, 0, 0, 0))
local Col2 = makeColumn("Col2", UDim2.new(0.5, 6, 0, 0))

local registeredRows, registeredCards, rowCounter = {}, {}, {}

local function createCard(parent, title, order)
    local card = Instance.new("Frame")
    card.Name = title
    card.Size = UDim2.new(1, 0, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = THEME.CardBg
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.Parent = parent
    corner(card, 8)
    stroke(card, THEME.Border, 1)

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = card

    local pad = Instance.new("UIPadding")
    pad.PaddingBottom = UDim.new(0, 6)
    pad.Parent = card

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 32)
    header.BackgroundTransparency = 1
    header.LayoutOrder = 0
    header.Parent = card

    local lbl = Instance.new("TextLabel")
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.Size = UDim2.new(1, -44, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextColor3 = THEME.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = header

    local more = Instance.new("ImageLabel")
    more.Size = UDim2.new(0, 14, 0, 14)
    more.Position = UDim2.new(1, -26, 0.5, -7)
    more.BackgroundTransparency = 1
    more.Image = ICONS.More
    more.ImageColor3 = THEME.TextMuted
    more.Parent = header

    rowCounter[card] = 0
    table.insert(registeredCards, card)
    return card
end

local function addToggle(card, name, desc, default, bind, callback)
    rowCounter[card] = rowCounter[card] + 1

    local row = Instance.new("TextButton")
    row.Name = name
    row.Size = UDim2.new(1, 0, 0, desc and 40 or 30)
    row.BackgroundTransparency = 1
    row.Text = ""
    row.AutoButtonColor = false
    row.LayoutOrder = rowCounter[card]
    row.Parent = card

    local nameLbl = Instance.new("TextLabel")
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = name
    nameLbl.Font = Enum.Font.GothamMedium
    nameLbl.TextSize = 11
    nameLbl.TextColor3 = THEME.TextPrimary
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.Position = UDim2.new(0, 12, 0, desc and 5 or 0)
    nameLbl.Size = UDim2.new(1, -96, 0, desc and 16 or 30)
    nameLbl.Parent = row

    if desc then
        local d = Instance.new("TextLabel")
        d.BackgroundTransparency = 1
        d.Text = desc
        d.Font = Enum.Font.Gotham
        d.TextSize = 9
        d.TextColor3 = THEME.TextMuted
        d.TextXAlignment = Enum.TextXAlignment.Left
        d.Position = UDim2.new(0, 12, 0, 21)
        d.Size = UDim2.new(1, -96, 0, 14)
        d.Parent = row
    end

    local switch = Instance.new("Frame")
    switch.Size = UDim2.new(0, 28, 0, 16)
    switch.AnchorPoint = Vector2.new(1, 0.5)
    switch.Position = UDim2.new(1, -12, 0.5, 0)
    switch.BackgroundColor3 = THEME.ToggleOff
    switch.BorderSizePixel = 0
    switch.Parent = row
    corner(switch, 8)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.Position = UDim2.new(0, 2, 0.5, -6)
    knob.BackgroundColor3 = THEME.KnobOff
    knob.BorderSizePixel = 0
    knob.Parent = switch
    corner(knob, 6)

    if bind then
        local badge = Instance.new("Frame")
        badge.AutomaticSize = Enum.AutomaticSize.X
        badge.Size = UDim2.new(0, 0, 0, 16)
        badge.AnchorPoint = Vector2.new(1, 0.5)
        badge.Position = UDim2.new(1, -48, 0.5, 0)
        badge.BackgroundColor3 = THEME.BadgeBg
        badge.BorderSizePixel = 0
        badge.Parent = row
        corner(badge, 4)
        stroke(badge, THEME.Border, 1)

        local bp = Instance.new("UIPadding")
        bp.PaddingLeft = UDim.new(0, 6)
        bp.PaddingRight = UDim.new(0, 6)
        bp.Parent = badge

        local bl = Instance.new("TextLabel")
        bl.AutomaticSize = Enum.AutomaticSize.X
        bl.Size = UDim2.new(0, 0, 1, 0)
        bl.BackgroundTransparency = 1
        bl.Text = bind
        bl.Font = Enum.Font.GothamMedium
        bl.TextSize = 9
        bl.TextColor3 = THEME.TextMuted
        bl.Parent = badge
    end

    local isToggled = default and true or false
    if isToggled then
        switch.BackgroundColor3 = THEME.Accent
        knob.BackgroundColor3 = THEME.KnobOn
        knob.Position = UDim2.new(1, -14, 0.5, -6)
    end

    row.MouseButton1Click:Connect(function()
        isToggled = not isToggled
        play(isToggled and "ToggleOn" or "ToggleOff")

        local targetColor = isToggled and THEME.Accent or THEME.ToggleOff
        local targetKnobColor = isToggled and THEME.KnobOn or THEME.KnobOff
        local targetPos = isToggled and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)

        tw(switch, TWEEN_FAST, {BackgroundColor3 = targetColor})
        tw(knob, TWEEN_FAST, {BackgroundColor3 = targetKnobColor, Position = targetPos})

        if callback then callback(isToggled) end
    end)

    table.insert(registeredRows, {Name = name:lower(), Frame = row, Card = card})
end

-- Живой поиск
SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
    local query = SearchInput.Text:lower()
    for _, item in ipairs(registeredRows) do
        item.Frame.Visible = (query == "") or (string.find(item.Name, query, 1, true) ~= nil)
    end
    for _, card in ipairs(registeredCards) do
        local any = false
        for _, item in ipairs(registeredRows) do
            if item.Card == card and item.Frame.Visible then any = true break end
        end
        card.Visible = any
    end
end)

-- Карточки (как в оригинале)
local cardFighting = createCard(Col1, "Fighting", 1)
addToggle(cardFighting, "Attack Aura", nil, false, nil)
addToggle(cardFighting, "No Velocity", nil, false, nil)
addToggle(cardFighting, "Trigger Bot", nil, false, nil)
addToggle(cardFighting, "Aim Assist", nil, false, "F1")
addToggle(cardFighting, "Auto Explosion", nil, false, nil)

local cardBase = createCard(Col1, "Base", 2)
addToggle(cardBase, "Auto Swap", nil, true, nil)
addToggle(cardBase, "Item Release", nil, false, nil)

local cardTools = createCard(Col2, "Tools", 1)
addToggle(cardTools, "Sprint Reset", nil, false, nil)
addToggle(cardTools, "Tape Mouse", nil, false, nil)
addToggle(cardTools, "Aim Assist", "Helps to Focus on Entities", false, nil)
addToggle(cardTools, "Web Trap", nil, false, nil)

local cardOther = createCard(Col2, "Other", 2)
addToggle(cardOther, "No Slot Change", nil, false, nil)
addToggle(cardOther, "Anti Bot", nil, false, nil)
addToggle(cardOther, "No Friend Damage", nil, true, nil)

-- =============================================================================
-- ПЛАВАЮЩАЯ КНОПКА Z (перетаскивается, открывает/закрывает меню)
-- =============================================================================
local FloatBtn = Instance.new("TextButton")
FloatBtn.Name = "ZynthButton"
FloatBtn.Size = UDim2.new(0, 52, 0, 52)
FloatBtn.AnchorPoint = Vector2.new(0.5, 0.5)
FloatBtn.Position = UDim2.new(0, 46, 0.4, 0)
FloatBtn.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
FloatBtn.Text = ""
FloatBtn.AutoButtonColor = false
FloatBtn.Visible = false
FloatBtn.ZIndex = 10
FloatBtn.Parent = ScreenGui
corner(FloatBtn, 16)
local FloatStroke = stroke(FloatBtn, THEME.Accent, 1.4, 0.45)

local FloatBtnScale = Instance.new("UIScale")
FloatBtnScale.Scale = 0
FloatBtnScale.Parent = FloatBtn

local FloatZ = Instance.new("TextLabel")
FloatZ.Size = UDim2.new(1, 0, 1, 0)
FloatZ.BackgroundTransparency = 1
FloatZ.Text = "Z"
FloatZ.Font = Enum.Font.GothamBlack
FloatZ.TextSize = 30
FloatZ.TextColor3 = Color3.fromRGB(255, 255, 255)
FloatZ.ZIndex = 11
FloatZ.Parent = FloatBtn

local FloatGrad = Instance.new("UIGradient")
FloatGrad.Color = Z_RED
FloatGrad.Rotation = 90
FloatGrad.Parent = FloatZ

-- =============================================================================
-- ОТКРЫТИЕ / ЗАКРЫТИЕ МЕНЮ (анимация из центра)
-- =============================================================================
local sbFinal, tbFinal = Sidebar.Position, TopBar.Position
local c1Final, c2Final = Col1.Position, Col2.Position
local menuOpen, busy = false, false

local function openMenu()
    if menuOpen or busy then return end
    busy, menuOpen = true, true
    play("Open")

    Holder.Visible = true
    MainScale.Scale = 0.02
    Sidebar.Position = sbFinal + UDim2.new(0, -45, 0, 0)
    TopBar.Position  = tbFinal + UDim2.new(0, 0, 0, -24)
    Col1.Position    = c1Final + UDim2.new(0, 0, 0, 50)
    Col2.Position    = c2Final + UDim2.new(0, 0, 0, 50)

    tw(MainScale, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})

    local info = TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    task.delay(0.15, function()
        tw(Sidebar, info, {Position = sbFinal})
        tw(TopBar, info, {Position = tbFinal})
    end)
    task.delay(0.25, function() tw(Col1, info, {Position = c1Final}) end)
    task.delay(0.33, function() tw(Col2, info, {Position = c2Final}) end)
    task.delay(0.9, function() busy = false end)
end

local function closeMenu()
    if not menuOpen or busy then return end
    busy, menuOpen = true, false
    play("Close")

    local t = tw(MainScale, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.02})
    t.Completed:Connect(function()
        if not menuOpen then Holder.Visible = false end
        busy = false
    end)
end

local function toggleMenu()
    if menuOpen then closeMenu() else openMenu() end
end

makeDraggable(FloatBtn, FloatBtn, function()
    play("Click")
    toggleMenu()
end)

MenuBtn.MouseButton1Click:Connect(function()
    play("Click")
    closeMenu()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == CONFIG.ToggleKey then
        toggleMenu()
    end
end)

-- =============================================================================
-- ИНТРО: чёрный экран, красная Z, Zynth
-- =============================================================================
local function runIntro()
    local Intro = Instance.new("Frame")
    Intro.Name = "Intro"
    Intro.Size = UDim2.new(1, 0, 1, 0)
    Intro.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Intro.BackgroundTransparency = 1
    Intro.BorderSizePixel = 0
    Intro.Active = true
    Intro.ZIndex = 50
    Intro.Parent = ScreenGui

    local ok = pcall(function()
        local Group = Instance.new("Frame")
        Group.AnchorPoint = Vector2.new(0.5, 0.5)
        Group.Position = UDim2.new(0.5, 0, 0.5, 0)
        Group.Size = UDim2.new(0, 500, 0, 200)
        Group.BackgroundTransparency = 1
        Group.ZIndex = 51
        Group.Parent = Intro

        local vp = Camera.ViewportSize
        local GS = Instance.new("UIScale")
        GS.Scale = math.clamp(math.min(vp.X / 440, vp.Y / 230), 0.5, 1.4)
        GS.Parent = Group

        local FONT, SIZE = Enum.Font.GothamBlack, 96
        local zw = TextService:GetTextSize("Z", SIZE, FONT, Vector2.new(1000, 1000)).X + 8
        local yw = TextService:GetTextSize(CONFIG.IntroText, SIZE, FONT, Vector2.new(1000, 1000)).X + 8
        local total = zw + yw
        local zEnd = -total / 2 + zw / 2   -- центр Z после сдвига
        local yEndX = -total / 2 + zw      -- левый край надписи в конце
        local yStartX = -zw * 0.35         -- откуда она "выходит"

        local Glow = Instance.new("ImageLabel")
        Glow.AnchorPoint = Vector2.new(0.5, 0.5)
        Glow.Position = UDim2.new(0.5, 0, 0.5, 0)
        Glow.Size = UDim2.new(0, 300, 0, 300)
        Glow.BackgroundTransparency = 1
        Glow.Image = GLOW_IMG
        Glow.ImageColor3 = THEME.Accent
        Glow.ImageTransparency = 1
        Glow.ZIndex = 52
        Glow.Parent = Group

        local Word = Instance.new("TextLabel")
        Word.AnchorPoint = Vector2.new(0, 0.5)
        Word.Position = UDim2.new(0.5, yStartX, 0.5, 0)
        Word.Size = UDim2.new(0, yw, 0, SIZE + 20)
        Word.BackgroundTransparency = 1
        Word.Text = CONFIG.IntroText
        Word.Font = FONT
        Word.TextSize = SIZE
        Word.TextColor3 = Color3.fromRGB(255, 255, 255)
        Word.TextTransparency = 1
        Word.TextXAlignment = Enum.TextXAlignment.Left
        Word.ZIndex = 53
        Word.Parent = Group

        local Z = Instance.new("TextLabel")
        Z.AnchorPoint = Vector2.new(0.5, 0.5)
        Z.Position = UDim2.new(0.5, 0, 0.5, 0)
        Z.Size = UDim2.new(0, zw, 0, SIZE + 20)
        Z.BackgroundTransparency = 1
        Z.Text = "Z"
        Z.Font = FONT
        Z.TextSize = SIZE
        Z.TextColor3 = Color3.fromRGB(255, 255, 255)
        Z.TextTransparency = 1
        Z.ZIndex = 54
        Z.Parent = Group

        local ZGrad = Instance.new("UIGradient")
        ZGrad.Color = Z_RED
        ZGrad.Rotation = 90
        ZGrad.Parent = Z

        local ZStroke = stroke(Z, THEME.Accent, 2.5, 1)

        local ZScale = Instance.new("UIScale")
        ZScale.Scale = 0.45
        ZScale.Parent = Z

        -- 1. затемнение + появление Z
        tw(Intro, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {BackgroundTransparency = 0})
        task.wait(0.35)
        play("Intro")
        tw(Z, TweenInfo.new(0.7, Enum.EasingStyle.Quad), {TextTransparency = 0})
        tw(ZStroke, TweenInfo.new(0.7), {Transparency = 0.5})
        tw(ZScale, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
        tw(Glow, TweenInfo.new(0.9), {ImageTransparency = 0.5})
        task.wait(1.1)

        -- 2. Z уезжает влево, из неё выходит слово
        play("Slide")
        local slide = TweenInfo.new(1.0, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
        tw(Z, slide, {Position = UDim2.new(0.5, zEnd, 0.5, 0)})
        tw(Glow, slide, {Position = UDim2.new(0.5, zEnd, 0.5, 0)})
        task.delay(0.15, function()
            tw(Word, slide, {Position = UDim2.new(0.5, yEndX, 0.5, 0), TextTransparency = 0})
        end)
        task.wait(2.0)

        -- 3. слово заходит обратно, Z возвращается
        play("Slide", 0.85)
        tw(Word, slide, {Position = UDim2.new(0.5, yStartX, 0.5, 0), TextTransparency = 1})
        task.delay(0.15, function()
            tw(Z, slide, {Position = UDim2.new(0.5, 0, 0.5, 0)})
            tw(Glow, slide, {Position = UDim2.new(0.5, 0, 0.5, 0)})
        end)
        task.wait(1.3)

        -- 4. всё исчезает
        local fade = TweenInfo.new(0.55, Enum.EasingStyle.Quad)
        tw(Intro, fade, {BackgroundTransparency = 1})
        tw(Z, fade, {TextTransparency = 1})
        tw(ZStroke, fade, {Transparency = 1})
        tw(Glow, fade, {ImageTransparency = 1})
        task.wait(0.55)
    end)

    Intro:Destroy()
    return ok
end

task.spawn(function()
    runIntro()

    -- кнопка Z появляется
    FloatBtn.Visible = true
    tw(FloatBtnScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})

    -- меню вылетает из центра
    openMenu()
end)
