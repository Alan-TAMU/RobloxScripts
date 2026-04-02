-- AutoFarm (team-aware) — reliable minimizable GUI + M shortcut
-- Paste into a LocalScript (StarterPlayerScripts)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local player = Players.LocalPlayer

-- CONFIG
local CONFIG = {
    PlayerName = "NamiPlaysAM",
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

    Debug = true,
    PerTargetTimeout = 30,
    TeleportIntervalMin = 0.03,
    TeleportIntervalMax = 2.0,
    ClickIntervalMin = 0.03,
    ClickIntervalMax = 2.0,

    -- AntiAFK settings
    AntiAFKBackupNudge = true,
    AntiAFKNudgeAmount = 0.1, -- studs (very small)
    AntiAFKNudgeInterval = 30, -- seconds between nudges (backup)
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

-- ---------- basic helpers ----------
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

-- ---------- tool helpers ----------
local function findRealTool(toolName)
    local char = player.Character
    if char and char:FindFirstChild(toolName) and char:FindFirstChild(toolName):IsA("Tool") then
        return char:FindFirstChild(toolName)
    end
    local toolsFolder = player:FindFirstChild("Tools")
    if toolsFolder then
        local t = toolsFolder:FindFirstChild(toolName)
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

-- ---------- model / target helpers ----------
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

-- ---------- round-robin getters ----------
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

-- detect player's team
local function detectPlayerTeam()
    local un = workspace:FindFirstChild("Unbreakable")
    if not un then return nil end
    local chars = un:FindFirstChild("Characters")
    if not chars then return nil end
    local teams = {"Human","Orc","Undead"}
    for _, team in ipairs(teams) do
        local folder = chars:FindFirstChild(team)
        if folder and folder:FindFirstChild(CONFIG.PlayerName) then
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

-- TEAM-AWARE Easter search
local function getNextEasterModel(currentIndex)
    local un = workspace:FindFirstChild("Unbreakable")
    if not un then return nil, currentIndex end
    local chars = un:FindFirstChild("Characters")
    if not chars then return nil, currentIndex end

    local playerTeam = detectPlayerTeam()
    local teamsToSearch = {"Orc","Human","Undead"}
    if playerTeam and ENEMIES[playerTeam] then
        teamsToSearch = ENEMIES[playerTeam]
    else
        dprint("Player team not detected; searching all teams")
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
                if model and model.Name ~= CONFIG.PlayerName then
                    return model, nextIndex
                end
                for _, child in ipairs(teamFolder:GetChildren()) do
                    if child:IsA("Model") and child.Name:lower():find(name:lower()) and child.Name ~= CONFIG.PlayerName then
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

-- ---------- TestDemon finder ----------
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

-- ---------- core attack routine ----------
-- signature: attackModelPersist(targetModel, shouldContinue)
-- shouldContinue is a function returning true when we should keep attacking (used to cancel mid-target)
-- returns one of: "removed", "dead", "timeout", "cancelled", "tool_missing"
local function attackModelPersist(targetModel, shouldContinue)
    if not targetModel then return "removed" end -- nothing to do
    local targetPart = getTargetPartFromModel(targetModel)
    if not targetPart then
        dprint("No target part for:", tostring(targetModel.Name))
        return "removed"
    end

    local startTime = tick()
    while true do
        -- immediate cancellation check
        if shouldContinue and not shouldContinue() then
            dprint("Attack cancelled by toggle for:", targetModel.Name)
            return "cancelled"
        end

        -- stop conditions
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
        teleportToPosition(targetPart.Position + CONFIG.TeleportOffset, targetPart.Position)

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

-- ---------- Anti-AFK implementation ----------
local autoAntiAFK = false
local antiAFKConnection = nil
local antiAFKBackupTask = nil

local function enableAntiAFK()
    if antiAFKConnection then return end
    -- VirtualUser capture on Idled
    antiAFKConnection = player.Idled:Connect(function()
        -- Capture and click to fool AFK detection
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0,0))
        end)
        -- Also do a tiny nudge if configured (backup)
        if CONFIG.AntiAFKBackupNudge then
            local ok, err = pcall(function()
                local char = player.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    local root = char.HumanoidRootPart
                    local orig = root.CFrame
                    root.CFrame = orig * CFrame.new(0, 0, CONFIG.AntiAFKNudgeAmount)
                    task.wait(0.12)
                    root.CFrame = orig
                end
            end)
            if not ok then dprint("AntiAFK nudge failed:", err) end
        end
    end)

    -- periodic backup nudges so long as enabled (helps if Idled not firing in some environments)
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
    -- setting autoAntiAFK false will allow the backup task to exit naturally
    dprint("AntiAFK disabled")
end

-- ---------- GUI (Main + Settings) with reliable minimize button ----------
local function createGui()
    local existing = player:WaitForChild("PlayerGui"):FindFirstChild("AutoEggsGui")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoEggsGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 420, 0, 240)
    frame.Position = UDim2.new(0, 24, 0.6, -120)
    frame.BackgroundColor3 = Color3.fromRGB(28,28,30)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    frame.ZIndex = 2

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,10)

    -- Title (left aligned so minimize button won't overlap)
    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, -44, 0, 28) -- leave room for minimize on right
    title.Position = UDim2.new(0, 6, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = "Auto Farm GUI"
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 18
    title.TextColor3 = Color3.new(1,1,1)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 3

    -- Reliable minimize button (top-right of frame). ZIndex high so visible.
    local minimizeBtn = Instance.new("TextButton", frame)
    minimizeBtn.Name = "MinimizeBtn"
    minimizeBtn.Size = UDim2.new(0, 30, 0, 24)
    minimizeBtn.Position = UDim2.new(1, -36, 0, 6)
    minimizeBtn.AnchorPoint = Vector2.new(0, 0)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(60,60,62)
    minimizeBtn.BorderSizePixel = 0
    minimizeBtn.Font = Enum.Font.SourceSansBold
    minimizeBtn.TextSize = 18
    minimizeBtn.TextColor3 = Color3.new(1,1,1)
    minimizeBtn.Text = "—" -- minimize icon
    minimizeBtn.AutoButtonColor = true
    minimizeBtn.ZIndex = 20
    Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0,6)

    -- Tabs
    local tabMainBtn = Instance.new("TextButton", frame)
    tabMainBtn.Size = UDim2.new(0, 120, 0, 28)
    tabMainBtn.Position = UDim2.new(0, 6, 0, 38)
    tabMainBtn.Text = "Main"
    tabMainBtn.Font = Enum.Font.SourceSans
    tabMainBtn.TextSize = 14
    tabMainBtn.BackgroundColor3 = Color3.fromRGB(40,40,42)
    tabMainBtn.TextColor3 = Color3.new(1,1,1)
    tabMainBtn.ZIndex = 3

    local tabSettingsBtn = Instance.new("TextButton", frame)
    tabSettingsBtn.Size = UDim2.new(0, 120, 0, 28)
    tabSettingsBtn.Position = UDim2.new(0, 132, 0, 38)
    tabSettingsBtn.Text = "Settings"
    tabSettingsBtn.Font = Enum.Font.SourceSans
    tabSettingsBtn.TextSize = 14
    tabSettingsBtn.BackgroundColor3 = Color3.fromRGB(40,40,42)
    tabSettingsBtn.TextColor3 = Color3.new(1,1,1)
    tabSettingsBtn.ZIndex = 3

    local content = Instance.new("Frame", frame)
    content.Size = UDim2.new(1, -12, 1, -108)
    content.Position = UDim2.new(0, 6, 0, 72)
    content.BackgroundTransparency = 1
    content.ZIndex = 2

    -- Main pane
    local mainPane = Instance.new("Frame", content)
    mainPane.Size = UDim2.new(1,0,1,0)
    mainPane.BackgroundTransparency = 1
    mainPane.ZIndex = 2

    local eggsBtn = Instance.new("TextButton", mainPane)
    eggsBtn.Size = UDim2.new(0, 110, 0, 50)
    eggsBtn.Position = UDim2.new(0, 6, 0, 6)
    eggsBtn.BackgroundColor3 = Color3.fromRGB(55,120,70)
    eggsBtn.Font = Enum.Font.SourceSansBold; eggsBtn.TextSize = 14
    eggsBtn.TextColor3 = Color3.new(1,1,1); eggsBtn.Text = "Auto Eggs: OFF"
    eggsBtn.ZIndex = 2

    local easterBtn = Instance.new("TextButton", mainPane)
    easterBtn.Size = UDim2.new(0, 110, 0, 50)
    easterBtn.Position = UDim2.new(0, 126, 0, 6)
    easterBtn.BackgroundColor3 = Color3.fromRGB(200,120,40)
    easterBtn.Font = Enum.Font.SourceSansBold; easterBtn.TextSize = 14
    easterBtn.TextColor3 = Color3.new(1,1,1); easterBtn.Text = "Auto Easter: OFF"
    easterBtn.ZIndex = 2

    local combinedBtn = Instance.new("TextButton", mainPane)
    combinedBtn.Size = UDim2.new(0, 110, 0, 50)
    combinedBtn.Position = UDim2.new(0, 246, 0, 6)
    combinedBtn.BackgroundColor3 = Color3.fromRGB(120,60,200)
    combinedBtn.Font = Enum.Font.SourceSansBold; combinedBtn.TextSize = 14
    combinedBtn.TextColor3 = Color3.new(1,1,1); combinedBtn.Text = "Auto Combined: OFF"
    combinedBtn.ZIndex = 2

    local antiAFKBtn = Instance.new("TextButton", mainPane)
    antiAFKBtn.Size = UDim2.new(0, 110, 0, 40)
    antiAFKBtn.Position = UDim2.new(0, 6, 0, 66)
    antiAFKBtn.BackgroundColor3 = Color3.fromRGB(50,90,160)
    antiAFKBtn.Font = Enum.Font.SourceSansBold; antiAFKBtn.TextSize = 14
    antiAFKBtn.TextColor3 = Color3.new(1,1,1); antiAFKBtn.Text = "Anti-AFK: OFF"
    antiAFKBtn.ZIndex = 2

    local testDemonBtn = Instance.new("TextButton", mainPane)
    testDemonBtn.Size = UDim2.new(0, 110, 0, 40)
    testDemonBtn.Position = UDim2.new(0, 126, 0, 66)
    testDemonBtn.BackgroundColor3 = Color3.fromRGB(180,60,60)
    testDemonBtn.Font = Enum.Font.SourceSansBold; testDemonBtn.TextSize = 14
    testDemonBtn.TextColor3 = Color3.new(1,1,1); testDemonBtn.Text = "Auto TestDemon: OFF"
    testDemonBtn.ZIndex = 2

    -- Settings pane
    local settingsPane = Instance.new("Frame", content)
    settingsPane.Size = UDim2.new(1,0,1,0)
    settingsPane.BackgroundTransparency = 1
    settingsPane.Visible = false
    settingsPane.ZIndex = 2

    local tpLabel = Instance.new("TextLabel", settingsPane)
    tpLabel.Size = UDim2.new(0, 220, 0, 22)
    tpLabel.Position = UDim2.new(0, 6, 0, 6)
    tpLabel.BackgroundTransparency = 1
    tpLabel.Text = "Teleport Interval (seconds):"
    tpLabel.Font = Enum.Font.SourceSans
    tpLabel.TextSize = 14
    tpLabel.TextColor3 = Color3.new(1,1,1)
    tpLabel.ZIndex = 2

    local tpBox = Instance.new("TextBox", settingsPane)
    tpBox.Size = UDim2.new(0, 120, 0, 28)
    tpBox.Position = UDim2.new(0, 6, 0, 34)
    tpBox.ClearTextOnFocus = false
    tpBox.Text = tostring(CONFIG.TeleportInterval)
    tpBox.Font = Enum.Font.SourceSans
    tpBox.TextSize = 14
    tpBox.ZIndex = 2

    local clLabel = Instance.new("TextLabel", settingsPane)
    clLabel.Size = UDim2.new(0, 220, 0, 22)
    clLabel.Position = UDim2.new(0, 138, 0, 6)
    clLabel.BackgroundTransparency = 1
    clLabel.Text = "Click Interval (seconds):"
    clLabel.Font = Enum.Font.SourceSans
    clLabel.TextSize = 14
    clLabel.TextColor3 = Color3.new(1,1,1)
    clLabel.ZIndex = 2

    local clBox = Instance.new("TextBox", settingsPane)
    clBox.Size = UDim2.new(0, 120, 0, 28)
    clBox.Position = UDim2.new(0, 138, 0, 34)
    clBox.ClearTextOnFocus = false
    clBox.Text = tostring(CONFIG.ClickInterval)
    clBox.Font = Enum.Font.SourceSans
    clBox.TextSize = 14
    clBox.ZIndex = 2

    local applyBtn = Instance.new("TextButton", settingsPane)
    applyBtn.Size = UDim2.new(0, 120, 0, 36)
    applyBtn.Position = UDim2.new(0, 6, 0, 72)
    applyBtn.Text = "Apply"
    applyBtn.Font = Enum.Font.SourceSansBold
    applyBtn.TextSize = 14
    applyBtn.BackgroundColor3 = Color3.fromRGB(80,160,90)
    applyBtn.TextColor3 = Color3.new(1,1,1)
    applyBtn.ZIndex = 2

    local resetBtn = Instance.new("TextButton", settingsPane)
    resetBtn.Size = UDim2.new(0, 120, 0, 36)
    resetBtn.Position = UDim2.new(0, 138, 0, 72)
    resetBtn.Text = "Reset Defaults"
    resetBtn.Font = Enum.Font.SourceSansBold
    resetBtn.TextSize = 14
    resetBtn.BackgroundColor3 = Color3.fromRGB(160,80,80)
    resetBtn.TextColor3 = Color3.new(1,1,1)
    resetBtn.ZIndex = 2

    local infoLabel = Instance.new("TextLabel", settingsPane)
    infoLabel.Size = UDim2.new(1, -12, 0, 34)
    infoLabel.Position = UDim2.new(0, 6, 0, 116)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = ("Teleport: %ss    Click: %ss"):format(tostring(CONFIG.TeleportInterval), tostring(CONFIG.ClickInterval))
    infoLabel.TextColor3 = Color3.new(1,1,1)
    infoLabel.Font = Enum.Font.SourceSansItalic
    infoLabel.TextSize = 12
    infoLabel.ZIndex = 2

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

    -- draggable (works when minimized too)
    frame.Active = true
    do
        local dragging, dragStart, startPos, dragInput = false, nil, nil, nil
        local function updateDrag(input)
            if not dragging or not dragStart or not startPos then return end
            local delta = input.Position - dragStart
            local newPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            frame.Position = newPos
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

    -- minimizable state
    local isMinimized = false
    local prevSize = frame.Size
    local prevPos = frame.Position

    local function minimize()
        if isMinimized then return end
        isMinimized = true
        prevSize = frame.Size
        prevPos = frame.Position
        -- collapse to small bar, hide content but keep minimizeBtn visible
        frame.Size = UDim2.new(0, 240, 0, 36)
        -- keep the frame's top-left in the same visual area
        frame.Position = UDim2.new(prevPos.X.Scale, prevPos.X.Offset, prevPos.Y.Scale, prevPos.Y.Offset)
        -- hide internal panes/buttons except the minimize button and title
        tabMainBtn.Visible = false
        tabSettingsBtn.Visible = false
        mainPane.Visible = false
        settingsPane.Visible = false
        -- move minimizeBtn to remain on the right edge of the small bar
        minimizeBtn.Position = UDim2.new(1, -36, 0, 6)
        minimizeBtn.Text = "▢" -- restore icon
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
        minimizeBtn.Position = UDim2.new(1, -36, 0, 6)
        minimizeBtn.Text = "—"
    end

    -- minimize button click (guaranteed visible)
    minimizeBtn.MouseButton1Click:Connect(function()
        if isMinimized then
            restore()
        else
            minimize()
        end
    end)

    -- keyboard shortcut: press M to toggle
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.M then
            if isMinimized then restore() else minimize() end
        end
    end)

    -- expose some elements for the rest of the script
    return screenGui, frame, eggsBtn, easterBtn, combinedBtn, antiAFKBtn, testDemonBtn, tpBox, clBox, applyBtn, resetBtn, infoLabel
end

-- ---------- main state ----------
local gui, frame, eggsBtn, easterBtn, combinedBtn, antiAFKBtn, testDemonBtn, tpBox, clBox, applyBtn, resetBtn, infoLabel = createGui()
local autoEggs, autoEaster, autoCombined, autoTestDemon = false, false, false, false
local autoAntiAFK = false
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

-- TestDemon toggle
testDemonBtn.MouseButton1Click:Connect(function()
    autoTestDemon = not autoTestDemon
    testDemonBtn.Text = autoTestDemon and "Auto TestDemon: ON" or "Auto TestDemon: OFF"
end)

-- Anti-AFK toggle handling
antiAFKBtn.MouseButton1Click:Connect(function()
    autoAntiAFK = not autoAntiAFK
    if autoAntiAFK then
        antiAFKBtn.Text = "Anti-AFK: ON"
        enableAntiAFK()
    else
        antiAFKBtn.Text = "Anti-AFK: OFF"
        disableAntiAFK()
    end
end)

-- Settings apply/reset
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

-- ---------- worker loops (advance index ONLY on "removed" or "dead") ----------

-- Eggs loop
task.spawn(function()
    while true do
        if autoEggs then
            if not player.Character then player.CharacterAdded:Wait() end
            local eggModel, idx = getNextEggModel(currentEggIndex)
            if eggModel then
                dprint("Found egg:", eggModel.Name, " — attacking until gone (or cancelled)")
                local status = attackModelPersist(eggModel, function() return autoEggs end)
                if status == "removed" or status == "dead" then
                    currentEggIndex = (idx % #CONFIG.EggNames) + 1
                else
                    dprint("Egg attack ended with status:", status, "- not advancing index")
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

-- Easter loop (enemy-only)
task.spawn(function()
    while true do
        if autoEaster then
            if not player.Character then player.CharacterAdded:Wait() end
            local model, idx = getNextEasterModel(currentEasterIndex)
            if model then
                dprint("Found Easter target:", model.Name, " — attacking until gone (enemy only)")
                local status = attackModelPersist(model, function() return autoEaster end)
                if status == "removed" or status == "dead" then
                    currentEasterIndex = (idx % #CONFIG.EasterNames) + 1
                else
                    dprint("Easter attack ended with status:", status, "- not advancing index")
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

-- Combined loop: egg then enemy-easter; each waits to finish and advances index only on removal/death
task.spawn(function()
    while true do
        if autoCombined then
            if not player.Character then player.CharacterAdded:Wait() end

            local eggModel, eggIdx = getNextEggModel(currentEggIndex)
            if eggModel then
                dprint("Combined: attacking egg:", eggModel.Name)
                local status = attackModelPersist(eggModel, function() return autoCombined end)
                if status == "removed" or status == "dead" then
                    currentEggIndex = (eggIdx % #CONFIG.EggNames) + 1
                else
                    dprint("Combined egg attack ended with status:", status)
                end
                task.wait(0.08)
            end

            local easterModel, easterIdx = getNextEasterModel(currentEasterIndex)
            if easterModel then
                dprint("Combined: attacking Easter (enemy only):", easterModel.Name)
                local status = attackModelPersist(easterModel, function() return autoCombined end)
                if status == "removed" or status == "dead" then
                    currentEasterIndex = (easterIdx % #CONFIG.EasterNames) + 1
                else
                    dprint("Combined easter attack ended with status:", status)
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

-- TestDemon loop (single-target)
task.spawn(function()
    while true do
        if autoTestDemon then
            if not player.Character then player.CharacterAdded:Wait() end
            local model = getTestDemonModel()
            if model then
                dprint("Found TestDemon:", model.Name, " — attacking until gone (or cancelled)")
                local status = attackModelPersist(model, function() return autoTestDemon end)
                if status == "removed" or status == "dead" then
                    dprint("TestDemon removed/dead. (will retry if it respawns)")
                else
                    dprint("TestDemon attack ended with status:", status, "- will not advance anything (single target)")
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
