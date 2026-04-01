-- AutoEggs (client-side) -- draggable GUI + persistent-teleport-per-egg behavior
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
        "Orange Egg", -- added
    },
    Debug = true,
    PerEggTimeout = 30, -- safety: max seconds to spend on a single egg (adjust if you want)
}

local function dprint(...)
    if CONFIG.Debug then
        print("[AutoEggs]", ...)
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

-- Get a useful target part from an egg model
local function getTargetPartFromEggModel(model)
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

-- Attack a single egg model and persist teleporting until egg gone
local function attackEggModelPersist(eggModel)
    if not eggModel then return end

    local targetPart = getTargetPartFromEggModel(eggModel)
    if not targetPart then
        dprint("No target part for egg:", eggModel:GetDebugId() or eggModel.Name)
        return
    end

    -- Keep teleporting + activating until egg removed or humanoid dead or timeout
    local startTime = tick()
    while true do
        -- stop if egg removed (no parent)
        if not eggModel.Parent then
            dprint("Egg removed:", eggModel.Name)
            break
        end

        -- check humanoid (if present)
        local eggHumanoid = eggModel:FindFirstChildOfClass("Humanoid")
        if eggHumanoid and eggHumanoid.Health <= 0 then
            dprint("Egg humanoid died:", eggModel.Name)
            break
        end

        -- Teleport near the egg each iteration to ensure we stay in range
        local pos = targetPart.Position + CONFIG.TeleportOffset
        teleportToPosition(pos, targetPart.Position)

        -- Equip & activate sword
        local sword = equipToolByName(CONFIG.SwordName)
        if sword and sword:IsA("Tool") then
            -- Use pcall in case Activate errors
            pcall(function()
                sword:Activate()
            end)
        else
            dprint("Sword not found while attacking egg:", CONFIG.SwordName)
            -- if no sword, we still keep teleporting but break to avoid infinite loop
            break
        end

        -- Timeout safety
        if tick() - startTime > CONFIG.PerEggTimeout then
            dprint("Per-egg timeout reached for:", eggModel.Name)
            break
        end

        task.wait(CONFIG.ClickInterval)
    end
end

-- GUI: create small draggable GUI
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
    frame.Size = UDim2.new(0, 240, 0, 92)
    frame.Position = UDim2.new(0, 24, 0.6, -46)
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
    title.Text = "Auto Egg Farmer"
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 18
    title.TextColor3 = Color3.new(1,1,1)
    title.Parent = frame

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(1, -12, 0, 44)
    toggleBtn.Position = UDim2.new(0, 6, 0, 38)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(55, 120, 70)
    toggleBtn.TextColor3 = Color3.new(1,1,1)
    toggleBtn.Font = Enum.Font.SourceSansBold
    toggleBtn.TextSize = 18
    toggleBtn.Text = "Auto Eggs: OFF"
    toggleBtn.Parent = frame

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

    return screenGui, toggleBtn, frame
end

-- Main runner
local autoEggs = false
local gui, toggleBtn = createGui()
local currentEggIndex = 1

toggleBtn.MouseButton1Click:Connect(function()
    autoEggs = not autoEggs
    toggleBtn.Text = autoEggs and "Auto Eggs: ON" or "Auto Eggs: OFF"
end)

-- Background loop: pick an egg, persist on it until gone, then move to next.
task.spawn(function()
    while true do
        if autoEggs then
            -- Ensure character exists
            if not player.Character then
                player.CharacterAdded:Wait()
            end

            local eggModel, idx = getNextEggModel(currentEggIndex)
            if eggModel then
                -- Set next index for subsequent searches (round-robin)
                currentEggIndex = idx + 1
                if currentEggIndex > #CONFIG.EggNames then currentEggIndex = 1 end

                dprint("Starting persistent attack on egg:", eggModel.Name)
                attackEggModelPersist(eggModel)
                -- small pause before getting next egg
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
