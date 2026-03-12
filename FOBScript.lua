local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer

local CONFIG = {
	ContainerPath = {"Unbreakable", "Projectiles"},

	BadGemColor = Color3.fromRGB(248, 248, 248),
	ColorTolerance = 3,
	MaxChildrenToCheck = 150,

	TeleportOffset = Vector3.new(0, 4, 0),
	TeleportDelay = 0.3,
	AutoCollectOnStart = false,

	OrcContainerPath = {"Unbreakable", "Characters", "Orc"},
	OrcName = "Orc General",
	OrcTeleportOffset = Vector3.new(0, 0, 3),
	OrcDelay = 0.01,
	AutoOrcOnStart = false,

	HumanContainerPath = {"Unbreakable", "Characters", "Human"},
	HumanName = "Human General",
	HumanTeleportOffset = Vector3.new(0, 0, 3),
	HumanDelay = 0.01,
	GeneralDelay = 0.01,
	AutoHumanOnStart = false,

	NeutralContainerPath = {"Unbreakable", "Characters", "Neutral"},
	NeutralTeleportOffset = Vector3.new(0, 0, 3),
	NeutralDelay = 0.01,

	DemonContainerPath = {"Unbreakable", "Characters", "Demon"},
	DemonName = "Giant Demon Spawn",
	DemonTeleportOffset = Vector3.new(0, 0, 3),
	DemonDelay = 0.01,
	AutoDemonOnStart = false,

	AntiAfkOnStart = false,

	SwordName = "Greatsword of Flying II",
	BowName = "Short Bow",

	Debug = true
}

local DEFAULTS = {
	TeleportDelay = CONFIG.TeleportDelay,
	OrcDelay = CONFIG.OrcDelay,
	HumanDelay = CONFIG.HumanDelay,
	NeutralDelay = CONFIG.NeutralDelay,
	DemonDelay = CONFIG.DemonDelay,
	GeneralDelay = CONFIG.GeneralDelay,
	SwordName = CONFIG.SwordName,
	BowName = CONFIG.BowName,
}

local PROFILE_FOLDER_NAME = "FOB_GUI_SAVED_PROFILES"
local ACTIVE_PROFILE_ATTRIBUTE = "FOB_GUI_ACTIVE_PROFILE"

local autoCollect = CONFIG.AutoCollectOnStart
local autoOrc = CONFIG.AutoOrcOnStart
local autoOrcNPC = false
local autoHuman = CONFIG.AutoHumanOnStart
local autoHumanNPC = false
local autoNeutralNPC = false
local autoTeamNPC = false
local autoBowOrc = false
local autoBowHuman = false
local autoGeneral = false
local autoDemon = CONFIG.AutoDemonOnStart
local autoTeamTarget = false
local autoTeamTargetCollect = false
local antiAfk = CONFIG.AntiAfkOnStart
local antiAfkConnection = nil
local minimized = false
local activeTab = "Main"
local currentProfileName = ""

local gemList = {}
local currentGemIndex = 1

local humanNPCList = {}
local currentHumanNPCIndex = 1
local currentHumanNPCTarget = nil

local orcNPCList = {}
local currentOrcNPCIndex = 1
local currentOrcNPCTarget = nil

local neutralNPCList = {}
local currentNeutralNPCIndex = 1
local currentNeutralNPCTarget = nil

local currentTeamNPCTarget = nil
local currentTeamNPCTargetType = nil

local timedCollectEndTime = 0
local teamTargetCollectSawDemon = false
local teamTargetCollectTriggered = false

local expandedSize = UDim2.new(0, 300, 0, 440)
local minimizedSize = UDim2.new(0, 300, 0, 34)

local dragging = false
local dragInput = nil
local dragStart = nil
local startPos = nil

local function dprint(...)
	if CONFIG.Debug then
		print("[AutoGem]", ...)
	end
end

local function trimString(value)
	if type(value) ~= "string" then
		return ""
	end
	return (value:match("^%s*(.-)%s*$") or "")
end

local function getProfilesFolder()
	local folder = player:FindFirstChild(PROFILE_FOLDER_NAME)
	if folder and folder:IsA("Folder") then
		return folder
	end

	if folder then
		folder:Destroy()
	end

	folder = Instance.new("Folder")
	folder.Name = PROFILE_FOLDER_NAME
	folder.Parent = player
	return folder
end

local function listProfileNames()
	local folder = getProfilesFolder()
	local names = {}

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("StringValue") then
			table.insert(names, child.Name)
		end
	end

	table.sort(names, function(a, b)
		return string.lower(a) < string.lower(b)
	end)

	return names
end

local function getCharacter()
	return player.Character or player.CharacterAdded:Wait()
end

local function getRoot()
	local character = getCharacter()
	return character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
	local character = getCharacter()
	return character:FindFirstChildOfClass("Humanoid")
end

local function getContainer()
	local current = workspace
	for _, name in ipairs(CONFIG.ContainerPath) do
		current = current:FindFirstChild(name)
		if not current then
			return nil
		end
	end
	return current
end

local function getOrcContainer()
	local current = workspace
	for _, name in ipairs(CONFIG.OrcContainerPath) do
		current = current:FindFirstChild(name)
		if not current then
			return nil
		end
	end
	return current
end

local function getHumanContainer()
	local current = workspace
	for _, name in ipairs(CONFIG.HumanContainerPath) do
		current = current:FindFirstChild(name)
		if not current then
			return nil
		end
	end
	return current
end

local function getNeutralContainer()
	local current = workspace
	for _, name in ipairs(CONFIG.NeutralContainerPath) do
		current = current:FindFirstChild(name)
		if not current then
			return nil
		end
	end
	return current
end

local function getDemonContainer()
	local current = workspace
	for _, name in ipairs(CONFIG.DemonContainerPath) do
		current = current:FindFirstChild(name)
		if not current then
			return nil
		end
	end
	return current
end

local function getPlayerTeamFolder()
	local character = player.Character
	if character and character.Parent then
		local parentName = character.Parent.Name
		if parentName == "Orc" then
			return "Orc"
		elseif parentName == "Human" then
			return "Human"
		elseif parentName == "Neutral" then
			return "Neutral"
		end
	end

	local unbreakable = workspace:FindFirstChild("Unbreakable")
	if not unbreakable then
		return nil
	end

	local characters = unbreakable:FindFirstChild("Characters")
	if not characters then
		return nil
	end

	local username = player.Name

	local orcFolder = characters:FindFirstChild("Orc")
	if orcFolder and orcFolder:FindFirstChild(username) then
		return "Orc"
	end

	local humanFolder = characters:FindFirstChild("Human")
	if humanFolder and humanFolder:FindFirstChild(username) then
		return "Human"
	end

	local neutralFolder = characters:FindFirstChild("Neutral")
	if neutralFolder and neutralFolder:FindFirstChild(username) then
		return "Neutral"
	end

	return nil
end

local function getOrcModel()
	local container = getOrcContainer()
	if not container then
		return nil
	end

	local orc = container:FindFirstChild(CONFIG.OrcName)
	if orc and orc:IsA("Model") then
		return orc
	end

	return nil
end

local function getHumanModel()
	local container = getHumanContainer()
	if not container then
		return nil
	end

	local human = container:FindFirstChild(CONFIG.HumanName)
	if human and human:IsA("Model") then
		return human
	end

	return nil
end

local function getDemonModel()
	local container = getDemonContainer()
	if not container then
		return nil
	end

	local demon = container:FindFirstChild(CONFIG.DemonName)
	if demon and demon:IsA("Model") then
		return demon
	end

	return nil
end

local function getOrcHumanoid()
	local orc = getOrcModel()
	if not orc then
		return nil
	end

	local humanoid = orc:FindFirstChild("Humanoid")
	if humanoid and humanoid:IsA("Humanoid") then
		return humanoid
	end

	return nil
end

local function getHumanHumanoid()
	local human = getHumanModel()
	if not human then
		return nil
	end

	local humanoid = human:FindFirstChild("Humanoid")
	if humanoid and humanoid:IsA("Humanoid") then
		return humanoid
	end

	return nil
end

local function getDemonHumanoid()
	local demon = getDemonModel()
	if not demon then
		return nil
	end

	local humanoid = demon:FindFirstChild("Humanoid")
	if humanoid and humanoid:IsA("Humanoid") then
		return humanoid
	end

	return nil
end

local function getTargetPartFromModel(model)
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

local function getOrcTargetPart()
	return getTargetPartFromModel(getOrcModel())
end

local function getHumanTargetPart()
	return getTargetPartFromModel(getHumanModel())
end

local function getDemonTargetPart()
	return getTargetPartFromModel(getDemonModel())
end

local function isValidHumanNPCModel(model)
	if not model or not model:IsA("Model") then
		return false
	end

	if model.Name == CONFIG.HumanName then
		return false
	end

	if model.Name == player.Name then
		return false
	end

	local humanoid = model:FindFirstChild("Humanoid")
	if not humanoid or not humanoid:IsA("Humanoid") then
		return false
	end

	if humanoid.Health <= 0 then
		return false
	end

	if not getTargetPartFromModel(model) then
		return false
	end

	return true
end

local function rebuildHumanNPCList()
	local container = getHumanContainer()
	if not container then
		humanNPCList = {}
		currentHumanNPCIndex = 1
		return
	end

	local newList = {}

	for _, obj in ipairs(container:GetChildren()) do
		if isValidHumanNPCModel(obj) then
			table.insert(newList, obj)
		end
	end

	table.sort(newList, function(a, b)
		if a.Name == b.Name then
			return a:GetDebugId() < b:GetDebugId()
		end
		return a.Name < b.Name
	end)

	humanNPCList = newList

	if #humanNPCList == 0 then
		currentHumanNPCIndex = 1
	elseif currentHumanNPCIndex > #humanNPCList then
		currentHumanNPCIndex = 1
	end
end

local function getNextHumanNPCModel()
	if #humanNPCList == 0 then
		return nil
	end

	local checked = 0
	while checked < #humanNPCList do
		local model = humanNPCList[currentHumanNPCIndex]

		if isValidHumanNPCModel(model) then
			currentHumanNPCIndex += 1
			if currentHumanNPCIndex > #humanNPCList then
				currentHumanNPCIndex = 1
			end
			return model
		else
			table.remove(humanNPCList, currentHumanNPCIndex)
			if currentHumanNPCIndex > #humanNPCList and #humanNPCList > 0 then
				currentHumanNPCIndex = 1
			end
		end

		checked += 1
		if #humanNPCList == 0 then
			return nil
		end
	end

	return nil
end

local function isCurrentHumanNPCTargetValid(model)
	if not isValidHumanNPCModel(model) then
		return false
	end

	local humanoid = model:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	return true
end

local function teleportToHumanNPC(model)
	local character = getCharacter()
	local root = getRoot()
	local targetPart = getTargetPartFromModel(model)

	if not character or not root or not targetPart then
		return
	end

	local targetPos = targetPart.Position + CONFIG.HumanTeleportOffset
	character:PivotTo(CFrame.new(targetPos, targetPart.Position))
end

local function isValidOrcNPCModel(model)
	if not model or not model:IsA("Model") then
		return false
	end

	if model.Name == CONFIG.OrcName then
		return false
	end

	if model.Name == player.Name then
		return false
	end

	local humanoid = model:FindFirstChild("Humanoid")
	if not humanoid or not humanoid:IsA("Humanoid") then
		return false
	end

	if humanoid.Health <= 0 then
		return false
	end

	if not getTargetPartFromModel(model) then
		return false
	end

	return true
end

local function rebuildOrcNPCList()
	local container = getOrcContainer()
	if not container then
		orcNPCList = {}
		currentOrcNPCIndex = 1
		return
	end

	local newList = {}

	for _, obj in ipairs(container:GetChildren()) do
		if isValidOrcNPCModel(obj) then
			table.insert(newList, obj)
		end
	end

	table.sort(newList, function(a, b)
		if a.Name == b.Name then
			return a:GetDebugId() < b:GetDebugId()
		end
		return a.Name < b.Name
	end)

	orcNPCList = newList

	if #orcNPCList == 0 then
		currentOrcNPCIndex = 1
	elseif currentOrcNPCIndex > #orcNPCList then
		currentOrcNPCIndex = 1
	end
end

local function getNextOrcNPCModel()
	if #orcNPCList == 0 then
		return nil
	end

	local checked = 0
	while checked < #orcNPCList do
		local model = orcNPCList[currentOrcNPCIndex]

		if isValidOrcNPCModel(model) then
			currentOrcNPCIndex += 1
			if currentOrcNPCIndex > #orcNPCList then
				currentOrcNPCIndex = 1
			end
			return model
		else
			table.remove(orcNPCList, currentOrcNPCIndex)
			if currentOrcNPCIndex > #orcNPCList and #orcNPCList > 0 then
				currentOrcNPCIndex = 1
			end
		end

		checked += 1
		if #orcNPCList == 0 then
			return nil
		end
	end

	return nil
end

local function isCurrentOrcNPCTargetValid(model)
	if not isValidOrcNPCModel(model) then
		return false
	end

	local humanoid = model:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	return true
end

local function teleportToOrcNPC(model)
	local character = getCharacter()
	local root = getRoot()
	local targetPart = getTargetPartFromModel(model)

	if not character or not root or not targetPart then
		return
	end

	local targetPos = targetPart.Position + CONFIG.OrcTeleportOffset
	character:PivotTo(CFrame.new(targetPos, targetPart.Position))
end

local function isValidNeutralNPCModel(model)
	if not model or not model:IsA("Model") then
		return false
	end

	if model.Name == player.Name then
		return false
	end

	local humanoid = model:FindFirstChild("Humanoid")
	if not humanoid or not humanoid:IsA("Humanoid") then
		return false
	end

	if humanoid.Health <= 0 then
		return false
	end

	if not getTargetPartFromModel(model) then
		return false
	end

	return true
end

local function rebuildNeutralNPCList()
	local container = getNeutralContainer()
	if not container then
		neutralNPCList = {}
		currentNeutralNPCIndex = 1
		return
	end

	local newList = {}

	for _, obj in ipairs(container:GetChildren()) do
		if isValidNeutralNPCModel(obj) then
			table.insert(newList, obj)
		end
	end

	table.sort(newList, function(a, b)
		if a.Name == b.Name then
			return a:GetDebugId() < b:GetDebugId()
		end
		return a.Name < b.Name
	end)

	neutralNPCList = newList

	if #neutralNPCList == 0 then
		currentNeutralNPCIndex = 1
	elseif currentNeutralNPCIndex > #neutralNPCList then
		currentNeutralNPCIndex = 1
	end
end

local function getNextNeutralNPCModel()
	if #neutralNPCList == 0 then
		return nil
	end

	local checked = 0
	while checked < #neutralNPCList do
		local model = neutralNPCList[currentNeutralNPCIndex]

		if isValidNeutralNPCModel(model) then
			currentNeutralNPCIndex += 1
			if currentNeutralNPCIndex > #neutralNPCList then
				currentNeutralNPCIndex = 1
			end
			return model
		else
			table.remove(neutralNPCList, currentNeutralNPCIndex)
			if currentNeutralNPCIndex > #neutralNPCList and #neutralNPCList > 0 then
				currentNeutralNPCIndex = 1
			end
		end

		checked += 1
		if #neutralNPCList == 0 then
			return nil
		end
	end

	return nil
end

local function isCurrentNeutralNPCTargetValid(model)
	if not isValidNeutralNPCModel(model) then
		return false
	end

	local humanoid = model:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	return true
end

local function teleportToNeutralNPC(model)
	local character = getCharacter()
	local root = getRoot()
	local targetPart = getTargetPartFromModel(model)

	if not character or not root or not targetPart then
		return
	end

	local targetPos = targetPart.Position + CONFIG.NeutralTeleportOffset
	character:PivotTo(CFrame.new(targetPos, targetPart.Position))
end

local function isTeamNPCTargetTypeAllowed(targetType)
	local teamFolder = getPlayerTeamFolder()

	if teamFolder == "Orc" then
		return targetType == "Human" or targetType == "Neutral"
	elseif teamFolder == "Human" then
		return targetType == "Orc" or targetType == "Neutral"
	elseif teamFolder == "Neutral" then
		return targetType == "Neutral"
	end

	return false
end

local function isCurrentTeamNPCTargetValid(model, targetType)
	if not isTeamNPCTargetTypeAllowed(targetType) then
		return false
	end

	if targetType == "Human" then
		return isCurrentHumanNPCTargetValid(model)
	elseif targetType == "Orc" then
		return isCurrentOrcNPCTargetValid(model)
	elseif targetType == "Neutral" then
		return isCurrentNeutralNPCTargetValid(model)
	end

	return false
end

local function getClosestAllowedTeamNPC()
	local teamFolder = getPlayerTeamFolder()
	local root = getRoot()

	if not root then
		return nil, nil
	end

	local bestModel = nil
	local bestType = nil
	local bestDistance = nil

	local function considerModel(model, targetType, validator)
		if not validator(model) then
			return
		end

		local targetPart = getTargetPartFromModel(model)
		if not targetPart then
			return
		end

		local distance = (root.Position - targetPart.Position).Magnitude
		if not bestDistance or distance < bestDistance then
			bestDistance = distance
			bestModel = model
			bestType = targetType
		end
	end

	if teamFolder == "Orc" then
		local humanContainer = getHumanContainer()
		if humanContainer then
			for _, model in ipairs(humanContainer:GetChildren()) do
				considerModel(model, "Human", isValidHumanNPCModel)
			end
		end

		local neutralContainer = getNeutralContainer()
		if neutralContainer then
			for _, model in ipairs(neutralContainer:GetChildren()) do
				considerModel(model, "Neutral", isValidNeutralNPCModel)
			end
		end

	elseif teamFolder == "Human" then
		local orcContainer = getOrcContainer()
		if orcContainer then
			for _, model in ipairs(orcContainer:GetChildren()) do
				considerModel(model, "Orc", isValidOrcNPCModel)
			end
		end

		local neutralContainer = getNeutralContainer()
		if neutralContainer then
			for _, model in ipairs(neutralContainer:GetChildren()) do
				considerModel(model, "Neutral", isValidNeutralNPCModel)
			end
		end

	elseif teamFolder == "Neutral" then
		local neutralContainer = getNeutralContainer()
		if neutralContainer then
			for _, model in ipairs(neutralContainer:GetChildren()) do
				considerModel(model, "Neutral", isValidNeutralNPCModel)
			end
		end
	end

	return bestModel, bestType
end

local function attackTeamNPC(model, targetType)
	if not model then
		return
	end

	local humanoid = model:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	if targetType == "Human" then
		teleportToHumanNPC(model)
	elseif targetType == "Orc" then
		teleportToOrcNPC(model)
	elseif targetType == "Neutral" then
		teleportToNeutralNPC(model)
	else
		return
	end

	attackWithSword(humanoid, model.Name)
end

local function getTeamNPCDelay(targetType)
	if targetType == "Human" then
		return CONFIG.HumanDelay
	elseif targetType == "Orc" then
		return CONFIG.OrcDelay
	elseif targetType == "Neutral" then
		return CONFIG.NeutralDelay
	end

	return 0.1
end

local function getEnemyGeneralInfo()
	local teamFolder = getPlayerTeamFolder()

	if teamFolder == "Orc" then
		return {
			label = "Human General",
			targetPart = getHumanTargetPart(),
			targetHumanoid = getHumanHumanoid(),
			offset = CONFIG.HumanTeleportOffset,
			delay = CONFIG.GeneralDelay
		}
	elseif teamFolder == "Human" then
		return {
			label = "Orc General",
			targetPart = getOrcTargetPart(),
			targetHumanoid = getOrcHumanoid(),
			offset = CONFIG.OrcTeleportOffset,
			delay = CONFIG.GeneralDelay
		}
	end

	return nil
end

local function teleportToEnemyGeneral()
	local info = getEnemyGeneralInfo()
	local character = getCharacter()
	local root = getRoot()

	if not info or not character or not root or not info.targetPart then
		return
	end

	local targetPos = info.targetPart.Position + info.offset
	character:PivotTo(CFrame.new(targetPos, info.targetPart.Position))
end

local function getEnemyGeneralHumanoid()
	local info = getEnemyGeneralInfo()
	if not info then
		return nil
	end
	return info.targetHumanoid
end

local function getEnemyGeneralLabel()
	local info = getEnemyGeneralInfo()
	if not info then
		return "Unknown General"
	end
	return info.label
end

local function getTeamTargetInfo()
	local teamFolder = getPlayerTeamFolder()

	if teamFolder == "Orc" then
		return {
			label = "Human General",
			targetPart = getHumanTargetPart(),
			targetHumanoid = getHumanHumanoid(),
			offset = CONFIG.HumanTeleportOffset,
			delay = CONFIG.GeneralDelay
		}
	elseif teamFolder == "Human" then
		return {
			label = "Orc General",
			targetPart = getOrcTargetPart(),
			targetHumanoid = getOrcHumanoid(),
			offset = CONFIG.OrcTeleportOffset,
			delay = CONFIG.GeneralDelay
		}
	elseif teamFolder == "Neutral" then
		return {
			label = "Giant Demon Spawn",
			targetPart = getDemonTargetPart(),
			targetHumanoid = getDemonHumanoid(),
			offset = CONFIG.DemonTeleportOffset,
			delay = CONFIG.DemonDelay
		}
	end

	return nil
end

local function teleportToTeamTarget()
	local info = getTeamTargetInfo()
	local character = getCharacter()
	local root = getRoot()

	if not info or not character or not root or not info.targetPart then
		return
	end

	local targetPos = info.targetPart.Position + info.offset
	character:PivotTo(CFrame.new(targetPos, info.targetPart.Position))
end

local function getTeamTargetHumanoid()
	local info = getTeamTargetInfo()
	if not info then
		return nil
	end
	return info.targetHumanoid
end

local function getTeamTargetLabel()
	local info = getTeamTargetInfo()
	if not info then
		return "Unknown Target"
	end
	return info.label
end

local function isTimedCollectActive()
	return time() < timedCollectEndTime
end

local function getTimedCollectRemaining()
	local remaining = math.ceil(timedCollectEndTime - time())
	if remaining < 0 then
		remaining = 0
	end
	return remaining
end

local function isCollectEnabled()
	return autoCollect or isTimedCollectActive()
end

local function colorClose(a, b, tolerance)
	local ar = math.floor(a.R * 255 + 0.5)
	local ag = math.floor(a.G * 255 + 0.5)
	local ab = math.floor(a.B * 255 + 0.5)

	local br = math.floor(b.R * 255 + 0.5)
	local bg = math.floor(b.G * 255 + 0.5)
	local bb = math.floor(b.B * 255 + 0.5)

	return math.abs(ar - br) <= tolerance
		and math.abs(ag - bg) <= tolerance
		and math.abs(ab - bb) <= tolerance
end

local function isFakeGem(part)
	return colorClose(part.Color, CONFIG.BadGemColor, CONFIG.ColorTolerance)
end

local function isValidGem(obj)
	if not obj then
		return false
	end

	if not obj:IsA("BasePart") then
		return false
	end

	if obj.Transparency >= 0.95 then
		return false
	end

	if isFakeGem(obj) then
		return false
	end

	if not obj.Parent then
		return false
	end

	return true
end

local function rebuildGemList()
	local container = getContainer()
	if not container then
		gemList = {}
		currentGemIndex = 1
		dprint("Container not found")
		return
	end

	local children = container:GetChildren()
	local maxIndex = math.min(CONFIG.MaxChildrenToCheck, #children)

	local newList = {}

	for index = 1, maxIndex do
		local obj = children[index]
		if isValidGem(obj) then
			table.insert(newList, obj)
		end
	end

	table.sort(newList, function(a, b)
		return a:GetDebugId() < b:GetDebugId()
	end)

	local oldCurrent = gemList[currentGemIndex]
	gemList = newList

	if #gemList == 0 then
		currentGemIndex = 1
		return
	end

	local foundIndex = nil
	if oldCurrent and isValidGem(oldCurrent) then
		for i, gem in ipairs(gemList) do
			if gem == oldCurrent then
				foundIndex = i
				break
			end
		end
	end

	if foundIndex then
		currentGemIndex = foundIndex
	else
		if currentGemIndex > #gemList then
			currentGemIndex = 1
		end
	end
end

local function getNextGem()
	if #gemList == 0 then
		return nil
	end

	local checked = 0
	while checked < #gemList do
		local gem = gemList[currentGemIndex]

		if isValidGem(gem) then
			currentGemIndex += 1
			if currentGemIndex > #gemList then
				currentGemIndex = 1
			end
			return gem
		else
			table.remove(gemList, currentGemIndex)
			if currentGemIndex > #gemList and #gemList > 0 then
				currentGemIndex = 1
			end
		end

		checked += 1
		if #gemList == 0 then
			return nil
		end
	end

	return nil
end

local function teleportToGem(gem)
	if not gem then
		return
	end

	local character = getCharacter()
	local root = getRoot()

	if not character or not root then
		return
	end

	local targetPos = gem.Position + CONFIG.TeleportOffset
	character:PivotTo(CFrame.new(targetPos, gem.Position))
end

local function teleportToOrc()
	local character = getCharacter()
	local root = getRoot()
	local targetPart = getOrcTargetPart()

	if not character or not root or not targetPart then
		return
	end

	local targetPos = targetPart.Position + CONFIG.OrcTeleportOffset
	character:PivotTo(CFrame.new(targetPos, targetPart.Position))
end

local function teleportToHuman()
	local character = getCharacter()
	local root = getRoot()
	local targetPart = getHumanTargetPart()

	if not character or not root or not targetPart then
		return
	end

	local targetPos = targetPart.Position + CONFIG.HumanTeleportOffset
	character:PivotTo(CFrame.new(targetPos, targetPart.Position))
end

local function teleportToDemon()
	local character = getCharacter()
	local root = getRoot()
	local targetPart = getDemonTargetPart()

	if not character or not root or not targetPart then
		return
	end

	local targetPos = targetPart.Position + CONFIG.DemonTeleportOffset
	character:PivotTo(CFrame.new(targetPos, targetPart.Position))
end

local function findRealTool(toolName)
	local character = getCharacter()

	local toolsFolder = player:FindFirstChild("Tools")
	if toolsFolder then
		local toolInTools = toolsFolder:FindFirstChild(toolName)
		if toolInTools and toolInTools:IsA("Tool") then
			return toolInTools
		end
	end

	local equippedTool = character:FindFirstChild(toolName)
	if equippedTool and equippedTool:IsA("Tool") then
		return equippedTool
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		local backpackTool = backpack:FindFirstChild(toolName)
		if backpackTool and backpackTool:IsA("Tool") then
			return backpackTool
		end
	end

	return nil
end

local function equipToolByName(toolName)
	local humanoid = getHumanoid()
	if not humanoid then
		return nil
	end

	local tool = findRealTool(toolName)
	if not tool then
		return nil
	end

	if tool.Parent ~= getCharacter() then
		humanoid:EquipTool(tool)
		task.wait(0.15)
	end

	local equippedTool = getCharacter():FindFirstChild(toolName)
	if equippedTool and equippedTool:IsA("Tool") then
		return equippedTool
	end

	return tool
end

local function attackWithSword(targetHumanoid, targetLabel)
	if not targetHumanoid or targetHumanoid.Health <= 0 then
		return
	end

	local sword = equipToolByName(CONFIG.SwordName)
	if not sword then
		dprint("Sword not found:", CONFIG.SwordName)
		return
	end

	sword:Activate()
	dprint("Activated sword on " .. targetLabel)
end

local function attackWithBow(targetHumanoid, targetLabel)
	if not targetHumanoid or targetHumanoid.Health <= 0 then
		return
	end

	local bow = equipToolByName(CONFIG.BowName)
	if not bow then
		dprint("Bow not found:", CONFIG.BowName)
		return
	end

	bow:Activate()
	dprint("Activated bow on " .. targetLabel)
end

local function disconnectAntiAfk()
	if antiAfkConnection then
		antiAfkConnection:Disconnect()
		antiAfkConnection = nil
	end
end

local function connectAntiAfk()
	disconnectAntiAfk()

	antiAfkConnection = player.Idled:Connect(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new(0, 0))
		dprint("Anti-AFK triggered")
	end)
end

local function captureConfigTable()
	return {
		toggles = {
			autoCollect = autoCollect,
			autoOrc = autoOrc,
			autoOrcNPC = autoOrcNPC,
			autoHuman = autoHuman,
			autoHumanNPC = autoHumanNPC,
			autoNeutralNPC = autoNeutralNPC,
			autoTeamNPC = autoTeamNPC,
			autoBowOrc = autoBowOrc,
			autoBowHuman = autoBowHuman,
			autoGeneral = autoGeneral,
			autoDemon = autoDemon,
			autoTeamTarget = autoTeamTarget,
			autoTeamTargetCollect = autoTeamTargetCollect,
			antiAfk = antiAfk,
		},
		inputs = {
			TeleportDelay = CONFIG.TeleportDelay,
			OrcDelay = CONFIG.OrcDelay,
			HumanDelay = CONFIG.HumanDelay,
			NeutralDelay = CONFIG.NeutralDelay,
			DemonDelay = CONFIG.DemonDelay,
			GeneralDelay = CONFIG.GeneralDelay,
			SwordName = CONFIG.SwordName,
			BowName = CONFIG.BowName,
		},
		ui = {
			activeTab = activeTab,
		}
	}
end

local function applyConfigTable(data)
	if type(data) ~= "table" then
		return
	end

	local toggles = data.toggles
	if type(toggles) == "table" then
		if type(toggles.autoCollect) == "boolean" then autoCollect = toggles.autoCollect end
		if type(toggles.autoOrc) == "boolean" then autoOrc = toggles.autoOrc end
		if type(toggles.autoOrcNPC) == "boolean" then autoOrcNPC = toggles.autoOrcNPC end
		if type(toggles.autoHuman) == "boolean" then autoHuman = toggles.autoHuman end
		if type(toggles.autoHumanNPC) == "boolean" then autoHumanNPC = toggles.autoHumanNPC end
		if type(toggles.autoNeutralNPC) == "boolean" then autoNeutralNPC = toggles.autoNeutralNPC end
		if type(toggles.autoTeamNPC) == "boolean" then autoTeamNPC = toggles.autoTeamNPC end
		if type(toggles.autoBowOrc) == "boolean" then autoBowOrc = toggles.autoBowOrc end
		if type(toggles.autoBowHuman) == "boolean" then autoBowHuman = toggles.autoBowHuman end
		if type(toggles.autoGeneral) == "boolean" then autoGeneral = toggles.autoGeneral end
		if type(toggles.autoDemon) == "boolean" then autoDemon = toggles.autoDemon end
		if type(toggles.autoTeamTarget) == "boolean" then autoTeamTarget = toggles.autoTeamTarget end
		if type(toggles.autoTeamTargetCollect) == "boolean" then autoTeamTargetCollect = toggles.autoTeamTargetCollect end
		if type(toggles.antiAfk) == "boolean" then antiAfk = toggles.antiAfk end
	end

	local inputs = data.inputs
	if type(inputs) == "table" then
		if type(inputs.TeleportDelay) == "number" and inputs.TeleportDelay > 0 then CONFIG.TeleportDelay = inputs.TeleportDelay end
		if type(inputs.OrcDelay) == "number" and inputs.OrcDelay > 0 then CONFIG.OrcDelay = inputs.OrcDelay end
		if type(inputs.HumanDelay) == "number" and inputs.HumanDelay > 0 then CONFIG.HumanDelay = inputs.HumanDelay end
		if type(inputs.NeutralDelay) == "number" and inputs.NeutralDelay > 0 then CONFIG.NeutralDelay = inputs.NeutralDelay end
		if type(inputs.DemonDelay) == "number" and inputs.DemonDelay > 0 then CONFIG.DemonDelay = inputs.DemonDelay end
		if type(inputs.GeneralDelay) == "number" and inputs.GeneralDelay > 0 then CONFIG.GeneralDelay = inputs.GeneralDelay end

		if type(inputs.SwordName) == "string" and trimString(inputs.SwordName) ~= "" then
			CONFIG.SwordName = inputs.SwordName
		end

		if type(inputs.BowName) == "string" and trimString(inputs.BowName) ~= "" then
			CONFIG.BowName = inputs.BowName
		end
	end

	local ui = data.ui
	if type(ui) == "table" then
		if ui.activeTab == "Main" or ui.activeTab == "Settings" then
			activeTab = ui.activeTab
		end
	end

	timedCollectEndTime = 0
	teamTargetCollectSawDemon = false
	teamTargetCollectTriggered = false

	humanNPCList = {}
	currentHumanNPCIndex = 1
	currentHumanNPCTarget = nil

	orcNPCList = {}
	currentOrcNPCIndex = 1
	currentOrcNPCTarget = nil

	neutralNPCList = {}
	currentNeutralNPCIndex = 1
	currentNeutralNPCTarget = nil

	currentTeamNPCTarget = nil
	currentTeamNPCTargetType = nil

	disconnectAntiAfk()
	if antiAfk then
		connectAntiAfk()
	end
end

local function saveProfile(profileName, quiet)
	profileName = trimString(profileName)
	if profileName == "" then
		return false
	end

	local folder = getProfilesFolder()
	local slot = folder:FindFirstChild(profileName)

	if slot and not slot:IsA("StringValue") then
		slot:Destroy()
		slot = nil
	end

	if not slot then
		slot = Instance.new("StringValue")
		slot.Name = profileName
		slot.Parent = folder
	end

	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(captureConfigTable())
	end)

	if not ok then
		return false
	end

	slot.Value = encoded
	currentProfileName = profileName
	player:SetAttribute(ACTIVE_PROFILE_ATTRIBUTE, currentProfileName)

	if not quiet then
		dprint("Saved profile:", profileName)
	end

	return true
end

local function loadProfile(profileName, quiet)
	profileName = trimString(profileName)
	if profileName == "" then
		return false
	end

	local folder = getProfilesFolder()
	local slot = folder:FindFirstChild(profileName)

	if not slot or not slot:IsA("StringValue") then
		return false
	end

	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(slot.Value)
	end)

	if not ok or type(decoded) ~= "table" then
		return false
	end

	applyConfigTable(decoded)
	currentProfileName = profileName
	player:SetAttribute(ACTIVE_PROFILE_ATTRIBUTE, currentProfileName)

	if not quiet then
		dprint("Loaded profile:", profileName)
	end

	return true
end

local function deleteProfile(profileName)
	profileName = trimString(profileName)
	if profileName == "" then
		return false
	end

	local folder = getProfilesFolder()
	local slot = folder:FindFirstChild(profileName)

	if slot then
		slot:Destroy()
	end

	if currentProfileName == profileName then
		currentProfileName = ""
		player:SetAttribute(ACTIVE_PROFILE_ATTRIBUTE, "")
	end

	dprint("Deleted profile:", profileName)
	return true
end

local function autoSaveCurrentProfile()
	if currentProfileName ~= "" then
		saveProfile(currentProfileName, true)
	end
end

local function resetCurrentConfig()
	autoCollect = CONFIG.AutoCollectOnStart
	autoOrc = CONFIG.AutoOrcOnStart
	autoOrcNPC = false
	autoHuman = CONFIG.AutoHumanOnStart
	autoHumanNPC = false
	autoNeutralNPC = false
	autoTeamNPC = false
	autoBowOrc = false
	autoBowHuman = false
	autoGeneral = false
	autoDemon = CONFIG.AutoDemonOnStart
	autoTeamTarget = false
	autoTeamTargetCollect = false
	antiAfk = CONFIG.AntiAfkOnStart
	activeTab = "Main"

	CONFIG.TeleportDelay = DEFAULTS.TeleportDelay
	CONFIG.OrcDelay = DEFAULTS.OrcDelay
	CONFIG.HumanDelay = DEFAULTS.HumanDelay
	CONFIG.NeutralDelay = DEFAULTS.NeutralDelay
	CONFIG.DemonDelay = DEFAULTS.DemonDelay
	CONFIG.GeneralDelay = DEFAULTS.GeneralDelay
	CONFIG.SwordName = DEFAULTS.SwordName
	CONFIG.BowName = DEFAULTS.BowName

	gemList = {}
	currentGemIndex = 1

	humanNPCList = {}
	currentHumanNPCIndex = 1
	currentHumanNPCTarget = nil

	orcNPCList = {}
	currentOrcNPCIndex = 1
	currentOrcNPCTarget = nil

	neutralNPCList = {}
	currentNeutralNPCIndex = 1
	currentNeutralNPCTarget = nil

	currentTeamNPCTarget = nil
	currentTeamNPCTargetType = nil

	timedCollectEndTime = 0
	teamTargetCollectSawDemon = false
	teamTargetCollectTriggered = false

	disconnectAntiAfk()
	if antiAfk then
		connectAntiAfk()
	end
end

local startupProfileName = trimString(player:GetAttribute(ACTIVE_PROFILE_ATTRIBUTE))
if startupProfileName ~= "" then
	loadProfile(startupProfileName, true)
end

local existingGui = player:WaitForChild("PlayerGui"):FindFirstChild("AutoGemGui")
if existingGui then
	existingGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoGemGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = expandedSize
frame.Position = UDim2.new(0, 20, 0.5, -220)
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
title.Size = UDim2.new(0, 120, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "FOB GUI"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.SourceSansBold
title.TextSize = 20
title.Parent = titleBar

local mainTabButton = Instance.new("TextButton")
mainTabButton.Size = UDim2.new(0, 60, 0, 24)
mainTabButton.Position = UDim2.new(0, 128, 0, 5)
mainTabButton.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
mainTabButton.TextColor3 = Color3.new(1, 1, 1)
mainTabButton.Font = Enum.Font.SourceSansBold
mainTabButton.TextSize = 18
mainTabButton.Text = "Main"
mainTabButton.BorderSizePixel = 0
mainTabButton.Parent = titleBar

local mainTabCorner = Instance.new("UICorner")
mainTabCorner.CornerRadius = UDim.new(0, 8)
mainTabCorner.Parent = mainTabButton

local settingsTabButton = Instance.new("TextButton")
settingsTabButton.Size = UDim2.new(0, 72, 0, 24)
settingsTabButton.Position = UDim2.new(0, 192, 0, 5)
settingsTabButton.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
settingsTabButton.TextColor3 = Color3.new(1, 1, 1)
settingsTabButton.Font = Enum.Font.SourceSansBold
settingsTabButton.TextSize = 18
settingsTabButton.Text = "Settings"
settingsTabButton.BorderSizePixel = 0
settingsTabButton.Parent = titleBar

local settingsTabCorner = Instance.new("UICorner")
settingsTabCorner.CornerRadius = UDim.new(0, 8)
settingsTabCorner.Parent = settingsTabButton

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

local function createScrollingContent()
	local scrolling = Instance.new("ScrollingFrame")
	scrolling.Size = UDim2.new(1, -12, 1, -46)
	scrolling.Position = UDim2.new(0, 6, 0, 40)
	scrolling.BackgroundTransparency = 1
	scrolling.BorderSizePixel = 0
	scrolling.ScrollBarThickness = 6
	scrolling.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrolling.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrolling.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 4)
	padding.PaddingTop = UDim.new(0, 2)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = scrolling

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scrolling

	return scrolling
end

local mainContentFrame = createScrollingContent()
local settingsContentFrame = createScrollingContent()

local function createFullWidthLabel(parent, text, height, font, textSize)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -8, 0, height)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(220, 220, 220)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = font or Enum.Font.SourceSans
	label.TextSize = textSize or 18
	label.Parent = parent
	return label
end

local function createActionButton(parent)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -8, 0, 40)
	button.BackgroundColor3 = Color3.fromRGB(65, 65, 75)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.SourceSansBold
	button.TextSize = 20
	button.BorderSizePixel = 0
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button

	return button
end

local function createLabeledBoxRow(parent, labelText, defaultValue)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, 30)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 105, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(220, 220, 220)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = Enum.Font.SourceSans
	label.TextSize = 18
	label.Parent = row

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, -110, 1, 0)
	box.Position = UDim2.new(0, 110, 0, 0)
	box.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	box.TextColor3 = Color3.new(1, 1, 1)
	box.PlaceholderText = tostring(defaultValue)
	box.ClearTextOnFocus = false
	box.Text = tostring(defaultValue)
	box.Font = Enum.Font.SourceSans
	box.TextSize = 18
	box.BorderSizePixel = 0
	box.Parent = row

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = box

	return row, label, box
end

local status = createFullWidthLabel(mainContentFrame, "Status: Idle", 24, Enum.Font.SourceSans, 18)

local collectButton = createActionButton(mainContentFrame)
local orcButton = createActionButton(mainContentFrame)
local orcNPCButton = createActionButton(mainContentFrame)
local humanButton = createActionButton(mainContentFrame)
local humanNPCButton = createActionButton(mainContentFrame)
local neutralNPCButton = createActionButton(mainContentFrame)
local teamNPCButton = createActionButton(mainContentFrame)
local bowOrcButton = createActionButton(mainContentFrame)
local bowHumanButton = createActionButton(mainContentFrame)
local generalButton = createActionButton(mainContentFrame)
local demonButton = createActionButton(mainContentFrame)
local antiAfkButton = createActionButton(mainContentFrame)
local teamTargetButton = createActionButton(mainContentFrame)
local teamTargetCollectButton = createActionButton(mainContentFrame)

local delayHeader = createFullWidthLabel(settingsContentFrame, "Delay Inputs (press Enter)", 24, Enum.Font.SourceSansBold, 18)

local gemDelayRow, gemDelayLabel, gemDelayBox = createLabeledBoxRow(settingsContentFrame, "Gem Delay", CONFIG.TeleportDelay)
local orcDelayRow, orcDelayLabel, orcDelayBox = createLabeledBoxRow(settingsContentFrame, "Orc Delay", CONFIG.OrcDelay)
local humanDelayRow, humanDelayLabel, humanDelayBox = createLabeledBoxRow(settingsContentFrame, "Human Delay", CONFIG.HumanDelay)
local neutralDelayRow, neutralDelayLabel, neutralDelayBox = createLabeledBoxRow(settingsContentFrame, "Neutral Delay", CONFIG.NeutralDelay)
local demonDelayRow, demonDelayLabel, demonDelayBox = createLabeledBoxRow(settingsContentFrame, "Demon Delay", CONFIG.DemonDelay)
local generalDelayRow, generalDelayLabel, generalDelayBox = createLabeledBoxRow(settingsContentFrame, "General Delay", CONFIG.GeneralDelay)

local weaponHeader = createFullWidthLabel(settingsContentFrame, "Weapon Inputs (press Enter)", 24, Enum.Font.SourceSansBold, 18)
local swordNameRow, swordNameLabel, swordNameBox = createLabeledBoxRow(settingsContentFrame, "Weapon", CONFIG.SwordName)
local bowNameRow, bowNameLabel, bowNameBox = createLabeledBoxRow(settingsContentFrame, "Bow", CONFIG.BowName)

local profileHeader = createFullWidthLabel(settingsContentFrame, "Profiles", 24, Enum.Font.SourceSansBold, 18)
local profileNameRow, profileNameLabel, profileNameBox = createLabeledBoxRow(settingsContentFrame, "Profile", "")
profileNameBox.PlaceholderText = "Type profile name"

local currentProfileLabel = createFullWidthLabel(settingsContentFrame, "Current Profile: None", 22, Enum.Font.SourceSans, 18)
local savedProfilesLabel = createFullWidthLabel(settingsContentFrame, "Saved Profiles: None", 40, Enum.Font.SourceSans, 16)
savedProfilesLabel.TextWrapped = true
savedProfilesLabel.TextYAlignment = Enum.TextYAlignment.Top

local saveProfileButton = createActionButton(settingsContentFrame)
saveProfileButton.Text = "Save Profile"
saveProfileButton.TextSize = 18

local loadProfileButton = createActionButton(settingsContentFrame)
loadProfileButton.Text = "Load Profile"
loadProfileButton.TextSize = 18

local deleteProfileButton = createActionButton(settingsContentFrame)
deleteProfileButton.Text = "Delete Profile"
deleteProfileButton.TextSize = 18

local resetCurrentButton = createActionButton(settingsContentFrame)
resetCurrentButton.Text = "Reset Current Config"
resetCurrentButton.TextSize = 18

local function syncInputBoxesFromConfig()
	gemDelayBox.Text = tostring(CONFIG.TeleportDelay)
	orcDelayBox.Text = tostring(CONFIG.OrcDelay)
	humanDelayBox.Text = tostring(CONFIG.HumanDelay)
	neutralDelayBox.Text = tostring(CONFIG.NeutralDelay)
	demonDelayBox.Text = tostring(CONFIG.DemonDelay)
	generalDelayBox.Text = tostring(CONFIG.GeneralDelay)
	swordNameBox.Text = CONFIG.SwordName
	bowNameBox.Text = CONFIG.BowName
end

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

profileNameBox.Text = currentProfileName
syncInputBoxesFromConfig()

local function updateGui()
	local timedCollectActive = isTimedCollectActive()

	if autoCollect then
		collectButton.Text = "Auto Collect: ON"
	elseif timedCollectActive then
		collectButton.Text = "Auto Collect: TEMP (" .. tostring(getTimedCollectRemaining()) .. "s)"
	else
		collectButton.Text = "Auto Collect: OFF"
	end
	collectButton.BackgroundColor3 = (autoCollect or timedCollectActive) and Color3.fromRGB(50, 140, 70) or Color3.fromRGB(65, 65, 75)

	orcButton.Text = autoOrc and "Sword Orc General: ON" or "Sword Orc General: OFF"
	orcButton.BackgroundColor3 = autoOrc and Color3.fromRGB(50, 140, 70) or Color3.fromRGB(65, 65, 75)

	orcNPCButton.Text = autoOrcNPC and "Sword Orc NPCs: ON" or "Sword Orc NPCs: OFF"
	orcNPCButton.BackgroundColor3 = autoOrcNPC and Color3.fromRGB(50, 140, 70) or Color3.fromRGB(65, 65, 75)

	humanButton.Text = autoHuman and "Sword Human General: ON" or "Sword Human General: OFF"
	humanButton.BackgroundColor3 = autoHuman and Color3.fromRGB(50, 140, 70) or Color3.fromRGB(65, 65, 75)

	humanNPCButton.Text = autoHumanNPC and "Sword Human NPCs: ON" or "Sword Human NPCs: OFF"
	humanNPCButton.BackgroundColor3 = autoHumanNPC and Color3.fromRGB(50, 140, 70) or Color3.fromRGB(65, 65, 75)

	neutralNPCButton.Text = autoNeutralNPC and "Sword Neutral NPCs: ON" or "Sword Neutral NPCs: OFF"
	neutralNPCButton.BackgroundColor3 = autoNeutralNPC and Color3.fromRGB(50, 140, 70) or Color3.fromRGB(65, 65, 75)

	local npcTeam = getPlayerTeamFolder()
	if autoTeamNPC then
		if npcTeam == "Orc" then
			teamNPCButton.Text = "Auto Team NPCs: ON (Human + Neutral)"
		elseif npcTeam == "Human" then
			teamNPCButton.Text = "Auto Team NPCs: ON (Orc + Neutral)"
		elseif npcTeam == "Neutral" then
			teamNPCButton.Text = "Auto Team NPCs: ON (Neutral)"
		else
			teamNPCButton.Text = "Auto Team NPCs: ON (No Team)"
		end
	else
		teamNPCButton.Text = "Auto Team NPCs: OFF"
	end
	teamNPCButton.BackgroundColor3 = autoTeamNPC and Color3.fromRGB(50, 140, 70) or Color3.fromRGB(65, 65, 75)

	bowOrcButton.Text = autoBowOrc and "Bow Orc General: ON" or "Bow Orc General: OFF"
	bowOrcButton.BackgroundColor3 = autoBowOrc and Color3.fromRGB(50, 140, 70) or Color3.fromRGB(65, 65, 75)

	bowHumanButton.Text = autoBowHuman and "Bow Human General: ON" or "Bow Human General: OFF"
	bowHumanButton.BackgroundColor3 = autoBowHuman and Color3.fromRGB(50, 140, 70) or Color3.fromRGB(65, 65, 75)

	local teamFolder = getPlayerTeamFolder()
	if autoGeneral then
		if teamFolder == "Orc" then
			generalButton.Text = "Auto General: ON (Target Human)"
		elseif teamFolder == "Human" then
			generalButton.Text = "Auto General: ON (Target Orc)"
		else
			generalButton.Text = "Auto General: ON (No Team Found)"
		end
	else
		generalButton.Text = "Auto General: OFF"
	end
	generalButton.BackgroundColor3 = autoGeneral and Color3.fromRGB(50, 140, 70) or Color3.fromRGB(65, 65, 75)

	demonButton.Text = autoDemon and "Auto Demon: ON" or "Auto Demon: OFF"
	demonButton.BackgroundColor3 = autoDemon and Color3.fromRGB(50, 140, 70) or Color3.fromRGB(65, 65, 75)

	antiAfkButton.Text = antiAfk and "Anti-AFK: ON" or "Anti-AFK: OFF"
	antiAfkButton.BackgroundColor3 = antiAfk and Color3.fromRGB(50, 140, 70) or Color3.fromRGB(65, 65, 75)

	local teamFolder2 = getPlayerTeamFolder()
	if autoTeamTarget then
		if teamFolder2 == "Orc" then
			teamTargetButton.Text = "Auto Team Target: ON (Human)"
		elseif teamFolder2 == "Human" then
			teamTargetButton.Text = "Auto Team Target: ON (Orc)"
		elseif teamFolder2 == "Neutral" then
			teamTargetButton.Text = "Auto Team Target: ON (Demon)"
		else
			teamTargetButton.Text = "Auto Team Target: ON (No Team)"
		end
	else
		teamTargetButton.Text = "Auto Team Target: OFF"
	end
	teamTargetButton.BackgroundColor3 = autoTeamTarget and Color3.fromRGB(50, 140, 70) or Color3.fromRGB(65, 65, 75)

	local teamFolder3 = getPlayerTeamFolder()
	if autoTeamTargetCollect then
		if teamFolder3 == "Orc" then
			teamTargetCollectButton.Text = "Auto Team+Gems: ON (Human)"
		elseif teamFolder3 == "Human" then
			teamTargetCollectButton.Text = "Auto Team+Gems: ON (Orc)"
		elseif teamFolder3 == "Neutral" then
			teamTargetCollectButton.Text = "Auto Team+Gems: ON (Demon -> Gems)"
		else
			teamTargetCollectButton.Text = "Auto Team+Gems: ON (No Team)"
		end
	else
		teamTargetCollectButton.Text = "Auto Team+Gems: OFF"
	end
	teamTargetCollectButton.BackgroundColor3 = autoTeamTargetCollect and Color3.fromRGB(50, 140, 70) or Color3.fromRGB(65, 65, 75)

	if activeTab == "Main" then
		mainTabButton.BackgroundColor3 = Color3.fromRGB(50, 140, 70)
		settingsTabButton.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
		mainContentFrame.Visible = true
		settingsContentFrame.Visible = false
	else
		mainTabButton.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
		settingsTabButton.BackgroundColor3 = Color3.fromRGB(50, 140, 70)
		mainContentFrame.Visible = false
		settingsContentFrame.Visible = true
	end

	if minimized then
		frame.Size = minimizedSize
		mainContentFrame.Visible = false
		settingsContentFrame.Visible = false
		mainTabButton.Visible = false
		settingsTabButton.Visible = false
		minimizeButton.Text = "+"
	else
		frame.Size = expandedSize
		mainTabButton.Visible = true
		settingsTabButton.Visible = true

		if activeTab == "Main" then
			mainContentFrame.Visible = true
			settingsContentFrame.Visible = false
		else
			mainContentFrame.Visible = false
			settingsContentFrame.Visible = true
		end

		minimizeButton.Text = "-"
	end

	currentProfileLabel.Text = "Current Profile: " .. (currentProfileName ~= "" and currentProfileName or "None")

	local names = listProfileNames()
	if #names == 0 then
		savedProfilesLabel.Text = "Saved Profiles: None"
	else
		savedProfilesLabel.Text = "Saved Profiles: " .. table.concat(names, ", ")
	end

	local active = {}

	if autoCollect then
		table.insert(active, "Gems")
	elseif isTimedCollectActive() then
		table.insert(active, "Timed Gems")
	end

	if autoOrc then table.insert(active, "Sword Orc") end
	if autoOrcNPC then table.insert(active, "Orc NPCs") end
	if autoHuman then table.insert(active, "Sword Human") end
	if autoHumanNPC then table.insert(active, "Human NPCs") end
	if autoNeutralNPC then table.insert(active, "Neutral NPCs") end
	if autoTeamNPC then table.insert(active, "Team NPCs") end
	if autoBowOrc then table.insert(active, "Bow Orc") end
	if autoBowHuman then table.insert(active, "Bow Human") end
	if autoDemon then table.insert(active, "Demon") end
	if antiAfk then table.insert(active, "Anti-AFK") end

	if autoGeneral then
		local teamFolderNow = getPlayerTeamFolder()
		if teamFolderNow == "Orc" then
			table.insert(active, "Auto Human General")
		elseif teamFolderNow == "Human" then
			table.insert(active, "Auto Orc General")
		else
			table.insert(active, "Auto General")
		end
	end

	if autoTeamTarget then
		local teamFolderNow2 = getPlayerTeamFolder()
		if teamFolderNow2 == "Orc" then
			table.insert(active, "Team Human")
		elseif teamFolderNow2 == "Human" then
			table.insert(active, "Team Orc")
		elseif teamFolderNow2 == "Neutral" then
			table.insert(active, "Team Demon")
		else
			table.insert(active, "Team Target")
		end
	end

	if autoTeamTargetCollect then
		local teamFolderNow3 = getPlayerTeamFolder()
		if teamFolderNow3 == "Orc" then
			table.insert(active, "Team Human+Gems")
		elseif teamFolderNow3 == "Human" then
			table.insert(active, "Team Orc+Gems")
		elseif teamFolderNow3 == "Neutral" then
			table.insert(active, "Team Demon+Gems")
		else
			table.insert(active, "Team Target+Gems")
		end
	end

	if #active == 0 then
		status.Text = "Status: Idle"
	else
		status.Text = "Status: " .. table.concat(active, " + ")
	end
end

local function syncProfileNameBox()
	profileNameBox.Text = currentProfileName
end

collectButton.MouseButton1Click:Connect(function()
	autoCollect = not autoCollect
	if autoCollect then
		rebuildGemList()
	end
	autoSaveCurrentProfile()
	updateGui()
end)

orcButton.MouseButton1Click:Connect(function()
	autoOrc = not autoOrc
	autoSaveCurrentProfile()
	updateGui()
end)

orcNPCButton.MouseButton1Click:Connect(function()
	autoOrcNPC = not autoOrcNPC
	if not autoOrcNPC then
		currentOrcNPCTarget = nil
	end
	autoSaveCurrentProfile()
	updateGui()
end)

humanButton.MouseButton1Click:Connect(function()
	autoHuman = not autoHuman
	autoSaveCurrentProfile()
	updateGui()
end)

humanNPCButton.MouseButton1Click:Connect(function()
	autoHumanNPC = not autoHumanNPC
	if not autoHumanNPC then
		currentHumanNPCTarget = nil
	end
	autoSaveCurrentProfile()
	updateGui()
end)

neutralNPCButton.MouseButton1Click:Connect(function()
	autoNeutralNPC = not autoNeutralNPC
	if not autoNeutralNPC then
		currentNeutralNPCTarget = nil
	end
	autoSaveCurrentProfile()
	updateGui()
end)

teamNPCButton.MouseButton1Click:Connect(function()
	autoTeamNPC = not autoTeamNPC
	if not autoTeamNPC then
		currentTeamNPCTarget = nil
		currentTeamNPCTargetType = nil
	end
	autoSaveCurrentProfile()
	updateGui()
end)

bowOrcButton.MouseButton1Click:Connect(function()
	autoBowOrc = not autoBowOrc
	autoSaveCurrentProfile()
	updateGui()
end)

bowHumanButton.MouseButton1Click:Connect(function()
	autoBowHuman = not autoBowHuman
	autoSaveCurrentProfile()
	updateGui()
end)

generalButton.MouseButton1Click:Connect(function()
	autoGeneral = not autoGeneral
	autoSaveCurrentProfile()
	updateGui()
end)

demonButton.MouseButton1Click:Connect(function()
	autoDemon = not autoDemon
	autoSaveCurrentProfile()
	updateGui()
end)

antiAfkButton.MouseButton1Click:Connect(function()
	antiAfk = not antiAfk

	if antiAfk then
		connectAntiAfk()
	else
		disconnectAntiAfk()
	end

	autoSaveCurrentProfile()
	updateGui()
end)

teamTargetButton.MouseButton1Click:Connect(function()
	autoTeamTarget = not autoTeamTarget
	autoSaveCurrentProfile()
	updateGui()
end)

teamTargetCollectButton.MouseButton1Click:Connect(function()
	autoTeamTargetCollect = not autoTeamTargetCollect

	if not autoTeamTargetCollect then
		teamTargetCollectSawDemon = false
		teamTargetCollectTriggered = false
	end

	autoSaveCurrentProfile()
	updateGui()
end)

mainTabButton.MouseButton1Click:Connect(function()
	activeTab = "Main"
	autoSaveCurrentProfile()
	updateGui()
end)

settingsTabButton.MouseButton1Click:Connect(function()
	activeTab = "Settings"
	autoSaveCurrentProfile()
	updateGui()
end)

saveProfileButton.MouseButton1Click:Connect(function()
	local name = trimString(profileNameBox.Text)
	if saveProfile(name) then
		profileNameBox.Text = name
	end
	updateGui()
end)

loadProfileButton.MouseButton1Click:Connect(function()
	local name = trimString(profileNameBox.Text)
	if loadProfile(name) then
		profileNameBox.Text = name
		syncInputBoxesFromConfig()
	end
	updateGui()
end)

deleteProfileButton.MouseButton1Click:Connect(function()
	local name = trimString(profileNameBox.Text)
	deleteProfile(name)
	if currentProfileName == "" then
		profileNameBox.Text = ""
	end
	updateGui()
end)

resetCurrentButton.MouseButton1Click:Connect(function()
	resetCurrentConfig()
	syncInputBoxesFromConfig()
	syncProfileNameBox()
	autoSaveCurrentProfile()
	updateGui()
end)

minimizeButton.MouseButton1Click:Connect(function()
	minimized = not minimized
	updateGui()
end)

local function bindDelayBox(textBox, configKey)
	textBox.FocusLost:Connect(function()
		local value = tonumber(textBox.Text)

		if value and value > 0 then
			CONFIG[configKey] = value
			textBox.Text = tostring(value)
			dprint(configKey .. " set to " .. tostring(value))
			autoSaveCurrentProfile()
		else
			textBox.Text = tostring(CONFIG[configKey])
		end
	end)
end

local function bindTextBox(textBox, configKey)
	textBox.FocusLost:Connect(function()
		local value = textBox.Text
		if value and value:gsub("%s+", "") ~= "" then
			CONFIG[configKey] = value
			textBox.Text = value
			dprint(configKey .. " set to " .. value)
			autoSaveCurrentProfile()
		else
			textBox.Text = tostring(CONFIG[configKey])
		end
	end)
end

bindDelayBox(gemDelayBox, "TeleportDelay")
bindDelayBox(orcDelayBox, "OrcDelay")
bindDelayBox(humanDelayBox, "HumanDelay")
bindDelayBox(neutralDelayBox, "NeutralDelay")
bindDelayBox(demonDelayBox, "DemonDelay")
bindDelayBox(generalDelayBox, "GeneralDelay")

bindTextBox(swordNameBox, "SwordName")
bindTextBox(bowNameBox, "BowName")

if antiAfk then
	connectAntiAfk()
end

profileNameBox.Text = currentProfileName
syncInputBoxesFromConfig()
updateGui()
rebuildGemList()
rebuildHumanNPCList()
rebuildOrcNPCList()
rebuildNeutralNPCList()

task.spawn(function()
	while true do
		updateGui()
		task.wait(0.5)
	end
end)

task.spawn(function()
	while true do
		if isCollectEnabled() then
			rebuildGemList()

			local gem = getNextGem()
			if gem then
				teleportToGem(gem)
			end

			task.wait(CONFIG.TeleportDelay)
		else
			task.wait(0.1)
		end
	end
end)

task.spawn(function()
	while true do
		if autoOrc then
			teleportToOrc()
			attackWithSword(getOrcHumanoid(), "Orc General")
			task.wait(CONFIG.OrcDelay)
		else
			task.wait(0.1)
		end
	end
end)

task.spawn(function()
	while true do
		if autoOrcNPC then
			if not isCurrentOrcNPCTargetValid(currentOrcNPCTarget) then
				rebuildOrcNPCList()
				currentOrcNPCTarget = getNextOrcNPCModel()
			end

			if currentOrcNPCTarget and isCurrentOrcNPCTargetValid(currentOrcNPCTarget) then
				local humanoid = currentOrcNPCTarget:FindFirstChild("Humanoid")
				teleportToOrcNPC(currentOrcNPCTarget)
				attackWithSword(humanoid, currentOrcNPCTarget.Name)
			else
				currentOrcNPCTarget = nil
			end

			task.wait(CONFIG.OrcDelay)
		else
			currentOrcNPCTarget = nil
			task.wait(0.1)
		end
	end
end)

task.spawn(function()
	while true do
		if autoHuman then
			teleportToHuman()
			attackWithSword(getHumanHumanoid(), "Human General")
			task.wait(CONFIG.HumanDelay)
		else
			task.wait(0.1)
		end
	end
end)

task.spawn(function()
	while true do
		if autoHumanNPC then
			if not isCurrentHumanNPCTargetValid(currentHumanNPCTarget) then
				rebuildHumanNPCList()
				currentHumanNPCTarget = getNextHumanNPCModel()
			end

			if currentHumanNPCTarget and isCurrentHumanNPCTargetValid(currentHumanNPCTarget) then
				local humanoid = currentHumanNPCTarget:FindFirstChild("Humanoid")
				teleportToHumanNPC(currentHumanNPCTarget)
				attackWithSword(humanoid, currentHumanNPCTarget.Name)
			else
				currentHumanNPCTarget = nil
			end

			task.wait(CONFIG.HumanDelay)
		else
			currentHumanNPCTarget = nil
			task.wait(0.1)
		end
	end
end)

task.spawn(function()
	while true do
		if autoNeutralNPC then
			if not isCurrentNeutralNPCTargetValid(currentNeutralNPCTarget) then
				rebuildNeutralNPCList()
				currentNeutralNPCTarget = getNextNeutralNPCModel()
			end

			if currentNeutralNPCTarget and isCurrentNeutralNPCTargetValid(currentNeutralNPCTarget) then
				local humanoid = currentNeutralNPCTarget:FindFirstChild("Humanoid")
				teleportToNeutralNPC(currentNeutralNPCTarget)
				attackWithSword(humanoid, currentNeutralNPCTarget.Name)
			else
				currentNeutralNPCTarget = nil
			end

			task.wait(CONFIG.NeutralDelay)
		else
			currentNeutralNPCTarget = nil
			task.wait(0.1)
		end
	end
end)

task.spawn(function()
	while true do
		if autoTeamNPC then
			if not isCurrentTeamNPCTargetValid(currentTeamNPCTarget, currentTeamNPCTargetType) then
				currentTeamNPCTarget, currentTeamNPCTargetType = getClosestAllowedTeamNPC()
			end

			if currentTeamNPCTarget and currentTeamNPCTargetType then
				attackTeamNPC(currentTeamNPCTarget, currentTeamNPCTargetType)
				task.wait(getTeamNPCDelay(currentTeamNPCTargetType))
			else
				currentTeamNPCTarget = nil
				currentTeamNPCTargetType = nil
				task.wait(0.1)
			end
		else
			currentTeamNPCTarget = nil
			currentTeamNPCTargetType = nil
			task.wait(0.1)
		end
	end
end)

task.spawn(function()
	while true do
		if autoBowOrc then
			teleportToOrc()
			attackWithBow(getOrcHumanoid(), "Orc General")
			task.wait(CONFIG.OrcDelay)
		else
			task.wait(0.1)
		end
	end
end)

task.spawn(function()
	while true do
		if autoBowHuman then
			teleportToHuman()
			attackWithBow(getHumanHumanoid(), "Human General")
			task.wait(CONFIG.HumanDelay)
		else
			task.wait(0.1)
		end
	end
end)

task.spawn(function()
	while true do
		if autoGeneral then
			local targetHumanoid = getEnemyGeneralHumanoid()
			local targetLabel = getEnemyGeneralLabel()

			if targetHumanoid then
				teleportToEnemyGeneral()
				attackWithSword(targetHumanoid, targetLabel)
			end

			task.wait(CONFIG.GeneralDelay)
		else
			task.wait(0.1)
		end
	end
end)

task.spawn(function()
	while true do
		if autoDemon then
			teleportToDemon()
			attackWithSword(getDemonHumanoid(), "Giant Demon Spawn")
			task.wait(CONFIG.DemonDelay)
		else
			task.wait(0.1)
		end
	end
end)

task.spawn(function()
	while true do
		if autoTeamTarget then
			local targetHumanoid = getTeamTargetHumanoid()
			local targetLabel = getTeamTargetLabel()
			local info = getTeamTargetInfo()

			if targetHumanoid then
				teleportToTeamTarget()
				attackWithSword(targetHumanoid, targetLabel)
			end

			if info then
				task.wait(info.delay)
			else
				task.wait(0.1)
			end
		else
			task.wait(0.1)
		end
	end
end)

task.spawn(function()
	while true do
		if autoTeamTargetCollect then
			local teamFolder = getPlayerTeamFolder()

			if teamFolder == "Neutral" then
				local demonHumanoid = getDemonHumanoid()
				local demonTargetPart = getDemonTargetPart()

				if demonHumanoid and demonHumanoid.Health > 0 and demonTargetPart then
					teamTargetCollectSawDemon = true
					teamTargetCollectTriggered = false

					teleportToDemon()
					attackWithSword(demonHumanoid, "Giant Demon Spawn")
					task.wait(CONFIG.DemonDelay)
				else
					if teamTargetCollectSawDemon and not teamTargetCollectTriggered then
						timedCollectEndTime = math.max(timedCollectEndTime, time() + 180)
						teamTargetCollectTriggered = true
						dprint("Giant Demon Spawn defeated, starting Auto Collect for 180 seconds")
					end

					task.wait(0.1)
				end
			else
				teamTargetCollectSawDemon = false
				teamTargetCollectTriggered = false

				local info = getTeamTargetInfo()
				if info and info.targetHumanoid and info.targetHumanoid.Health > 0 then
					teleportToTeamTarget()
					attackWithSword(info.targetHumanoid, info.label)
					task.wait(info.delay)
				else
					task.wait(0.1)
				end
			end
		else
			teamTargetCollectSawDemon = false
			teamTargetCollectTriggered = false
			task.wait(0.1)
		end
	end
end)
