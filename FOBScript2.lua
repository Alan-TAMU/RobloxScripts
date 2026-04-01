-- AutoEggs + AutoEaster (client-side) -- draggable GUI + persistent-per-target behavior
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
        "Orange Egg", -- existing
    },
    EasterNames = { -- NEW: list of Easter-character model names to search for across teams
        "Bunny Warrior",
        "Easter Guardian",
        "Carrot Menace",
        "Bunny",
    },
    Debug = true,
    PerTargetTimeout = 30, -- seconds to spend on a single target before skipping (safety)
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
        -- Equip from Backpack or Tools
        humanoid:EquipTool(tool)
        task.wait(0.12)
    end
    -- return tool instance (should now be parented to character)
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
    -- list of teams to search under Characters
    local charactersRoot = workspace:FindFirstChild("Unbreakable")
    if not charactersRoot then return nil, currentIndex end
    charactersRoot = charactersRoot:FindFirstChild("Characters")
    if not charactersRoot then return nil, currentIndex end

    local teams = {"Orc", "Human", "Undead"} -- search these folders
    local names = CONFIG.EasterNames
    local n = #names
    if n == 0 then return nil, currentIndex end

    local nextIndex = (currentIndex or 1)
    local tries = 0
    while tries < n do
        local name = names[nextIndex]
        -- search each team for this model name or for a nested folder/model "Bunny" etc.
        for _, teamName in ipairs(teams) do
            local teamFolder = charactersRoot:FindFirstChild(teamName)
            if teamFolder then
                -- direct child with that name
                local model = teamFolder:FindFirstChild(name)
                if model then
                    return model, nextIndex
                end
                -- also search within teamFolder for a folder named name that itself may contain a Humanoid (e.g., teamFolder.Bunny)
                -- (teamFolder:FindFirstChild(name) already covers this if Bunny is present)
                -- Additionally, search children of teamFolder for models whose name contains the name (case-insensitive partial)
                for _, child in ipairs(teamFolder:GetChildren()) do
                    if child:IsA("Model") and child.Name:lower():find(name:lower()) then
                        return child, nextIndex
                    end
                end
            end
        end

        -- advance index
        nextIndex = nextIndex + 1
        if nextIndex > n then nextIndex = 1 end
        tries = tries + 1
    end

    return nil, nextIndex
end

-- Attack a single egg model and persist teleporting until egg gone (used for eggs)
local function attackModelPersist(targetModel)
    if not targetModel then return end

    local targetPart = getTargetPartFromModel(targetModel)
    if not targetPart then
        dprint("No target part for model:", tostring(targetModel.Name))
        return
    end

    -- Keep teleporting + activating until removed or humanoid dead or timeout
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

        -- Teleport near the target each iteration to ensure we stay in range
        local pos = targetPart.Position + CONFIG.TeleportOffset
        teleportToPosition(pos, targetPart.Position)

        -- Equip & activate sword
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

-- GUI: create small draggable GUI with two buttons (Eggs + Easter)
local function createGui()
    -- remove existing if present
    local existing = player:WaitForChild("PlayerGui"):FindFirstChild("AutoEggsGui")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoEggsGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 260, 0, 128)
    frame.Position = UDim2.new(0, 24, 0.6, -64)
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
    eggsBtn.Size = UDim2.new(0.48, -10, 0, 44)
    eggsBtn.Position = UDim2.new(0, 6, 0, 40)
    eggsBtn.BackgroundColor3 = Color3.fromRGB(55, 120, 70)
    eggsBtn.TextColor3 = Color3.new(1,1,1)
    eggsBtn.Font = Enum.Font.SourceSansBold
    eggsBtn.TextSize = 16
    eggsBtn.Text = "Auto Eggs: OFF"
    eggsBtn.Parent = frame

    -- Easter button (NEW)
    local easterBtn = Instance.new("TextButton")
    easterBtn.Size = UDim2.new(0.48, -10, 0, 44)
    easterBtn.Position = UDim2.new(0.52, 4, 0, 40)
    easterBtn.BackgroundColor3 = Color3.fromRGB(200, 120, 40)
    easterBtn.TextColor3 = Color3.new(1,1,1)
    easterBtn.Font = Enum.Font.SourceSansBold
    easterBtn.TextSize = 16
    easterBtn.Text = "Auto Easter: OFF"
    easterBtn.Parent = frame

    -- Draggable: track input from frame
    frame.Active = true -- important to receive input events for dragging
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

    return screenGui, eggsBtn, easterBtn, frame
end

-- Main runner
local autoEggs = false
local autoEaster = false
local gui, eggsBtn, easterBtn = createGui()
local currentEggIndex = 1
local currentEasterIndex = 1

eggsBtn.MouseButton1Click:Connect(function()
    autoEggs = not autoEggs
    eggsBtn.Text = autoEggs and "Auto Eggs: ON" or "Auto Eggs: OFF"
end)

easterBtn.MouseButton1Click:Connect(function()
    autoEaster = not autoEaster
    easterBtn.Text = autoEaster and "Auto Easter: ON" or "Auto Easter: OFF"
end)

-- Background loop: pick an egg, persist on it until gone, then move to next.
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

-- Background loop: pick an Easter target, persist on it until gone, then move to next.
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
