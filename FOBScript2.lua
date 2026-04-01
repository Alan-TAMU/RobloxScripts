-- AutoEggs + AutoEaster + AutoCombined (client-side) - fixed button layout (absolute positions)
-- Paste into a LocalScript (StarterPlayerScripts)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

-- CONFIG
local CONFIG = {
    SwordName = "Greatsword of Flying II",
    TeleportOffset = Vector3.new(0, 4, 0),
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
}

local function dprint(...)
    if CONFIG.Debug then
        print("[AutoFarm]", ...)
    end
end

-- basic character helpers
local function getCharacter()
    return player.Character or player.CharacterAdded:Wait()
end
local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
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

-- find helper: egg parent
local function findEggParent()
    local cur = workspace
    for _, name in ipairs(CONFIG.EggParentPath) do
        cur = cur:FindFirstChild(name)
        if not cur then return nil end
    end
    return cur
end

-- get a part to teleport to for a model
local function getTargetPartFromModel(model)
    if not model then return nil end
    if model:FindFirstChild("HumanoidRootPart") then return model.HumanoidRootPart end
    if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then return model.PrimaryPart end
    for _, c in ipairs(model:GetChildren()) do
        if c:IsA("BasePart") then return c end
    end
    return nil
end

-- tool helpers
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

-- egg round-robin
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

-- search Easter characters across teams
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

-- attack loop that persists on a model until removed/dead/timeout
local function attackModelPersist(targetModel)
    if not targetModel then return end
    local part = getTargetPartFromModel(targetModel)
    if not part then
        dprint("No target part for model:", tostring(targetModel.Name))
        return
    end
    local startTime = tick()
    while true do
        if not targetModel.Parent then dprint("Target removed:", targetModel.Name); break end
        local hum = targetModel:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health <= 0 then dprint("Target humanoid died:", targetModel.Name); break end
        teleportToPosition(part.Position + CONFIG.TeleportOffset, part.Position)
        local sword = equipToolByName(CONFIG.SwordName)
        if sword and sword:IsA("Tool") then
            pcall(function() sword:Activate() end)
        else
            dprint("Sword not found:", CONFIG.SwordName); break
        end
        if tick() - startTime > CONFIG.PerTargetTimeout then dprint("Timeout for:", targetModel.Name); break end
        task.wait(CONFIG.ClickInterval)
    end
end

-- GUI (fixed absolute positions so all 3 buttons render)
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
    frame.Size = UDim2.new(0, 320, 0, 150) -- wide enough for 3 absolute buttons
    frame.Position = UDim2.new(0, 24, 0.6, -75)
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

    -- Eggs button (absolute)
    local eggsBtn = Instance.new("TextButton", frame)
    eggsBtn.Size = UDim2.new(0, 96, 0, 44)
    eggsBtn.Position = UDim2.new(0, 6, 0, 44)
    eggsBtn.BackgroundColor3 = Color3.fromRGB(55,120,70)
    eggsBtn.Font = Enum.Font.SourceSansBold
    eggsBtn.TextSize = 14
    eggsBtn.TextColor3 = Color3.new(1,1,1)
    eggsBtn.Text = "Auto Eggs: OFF"

    -- Easter button (absolute)
    local easterBtn = Instance.new("TextButton", frame)
    easterBtn.Size = UDim2.new(0, 96, 0, 44)
    easterBtn.Position = UDim2.new(0, 108, 0, 44) -- 6 + 96 + 6 = 108
    easterBtn.BackgroundColor3 = Color3.fromRGB(200,120,40)
    easterBtn.Font = Enum.Font.SourceSansBold
    easterBtn.TextSize = 14
    easterBtn.TextColor3 = Color3.new(1,1,1)
    easterBtn.Text = "Auto Easter: OFF"

    -- Combined button (absolute)
    local combinedBtn = Instance.new("TextButton", frame)
    combinedBtn.Size = UDim2.new(0, 96, 0, 44)
    combinedBtn.Position = UDim2.new(0, 210, 0, 44) -- 108 + 96 + 6 = 210
    combinedBtn.BackgroundColor3 = Color3.fromRGB(120,60,200)
    combinedBtn.Font = Enum.Font.SourceSansBold
    combinedBtn.TextSize = 14
    combinedBtn.TextColor3 = Color3.new(1,1,1)
    combinedBtn.Text = "Auto Combined: OFF"

    -- draggable logic (frame)
    frame.Active = true
    local dragging, dragStart, startPos, dragInput = false, nil, nil, nil
    local function updateDrag(input)
        if not dragging or not dragStart or not startPos then return end
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
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
        if input == dragInput then updateDrag(input) end
    end)

    return screenGui, eggsBtn, easterBtn, combinedBtn
end

-- main state
local autoEggs, autoEaster, autoCombined = false, false, false
local gui, eggsBtn, easterBtn, combinedBtn = createGui()
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
    if not autoCombined then
        setModeStates(false,false,true)
    else
        setModeStates(false,false,false)
    end
end)

-- worker loops (eggs, easter, combined)
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
