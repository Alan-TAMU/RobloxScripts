-- AutoEggs + AutoEaster + AutoCombined (client-side)
-- draggable GUI + persistent-per-target behavior
-- Paste into a LocalScript (StarterPlayerScripts)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

-- CONFIG
local CONFIG = {
    SwordName = "Greatsword of Flying II",
    TeleportOffset = Vector3.new(0, 4, 0),
    ClickInterval = 0.12,   -- time between tool activations
    EggParentPath = {"Unbreakable", "Characters", "Undead"},
    EggNames = {
        "Blue Egg",
        "Green Egg",
        "Pink Egg",
        "Yellow Egg",
        "Shiny Red Egg",
        "Shiny Pink Egg",
        "Shiny Green Egg",
        "Golden Egg",
        "Orange Egg",
    },
    EasterNames = { -- Easter-character model names to search for across teams
        "Bunny Warrior",
        "Easter Guardian",
        "Carrot Menace",
        "Bunny",
    },
    Debug = true,
    PerTargetTimeout = 30, -- seconds to spend on a single target before skipping
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

local function getRoot()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

-- Find eggs parent container
local function findEggParent()
    local cur = workspace
    for _, name in ipairs(CONFIG.EggParentPath) do
        cur = cur:FindFirstChild(name)
        if not cur then return nil end
    end
    return cur
end

-- Get a useful target part from a model (eggs or NPCs)
local function getTargetPartFromModel(model)
    if not model then return nil end
    if model:FindFirstChild("HumanoidRootPart") then
        return model:FindFirstChild("HumanoidRootPart")
    end
    if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
        return model.PrimaryPart
    end
    for _, child in ipairs(model:GetChildren()) do
        if child:IsA("BasePart") then
            return child
        end
    end
    return nil
end

-- Tool helpers (find in Tools folder, character, or Backpack)
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
        local tb = backpack:FindFirstChild(toolName)
        if tb and tb:IsA("Tool") then return tb end
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

-- Teleport/pivot helper
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

-- Get next egg model in the configured list (round-robin)
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
        if model then
            return model, nextIndex
        end
        nextIndex = nextIndex + 1
        if nextIndex > n then nextIndex = 1 end
        tries = tries + 1
    end
    return nil, nextIndex
end

-- Find next Easter-character model by scanning Characters -> (Orc, Human, Undead) for configured names
local function getNextEasterModel(currentIndex)
    local charactersRoot = workspace:FindFirstChild("Unbreakable")
    if not charactersRoot then return nil, currentIndex end
    charactersRoot = charactersRoot:FindFirstChild("Characters")
    if not charactersRoot then return nil, currentIndex end

    local teams = {"Orc", "Human", "Undead"}
    local names = CONFIG.EasterNames
    local n = #names
    if n == 0 then return nil, currentIndex end

    local nextIndex = (currentIndex or 1)
    local tries = 0
    while tries < n do
        local name = names[nextIndex]
        for _, teamName in ipairs(teams) do
            local teamFolder = charactersRoot:FindFirstChild(teamName)
            if teamFolder then
                local model = teamFolder:FindFirstChild(name)
                if model then
                    return model, nextIndex
                end
                for _, child in ipairs(teamFolder:GetChildren()) do
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

-- Attack a single model and persist teleporting until removed or humanoid dead or timeout
local function attackModelPersist(targetModel)
    if not targetModel then return end

    local targetPart = getTargetPartFromModel(targetModel)
    if not targetPart then
        dprint("No target part for model:", tostring(targetModel.Name))
        return
    end

    local startTime = tick()
    while true do
        if not targetModel.Parent then
            dprint("Target removed:", targetModel.Name)
            break
        end

        local modelHumanoid = targetModel:FindFirstChildOfClass("Humanoid")
        if modelHumanoid and modelHumanoid.Health <= 0 then
            dprint("Target humanoid died:", targetModel.Name)
            break
        end

        local pos = targetPart.Position + CONFIG.TeleportOffset
        teleportToPosition(pos, targetPart.Position)

        local sword = equipToolByName(CONFIG.SwordName)
        if sword and sword:IsA("Tool") then
            pcall(function()
                sword:Activate()
            end)
        else
            dprint("Sword not found while attacking target:", CONFIG.SwordName)
            break
        end

        if tick() - startTime > CONFIG.PerTargetTimeout then
            dprint("Per-target timeout reached for:", targetModel.Name)
            break
        end

        task.wait(CONFIG.ClickInterval)
    end
end

-- GUI: create draggable GUI with three buttons (Eggs, Easter, Combined)
local function createGui()
    local existing = player:WaitForChild("PlayerGui"):FindFirstChild("AutoEggsGui")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoEggsGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 320, 0, 150)
    frame.Position = UDim2.new(0, 24, 0.6, -75)
    frame.BackgroundColor3 = Color3.fromRGB(28, 28, 30)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -12, 0, 30)
    title.Position = UDim2.new(0, 6, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = "Auto Farm GUI"
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 18
    title.TextColor3 = Color3.new(1,1,1)
    title.Parent = frame

    -- Eggs button
    local eggsBtn = Instance.new("TextButton")
    eggsBtn.Size = UDim2.new(0.32, -10, 0, 44)
    eggsBtn.Position = UDim2.new(0, 6, 0, 44)
    eggsBtn.BackgroundColor3 = Color3.fromRGB(55, 120, 70)
    eggsBtn.TextColor3 = Color3.new(1,1,1)
    eggsBtn.Font = Enum.Font.SourceSansBold
    eggsBtn.TextSize = 14
    eggsBtn.Text = "Auto Eggs: OFF"
    eggsBtn.Parent = frame

    -- Easter button
    local easterBtn = Instance.new("TextButton")
    easterBtn.Size = UDim2.new(0.32, -10, 0, 44)
    easterBtn.Position = UDim2.new(0.34, 4, 0, 44)
    easterBtn.BackgroundColor3 = Color3.fromRGB(200, 120, 40)
    easterBtn.TextColor3 = Color3.new(1,1,1)
    easterBtn.Font = Enum.Font.SourceSansBold
    easterBtn.TextSize = 14
    easterBtn.Text = "Auto Easter: OFF"
    easterBtn.Parent = frame

    -- Combined button (NEW)
    local combinedBtn = Instance.new("TextButton")
    combinedBtn.Size = UDim2.new(0.32, -10, 0, 44)
    combinedBtn.Position = UDim2.new(0.68, 4, 0, 44)
    combinedBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 200)
    combinedBtn.TextColor3 = Color3.new(1,1,1)
    combinedBtn.Font = Enum.Font.SourceSansBold
    combinedBtn.TextSize = 14
    combinedBtn.Text = "Auto Combined: OFF"
    combinedBtn.Parent = frame

    -- Draggable: track input from frame
    frame.Active = true
    local dragging = false
    local dragStart = nil
    local startPos = nil
    local dragInput = nil

    local function updateDrag(input)
        if not dragging or not dragStart or not startPos then return end
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end

    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            dragInput = input

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    dragInput = nil
                end
            end)
        end
    end)

    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput then
            updateDrag(input)
        end
    end)

    return screenGui, eggsBtn, easterBtn, combinedBtn, frame
end

-- Main runner
local autoEggs = false
local autoEaster = false
local autoCombined = false

local gui, eggsBtn, easterBtn, combinedBtn = createGui()
local currentEggIndex = 1
local currentEasterIndex = 1

-- Helper to set button states consistently (keeps only one mode active when Combined is used)
local function setModeStates(eggs, easter, combined)
    autoEggs = eggs
    autoEaster = easter
    autoCombined = combined
    eggsBtn.Text = autoEggs and "Auto Eggs: ON" or "Auto Eggs: OFF"
    easterBtn.Text = autoEaster and "Auto Easter: ON" or "Auto Easter: OFF"
    combinedBtn.Text = autoCombined and "Auto Combined: ON" or "Auto Combined: OFF"
end

-- Eggs toggle
eggsBtn.MouseButton1Click:Connect(function()
    -- toggling eggs off will not affect combined; toggling on will turn combined off
    if autoCombined then
        setModeStates(false, false, false)
    end
    setModeStates(not autoEggs, autoEaster, false)
end)

-- Easter toggle
easterBtn.MouseButton1Click:Connect(function()
    if autoCombined then
        setModeStates(false, false, false)
    end
    setModeStates(autoEggs, not autoEaster, false)
end)

-- Combined toggle: when enabled, disable the other two to avoid conflicts
combinedBtn.MouseButton1Click:Connect(function()
    if not autoCombined then
        -- turn combined ON, turn others OFF
        setModeStates(false, false, true)
    else
        -- turn combined OFF
        setModeStates(false, false, false)
    end
end)

-- Loop: Eggs-only behavior
task.spawn(function()
    while true do
        if autoEggs then
            if not player.Character then player.CharacterAdded:Wait() end

            local eggModel, idx = getNextEggModel(currentEggIndex)
            if eggModel then
                currentEggIndex = idx + 1
                if currentEggIndex > #CONFIG.EggNames then currentEggIndex = 1 end

                dprint("Starting persistent attack on egg:", eggModel.Name)
                attackModelPersist(eggModel)
                task.wait(0.08)
            else
                dprint("No eggs found, retrying soon...")
                task.wait(1.2)
            end
        else
            task.wait(0.12)
        end
    end
end)

-- Loop: Easter-only behavior
task.spawn(function()
    while true do
        if autoEaster then
            if not player.Character then player.CharacterAdded:Wait() end

            local targetModel, idx = getNextEasterModel(currentEasterIndex)
            if targetModel then
                currentEasterIndex = idx + 1
                if currentEasterIndex > #CONFIG.EasterNames then currentEasterIndex = 1 end

                dprint("Starting persistent attack on Easter target:", targetModel.Name)
                attackModelPersist(targetModel)
                task.wait(0.08)
            else
                dprint("No Easter targets found, retrying soon...")
                task.wait(1.2)
            end
        else
            task.wait(0.12)
        end
    end
end)

-- Loop: Combined behavior (egg then easter, repeat)
task.spawn(function()
    while true do
        if autoCombined then
            if not player.Character then player.CharacterAdded:Wait() end

            -- 1) Try an egg first
            local eggModel, eggIdx = getNextEggModel(currentEggIndex)
            if eggModel then
                currentEggIndex = eggIdx + 1
                if currentEggIndex > #CONFIG.EggNames then currentEggIndex = 1 end

                dprint("Combined: attacking egg:", eggModel.Name)
                attackModelPersist(eggModel)
                task.wait(0.08)
            end

            -- 2) Then try an Easter target
            local targetModel, easterIdx = getNextEasterModel(currentEasterIndex)
            if targetModel then
                currentEasterIndex = easterIdx + 1
                if currentEasterIndex > #CONFIG.EasterNames then currentEasterIndex = 1 end

                dprint("Combined: attacking Easter target:", targetModel.Name)
                attackModelPersist(targetModel)
                task.wait(0.08)
            end

            -- If neither found, wait a bit before retrying
            if not eggModel and not targetModel then
                dprint("Combined: no targets found, retrying...")
                task.wait(1.2)
            end
        else
            task.wait(0.12)
        end
    end
end)
