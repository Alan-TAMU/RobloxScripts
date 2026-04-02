-- Full AutoFarm LocalScript (uses local player name automatically)
-- Paste into StarterPlayerScripts (client-side)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local player = Players.LocalPlayer

-- CONFIG
local CONFIG = {
    SwordName = "Greatsword of Flying II",
    TeleportOffset = Vector3.new(0, 4, 0),

    TeleportInterval = 0.12,
    ClickInterval = 0.12,

    EggParentPath = {"Unbreakable", "Characters", "Undead"},
    EggNames = {
        "Blue Egg","Green Egg","Pink Egg","Yellow Egg",
        "Shiny Red Egg","Shiny Pink Egg","Shiny Green Egg",
        "Golden Egg","Orange Egg",
    },

    EasterNames = {
        "Bunny Warrior","Easter Guardian","Carrot Menace","Bunny",
    },

    Debug = false,
    PerTargetTimeout = 30,
    TeleportIntervalMin = 0.03,
    TeleportIntervalMax = 2.0,
    ClickIntervalMin = 0.03,
    ClickIntervalMax = 2.0,

    AntiAFKBackupNudge = true,
    AntiAFKNudgeAmount = 0.1,
    AntiAFKNudgeInterval = 30,
}

local function dprint(...)
    if CONFIG.Debug then
        print("[AutoFarm]", ...)
    end
end

local ENEMIES = {
    Human = {"Orc", "Undead"},
    Orc   = {"Human", "Undead"},
    Undead= {"Human", "Orc"},
}

-- Basic helpers
local function getCharacter()
    return player.Character or player.CharacterAdded:Wait()
end
local function getHumanoid()
    local c = player.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function teleportToPosition(pos, lookAt)
    local char = getCharacter()
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local cf = lookAt and CFrame.new(pos, lookAt) or CFrame.new(pos)
    if char.PrimaryPart then
        char:PivotTo(cf)
    else
        root.CFrame = cf
    end
end

-- Tool helpers
local function findRealTool(toolName)
    local char = player.Character
    if char then
        local t = char:FindFirstChild(toolName)
        if t and t:IsA("Tool") then return t end
    end
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        local b = backpack:FindFirstChild(toolName)
        if b and b:IsA("Tool") then return b end
    end
    return nil
end

local function equipToolByName(toolName)
    local humanoid = getHumanoid()
    if not humanoid then return nil end
    local tool = findRealTool(toolName)
    if not tool then return nil end
    if tool.Parent ~= getCharacter() then
        humanoid:EquipTool(tool)
        task.wait(0.12)
    end
    return getCharacter():FindFirstChild(toolName) or tool
end

-- Model / target helpers
local function findEggParent()
    local cur = workspace
    for _, name in ipairs(CONFIG.EggParentPath) do
        cur = cur:FindFirstChild(name)
        if not cur then return nil end
    end
    return cur
end

local function getTargetPartFromModel(model)
    if not model then return nil end
    if model:FindFirstChild("HumanoidRootPart") then return model.HumanoidRootPart end
    if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then return model.PrimaryPart end
    for _, c in ipairs(model:GetChildren()) do
        if c:IsA("BasePart") then return c end
    end
    return nil
end

-- Round-robin getters
local function getNextEggModel(currentIndex)
    local parent = findEggParent()
    if not parent then return nil, currentIndex end
    local n = #CONFIG.EggNames
    if n == 0 then return nil, currentIndex end
    local nextIndex = (currentIndex or 1)
    local tries = 0
    while tries < n do
        local name = CONFIG.EggNames[nextIndex]
        local model = parent:FindFirstChild(name)
        if model then return model, nextIndex end
        nextIndex = nextIndex + 1
        if nextIndex > n then nextIndex = 1 end
        tries = tries + 1
    end
    return nil, nextIndex
end

-- Detect player team (searches Characters folder for player.Name)
local function detectPlayerTeam()
    local un = workspace:FindFirstChild("Unbreakable")
    if not un then return nil end
    local chars = un:FindFirstChild("Characters")
    if not chars then return nil end
    local teams = {"Human","Orc","Undead"}
    for _, team in ipairs(teams) do
        local folder = chars:FindFirstChild(team)
        if folder and folder:FindFirstChild(player.Name) then
            return team
        end
    end
    if player.Character and player.Character.Parent then
        local p = player.Character.Parent
        if p.Name == "Human" or p.Name == "Orc" or p.Name == "Undead" then
            return p.Name
        end
        if p.Parent and p.Parent.Name == "Characters" then
            local maybeTeam = p.Name
            if maybeTeam == "Human" or maybeTeam == "Orc" or maybeTeam == "Undead" then
                return maybeTeam
            end
        end
    end
    return nil
end

-- Easter getter (team-aware, avoid attacking allies) — uses player.Name to skip allies
local function getNextEasterModel(currentIndex)
    local un = workspace:FindFirstChild("Unbreakable")
    if not un then return nil, currentIndex end
    local chars = un:FindFirstChild("Characters")
    if not chars then return nil, currentIndex end

    local playerTeam = detectPlayerTeam()
    local teamsToSearch = {"Orc","Human","Undead"}
    if playerTeam and ENEMIES[playerTeam] then
        teamsToSearch = ENEMIES[playerTeam]
    end

    local names = CONFIG.EasterNames
    local n = #names
    if n == 0 then return nil, currentIndex end
    local nextIndex = (currentIndex or 1)
    local tries = 0
    while tries < n do
        local name = names[nextIndex]
        for _, teamName in ipairs(teamsToSearch) do
            local teamFolder = chars:FindFirstChild(teamName)
            if teamFolder then
                local model = teamFolder:FindFirstChild(name)
                if model and model.Name ~= player.Name then
                    return model, nextIndex
                end
                for _, child in ipairs(teamFolder:GetChildren()) do
                    if child:IsA("Model") and child.Name:lower():find(name:lower()) and child.Name ~= player.Name then
                        return child, nextIndex
                    end
                end
            end
        end
        nextIndex = nextIndex + 1
        if nextIndex > n then nextIndex = 1 end
        tries = tries + 1
    end

    return nil, nextIndex
end

-- TestDemon finder
local function getTestDemonModel()
    local un = workspace:FindFirstChild("Unbreakable")
    if not un then return nil end
    local chars = un:FindFirstChild("Characters")
    if not chars then return nil end
    local demonFolder = chars:FindFirstChild("Demon")
    if not demonFolder then return nil end
    local model = demonFolder:FindFirstChild("TestDemon")
    return model
end

-- Core attack routine
local function attackModelPersist(targetModel, shouldContinue)
    if not targetModel then return "removed" end
    local targetPart = getTargetPartFromModel(targetModel)
    if not targetPart then
        dprint("No target part for:", tostring(targetModel and targetModel.Name))
        return "removed"
    end

    local startTime = tick()
    while true do
        if shouldContinue and not shouldContinue() then
            dprint("Attack cancelled by toggle for:", targetModel.Name)
            return "cancelled"
        end

        if not targetModel.Parent then
            dprint("Target removed:", targetModel.Name)
            return "removed"
        end
        local tHum = targetModel:FindFirstChildOfClass("Humanoid")
        if tHum and tHum.Health <= 0 then
            dprint("Target dead:", targetModel.Name)
            return "dead"
        end

        -- teleport near the target
        local pos = targetPart.Position + CONFIG.TeleportOffset
        teleportToPosition(pos, targetPart.Position)

        -- equip and activate sword repeatedly for the configured teleport interval
        local sword = equipToolByName(CONFIG.SwordName)
        if not (sword and sword:IsA("Tool")) then
            dprint("Tool not available:", CONFIG.SwordName)
            return "tool_missing"
        end

        local teleInt = math.clamp(CONFIG.TeleportInterval, CONFIG.TeleportIntervalMin, CONFIG.TeleportIntervalMax)
        local clickInt = math.clamp(CONFIG.ClickInterval, CONFIG.ClickIntervalMin, CONFIG.ClickIntervalMax)
        local activations = math.max(1, math.floor(teleInt / clickInt))

        for i = 1, activations do
            if shouldContinue and not shouldContinue() then
                dprint("Attack cancelled during activations for:", targetModel.Name)
                return "cancelled"
            end
            if not targetModel.Parent then break end
            local th = targetModel:FindFirstChildOfClass("Humanoid")
            if th and th.Health <= 0 then break end
            pcall(function() sword:Activate() end)
            task.wait(clickInt)
        end

        if tick() - startTime > CONFIG.PerTargetTimeout then
            dprint("Per-target timeout reached for:", targetModel.Name)
            return "timeout"
        end
    end
end

-- Anti-AFK
local autoAntiAFK = false
local antiAFKConnection = nil
local antiAFKBackupTask = nil

local function enableAntiAFK()
    if antiAFKConnection then return end
    antiAFKConnection = player.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0,0))
        end)
        if CONFIG.AntiAFKBackupNudge then
            pcall(function()
                local char = player.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    local root = char.HumanoidRootPart
                    local orig = root.CFrame
                    root.CFrame = orig * CFrame.new(0, 0, CONFIG.AntiAFKNudgeAmount)
                    task.wait(0.12)
                    root.CFrame = orig
                end
            end)
        end
    end)

    antiAFKBackupTask = task.spawn(function()
        while autoAntiAFK do
            task.wait(CONFIG.AntiAFKNudgeInterval)
            if not autoAntiAFK then break end
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0,0))
            end)
            if CONFIG.AntiAFKBackupNudge then
                pcall(function()
                    local char = player.Character
                    if char and char:FindFirstChild("HumanoidRootPart") then
                        local root = char.HumanoidRootPart
                        local orig = root.CFrame
                        root.CFrame = orig * CFrame.new(0, 0, CONFIG.AntiAFKNudgeAmount)
                        task.wait(0.12)
                        root.CFrame = orig
                    end
                end)
            end
        end
    end)
    dprint("AntiAFK enabled")
end

local function disableAntiAFK()
    if antiAFKConnection then
        antiAFKConnection:Disconnect()
        antiAFKConnection = nil
    end
    dprint("AntiAFK disabled")
end

-- GUI creation (with floating always-visible minimize button)
local function createGui()
    local existing = player:WaitForChild("PlayerGui"):FindFirstChild("AutoEggsGui")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoEggsGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 420, 0, 240)
    frame.Position = UDim2.new(0, 24, 0.6, -120)
    frame.BackgroundColor3 = Color3.fromRGB(28,28,30)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    frame.ZIndex = 5
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,10)

    -- Title
    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, -44, 0, 28)
    title.Position = UDim2.new(0, 6, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = "Auto Farm GUI"
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 18
    title.TextColor3 = Color3.new(1,1,1)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 6

    -- Tabs
    local tabMainBtn = Instance.new("TextButton", frame)
    tabMainBtn.Size = UDim2.new(0, 120, 0, 28)
    tabMainBtn.Position = UDim2.new(0, 6, 0, 38)
    tabMainBtn.Text = "Main"
    tabMainBtn.Font = Enum.Font.SourceSans
    tabMainBtn.TextSize = 14
    tabMainBtn.BackgroundColor3 = Color3.fromRGB(40,40,42)
    tabMainBtn.TextColor3 = Color3.new(1,1,1)
    tabMainBtn.ZIndex = 6

    local tabSettingsBtn = Instance.new("TextButton", frame)
    tabSettingsBtn.Size = UDim2.new(0, 120, 0, 28)
    tabSettingsBtn.Position = UDim2.new(0, 132, 0, 38)
    tabSettingsBtn.Text = "Settings"
    tabSettingsBtn.Font = Enum.Font.SourceSans
    tabSettingsBtn.TextSize = 14
    tabSettingsBtn.BackgroundColor3 = Color3.fromRGB(40,40,42)
    tabSettingsBtn.TextColor3 = Color3.new(1,1,1)
    tabSettingsBtn.ZIndex = 6

    local content = Instance.new("Frame", frame)
    content.Size = UDim2.new(1, -12, 1, -108)
    content.Position = UDim2.new(0, 6, 0, 72)
    content.BackgroundTransparency = 1
    content.ZIndex = 5

    -- Main pane
    local mainPane = Instance.new("Frame", content)
    mainPane.Size = UDim2.new(1,0,1,0)
    mainPane.BackgroundTransparency = 1
    mainPane.ZIndex = 5

    local eggsBtn = Instance.new("TextButton", mainPane)
    eggsBtn.Size = UDim2.new(0, 110, 0, 50)
    eggsBtn.Position = UDim2.new(0, 6, 0, 6)
    eggsBtn.BackgroundColor3 = Color3.fromRGB(55,120,70)
    eggsBtn.Font = Enum.Font.SourceSansBold; eggsBtn.TextSize = 14
    eggsBtn.TextColor3 = Color3.new(1,1,1); eggsBtn.Text = "Auto Eggs: OFF"
    eggsBtn.ZIndex = 5

    local easterBtn = Instance.new("TextButton", mainPane)
    easterBtn.Size = UDim2.new(0, 110, 0, 50)
    easterBtn.Position = UDim2.new(0, 126, 0, 6)
    easterBtn.BackgroundColor3 = Color3.fromRGB(200,120,40)
    easterBtn.Font = Enum.Font.SourceSansBold; easterBtn.TextSize = 14
    easterBtn.TextColor3 = Color3.new(1,1,1); easterBtn.Text = "Auto Easter: OFF"
    easterBtn.ZIndex = 5

    local combinedBtn = Instance.new("TextButton", mainPane)
    combinedBtn.Size = UDim2.new(0, 110, 0, 50)
    combinedBtn.Position = UDim2.new(0, 246, 0, 6)
    combinedBtn.BackgroundColor3 = Color3.fromRGB(120,60,200)
    combinedBtn.Font = Enum.Font.SourceSansBold; combinedBtn.TextSize = 14
    combinedBtn.TextColor3 = Color3.new(1,1,1); combinedBtn.Text = "Auto Combined: OFF"
    combinedBtn.ZIndex = 5

    local antiAFKBtn = Instance.new("TextButton", mainPane)
    antiAFKBtn.Size = UDim2.new(0, 110, 0, 40)
    antiAFKBtn.Position = UDim2.new(0, 6, 0, 66)
    antiAFKBtn.BackgroundColor3 = Color3.fromRGB(50,90,160)
    antiAFKBtn.Font = Enum.Font.SourceSansBold; antiAFKBtn.TextSize = 14
    antiAFKBtn.TextColor3 = Color3.new(1,1,1); antiAFKBtn.Text = "Anti-AFK: OFF"
    antiAFKBtn.ZIndex = 5

    local testDemonBtn = Instance.new("TextButton", mainPane)
    testDemonBtn.Size = UDim2.new(0, 110, 0, 40)
    testDemonBtn.Position = UDim2.new(0, 126, 0, 66)
    testDemonBtn.BackgroundColor3 = Color3.fromRGB(180,60,60)
    testDemonBtn.Font = Enum.Font.SourceSansBold; testDemonBtn.TextSize = 14
    testDemonBtn.TextColor3 = Color3.new(1,1,1); testDemonBtn.Text = "Auto TestDemon: OFF"
    testDemonBtn.ZIndex = 5

    -- Settings pane
    local settingsPane = Instance.new("Frame", content)
    settingsPane.Size = UDim2.new(1,0,1,0)
    settingsPane.BackgroundTransparency = 1
    settingsPane.Visible = false
    settingsPane.ZIndex = 5

    local tpLabel = Instance.new("TextLabel", settingsPane)
    tpLabel.Size = UDim2.new(0, 220, 0, 22)
    tpLabel.Position = UDim2.new(0, 6, 0, 6)
    tpLabel.BackgroundTransparency = 1
    tpLabel.Text = "Teleport Interval (seconds):"
    tpLabel.Font = Enum.Font.SourceSans
    tpLabel.TextSize = 14
    tpLabel.TextColor3 = Color3.new(1,1,1)
    tpLabel.ZIndex = 5

    local tpBox = Instance.new("TextBox", settingsPane)
    tpBox.Size = UDim2.new(0, 120, 0, 28)
    tpBox.Position = UDim2.new(0, 6, 0, 34)
    tpBox.ClearTextOnFocus = false
    tpBox.Text = tostring(CONFIG.TeleportInterval)
    tpBox.Font = Enum.Font.SourceSans
    tpBox.TextSize = 14
    tpBox.ZIndex = 5

    local clLabel = Instance.new("TextLabel", settingsPane)
    clLabel.Size = UDim2.new(0, 220, 0, 22)
    clLabel.Position = UDim2.new(0, 138, 0, 6)
    clLabel.BackgroundTransparency = 1
    clLabel.Text = "Click Interval (seconds):"
    clLabel.Font = Enum.Font.SourceSans
    clLabel.TextSize = 14
    clLabel.TextColor3 = Color3.new(1,1,1)
    clLabel.ZIndex = 5

    local clBox = Instance.new("TextBox", settingsPane)
    clBox.Size = UDim2.new(0, 120, 0, 28)
    clBox.Position = UDim2.new(0, 138, 0, 34)
    clBox.ClearTextOnFocus = false
    clBox.Text = tostring(CONFIG.ClickInterval)
    clBox.Font = Enum.Font.SourceSans
    clBox.TextSize = 14
    clBox.ZIndex = 5

    local applyBtn = Instance.new("TextButton", settingsPane)
    applyBtn.Size = UDim2.new(0, 120, 0, 36)
    applyBtn.Position = UDim2.new(0, 6, 0, 72)
    applyBtn.Text = "Apply"
    applyBtn.Font = Enum.Font.SourceSansBold
    applyBtn.TextSize = 14
    applyBtn.BackgroundColor3 = Color3.fromRGB(80,160,90)
    applyBtn.TextColor3 = Color3.new(1,1,1)
    applyBtn.ZIndex = 5

    local resetBtn = Instance.new("TextButton", settingsPane)
    resetBtn.Size = UDim2.new(0, 120, 0, 36)
    resetBtn.Position = UDim2.new(0, 138, 0, 72)
    resetBtn.Text = "Reset Defaults"
    resetBtn.Font = Enum.Font.SourceSansBold
    resetBtn.TextSize = 14
    resetBtn.BackgroundColor3 = Color3.fromRGB(160,80,80)
    resetBtn.TextColor3 = Color3.new(1,1,1)
    resetBtn.ZIndex = 5

    local infoLabel = Instance.new("TextLabel", settingsPane)
    infoLabel.Size = UDim2.new(1, -12, 0, 34)
    infoLabel.Position = UDim2.new(0, 6, 0, 116)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = ("Teleport: %ss    Click: %ss"):format(tostring(CONFIG.TeleportInterval), tostring(CONFIG.ClickInterval))
    infoLabel.TextColor3 = Color3.new(1,1,1)
    infoLabel.Font = Enum.Font.SourceSansItalic
    infoLabel.TextSize = 12
    infoLabel.ZIndex = 5

    -- Tabs show/hide
    local function showMain()
        mainPane.Visible = true
        settingsPane.Visible = false
        tabMainBtn.BackgroundColor3 = Color3.fromRGB(60,60,62)
        tabSettingsBtn.BackgroundColor3 = Color3.fromRGB(40,40,42)
    end
    local function showSettings()
        mainPane.Visible = false
        settingsPane.Visible = true
        tabMainBtn.BackgroundColor3 = Color3.fromRGB(40,40,42)
        tabSettingsBtn.BackgroundColor3 = Color3.fromRGB(60,60,62)
    end
    tabMainBtn.MouseButton1Click:Connect(showMain)
    tabSettingsBtn.MouseButton1Click:Connect(showSettings)

    -- Draggable
    frame.Active = true
    do
        local dragging, dragStart, startPos, dragInput = false, nil, nil, nil
        local function updateDrag(input)
            if not dragging or not dragStart or not startPos then return end
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
        frame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = frame.Position
                dragInput = input
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then dragging = false; dragInput = nil end
                end)
            end
        end)
        frame.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
        end)
        UserInputService.InputChanged:Connect(function(input) if input == dragInput then updateDrag(input) end end)
    end

    -- Minimize state
    local isMinimized = false
    local prevSize = frame.Size
    local prevPos = frame.Position

    local function minimize()
        if isMinimized then return end
        isMinimized = true
        prevSize = frame.Size
        prevPos = frame.Position
        frame.Size = UDim2.new(0, 240, 0, 36)
        tabMainBtn.Visible = false
        tabSettingsBtn.Visible = false
        mainPane.Visible = false
        settingsPane.Visible = false
    end

    local function restore()
        if not isMinimized then return end
        isMinimized = false
        frame.Size = prevSize
        frame.Position = prevPos
        tabMainBtn.Visible = true
        tabSettingsBtn.Visible = true
        mainPane.Visible = true
        settingsPane.Visible = false
    end

    -- Floating minimize button (always visible, high ZIndex)
    local floatMinBtn = Instance.new("TextButton")
    floatMinBtn.Name = "FloatMinimizeBtn"
    floatMinBtn.Size = UDim2.new(0, 34, 0, 30)
    floatMinBtn.AnchorPoint = Vector2.new(0,0)
    floatMinBtn.BackgroundColor3 = Color3.fromRGB(255,140,0)
    floatMinBtn.BorderSizePixel = 0
    floatMinBtn.AutoButtonColor = true
    floatMinBtn.Font = Enum.Font.SourceSansBold
    floatMinBtn.TextSize = 18
    floatMinBtn.Text = "—"
    floatMinBtn.TextColor3 = Color3.fromRGB(255,255,255)
    floatMinBtn.ZIndex = 100
    floatMinBtn.Parent = screenGui

    local function updateFloatBtn()
        local ok, _ = pcall(function()
            local absPos = frame.AbsolutePosition
            local absSize = frame.AbsoluteSize
            floatMinBtn.Position = UDim2.new(0, absPos.X + absSize.X - 36, 0, absPos.Y + 6)
        end)
        if not ok then
            local fPos = frame.Position
            local fSize = frame.Size
            local xOff = (fPos.X.Offset or 0) + (fSize.X.Offset or 0) - 36
            local yOff = (fPos.Y.Offset or 0) + 6
            floatMinBtn.Position = UDim2.new(fPos.X.Scale, xOff, fPos.Y.Scale, yOff)
        end
    end
    task.defer(updateFloatBtn)
    frame:GetPropertyChangedSignal("Position"):Connect(updateFloatBtn)
    frame:GetPropertyChangedSignal("Size"):Connect(updateFloatBtn)
    frame:GetPropertyChangedSignal("AbsolutePosition"):Connect(updateFloatBtn)
    frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateFloatBtn)

    floatMinBtn.MouseButton1Click:Connect(function()
        if isMinimized then
            restore()
            floatMinBtn.Text = "—"
        else
            minimize()
            floatMinBtn.Text = "▢"
        end
    end)

    -- M keyboard toggle
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.M then
            if isMinimized then
                restore(); floatMinBtn.Text = "—"
            else
                minimize(); floatMinBtn.Text = "▢"
            end
        end
    end)

    -- Return handles used by script
    return {
        screenGui = screenGui,
        frame = frame,
        eggsBtn = eggsBtn,
        easterBtn = easterBtn,
        combinedBtn = combinedBtn,
        antiAFKBtn = antiAFKBtn,
        testDemonBtn = testDemonBtn,
        tpBox = tpBox,
        clBox = clBox,
        applyBtn = applyBtn,
        resetBtn = resetBtn,
        infoLabel = infoLabel,
        floatMinBtn = floatMinBtn,
    }
end

-- Create GUI and wire logic
local ui = createGui()
local eggsBtn = ui.eggsBtn
local easterBtn = ui.easterBtn
local combinedBtn = ui.combinedBtn
local antiAFKBtn = ui.antiAFKBtn
local testDemonBtn = ui.testDemonBtn
local tpBox = ui.tpBox
local clBox = ui.clBox
local applyBtn = ui.applyBtn
local resetBtn = ui.resetBtn
local infoLabel = ui.infoLabel

local autoEggs, autoEaster, autoCombined, autoTestDemon = false, false, false, false
local currentEggIndex, currentEasterIndex = 1, 1

local function setModeStates(eggs, easter, combined)
    autoEggs = eggs; autoEaster = easter; autoCombined = combined
    eggsBtn.Text = autoEggs and "Auto Eggs: ON" or "Auto Eggs: OFF"
    easterBtn.Text = autoEaster and "Auto Easter: ON" or "Auto Easter: OFF"
    combinedBtn.Text = autoCombined and "Auto Combined: ON" or "Auto Combined: OFF"
end

eggsBtn.MouseButton1Click:Connect(function()
    if autoCombined then setModeStates(false,false,false) end
    setModeStates(not autoEggs, autoEaster, false)
end)
easterBtn.MouseButton1Click:Connect(function()
    if autoCombined then setModeStates(false,false,false) end
    setModeStates(autoEggs, not autoEaster, false)
end)
combinedBtn.MouseButton1Click:Connect(function()
    if not autoCombined then setModeStates(false,false,true) else setModeStates(false,false,false) end
end)

testDemonBtn.MouseButton1Click:Connect(function()
    autoTestDemon = not autoTestDemon
    testDemonBtn.Text = autoTestDemon and "Auto TestDemon: ON" or "Auto TestDemon: OFF"
end)

local autoAnti = false
antiAFKBtn.MouseButton1Click:Connect(function()
    autoAnti = not autoAnti
    if autoAnti then
        antiAFKBtn.Text = "Anti-AFK: ON"
        autoAntiAFK = true
        enableAntiAFK()
    else
        antiAFKBtn.Text = "Anti-AFK: OFF"
        autoAntiAFK = false
        disableAntiAFK()
    end
end)

local function applySettingsFromInput()
    local tpVal = tonumber(tpBox.Text)
    local clVal = tonumber(clBox.Text)
    if tpVal then
        tpVal = math.clamp(tpVal, CONFIG.TeleportIntervalMin, CONFIG.TeleportIntervalMax)
        CONFIG.TeleportInterval = tpVal
    end
    if clVal then
        clVal = math.clamp(clVal, CONFIG.ClickIntervalMin, CONFIG.ClickIntervalMax)
        CONFIG.ClickInterval = clVal
    end
    infoLabel.Text = ("Teleport: %ss    Click: %ss"):format(string.format("%.3f", CONFIG.TeleportInterval), string.format("%.3f", CONFIG.ClickInterval))
    tpBox.Text = tostring(CONFIG.TeleportInterval)
    clBox.Text = tostring(CONFIG.ClickInterval)
end
applyBtn.MouseButton1Click:Connect(applySettingsFromInput)
resetBtn.MouseButton1Click:Connect(function()
    CONFIG.TeleportInterval = 0.12; CONFIG.ClickInterval = 0.12
    tpBox.Text = tostring(CONFIG.TeleportInterval); clBox.Text = tostring(CONFIG.ClickInterval)
    infoLabel.Text = ("Teleport: %ss    Click: %ss"):format(tostring(CONFIG.TeleportInterval), tostring(CONFIG.ClickInterval))
end)
tpBox.FocusLost:Connect(function(enterPressed) if enterPressed then applySettingsFromInput() end end)
clBox.FocusLost:Connect(function(enterPressed) if enterPressed then applySettingsFromInput() end end)

-- Worker loops
task.spawn(function()
    while true do
        if autoEggs then
            if not player.Character then player.CharacterAdded:Wait() end
            local eggModel, idx = getNextEggModel(currentEggIndex)
            if eggModel then
                dprint("Found egg:", eggModel.Name)
                local status = attackModelPersist(eggModel, function() return autoEggs end)
                if status == "removed" or status == "dead" then
                    currentEggIndex = (idx % #CONFIG.EggNames) + 1
                end
                task.wait(0.08)
            else
                task.wait(1.2)
            end
        else
            task.wait(0.12)
        end
    end
end)

task.spawn(function()
    while true do
        if autoEaster then
            if not player.Character then player.CharacterAdded:Wait() end
            local model, idx = getNextEasterModel(currentEasterIndex)
            if model then
                dprint("Found Easter target:", model.Name)
                local status = attackModelPersist(model, function() return autoEaster end)
                if status == "removed" or status == "dead" then
                    currentEasterIndex = (idx % #CONFIG.EasterNames) + 1
                end
                task.wait(0.08)
            else
                task.wait(1.2)
            end
        else
            task.wait(0.12)
        end
    end
end)

task.spawn(function()
    while true do
        if autoCombined then
            if not player.Character then player.CharacterAdded:Wait() end
            local eggModel, eggIdx = getNextEggModel(currentEggIndex)
            if eggModel then
                dprint("Combined attacking egg:", eggModel.Name)
                local status = attackModelPersist(eggModel, function() return autoCombined end)
                if status == "removed" or status == "dead" then
                    currentEggIndex = (eggIdx % #CONFIG.EggNames) + 1
                end
                task.wait(0.08)
            end
            local easterModel, easterIdx = getNextEasterModel(currentEasterIndex)
            if easterModel then
                dprint("Combined attacking Easter:", easterModel.Name)
                local status = attackModelPersist(easterModel, function() return autoCombined end)
                if status == "removed" or status == "dead" then
                    currentEasterIndex = (easterIdx % #CONFIG.EasterNames) + 1
                end
                task.wait(0.08)
            end
            if not eggModel and not easterModel then
                task.wait(1.2)
            end
        else
            task.wait(0.12)
        end
    end
end)

task.spawn(function()
    while true do
        if autoTestDemon then
            if not player.Character then player.CharacterAdded:Wait() end
            local model = getTestDemonModel()
            if model then
                dprint("Found TestDemon:", model.Name)
                local status = attackModelPersist(model, function() return autoTestDemon end)
                if status == "removed" or status == "dead" then
                    dprint("TestDemon gone.")
                end
                task.wait(0.08)
            else
                task.wait(1.2)
            end
        else
            task.wait(0.12)
        end
    end
end)

-- End of script
