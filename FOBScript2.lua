-- AutoEggFarming GUI (client-side)
-- Paste into a LocalScript (StarterPlayerScripts or similar)
-- Uses the same sword-equip / :Activate() approach as your existing script.

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local RunService = game:GetService("RunService")

-- Config
local CONFIG = {
    SwordName = "Greatsword of Flying II", -- matches your backpack path
    TeleportOffset = Vector3.new(0, 4, 0),
    ClickInterval = 0.12,
    EggParentPath = {"Unbreakable", "Characters", "Undead"}, -- base path to eggs
    EggNames = {
        "Blue Egg",
        "Green Egg",
        "Pink Egg",
        "Yellow Egg",
        "Shiny Red Egg",
        "Shiny Pink Egg",
        "Shiny Green Egg",
        "Golden Egg",
    },
    Debug = true,
}

local function dprint(...)
    if CONFIG.Debug then
        print("[AutoEggs]", ...)
    end
end

-- Basic helpers (robustly find player character/humanoid/rootpart)
local function getCharacter()
    return player.Character or player.CharacterAdded:Wait()
end

local function getRoot()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function findEggParent()
    local cur = workspace
    for _, name in ipairs(CONFIG.EggParentPath) do
        cur = cur:FindFirstChild(name)
        if not cur then return nil end
    end
    return cur
end

local function findEggModelByName(name)
    local parent = findEggParent()
    if not parent then return nil end
    return parent:FindFirstChild(name)
end

local function getTargetPartFromEggModel(model)
    if not model then return nil end
    -- Prefer HumanoidRootPart
    if model:FindFirstChild("HumanoidRootPart") then
        return model.HumanoidRootPart
    end
    -- Some eggs may be a single part or have PrimaryPart
    if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
        return model.PrimaryPart
    end
    -- fallback to any BasePart
    for _, child in ipairs(model:GetChildren()) do
        if child:IsA("BasePart") then
            return child
        end
    end
    return nil
end

-- Tool/equip helpers (copied/adjusted from your original approach)
local function findRealTool(toolName)
    local character = getCharacter()
    -- Tools folder (if used)
    local toolsFolder = player:FindFirstChild("Tools")
    if toolsFolder then
        local t = toolsFolder:FindFirstChild(toolName)
        if t and t:IsA("Tool") then return t end
    end
    -- equipped tool on model
    local equipped = character:FindFirstChild(toolName)
    if equipped and equipped:IsA("Tool") then return equipped end
    -- backpack
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        local b = backpack:FindFirstChild(toolName)
        if b and b:IsA("Tool") then return b end
    end
    return nil
end

local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function equipToolByName(toolName)
    local humanoid = getHumanoid()
    if not humanoid then return nil end
    local tool = findRealTool(toolName)
    if not tool then
        return nil
    end
    if tool.Parent ~= getCharacter() then
        -- Equip from backpack
        humanoid:EquipTool(tool)
        task.wait(0.12)
    end
    -- return reference to the tool instance (now parented to character)
    return getCharacter():FindFirstChild(toolName) or tool
end

-- Teleport helper (client-side pivot)
local function teleportToPosition(pos, lookAt)
    local char = getCharacter()
    if not char then return end
    local root = getRoot()
    if not root then return end
    local cf
    if lookAt then
        cf = CFrame.new(pos, lookAt)
    else
        cf = CFrame.new(pos)
    end
    -- Use PivotTo to avoid velocity issues
    if char.PrimaryPart then
        char:PivotTo(cf)
    else
        -- fallback: set HumanoidRootPart CFrame
        root.CFrame = cf
    end
end

-- Main attack loop for a single egg model
local function attackEggModel(eggModel)
    if not eggModel then return end

    local targetPart = getTargetPartFromEggModel(eggModel)
    if not targetPart then
        dprint("No target part for egg:", eggModel.Name)
        return
    end

    -- Teleport near the egg
    local targetPos = targetPart.Position + CONFIG.TeleportOffset
    teleportToPosition(targetPos, targetPart.Position)
    task.wait(0.06) -- small wait to ensure pivot finished

    -- Try to get the egg's humanoid (some eggs may contain a Humanoid)
    local eggHumanoid = eggModel:FindFirstChildOfClass("Humanoid")
    -- Equip sword
    local sword = equipToolByName(CONFIG.SwordName)
    if not sword then
        dprint("Could not find sword:", CONFIG.SwordName, "Make sure it's in Backpack or Tools.")
        return
    end

    -- Rapidly activate sword until egg is gone or timeout/interrupt
    local startTime = tick()
    local timeout = 10 -- seconds max per egg to avoid infinite loops (adjust if needed)

    while true do
        -- If the egg model no longer exists, break
        if not eggModel.Parent then
            dprint("Egg removed (destroyed):", eggModel.Name)
            break
        end

        -- If egg has humanoid, stop when health <= 0
        if eggHumanoid then
            if eggHumanoid.Health <= 0 then
                dprint("Egg humanoid died:", eggModel.Name)
                break
            end
        end

        -- Activate the sword (client-side)
        local ok, err = pcall(function()
            if sword and sword:IsA("Tool") then
                sword:Activate()
            end
        end)
        if not ok then
            dprint("Activate failed:", tostring(err))
        end

        -- Safety timeout
        if tick() - startTime > timeout then
            dprint("Timed out on egg:", eggModel.Name)
            break
        end

        task.wait(CONFIG.ClickInterval)
    end
end

-- Iterate through configured egg list (returns next available model or nil)
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
        -- advance
        nextIndex = nextIndex + 1
        if nextIndex > n then nextIndex = 1 end
        tries = tries + 1
    end
    return nil, nextIndex
end

-- Build a small GUI with a toggle button
local function createGui()
    -- destroy existing gui if present
    local existing = player:WaitForChild("PlayerGui"):FindFirstChild("AutoEggsGui")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoEggsGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 220, 0, 80)
    frame.Position = UDim2.new(0, 16, 0.6, -40)
    frame.BackgroundColor3 = Color3.fromRGB(28, 28, 30)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.Parent = frame
    corner.CornerRadius = UDim.new(0, 10)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -12, 0, 28)
    title.Position = UDim2.new(0, 6, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = "Auto Egg Farmer"
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 18
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -12, 0, 40)
    btn.Position = UDim2.new(0, 6, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(55, 120, 70)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 18
    btn.Text = "Auto Eggs: OFF"
    btn.Parent = frame

    return screenGui, btn
end

-- Main toggle & runner
local autoEggs = false
local gui, toggleBtn = createGui()
local currentEggIndex = 1

toggleBtn.MouseButton1Click:Connect(function()
    autoEggs = not autoEggs
    toggleBtn.Text = autoEggs and "Auto Eggs: ON" or "Auto Eggs: OFF"
end)

-- Background task: auto-farm eggs when toggled on
task.spawn(function()
    while true do
        if autoEggs then
            local eggModel, idx = getNextEggModel(currentEggIndex)
            if eggModel then
                currentEggIndex = idx + 1
                if currentEggIndex > #CONFIG.EggNames then currentEggIndex = 1 end
                -- Double-check character exists
                if not player.Character then
                    player.CharacterAdded:Wait()
                end
                attackEggModel(eggModel)
                task.wait(0.08)
            else
                -- No eggs found: wait longer then retry
                dprint("No eggs found under path; waiting then retrying.")
                task.wait(1.2)
            end
        else
            task.wait(0.12)
        end
    end
end)
