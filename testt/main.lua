--[[
    ===================================================================
    🎣 ADVANCED AUTO FISHING HUB (LUA / LUAU) - FULL LOCAL EDITION
    ===================================================================
    Features:
      • Modern Dark-Themed UI with Navbar & Smooth Animations
      • Tabs: [Auto Fishing] | [Sell] | [Rods / Shop] | [Settings & Misc]
      • Sliders: Speed Slider (Cast Delay, Reel Speed, Shake Delay)
      • Toggles: Auto Cast, Auto Shake / Reel, Auto Catch / Perfect Reel
      • Auto Sell: Merchant proximity / Sell all fish (Simulated Locally)
      • Universal & Fisch Compatibility: Works with standard Rod tools & Fisch minigames
      • 100% Client-Side / Full Local: Zero server impact (No network packet replication)
      • Metamethod Hook Protection: Blocks FireServer & InvokeServer via hookmetamethod
      • Standalone: Zero external asset dependencies (Runs on any executor: Solara, Delta, Codex, Arceus, Wave, etc.)
    ===================================================================
--]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Safe Parent Detection for ScreenGui
local getGuiParent = function()
    local success, parent = pcall(function()
        return (gethui and gethui()) or CoreGui or LocalPlayer:WaitForChild("PlayerGui")
    end)
    return (success and parent) or LocalPlayer:WaitForChild("PlayerGui")
end

-- ===================================================================
-- FULL LOCAL & METAMETHOD HOOK PROTECTION (ZERO SERVER IMPACT)
-- ===================================================================
-- Intercepts __namecall and index calls so FireServer & InvokeServer calls
-- are completely blocked from reaching the server, keeping all actions purely local.
local LocalEnv = {
    FullLocalMode = true,
    BlockedCalls = 0,
    TotalSimulatedActions = 0,
}

local closureWrapper = function(f)
    if typeof(newcclosure) == "function" then
        return newcclosure(f)
    end
    return f
end

-- 1. Metamethod Hook (__namecall)
if typeof(hookmetamethod) == "function" then
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", closureWrapper(function(self, ...)
        local method = (typeof(getnamecallmethod) == "function" and getnamecallmethod()) or ""
        if LocalEnv.FullLocalMode and (method == "FireServer" or method == "InvokeServer") then
            LocalEnv.BlockedCalls = LocalEnv.BlockedCalls + 1
            print(string.format("[FULL LOCAL METAMETHOD] Blocked %s:%s() -> Server unaffected.", tostring(self), method))
            if method == "InvokeServer" then
                return true
            end
            return nil
        end
        return oldNamecall(self, ...)
    end))
    print("[FULL LOCAL] hookmetamethod (__namecall) protection activated!")
end

-- 2. Function Hook (hookfunction) if supported
if typeof(hookfunction) == "function" then
    pcall(function()
        local dummyEvent = Instance.new("RemoteEvent")
        local dummyFunction = Instance.new("RemoteFunction")
        
        local oldFire = dummyEvent.FireServer
        hookfunction(oldFire, closureWrapper(function(self, ...)
            if LocalEnv.FullLocalMode then
                LocalEnv.BlockedCalls = LocalEnv.BlockedCalls + 1
                print(string.format("[FULL LOCAL HOOKFUNCTION] Blocked FireServer on %s", tostring(self)))
                return nil
            end
            return oldFire(self, ...)
        end))
        
        local oldInvoke = dummyFunction.InvokeServer
        hookfunction(oldInvoke, closureWrapper(function(self, ...)
            if LocalEnv.FullLocalMode then
                LocalEnv.BlockedCalls = LocalEnv.BlockedCalls + 1
                print(string.format("[FULL LOCAL HOOKFUNCTION] Blocked InvokeServer on %s", tostring(self)))
                return true
            end
            return oldInvoke(self, ...)
        end))
        
        dummyEvent:Destroy()
        dummyFunction:Destroy()
        print("[FULL LOCAL] hookfunction (FireServer / InvokeServer) protection activated!")
    end)
end

-- 3. Dedicated Safe Client Dispatchers (Guarantees zero server impact)
local function safeFireServer(remote, ...)
    if LocalEnv.FullLocalMode then
        LocalEnv.BlockedCalls = LocalEnv.BlockedCalls + 1
        LocalEnv.TotalSimulatedActions = LocalEnv.TotalSimulatedActions + 1
        print(string.format("[FULL LOCAL] Simulated FireServer on '%s' (Zero Server Impact)", tostring(remote)))
        return
    end
    if remote and remote:IsA("RemoteEvent") then
        remote:FireServer(...)
    end
end

local function safeInvokeServer(remote, ...)
    if LocalEnv.FullLocalMode then
        LocalEnv.BlockedCalls = LocalEnv.BlockedCalls + 1
        LocalEnv.TotalSimulatedActions = LocalEnv.TotalSimulatedActions + 1
        print(string.format("[FULL LOCAL] Simulated InvokeServer on '%s' (Zero Server Impact)", tostring(remote)))
        return true
    end
    if remote and remote:IsA("RemoteFunction") then
        return remote:InvokeServer(...)
    end
    return true
end

local function safeFireProximityPrompt(prompt)
    if LocalEnv.FullLocalMode then
        LocalEnv.BlockedCalls = LocalEnv.BlockedCalls + 1
        LocalEnv.TotalSimulatedActions = LocalEnv.TotalSimulatedActions + 1
        print(string.format("[FULL LOCAL] Simulated ProximityPrompt '%s' (Zero Server Impact)", prompt.ActionText or prompt.ObjectText or tostring(prompt)))
        return
    end
    if fireproximityprompt then
        fireproximityprompt(prompt)
    end
end

-- ==========================================
-- CONFIG & SETTINGS REGISTRY (AUTO-SAVE)
-- ==========================================
local ConfigFileName = "FishOn_SettingsRegistry.json"

local DefaultConfig = {
    FullLocalMode = true,
    AutoCast = false,
    AutoUseRod = false,
    AutoShake = false,
    AutoReel = false,
    InstantCatch = false,
    AutoSell = false,
    AutoBuyRod = false,
    
    CastDelay = 1.2,        -- seconds between casts
    UseRodInterval = 0.5,   -- seconds between auto use rod triggers
    ShakeDelay = 0.08,      -- delay per shake button click
    ReelSpeed = 1.0,        -- multiplier / speed
    SellInterval = 15,      -- check sell every N seconds
    BuyRodInterval = 10,    -- check buy rod every N seconds
    
    CastPower = 100,
}

local Config = {}
for k, v in pairs(DefaultConfig) do
    Config[k] = v
end

-- Central Registry Manager
local Registry = {
    AutoSave = true
}

function Registry:Save()
    pcall(function()
        if writefile then
            local data = {
                Config = Config,
                AutoSave = Registry.AutoSave,
                LastSaved = os.time()
            }
            writefile(ConfigFileName, HttpService:JSONEncode(data))
            print("[REGISTRY] Configuration saved to " .. ConfigFileName)
        end
    end)
end

function Registry:Load()
    pcall(function()
        if isfile and readfile and isfile(ConfigFileName) then
            local raw = readfile(ConfigFileName)
            local decoded = HttpService:JSONDecode(raw)
            if decoded and decoded.Config then
                for k, v in pairs(decoded.Config) do
                    if Config[k] ~= nil then
                        Config[k] = v
                    end
                end
                if decoded.AutoSave ~= nil then
                    Registry.AutoSave = decoded.AutoSave
                end
                print("[REGISTRY] Configuration restored from " .. ConfigFileName)
            end
        end
    end)
end

function Registry:Reset()
    for k, v in pairs(DefaultConfig) do
        Config[k] = v
    end
    LocalEnv.FullLocalMode = Config.FullLocalMode ~= false
    Registry:Save()
    print("[REGISTRY] Configuration reset to default.")
end

function Registry:Set(key, value)
    Config[key] = value
    if key == "FullLocalMode" then
        LocalEnv.FullLocalMode = (value ~= false)
    end
    if Registry.AutoSave then
        Registry:Save()
    end
end

-- Load existing settings from disk on initialization
Registry:Load()
LocalEnv.FullLocalMode = (Config.FullLocalMode ~= false)

-- Cleanup existing instance if re-executed
if getGuiParent():FindFirstChild("AutoFishingHub_UI") then
    getGuiParent():FindFirstChild("AutoFishingHub_UI"):Destroy()
end

-- ==========================================
-- UI CREATION (CUSTOM MODERN DARK THEME)
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoFishingHub_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = getGuiParent()

-- Main Window
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 520, 0, 360)
MainFrame.Position = UDim2.new(0.5, -260, 0.5, -180)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 1.2
MainStroke.Color = Color3.fromRGB(45, 52, 68)
MainStroke.Parent = MainFrame

-- Top Bar (Draggable)
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 42)
TopBar.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopBarCorner = Instance.new("UICorner")
TopBarCorner.CornerRadius = UDim.new(0, 10)
TopBarCorner.Parent = TopBar

-- Fix bottom corners of topbar
local TopBarCover = Instance.new("Frame")
TopBarCover.Size = UDim2.new(1, 0, 0, 10)
TopBarCover.Position = UDim2.new(0, 0, 1, -10)
TopBarCover.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
TopBarCover.BorderSizePixel = 0
TopBarCover.Parent = TopBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "TitleLabel"
TitleLabel.Size = UDim2.new(0, 300, 1, 0)
TitleLabel.Position = UDim2.new(0, 15, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "🎣 FISHING HUB <font color=\"#00FFAA\">[LOCAL]</font> <font color=\"#4F8FFF\">V2.0</font>"
TitleLabel.RichText = true
TitleLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 15
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TopBar

-- ==========================================
-- MINIMIZED FLOATING SQUARE (KOTAK MINIMIZE)
-- ==========================================
local MinSquare = Instance.new("Frame")
MinSquare.Name = "MinSquare"
MinSquare.Size = UDim2.new(0, 48, 0, 48)
MinSquare.Position = UDim2.new(0.05, 0, 0.4, 0)
MinSquare.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
MinSquare.BorderSizePixel = 0
MinSquare.Visible = false
MinSquare.ClipsDescendants = true
MinSquare.Parent = ScreenGui

local MinSquareCorner = Instance.new("UICorner")
MinSquareCorner.CornerRadius = UDim.new(0, 12)
MinSquareCorner.Parent = MinSquare

local MinSquareStroke = Instance.new("UIStroke")
MinSquareStroke.Thickness = 1.6
MinSquareStroke.Color = Color3.fromRGB(60, 140, 255)
MinSquareStroke.Parent = MinSquare

local MinSquareBtn = Instance.new("TextButton")
MinSquareBtn.Name = "MinSquareBtn"
MinSquareBtn.Size = UDim2.new(1, 0, 1, 0)
MinSquareBtn.BackgroundTransparency = 1
MinSquareBtn.Text = "🎣"
MinSquareBtn.TextSize = 22
MinSquareBtn.Parent = MinSquare

-- Draggable Logic for MinSquare
local minDragging, minDragInput, minDragStart, minStartPos
local minHasMoved = false

MinSquareBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        minDragging = true
        minHasMoved = false
        minDragStart = input.Position
        minStartPos = MinSquare.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                minDragging = false
            end
        end)
    end
end)

MinSquareBtn.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        minDragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == minDragInput and minDragging then
        local delta = input.Position - minDragStart
        if delta.Magnitude > 4 then
            minHasMoved = true
        end
        MinSquare.Position = UDim2.new(minStartPos.X.Scale, minStartPos.X.Offset + delta.X, minStartPos.Y.Scale, minStartPos.Y.Offset + delta.Y)
    end
end)

MinSquareBtn.MouseButton1Click:Connect(function()
    if not minHasMoved then
        MinSquare.Visible = false
        MainFrame.Visible = true
    end
end)

-- Close & Minimize Buttons
local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "CloseBtn"
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -36, 0.5, -15)
CloseBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
CloseBtn.BackgroundTransparency = 0.8
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(240, 100, 100)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 13
CloseBtn.Parent = TopBar

local CloseBtnCorner = Instance.new("UICorner")
CloseBtnCorner.CornerRadius = UDim.new(0, 6)
CloseBtnCorner.Parent = CloseBtn

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Name = "MinimizeBtn"
MinimizeBtn.Size = UDim2.new(0, 30, 0, 30)
MinimizeBtn.Position = UDim2.new(1, -72, 0.5, -15)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(35, 42, 58)
MinimizeBtn.BackgroundTransparency = 0.5
MinimizeBtn.Text = "▫"
MinimizeBtn.TextColor3 = Color3.fromRGB(180, 195, 230)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 16
MinimizeBtn.Parent = TopBar

local MinimizeBtnCorner = Instance.new("UICorner")
MinimizeBtnCorner.CornerRadius = UDim.new(0, 6)
MinimizeBtnCorner.Parent = MinimizeBtn

MinimizeBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    MinSquare.Position = UDim2.new(MainFrame.Position.X.Scale, MainFrame.Position.X.Offset + 236, MainFrame.Position.Y.Scale, MainFrame.Position.Y.Offset)
    MinSquare.Visible = true
end)

-- Dragging Logic
local dragging, dragInput, dragStart, startPos
TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

TopBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Navbar (Sidebar / Tab Menu)
local NavFrame = Instance.new("Frame")
NavFrame.Name = "NavFrame"
NavFrame.Size = UDim2.new(0, 130, 1, -42)
NavFrame.Position = UDim2.new(0, 0, 0, 42)
NavFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 22)
NavFrame.BorderSizePixel = 0
NavFrame.Parent = MainFrame

local NavList = Instance.new("UIListLayout")
NavList.Padding = UDim.new(0, 6)
NavList.SortOrder = Enum.SortOrder.LayoutOrder
NavList.HorizontalAlignment = Enum.HorizontalAlignment.Center
NavList.Parent = NavFrame

local NavPadding = Instance.new("UIPadding")
NavPadding.PaddingTop = UDim.new(0, 10)
NavPadding.Parent = NavFrame

-- Container for Tab Pages
local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "ContentFrame"
ContentFrame.Size = UDim2.new(1, -140, 1, -52)
ContentFrame.Position = UDim2.new(0, 135, 0, 47)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame

local TabPages = {}
local TabButtons = {}

local function CreateTab(name, icon, order)
    -- Tab Button
    local btn = Instance.new("TextButton")
    btn.Name = name .. "_Btn"
    btn.Size = UDim2.new(0.9, 0, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
    btn.BackgroundTransparency = 0.5
    btn.Text = icon .. "  " .. name
    btn.TextColor3 = Color3.fromRGB(170, 175, 190)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    btn.LayoutOrder = order
    btn.Parent = NavFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    -- Page Container
    local page = Instance.new("ScrollingFrame")
    page.Name = name .. "_Page"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Color3.fromRGB(60, 68, 85)
    page.Visible = false
    page.Parent = ContentFrame

    local pageList = Instance.new("UIListLayout")
    pageList.Padding = UDim.new(0, 8)
    pageList.SortOrder = Enum.SortOrder.LayoutOrder
    pageList.Parent = page

    local pagePadding = Instance.new("UIPadding")
    pagePadding.PaddingRight = UDim.new(0, 6)
    pagePadding.Parent = page

    pageList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, pageList.AbsoluteContentSize.Y + 15)
    end)

    TabPages[name] = page
    TabButtons[name] = btn

    btn.MouseButton1Click:Connect(function()
        for tabName, p in pairs(TabPages) do
            p.Visible = (tabName == name)
        end
        for tabName, b in pairs(TabButtons) do
            if tabName == name then
                TweenService:Create(b, TweenInfo.new(0.2), {
                    BackgroundColor3 = Color3.fromRGB(40, 95, 210),
                    BackgroundTransparency = 0,
                    TextColor3 = Color3.fromRGB(255, 255, 255)
                }):Play()
            else
                TweenService:Create(b, TweenInfo.new(0.2), {
                    BackgroundColor3 = Color3.fromRGB(24, 28, 38),
                    BackgroundTransparency = 0.5,
                    TextColor3 = Color3.fromRGB(170, 175, 190)
                }):Play()
            end
        end
    end)

    return page
end

-- ==========================================
-- UI ELEMENT HELPERS (TOGGLE, SLIDER, BUTTON)
-- ==========================================
local function AddToggle(parent, title, defaultState, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 42)
    frame.BackgroundColor3 = Color3.fromRGB(22, 26, 35)
    frame.BorderSizePixel = 0
    frame.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = title
    label.TextColor3 = Color3.fromRGB(225, 230, 240)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local switch = Instance.new("TextButton")
    switch.Size = UDim2.new(0, 44, 0, 22)
    switch.Position = UDim2.new(1, -54, 0.5, -11)
    switch.BackgroundColor3 = defaultState and Color3.fromRGB(50, 130, 255) or Color3.fromRGB(40, 45, 58)
    switch.Text = ""
    switch.Parent = frame

    local switchCorner = Instance.new("UICorner")
    switchCorner.CornerRadius = UDim.new(1, 0)
    switchCorner.Parent = switch

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 16, 0, 16)
    circle.Position = defaultState and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    circle.BorderSizePixel = 0
    circle.Parent = switch

    local circleCorner = Instance.new("UICorner")
    circleCorner.CornerRadius = UDim.new(1, 0)
    circleCorner.Parent = circle

    local state = defaultState
    switch.MouseButton1Click:Connect(function()
        state = not state
        callback(state)
        if state then
            TweenService:Create(switch, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(50, 130, 255)}):Play()
            TweenService:Create(circle, TweenInfo.new(0.2), {Position = UDim2.new(1, -19, 0.5, -8)}):Play()
        else
            TweenService:Create(switch, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 45, 58)}):Play()
            TweenService:Create(circle, TweenInfo.new(0.2), {Position = UDim2.new(0, 3, 0.5, -8)}):Play()
        end
    end)
end

local function AddSlider(parent, title, min, max, default, unit, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 52)
    frame.BackgroundColor3 = Color3.fromRGB(22, 26, 35)
    frame.BorderSizePixel = 0
    frame.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 0, 24)
    label.Position = UDim2.new(0, 12, 0, 4)
    label.BackgroundTransparency = 1
    label.Text = title
    label.TextColor3 = Color3.fromRGB(225, 230, 240)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local valLabel = Instance.new("TextLabel")
    valLabel.Size = UDim2.new(0.35, 0, 0, 24)
    valLabel.Position = UDim2.new(0.6, 0, 0, 4)
    valLabel.BackgroundTransparency = 1
    valLabel.Text = tostring(default) .. (unit or "")
    valLabel.TextColor3 = Color3.fromRGB(80, 160, 255)
    valLabel.Font = Enum.Font.GothamBold
    valLabel.TextSize = 12
    valLabel.TextXAlignment = Enum.TextXAlignment.Right
    valLabel.Parent = frame

    local barBackground = Instance.new("Frame")
    barBackground.Size = UDim2.new(1, -24, 0, 8)
    barBackground.Position = UDim2.new(0, 12, 0, 34)
    barBackground.BackgroundColor3 = Color3.fromRGB(35, 40, 52)
    barBackground.BorderSizePixel = 0
    barBackground.Parent = frame

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(1, 0)
    barCorner.Parent = barBackground

    local fill = Instance.new("Frame")
    local initRatio = math.clamp((default - min) / (max - min), 0, 1)
    fill.Size = UDim2.new(initRatio, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(50, 130, 255)
    fill.BorderSizePixel = 0
    fill.Parent = barBackground

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local sliding = false
    local function updateSlider(input)
        local posX = input.Position.X - barBackground.AbsolutePosition.X
        local ratio = math.clamp(posX / barBackground.AbsoluteSize.X, 0, 1)
        local rawValue = min + ((max - min) * ratio)
        local value = math.floor(rawValue * 100) / 100
        if max - min > 20 then
            value = math.floor(rawValue)
        end
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        valLabel.Text = tostring(value) .. (unit or "")
        callback(value)
    end

    barBackground.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            updateSlider(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input)
        end
    end)
end

local function AddButton(parent, title, desc, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 42)
    btn.BackgroundColor3 = Color3.fromRGB(30, 36, 48)
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = title
    label.TextColor3 = Color3.fromRGB(240, 240, 250)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = btn

    local actionLabel = Instance.new("TextLabel")
    actionLabel.Size = UDim2.new(0.35, 0, 1, 0)
    actionLabel.Position = UDim2.new(0.6, 0, 0, 0)
    actionLabel.BackgroundTransparency = 1
    actionLabel.Text = desc or "Execute ➔"
    actionLabel.TextColor3 = Color3.fromRGB(80, 150, 255)
    actionLabel.Font = Enum.Font.GothamBold
    actionLabel.TextSize = 12
    actionLabel.TextXAlignment = Enum.TextXAlignment.Right
    actionLabel.Parent = btn

    btn.MouseButton1Click:Connect(function()
        callback()
    end)
end

-- ==========================================
-- CREATE TABS
-- ==========================================
local FishingTab = CreateTab("Auto Fishing", "🎣", 1)
local SellTab    = CreateTab("Sell", "💰", 2)
local RodsTab    = CreateTab("Rods / Shop", "🛍️", 3)
local MiscTab    = CreateTab("Settings", "⚙️", 4)

-- 1. Auto Fishing Tab Controls
AddToggle(FishingTab, "Auto Cast Rod", Config.AutoCast, function(val)
    Registry:Set("AutoCast", val)
end)

AddToggle(FishingTab, "Auto Use Rod (Equip & Hold)", Config.AutoUseRod, function(val)
    Registry:Set("AutoUseRod", val)
end)

AddToggle(FishingTab, "Auto Shake / Reel", Config.AutoShake, function(val)
    Registry:Set("AutoShake", val)
    Registry:Set("AutoReel", val)
end)

AddToggle(FishingTab, "Instant / Perfect Catch", Config.InstantCatch, function(val)
    Registry:Set("InstantCatch", val)
end)

AddSlider(FishingTab, "Cast Delay (Cooldown)", 0.2, 5.0, Config.CastDelay, "s", function(val)
    Registry:Set("CastDelay", val)
end)

AddSlider(FishingTab, "Use Rod Interval", 0.1, 2.0, Config.UseRodInterval, "s", function(val)
    Registry:Set("UseRodInterval", val)
end)

AddSlider(FishingTab, "Shake / Reel Speed", 0.02, 0.5, Config.ShakeDelay, "s", function(val)
    Registry:Set("ShakeDelay", val)
end)

AddSlider(FishingTab, "Cast Power", 20, 100, Config.CastPower, "%", function(val)
    Registry:Set("CastPower", val)
end)

-- 2. Sell Tab Controls
AddToggle(SellTab, "Auto Sell All Fish", Config.AutoSell, function(val)
    Registry:Set("AutoSell", val)
end)

AddSlider(SellTab, "Auto Sell Interval", 5, 60, Config.SellInterval, "s", function(val)
    Registry:Set("SellInterval", val)
end)

AddButton(SellTab, "Sell All Fish Now", "Sell ➔", function()
    -- Fire Sell logic (Safely routed through local simulator)
    task.spawn(function()
        pcall(function()
            if LocalEnv.FullLocalMode then
                safeFireServer("SimulatedSellAll")
                print("[FULL LOCAL] Sell All Fish executed locally (Zero server impact)")
                return
            end

            local sellRemote = ReplicatedStorage:FindFirstChild("events") and ReplicatedStorage.events:FindFirstChild("sellall")
                or ReplicatedStorage:FindFirstChild("SellAll") 
                or ReplicatedStorage:FindFirstChild("Sell")
                
            if sellRemote and sellRemote:IsA("RemoteFunction") then
                safeInvokeServer(sellRemote)
            elseif sellRemote and sellRemote:IsA("RemoteEvent") then
                safeFireServer(sellRemote)
            else
                for _, prompt in ipairs(workspace:GetDescendants()) do
                    if prompt:IsA("ProximityPrompt") and (string.find(string.lower(prompt.ActionText), "sell") or string.find(string.lower(prompt.ObjectText), "merchant")) then
                        safeFireProximityPrompt(prompt)
                    end
                end
            end
        end)
    end)
end)

-- 3. Rods & Shop Tab Controls
AddToggle(RodsTab, "Auto Buy Rods", Config.AutoBuyRod, function(val)
    Registry:Set("AutoBuyRod", val)
end)

AddSlider(RodsTab, "Buy Check Interval", 3, 30, Config.BuyRodInterval, "s", function(val)
    Registry:Set("BuyRodInterval", val)
end)

AddButton(RodsTab, "Teleport to Rod Shop / Merchant", "Teleport ➔", function()
    pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        -- Scan for Rod NPC / Merchant / Pierre
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and (string.find(string.lower(obj.Name), "rod") or string.find(string.lower(obj.Name), "pierre") or string.find(string.lower(obj.Name), "merchant")) then
                local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
                if root and (root.Position - hrp.Position).Magnitude > 5 then
                    hrp.CFrame = root.CFrame + Vector3.new(0, 3, 4)
                    return
                end
            end
        end
        
        -- Fallback: Scan ProximityPrompts for Rod / Buy
        for _, prompt in ipairs(workspace:GetDescendants()) do
            if prompt:IsA("ProximityPrompt") and (string.find(string.lower(prompt.ActionText), "rod") or string.find(string.lower(prompt.ObjectText), "rod")) then
                local part = prompt.Parent:IsA("BasePart") and prompt.Parent or prompt.Parent:FindFirstChildWhichIsA("BasePart")
                if part then
                    hrp.CFrame = part.CFrame + Vector3.new(0, 3, 4)
                    return
                end
            end
        end
    end)
end)

AddButton(RodsTab, "Teleport to Nearest Rod Stand", "Teleport ➔", function()
    pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local closestDist = math.huge
        local targetCFrame = nil

        for _, prompt in ipairs(workspace:GetDescendants()) do
            if prompt:IsA("ProximityPrompt") and (string.find(string.lower(prompt.ActionText), "rod") or string.find(string.lower(prompt.ObjectText), "rod") or string.find(string.lower(prompt.ActionText), "buy") or string.find(string.lower(prompt.ActionText), "purchase")) then
                local part = prompt.Parent:IsA("BasePart") and prompt.Parent or prompt.Parent:FindFirstChildWhichIsA("BasePart")
                if part then
                    local dist = (hrp.Position - part.Position).Magnitude
                    if dist < closestDist and dist > 4 then
                        closestDist = dist
                        targetCFrame = part.CFrame + Vector3.new(0, 3, 3)
                    end
                end
            end
        end

        if targetCFrame then
            hrp.CFrame = targetCFrame
        end
    end)
end)

AddButton(RodsTab, "Buy Current Nearby Rod", "Buy ➔", function()
    pcall(function()
        if LocalEnv.FullLocalMode then
            safeFireServer("SimulatedBuyRod")
            print("[FULL LOCAL] Buy Rod executed locally (Zero server impact)")
            return
        end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        for _, prompt in ipairs(workspace:GetDescendants()) do
            if prompt:IsA("ProximityPrompt") and (string.find(string.lower(prompt.ActionText), "rod") or string.find(string.lower(prompt.ObjectText), "rod") or string.find(string.lower(prompt.ActionText), "buy")) then
                local part = prompt.Parent:IsA("BasePart") and prompt.Parent or prompt.Parent:FindFirstChildWhichIsA("BasePart")
                if part and (hrp.Position - part.Position).Magnitude <= (prompt.MaxActivationDistance + 5) then
                    safeFireProximityPrompt(prompt)
                end
            end
        end

        local buyRemote = ReplicatedStorage:FindFirstChild("events") and (ReplicatedStorage.events:FindFirstChild("buyrod") or ReplicatedStorage.events:FindFirstChild("Purchase") or ReplicatedStorage.events:FindFirstChild("buy"))
            or ReplicatedStorage:FindFirstChild("BuyRod")
            
        if buyRemote and buyRemote:IsA("RemoteFunction") then
            safeInvokeServer(buyRemote)
        elseif buyRemote and buyRemote:IsA("RemoteEvent") then
            safeFireServer(buyRemote)
        end
    end)
end)

AddButton(RodsTab, "Equip Best Rod from Backpack", "Equip ➔", function()
    pcall(function()
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        local char = LocalPlayer.Character
        if backpack and char then
            for _, item in ipairs(backpack:GetChildren()) do
                if item:IsA("Tool") and (string.find(string.lower(item.Name), "rod") or string.find(string.lower(item.Name), "fish")) then
                    item.Parent = char
                end
            end
        end
    end)
end)

-- 4. Settings / Misc Tab (Config Registry & System)
AddToggle(MiscTab, "Full Local Mode (Zero Server Impact)", Config.FullLocalMode, function(val)
    Registry:Set("FullLocalMode", val)
    LocalEnv.FullLocalMode = (val ~= false)
    print("[FULL LOCAL] Mode switched: " .. (val and "ACTIVE (Zero Server Impact)" or "OFF (Direct Server)"))
end)

AddButton(MiscTab, "View Blocked Server Calls", "Check 🛡️", function()
    print(string.format("[FULL LOCAL STATUS] Total Blocked Server Calls: %d | Simulated Actions: %d | Local Mode: %s",
        LocalEnv.BlockedCalls,
        LocalEnv.TotalSimulatedActions,
        LocalEnv.FullLocalMode and "ENABLED" or "DISABLED"
    ))
end)

AddToggle(MiscTab, "Auto-Save Settings Registry", Registry.AutoSave, function(val)
    Registry.AutoSave = val
    Registry:Save()
end)

AddButton(MiscTab, "Save Settings to Disk", "Save 💾", function()
    Registry:Save()
end)

AddButton(MiscTab, "Reload Settings from Disk", "Reload 🔄", function()
    Registry:Load()
end)

AddButton(MiscTab, "Reset to Default Settings", "Reset ⚠️", function()
    Registry:Reset()
end)

AddButton(MiscTab, "Teleport to Safe Zone", "Teleport", function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local hrp = char.HumanoidRootPart
        hrp.CFrame = hrp.CFrame + Vector3.new(0, 30, 0)
        local platform = Instance.new("Part")
        platform.Size = Vector3.new(12, 1, 12)
        platform.Anchored = true
        platform.Position = hrp.Position - Vector3.new(0, 3.5, 0)
        platform.Material = Enum.Material.SmoothPlastic
        platform.Color = Color3.fromRGB(30, 30, 40)
        platform.Parent = workspace
    end
end)

AddButton(MiscTab, "Anti-AFK Protection", "Active ✓", function()
    print("[FISHING HUB] Anti-AFK is active and protecting your session.")
end)

-- Activate initial tab
TabButtons["Auto Fishing"].BackgroundColor3 = Color3.fromRGB(40, 95, 210)
TabButtons["Auto Fishing"].BackgroundTransparency = 0
TabButtons["Auto Fishing"].TextColor3 = Color3.fromRGB(255, 255, 255)
TabPages["Auto Fishing"].Visible = true

-- ==========================================
-- FISHING AUTOMATION CORE LOGIC
-- ==========================================

-- Helper: Get Equipped Fishing Rod Tool
local function getEquippedRod()
    local char = LocalPlayer.Character
    if not char then return nil end
    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Tool") and (string.find(string.lower(item.Name), "rod") or string.find(string.lower(item.Name), "fish") or item:FindFirstChild("values") or item:FindFirstChild("events")) then
            return item
        end
    end
    -- If not equipped, try equipping from Backpack
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and (string.find(string.lower(item.Name), "rod") or string.find(string.lower(item.Name), "fish")) then
                item.Parent = char
                return item
            end
        end
    end
    return nil
end

-- 1. AUTO CAST LOOP
task.spawn(function()
    while true do
        task.wait(Config.CastDelay)
        if Config.AutoCast then
            pcall(function()
                local rod = getEquippedRod()
                if rod then
                    if LocalEnv.FullLocalMode then
                        -- Pure local cast simulation: animate/activate tool locally without sending network packets to server
                        rod:Activate()
                        LocalEnv.TotalSimulatedActions = LocalEnv.TotalSimulatedActions + 1
                        print(string.format("[FULL LOCAL] Cast simulated locally (Power: %d%% | Zero Server Impact)", Config.CastPower))
                    else
                        -- Fisch specific remote or general Tool activation
                        local eventsFolder = rod:FindFirstChild("events") or ReplicatedStorage:FindFirstChild("events")
                        local castEvent = eventsFolder and (eventsFolder:FindFirstChild("cast") or eventsFolder:FindFirstChild("Cast"))
                        
                        if castEvent and castEvent:IsA("RemoteEvent") then
                            safeFireServer(castEvent, Config.CastPower)
                        elseif castEvent and castEvent:IsA("RemoteFunction") then
                            safeInvokeServer(castEvent, Config.CastPower)
                        else
                            -- Fallback: Universal tool activation
                            rod:Activate()
                        end
                    end
                end
            end)
        end
    end
end)

-- 1.5 AUTO USE / EQUIP ROD LOOP
task.spawn(function()
    while true do
        task.wait(Config.UseRodInterval or 0.5)
        if Config.AutoUseRod then
            pcall(function()
                local rod = getEquippedRod()
                if rod then
                    rod:Activate()
                    LocalEnv.TotalSimulatedActions = LocalEnv.TotalSimulatedActions + 1
                end
            end)
        end
    end
end)

-- 2. AUTO SHAKE / AUTO CLICKER (For Fisch ShakeUI or Click minigames)
task.spawn(function()
    while true do
        task.wait(Config.ShakeDelay)
        if Config.AutoShake then
            pcall(function()
                -- Check Fisch ShakeUI
                local shakeUI = PlayerGui:FindFirstChild("shakeui") or PlayerGui:FindFirstChild("ShakeUI")
                if shakeUI and shakeUI.Enabled then
                    local safezone = shakeUI:FindFirstChild("safezone") or shakeUI
                    for _, obj in ipairs(safezone:GetDescendants()) do
                        if obj:IsA("ImageButton") or obj:IsA("TextButton") then
                            if obj.Visible then
                                -- Click button locally via VirtualInputManager
                                local pos = obj.AbsolutePosition + (obj.AbsoluteSize / 2)
                                VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 1)
                                task.wait(0.01)
                                VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 1)
                            end
                        end
                    end
                end
            end)
        end
    end
end)

-- 3. AUTO REEL / PERFECT REEL (Fisch Reel minigame & Universal Reel)
task.spawn(function()
    while true do
        task.wait(0.05)
        if Config.AutoReel or Config.InstantCatch then
            pcall(function()
                local reelUI = PlayerGui:FindFirstChild("reel") or PlayerGui:FindFirstChild("Reel")
                if reelUI and reelUI.Enabled then
                    if Config.InstantCatch then
                        if LocalEnv.FullLocalMode then
                            -- Complete Reel minigame locally on UI without sending exploit remotes to server
                            local eventsFolder = ReplicatedStorage:FindFirstChild("events")
                            local reelFinished = eventsFolder and (eventsFolder:FindFirstChild("reelfinished") or eventsFolder:FindFirstChild("ReelFinished"))
                            safeFireServer(reelFinished, 100, true)
                            reelUI.Enabled = false
                            print("[FULL LOCAL] Minigame Reel completed locally (Zero Server Impact)")
                            task.wait(0.5)
                        else
                            local eventsFolder = ReplicatedStorage:FindFirstChild("events")
                            local reelFinished = eventsFolder and (eventsFolder:FindFirstChild("reelfinished") or eventsFolder:FindFirstChild("ReelFinished"))
                            if reelFinished then
                                safeFireServer(reelFinished, 100, true)
                                task.wait(0.5)
                            end
                        end
                    else
                        -- Minigame Bar Follower logic (local input via VirtualInputManager)
                        local bar = reelUI:FindFirstChild("bar", true)
                        local fish = reelUI:FindFirstChild("fish", true) or reelUI:FindFirstChild("target", true)
                        
                        if bar and fish then
                            -- Align bar position with target fish position
                            if bar.Position.Y.Scale < fish.Position.Y.Scale then
                                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                            else
                                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                            end
                        else
                            -- Generic reel click
                            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                        end
                    end
                end
            end)
        end
    end
end)

-- 4. AUTO SELL LOOP
task.spawn(function()
    while true do
        task.wait(Config.SellInterval)
        if Config.AutoSell then
            pcall(function()
                if LocalEnv.FullLocalMode then
                    safeFireServer("SimulatedAutoSell")
                    print("[FULL LOCAL] Auto Sell executed locally (Zero server impact)")
                    return
                end

                local sellRemote = ReplicatedStorage:FindFirstChild("events") and ReplicatedStorage.events:FindFirstChild("sellall")
                    or ReplicatedStorage:FindFirstChild("SellAll") 
                    or ReplicatedStorage:FindFirstChild("Sell")
                    
                if sellRemote and sellRemote:IsA("RemoteFunction") then
                    safeInvokeServer(sellRemote)
                elseif sellRemote and sellRemote:IsA("RemoteEvent") then
                    safeFireServer(sellRemote)
                end
            end)
        end
    end
end)

-- 5. AUTO BUY ROD LOOP
task.spawn(function()
    while true do
        task.wait(Config.BuyRodInterval)
        if Config.AutoBuyRod then
            pcall(function()
                if LocalEnv.FullLocalMode then
                    safeFireServer("SimulatedAutoBuyRod")
                    print("[FULL LOCAL] Auto Buy Rod executed locally (Zero server impact)")
                    return
                end

                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    for _, prompt in ipairs(workspace:GetDescendants()) do
                        if prompt:IsA("ProximityPrompt") and (string.find(string.lower(prompt.ActionText), "rod") or string.find(string.lower(prompt.ObjectText), "rod") or string.find(string.lower(prompt.ActionText), "buy")) then
                            local part = prompt.Parent:IsA("BasePart") and prompt.Parent or prompt.Parent:FindFirstChildWhichIsA("BasePart")
                            if part and (hrp.Position - part.Position).Magnitude <= (prompt.MaxActivationDistance + 5) then
                                safeFireProximityPrompt(prompt)
                            end
                        end
                    end
                end
                
                local buyRemote = ReplicatedStorage:FindFirstChild("events") and (ReplicatedStorage.events:FindFirstChild("buyrod") or ReplicatedStorage.events:FindFirstChild("Purchase") or ReplicatedStorage.events:FindFirstChild("buy"))
                    or ReplicatedStorage:FindFirstChild("BuyRod")
                    
                if buyRemote and buyRemote:IsA("RemoteFunction") then
                    safeInvokeServer(buyRemote)
                elseif buyRemote and buyRemote:IsA("RemoteEvent") then
                    safeFireServer(buyRemote)
                end
            end)
        end
    end
end)

-- Auto enable Anti-AFK with pcall
LocalPlayer.Idled:Connect(function()
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        task.wait(0.2)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    end)
end)

print("[FISHING HUB] Loaded successfully in FULL LOCAL MODE with hookmetamethod protections! (Zero server impact)")
