local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local EGG_NAMES = {
	"Blue Egg",
	"Green Egg",
	"Pink Egg",
	"Yellow Egg",
	"Shiny Red Egg",
	"Shiny Pink Egg",
	"Shiny Green Egg",
	"Golden Egg",
}

local scanning = false
local minimized = false

local dragging = false
local dragInput = nil
local dragStart = nil
local startPos = nil

local function getEggContainer()
	local unbreakable = workspace:FindFirstChild("Unbreakable")
	if not unbreakable then
		return nil
	end

	local characters = unbreakable:FindFirstChild("Characters")
	if not characters then
		return nil
	end

	local undead = characters:FindFirstChild("Undead")
	if not undead then
		return nil
	end

	return undead
end

local function getEggModelByName(name)
	local container = getEggContainer()
	if not container then
		return nil
	end

	local model = container:FindFirstChild(name)
	if model and model:IsA("Model") then
		return model
	end

	return nil
end

local function getEggHumanoid(name)
	local model = getEggModelByName(name)
	if not model then
		return nil
	end

	local humanoid = model:FindFirstChild("Humanoid")
	if humanoid and humanoid:IsA("Humanoid") then
		return humanoid
	end

	return nil
end

local function getEggTargetPart(model)
	if not model then
		return nil
	end

	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end

	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end

	for _, partName in ipairs({"Head", "Torso", "UpperTorso"}) do
		local part = model:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			return part
		end
	end

	return model:FindFirstChildWhichIsA("BasePart")
end

local existingGui = player:WaitForChild("PlayerGui"):FindFirstChild("EggTesterGui")
if existingGui then
	existingGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EggTesterGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local expandedSize = UDim2.new(0, 320, 0, 360)
local minimizedSize = UDim2.new(0, 320, 0, 34)

local frame = Instance.new("Frame")
frame.Size = expandedSize
frame.Position = UDim2.new(0, 20, 0.5, -180)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
frame.BorderSizePixel = 0
frame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 12)
frameCorner.Parent = frame

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 34)
titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
titleBar.BorderSizePixel = 0
titleBar.Active = true
titleBar.Parent = frame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = titleBar

local titleFill = Instance.new("Frame")
titleFill.Size = UDim2.new(1, 0, 0, 12)
titleFill.Position = UDim2.new(0, 0, 1, -12)
titleFill.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
titleFill.BorderSizePixel = 0
titleFill.Parent = titleBar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -44, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Egg Path Tester"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.SourceSansBold
title.TextSize = 20
title.Parent = titleBar

local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.new(0, 28, 0, 24)
minimizeButton.Position = UDim2.new(1, -34, 0, 5)
minimizeButton.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
minimizeButton.TextColor3 = Color3.new(1, 1, 1)
minimizeButton.Font = Enum.Font.SourceSansBold
minimizeButton.TextSize = 22
minimizeButton.Text = "-"
minimizeButton.BorderSizePixel = 0
minimizeButton.Parent = titleBar

local minimizeCorner = Instance.new("UICorner")
minimizeCorner.CornerRadius = UDim.new(0, 8)
minimizeCorner.Parent = minimizeButton

local content = Instance.new("ScrollingFrame")
content.Size = UDim2.new(1, -12, 1, -46)
content.Position = UDim2.new(0, 6, 0, 40)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 6
content.CanvasSize = UDim2.new(0, 0, 0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = frame

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 4)
padding.PaddingRight = UDim.new(0, 4)
padding.PaddingTop = UDim.new(0, 2)
padding.PaddingBottom = UDim.new(0, 6)
padding.Parent = content

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = content

local function createLabel(text, height, size, bold)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -8, 0, height or 24)
	label.BackgroundTransparency = 1
	label.Text = text or ""
	label.TextColor3 = Color3.fromRGB(220, 220, 220)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.Font = bold and Enum.Font.SourceSansBold or Enum.Font.SourceSans
	label.TextSize = size or 18
	label.Parent = content
	return label
end

local function createButton(text)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -8, 0, 40)
	button.BackgroundColor3 = Color3.fromRGB(65, 65, 75)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.SourceSansBold
	button.TextSize = 20
	button.Text = text
	button.BorderSizePixel = 0
	button.Parent = content

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button

	return button
end

local statusLabel = createLabel("Status: Idle", 24, 18, false)
local scanButton = createButton("Live Scan: OFF")
local refreshButton = createButton("Refresh Egg Check")
local foundHeader = createLabel("Egg Results", 24, 18, true)
local foundLabel = createLabel("No scan yet.", 220, 16, false)

local function updateDrag(input)
	local delta = input.Position - dragStart
	frame.Position = UDim2.new(
		startPos.X.Scale,
		startPos.X.Offset + delta.X,
		startPos.Y.Scale,
		startPos.Y.Offset + delta.Y
	)
end

titleBar.InputBegan:Connect(function(input)
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

titleBar.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and input == dragInput then
		updateDrag(input)
	end
end)

local function buildEggReport()
	local lines = {}
	local foundCount = 0
	local container = getEggContainer()

	if not container then
		return "Undead container not found:\nworkspace.Unbreakable.Characters.Undead"
	end

	for _, eggName in ipairs(EGG_NAMES) do
		local model = getEggModelByName(eggName)
		local humanoid = getEggHumanoid(eggName)

		if model and humanoid then
			foundCount += 1

			local targetPart = getEggTargetPart(model)
			local hpText = "HP: " .. tostring(math.floor(humanoid.Health + 0.5))

			if targetPart then
				table.insert(lines, "✓ " .. eggName .. " | " .. hpText .. " | TargetPart: " .. targetPart.Name)
			else
				table.insert(lines, "✓ " .. eggName .. " | " .. hpText .. " | No target part found")
			end
		else
			table.insert(lines, "✗ " .. eggName .. " | Missing model or Humanoid")
		end
	end

	return "Found " .. tostring(foundCount) .. "/" .. tostring(#EGG_NAMES) .. " eggs\n\n" .. table.concat(lines, "\n")
end

local function updateGui()
	scanButton.Text = scanning and "Live Scan: ON" or "Live Scan: OFF"
	scanButton.BackgroundColor3 = scanning and Color3.fromRGB(50, 140, 70) or Color3.fromRGB(65, 65, 75)

	if scanning then
		statusLabel.Text = "Status: Scanning egg paths"
	else
		statusLabel.Text = "Status: Idle"
	end

	if minimized then
		frame.Size = minimizedSize
		content.Visible = false
		minimizeButton.Text = "+"
	else
		frame.Size = expandedSize
		content.Visible = true
		minimizeButton.Text = "-"
	end
end

scanButton.MouseButton1Click:Connect(function()
	scanning = not scanning
	if scanning then
		foundLabel.Text = buildEggReport()
	end
	updateGui()
end)

refreshButton.MouseButton1Click:Connect(function()
	foundLabel.Text = buildEggReport()
	updateGui()
end)

minimizeButton.MouseButton1Click:Connect(function()
	minimized = not minimized
	updateGui()
end)

updateGui()
foundLabel.Text = buildEggReport()

task.spawn(function()
	while true do
		if scanning then
			foundLabel.Text = buildEggReport()
			task.wait(0.5)
		else
			task.wait(0.1)
		end
	end
end)
