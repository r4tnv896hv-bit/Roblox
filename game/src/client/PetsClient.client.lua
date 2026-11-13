-- ペット: ついてくる見た目・卵を割ったときの演出・画面のペット表示
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local Locale = require(ReplicatedStorage:WaitForChild("Locale"))

local remotes = ReplicatedStorage:WaitForChild("CoinClickerRemotes")
local hatchResult = remotes:WaitForChild("HatchResult")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local language = Locale.GetLanguage(player)

local function L(key, ...)
	return Locale.Get(language, key, ...)
end

local function formatNumber(n)
	local s = string.format("%d", n)
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return formatted
end

local function percent(bonus)
	return formatNumber(math.floor(bonus * 100 + 0.5))
end

---------------------------------------------------------------------
-- 卵の看板と操作ボタンを自分の言語にする
---------------------------------------------------------------------
local function relabelEgg(eggPart)
	local eggId = eggPart:GetAttribute("EggId")
	local egg = eggId and UpgradeConfig.Eggs[eggId]
	if not egg then
		return
	end
	local billboard = eggPart:FindFirstChild("EggLabel")
	local label = billboard and billboard:FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = L("egg_" .. eggId, formatNumber(egg.cost))
	end
	local prompt = eggPart:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.ActionText = L("egg_action")
		prompt.ObjectText = string.match(L("egg_" .. eggId, ""), "^[^\n]+") or ""
	end
end

task.spawn(function()
	for _, child in ipairs(Workspace:GetChildren()) do
		if child.Name == "Egg" then
			relabelEgg(child)
		end
	end
end)
Workspace.ChildAdded:Connect(function(child)
	if child.Name == "Egg" then
		task.wait(0.5)
		relabelEgg(child)
	end
end)

---------------------------------------------------------------------
-- 画面: 自分のペット表示と、卵を割ったときの演出
---------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PetsGui"
screenGui.ResetOnSpawn = false

local uiScale = Instance.new("UIScale")
uiScale.Parent = screenGui
local function updateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		uiScale.Scale = math.clamp(camera.ViewportSize.Y / 650, 0.55, 1)
	end
end
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end
updateScale()

local petsLabel = Instance.new("TextLabel")
petsLabel.AnchorPoint = Vector2.new(0.5, 1)
petsLabel.Position = UDim2.new(0.5, 0, 1, -76)
petsLabel.Size = UDim2.new(0, 460, 0, 30)
petsLabel.BackgroundColor3 = Color3.fromRGB(35, 25, 45)
petsLabel.BackgroundTransparency = 0.3
petsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
petsLabel.TextScaled = true
petsLabel.Font = Enum.Font.GothamBold
petsLabel.Parent = screenGui

local petsCorner = Instance.new("UICorner")
petsCorner.CornerRadius = UDim.new(0, 10)
petsCorner.Parent = petsLabel

local function splitPets(text)
	local list = {}
	for petId in string.gmatch(text or "", "[^,]+") do
		if UpgradeConfig.Pets[petId] then
			table.insert(list, petId)
		end
	end
	return list
end

local function updatePetsLabel()
	local list = splitPets(player:GetAttribute("EquippedPets"))
	if #list == 0 then
		petsLabel.Text = L("pets_none")
		return
	end
	local names = {}
	for i, petId in ipairs(list) do
		names[i] = L("pet_" .. petId)
	end
	petsLabel.Text = L("pets_label", table.concat(names, ", "), percent(player:GetAttribute("PetBonus") or 0))
end

player:GetAttributeChangedSignal("EquippedPets"):Connect(updatePetsLabel)
player:GetAttributeChangedSignal("PetBonus"):Connect(updatePetsLabel)
updatePetsLabel()

hatchResult.OnClientEvent:Connect(function(petId)
	local pet = UpgradeConfig.Pets[petId]
	if not pet then
		return
	end
	local rarityColor = UpgradeConfig.Rarities[pet.rarity].color

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.45, 0)
	frame.Size = UDim2.new(0, 520, 0, 170)
	frame.BackgroundColor3 = Color3.fromRGB(30, 20, 45)
	frame.BackgroundTransparency = 0.1
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = rarityColor
	stroke.Thickness = 4
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.35, 0)
	title.BackgroundTransparency = 1
	title.Text = L("hatch_title")
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = frame

	local result = Instance.new("TextLabel")
	result.Position = UDim2.new(0, 10, 0.38, 0)
	result.Size = UDim2.new(1, -20, 0.55, 0)
	result.BackgroundTransparency = 1
	result.Text = L("hatch_result", L("rarity_" .. pet.rarity), L("pet_" .. petId), percent(pet.bonus))
	result.TextColor3 = rarityColor
	result.TextStrokeTransparency = 0
	result.TextScaled = true
	result.Font = Enum.Font.GothamBlack
	result.Parent = frame

	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = frame
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	task.delay(2.5, function()
		frame:Destroy()
	end)
end)

screenGui.Parent = playerGui

---------------------------------------------------------------------
-- ペットの見た目: みんなのペットが持ち主の後ろをふわふわついていく
---------------------------------------------------------------------
local petsFolder = Instance.new("Folder")
petsFolder.Name = "ClientPets"
petsFolder.Parent = Workspace

local OFFSETS = {
	Vector3.new(-3.5, 0, 4),
	Vector3.new(3.5, 0, 4),
	Vector3.new(0, 0, 6.5),
}

local followers = {} -- player -> { parts }

local function makePet(petId)
	local def = UpgradeConfig.Pets[petId]

	local body = Instance.new("Part")
	body.Name = petId
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(def.size, def.size, def.size)
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.CastShadow = false
	body.Color = def.color
	body.Material = def.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic

	-- 顔（目）
	local face = Instance.new("SurfaceGui")
	face.Face = Enum.NormalId.Front
	face.LightInfluence = 0
	face.Parent = body
	local eyes = Instance.new("TextLabel")
	eyes.Size = UDim2.new(1, 0, 1, 0)
	eyes.BackgroundTransparency = 1
	eyes.Text = "•  •"
	eyes.TextColor3 = Color3.fromRGB(20, 20, 20)
	eyes.TextScaled = true
	eyes.Font = Enum.Font.GothamBlack
	eyes.Parent = face

	-- 名前（レアリティの色）
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.new(0, 120, 0, 24)
	tag.StudsOffset = Vector3.new(0, def.size * 0.5 + 0.8, 0)
	tag.MaxDistance = 60
	tag.Parent = body
	local tagText = Instance.new("TextLabel")
	tagText.Size = UDim2.new(1, 0, 1, 0)
	tagText.BackgroundTransparency = 1
	tagText.Text = L("pet_" .. petId)
	tagText.TextColor3 = UpgradeConfig.Rarities[def.rarity].color
	tagText.TextStrokeTransparency = 0
	tagText.TextScaled = true
	tagText.Font = Enum.Font.GothamBold
	tagText.Parent = tag

	if def.rarity == "legendary" or def.rarity == "epic" then
		local light = Instance.new("PointLight")
		light.Color = def.color
		light.Range = 10
		light.Brightness = 2
		light.Parent = body

		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = def.color
		sparkles.Parent = body
	end

	body.Parent = petsFolder
	return body
end

local function clearPets(owner)
	local entry = followers[owner]
	if entry then
		for _, part in ipairs(entry.parts) do
			part:Destroy()
		end
	end
	followers[owner] = nil
end

local function rebuildPets(owner)
	clearPets(owner)
	local list = splitPets(owner:GetAttribute("EquippedPets"))
	if #list == 0 then
		return
	end
	local entry = { parts = {}, placed = false }
	for i, petId in ipairs(list) do
		if OFFSETS[i] then
			entry.parts[i] = makePet(petId)
		end
	end
	followers[owner] = entry
end

local function watchPlayer(owner)
	owner:GetAttributeChangedSignal("EquippedPets"):Connect(function()
		rebuildPets(owner)
	end)
	rebuildPets(owner)
end

for _, other in ipairs(Players:GetPlayers()) do
	watchPlayer(other)
end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(clearPets)

RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local alpha = math.clamp(dt * 8, 0, 1)
	for owner, entry in pairs(followers) do
		local character = owner.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local back = -root.CFrame.LookVector
			for i, part in ipairs(entry.parts) do
				local offset = OFFSETS[i]
				local base = (root.CFrame * CFrame.new(offset.X, 0, offset.Z)).Position
				local position = base + Vector3.new(0, -0.8 + math.sin(t * 3 + i) * 0.4, 0)
				local goal = CFrame.lookAt(position, position + back)
				if entry.placed then
					part.CFrame = part.CFrame:Lerp(goal, alpha)
				else
					part.CFrame = goal
				end
			end
			entry.placed = true
		end
	end
end)
