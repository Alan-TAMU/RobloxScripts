-- AutoFarm with Settings Tab (client-side)
-- Draggable GUI with Main + Settings tabs
-- Paste into a LocalScript (StarterPlayerScripts)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

-- CONFIG (defaults)
local CONFIG = {
    SwordName = "Greatsword of Flying II",
    TeleportOffset = Vector3.new(0, 4, 0),
    -- TeleportInterval controls how often the script teleports to the current target (seconds)
    TeleportInterval = 0.12,
    -- ClickInterval controls how often the tool:Activate() is called while staying on target (seconds)
    ClickInterval = 0.12,
    -- target lists
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
}

local function dprint(...)
    if CONFIG.Debug then
        print("[AutoFarm]", ...)
    end
end

-- Character helpers
local function getCharacter()
    return player.Character or player.CharacterAdded:Wait()
end
local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

-- Teleport helper
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

-- Find egg parent
local function findEggParent()
    local cur = workspace
    for _, name in ipairs(CONFIG.EggParentPath) do
        cur = cur:FindFirstChild(name)
        if not cur then return nil end
    end
    return cur
end

-- Get part to teleport to for a model
local function getTargetPartFromModel(model)
    if not model then return nil end
    if model:FindFirstChild("HumanoidRootPart") then return model.HumanoidRootPart end
    if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then return model.PrimaryPart end
    for _, c in ipairs(model:GetChildren()) do
        if c:IsA("BasePart") then return c end
    end
    return nil
end

-- Tool helpers
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

-- Egg round-robin
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

-- Easter search across teams
local function getNextEasterModel(currentIndex)
    local un = workspace:FindFirstChild("Unbreakable")
    if not un then return nil, currentIndex end
    local chars = un:FindFirstChild("Characters")
    if not chars then return nil, currentIndex end
    local teams = {"Orc","Human","Undead"}
    local names = CONFIG.EasterNames
    local n = #names
    if n == 0 then return nil, currentIndex end
    local nextIndex = (currentIndex or 1)
    local tries = 0
    while tries < n do
        local name = names[nextIndex]
        for _, team in ipairs(teams) do
            local folder = chars:FindFirstChild(team)
            if folder then
                local model = folder:FindFirstChild(name)
                if model then return model, nextIndex end
                for _, child in ipairs(folder:GetChildren()) do
                    if child:IsA("Model") and child.Name:lower():find(name:lower()) then
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

-- Attack a model persistently.
-- Behavior update: teleport every CONFIG.TeleportInterval seconds.
-- During each teleport cycle, call :Activate() repeatedly with CONFIG.ClickInterval spacing.
local function attackModelPersist(targetModel)
    if not targetModel then return end
    local targetPart = getTargetPartFromModel(targetModel)
    if not targetPart then
        dprint("No target part for model:", tostring(targetModel.Name))
        return
    end

    local startTime = tick()
    while true do
        if not targetModel.Parent then dprint("Target removed:", targetModel.Name); break end
        local modelHumanoid = targetModel:FindFirstChildOfClass("Humanoid")
        if modelHumanoid and modelHumanoid.Health <= 0 then dprint("Target humanoid died:", targetModel.Name); break end

        -- teleport to target
        teleportToPosition(targetPart.Position + CONFIG.TeleportOffset, targetPart.Position)

        -- equip sword
        local sword = equipToolByName(CONFIG.SwordName)
        if not (sword and sword:IsA("Tool")) then
            dprint("Sword not found while attacking:", CONFIG.SwordName)
            break
        end

        -- compute how many activations to perform before next teleport
        local teleInt = math.clamp(CONFIG.TeleportInterval, CONFIG.TeleportIntervalMin, CONFIG.TeleportIntervalMax)
        local clickInt = math.clamp(CONFIG.ClickInterval, CONFIG.ClickIntervalMin, CONFIG.ClickIntervalMax)
        -- ensure at least 1 activation per teleport
        local activations = math.max(1, math.floor(teleInt / clickInt))

        -- rapid-activate loop (stays near target)
        for i = 1, activations do
            if not targetModel.Parent then break end
            local hum = targetModel:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health <= 0 then break end
            pcall(function() sword:Activate() end)
            task.wait(clickInt)
        end

        -- safety/timeouts
        if tick() - startTime > CONFIG.PerTargetTimeout then
            dprint("Per-target timeout reached for:", targetModel.Name)
            break
        end
    end
end

-- GUI creation: Main tab (buttons) + Settings tab (interval adjust)
local function createGui()
    -- remove older GUI if present
    local existing = player:WaitForChild("PlayerGui"):FindFirstChild("AutoEggsGui")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoEggsGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 380, 0, 190)
    frame.Position = UDim2.new(0, 24, 0.6, -95)
    frame.BackgroundColor3 = Color3.fromRGB(28,28,30)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0,10)

    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, -12, 0, 28)
    title.Position = UDim2.new(0, 6, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = "Auto Farm GUI"
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 18
    title.TextColor3 = Color3.new(1,1,1)

    -- Tabs (Main / Settings)
    local tabMainBtn = Instance.new("TextButton", frame)
    tabMainBtn.Size = UDim2.new(0, 120, 0, 28)
    tabMainBtn.Position = UDim2.new(0, 6, 0, 38)
    tabMainBtn.Text = "Main"
    tabMainBtn.Font = Enum.Font.SourceSans
    tabMainBtn.TextSize = 14
    tabMainBtn.BackgroundColor3 = Color3.fromRGB(40,40,42)
    tabMainBtn.TextColor3 = Color3.new(1,1,1)

    local tabSettingsBtn = Instance.new("TextButton", frame)
    tabSettingsBtn.Size = UDim2.new(0, 120, 0, 28)
    tabSettingsBtn.Position = UDim2.new(0, 132, 0, 38)
    tabSettingsBtn.Text = "Settings"
    tabSettingsBtn.Font = Enum.Font.SourceSans
    tabSettingsBtn.TextSize = 14
    tabSettingsBtn.BackgroundColor3 = Color3.fromRGB(40,40,42)
    tabSettingsBtn.TextColor3 = Color3.new(1,1,1)

    -- Container for tab contents
    local content = Instance.new("Frame", frame)
    content.Size = UDim2.new(1, -12, 1, -76)
    content.Position = UDim2.new(0, 6, 0, 72)
    content.BackgroundTransparency = 1

    -- MAIN tab contents: three buttons (absolute)
    local mainPane = Instance.new("Frame", content)
    mainPane.Size = UDim2.new(1,0,1,0)
    mainPane.BackgroundTransparency = 1

    local eggsBtn = Instance.new("TextButton", mainPane)
    eggsBtn.Size = UDim2.new(0, 110, 0, 50)
    eggsBtn.Position = UDim2.new(0, 6, 0, 6)
    eggsBtn.BackgroundColor3 = Color3.fromRGB(55,120,70)
    eggsBtn.Font = Enum.Font.SourceSansBold; eggsBtn.TextSize = 14
    eggsBtn.TextColor3 = Color3.new(1,1,1); eggsBtn.Text = "Auto Eggs: OFF"

    local easterBtn = Instance.new("TextButton", mainPane)
    easterBtn.Size = UDim2.new(0, 110, 0, 50)
    easterBtn.Position = UDim2.new(0, 126, 0, 6)
    easterBtn.BackgroundColor3 = Color3.fromRGB(200,120,40)
    easterBtn.Font = Enum.Font.SourceSansBold; easterBtn.TextSize = 14
    easterBtn.TextColor3 = Color3.new(1,1,1); easterBtn.Text = "Auto Easter: OFF"

    local combinedBtn = Instance.new("TextButton", mainPane)
    combinedBtn.Size = UDim2.new(0, 110, 0, 50)
    combinedBtn.Position = UDim2.new(0, 246, 0, 6)
    combinedBtn.BackgroundColor3 = Color3.fromRGB(120,60,200)
    combinedBtn.Font = Enum.Font.SourceSansBold; combinedBtn.TextSize = 14
    combinedBtn.TextColor3 = Color3.new(1,1,1); combinedBtn.Text = "Auto Combined: OFF"

    -- SETTINGS tab contents
    local settingsPane = Instance.new("Frame", content)
    settingsPane.Size = UDim2.new(1,0,1,0)
    settingsPane.BackgroundTransparency = 1
    settingsPane.Visible = false

    -- Teleport Interval controls
    local tpLabel = Instance.new("TextLabel", settingsPane)
    tpLabel.Size = UDim2.new(0, 220, 0, 22)
    tpLabel.Position = UDim2.new(0, 6, 0, 6)
    tpLabel.BackgroundTransparency = 1
    tpLabel.Text = "Teleport Interval (seconds):"
    tpLabel.Font = Enum.Font.SourceSans
    tpLabel.TextSize = 14
    tpLabel.TextColor3 = Color3.new(1,1,1)

    local tpBox = Instance.new("TextBox", settingsPane)
    tpBox.Size = UDim2.new(0, 120, 0, 28)
    tpBox.Position = UDim2.new(0, 6, 0, 34)
    tpBox.ClearTextOnFocus = false
    tpBox.Text = tostring(CONFIG.TeleportInterval)
    tpBox.Font = Enum.Font.SourceSans
    tpBox.TextSize = 14

    -- Click Interval controls
    local clLabel = Instance.new("TextLabel", settingsPane)
    clLabel.Size = UDim2.new(0, 220, 0, 22)
    clLabel.Position = UDim2.new(0, 138, 0, 6)
    clLabel.BackgroundTransparency = 1
    clLabel.Text = "Click Interval (seconds):"
    clLabel.Font = Enum.Font.SourceSans
    clLabel.TextSize = 14
    clLabel.TextColor3 = Color3.new(1,1,1)

    local clBox = Instance.new("TextBox", settingsPane)
    clBox.Size = UDim2.new(0, 120, 0, 28)
    clBox.Position = UDim2.new(0, 138, 0, 34)
    clBox.ClearTextOnFocus = false
    clBox.Text = tostring(CONFIG.ClickInterval)
    clBox.Font = Enum.Font.SourceSans
    clBox.TextSize = 14

    -- Apply & Reset buttons
    local applyBtn = Instance.new("TextButton", settingsPane)
    applyBtn.Size = UDim2.new(0, 120, 0, 36)
    applyBtn.Position = UDim2.new(0, 6, 0, 72)
    applyBtn.Text = "Apply"
    applyBtn.Font = Enum.Font.SourceSansBold
    applyBtn.TextSize = 14
    applyBtn.BackgroundColor3 = Color3.fromRGB(80,160,90)
    applyBtn.TextColor3 = Color3.new(1,1,1)

    local resetBtn = Instance.new("TextButton", settingsPane)
    resetBtn.Size = UDim2.new(0, 120, 0, 36)
    resetBtn.Position = UDim2.new(0, 138, 0, 72)
    resetBtn.Text = "Reset Defaults"
    resetBtn.Font = Enum.Font.SourceSansBold
    resetBtn.TextSize = 14
    resetBtn.BackgroundColor3 = Color3.fromRGB(160,80,80)
    resetBtn.TextColor3 = Color3.new(1,1,1)

    local infoLabel = Instance.new("TextLabel", settingsPane)
    infoLabel.Size = UDim2.new(1, -12, 0, 34)
    infoLabel.Position = UDim2.new(0, 6, 0, 116)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = ("Teleport: %ss    Click: %ss"):format(tostring(CONFIG.TeleportInterval), tostring(CONFIG.ClickInterval))
    infoLabel.TextColor3 = Color3.new(1,1,1)
    infoLabel.Font = Enum.Font.SourceSansItalic
    infoLabel.TextSize = 12

    -- Tab switching
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

    -- Draggable frame
    frame.Active = true
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
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput then updateDrag(input) end
    end)

    -- return GUI elements we need to wire
    return screenGui, eggsBtn, easterBtn, combinedBtn, tpBox, clBox, applyBtn, resetBtn, infoLabel
end

-- Main state
local autoEggs, autoEaster, autoCombined = false, false, false
local gui, eggsBtn, easterBtn, combinedBtn, tpBox, clBox, applyBtn, resetBtn, infoLabel = createGui()
local currentEggIndex, currentEasterIndex = 1, 1

local function setModeStates(eggs, easter, combined)
    autoEggs = eggs; autoEaster = easter; autoCombined = combined
    eggsBtn.Text = autoEggs and "Auto Eggs: ON" or "Auto Eggs: OFF"
    easterBtn.Text = autoEaster and "Auto Easter: ON" or "Auto Easter: OFF"
    combinedBtn.Text = autoCombined and "Auto Combined: ON" or "Auto Combined: OFF"
end

-- button handlers
eggsBtn.MouseButton1Click:Connect(function()
    if autoCombined then setModeStates(false,false,false) end
    setModeStates(not autoEggs, autoEaster, false)
end)
easterBtn.MouseButton1Click:Connect(function()
    if autoCombined then setModeStates(false,false,false) end
    setModeStates(autoEggs, not autoEaster, false)
end)
combinedBtn.MouseButton1Click:Connect(function()
    if not autoCombined then setModeStates(false,false,true)
    else setModeStates(false,false,false) end
end)

-- settings apply/reset logic
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
    -- update info label
    infoLabel.Text = ("Teleport: %ss    Click: %ss"):format(string.format("%.3f", CONFIG.TeleportInterval), string.format("%.3f", CONFIG.ClickInterval))
    -- also update textboxes to clamped values
    tpBox.Text = tostring(CONFIG.TeleportInterval)
    clBox.Text = tostring(CONFIG.ClickInterval)
end

applyBtn.MouseButton1Click:Connect(applySettingsFromInput)

resetBtn.MouseButton1Click:Connect(function()
    CONFIG.TeleportInterval = 0.12
    CONFIG.ClickInterval = 0.12
    tpBox.Text = tostring(CONFIG.TeleportInterval)
    clBox.Text = tostring(CONFIG.ClickInterval)
    infoLabel.Text = ("Teleport: %ss    Click: %ss"):format(tostring(CONFIG.TeleportInterval), tostring(CONFIG.ClickInterval))
end)

-- also apply when user edits and leaves textbox (FocusLost)
tpBox.FocusLost:Connect(function(enterPressed)
    if not enterPressed then return end
    applySettingsFromInput()
end)
clBox.FocusLost:Connect(function(enterPressed)
    if not enterPressed then return end
    applySettingsFromInput()
end)

-- Worker loops (Eggs, Easter, Combined) same behavior as before but using CONFIG.TeleportInterval/ClickInterval
task.spawn(function()
    while true do
        if autoEggs then
            if not player.Character then player.CharacterAdded:Wait() end
            local eggModel, idx = getNextEggModel(currentEggIndex)
            if eggModel then
                currentEggIndex = idx + 1
                if currentEggIndex > #CONFIG.EggNames then currentEggIndex = 1 end
                dprint("Attacking egg:", eggModel.Name)
                attackModelPersist(eggModel)
                task.wait(0.08)
            else
                task.wait(1.2)
            end
        else task.wait(0.12) end
    end
end)

task.spawn(function()
    while true do
        if autoEaster then
            if not player.Character then player.CharacterAdded:Wait() end
            local targetModel, idx = getNextEasterModel(currentEasterIndex)
            if targetModel then
                currentEasterIndex = idx + 1
                if currentEasterIndex > #CONFIG.EasterNames then currentEasterIndex = 1 end
                dprint("Attacking Easter target:", targetModel.Name)
                attackModelPersist(targetModel)
                task.wait(0.08)
            else
                task.wait(1.2)
            end
        else task.wait(0.12) end
    end
end)

task.spawn(function()
    while true do
        if autoCombined then
            if not player.Character then player.CharacterAdded:Wait() end
            local eggModel, eggIdx = getNextEggModel(currentEggIndex)
            if eggModel then
                currentEggIndex = eggIdx + 1
                if currentEggIndex > #CONFIG.EggNames then currentEggIndex = 1 end
                dprint("Combined: egg:", eggModel.Name)
                attackModelPersist(eggModel)
                task.wait(0.08)
            end
            local targetModel, easterIdx = getNextEasterModel(currentEasterIndex)
            if targetModel then
                currentEasterIndex = easterIdx + 1
                if currentEasterIndex > #CONFIG.EasterNames then currentEasterIndex = 1 end
                dprint("Combined: Easter:", targetModel.Name)
                attackModelPersist(targetModel)
                task.wait(0.08)
            end
            if not eggModel and not targetModel then task.wait(1.2) end
        else task.wait(0.12) end
    end
end)
