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
local fuseRemote = remotes:WaitForChild("FusePet")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local language = Locale.GetLanguage(player)

local function L(key, ...)
	return Locale.Get(language, key, ...)
end

local function petName(petId)
	return Locale.PetName(language, petId)
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

local petsLabel = Instance.new("TextButton")
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
		names[i] = petName(petId)
	end
	petsLabel.Text = L("pets_label", table.concat(names, ", "), percent(player:GetAttribute("PetBonus") or 0))
end

player:GetAttributeChangedSignal("EquippedPets"):Connect(updatePetsLabel)
player:GetAttributeChangedSignal("PetBonus"):Connect(updatePetsLabel)
updatePetsLabel()

hatchResult.OnClientEvent:Connect(function(...)
	-- 1 個か 3 個（トリプルハッチ）。一番レアなものの色で枠を出す
	local petIds = {}
	local best
	for _, petId in ipairs({ ... }) do
		local def = UpgradeConfig.Pets[petId]
		if def then
			table.insert(petIds, petId)
			if not best or UpgradeConfig.Rarities[def.rarity].order > UpgradeConfig.Rarities[UpgradeConfig.Pets[best].rarity].order then
				best = petId
			end
		end
	end
	if not best then
		return
	end
	local rarityColor = UpgradeConfig.Rarities[UpgradeConfig.Pets[best].rarity].color
	local lines = {}
	for i, petId in ipairs(petIds) do
		local def = UpgradeConfig.Pets[petId]
		lines[i] = L("hatch_result", L("rarity_" .. def.rarity), petName(petId), percent(def.bonus))
	end

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.45, 0)
	frame.Size = UDim2.new(0, 520, 0, 110 + 60 * #petIds)
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
	title.Size = UDim2.new(1, 0, 0, 56)
	title.BackgroundTransparency = 1
	title.Text = L("hatch_title")
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = frame

	local result = Instance.new("TextLabel")
	result.Position = UDim2.new(0, 10, 0, 62)
	result.Size = UDim2.new(1, -20, 1, -72)
	result.BackgroundTransparency = 1
	result.Text = table.concat(lines, "\n")
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

---------------------------------------------------------------------
-- ペット一覧と合体（画面下のペット表示を押すと開く）
---------------------------------------------------------------------
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0, 460, 0, 420)
panel.BackgroundColor3 = Color3.fromRGB(35, 25, 45)
panel.BackgroundTransparency = 0.05
panel.Visible = false
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
panelStroke.Color = Color3.fromRGB(255, 220, 80)
panelStroke.Thickness = 2
panelStroke.Parent = panel

local panelTitle = Instance.new("TextLabel")
panelTitle.Position = UDim2.new(0, 16, 0, 10)
panelTitle.Size = UDim2.new(1, -120, 0, 36)
panelTitle.BackgroundTransparency = 1
panelTitle.Text = L("pets_title")
panelTitle.TextColor3 = Color3.fromRGB(255, 220, 80)
panelTitle.TextScaled = true
panelTitle.TextXAlignment = Enum.TextXAlignment.Left
panelTitle.Font = Enum.Font.GothamBold
panelTitle.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -12, 0, 12)
closeButton.Size = UDim2.new(0, 90, 0, 32)
closeButton.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
closeButton.Text = L("close")
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextScaled = true
closeButton.Font = Enum.Font.GothamBold
closeButton.Parent = panel
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeButton

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.new(0, 12, 0, 56)
list.Size = UDim2.new(1, -24, 1, -68)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

local function parseOwned()
	local owned = {}
	for petId, count in string.gmatch(player:GetAttribute("OwnedPets") or "", "([^,=]+)=(%d+)") do
		if UpgradeConfig.Pets[petId] then
			owned[petId] = tonumber(count)
		end
	end
	return owned
end

local function refreshList()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local owned = parseOwned()
	local ids = {}
	for petId in pairs(owned) do
		table.insert(ids, petId)
	end
	table.sort(ids, function(a, b)
		return UpgradeConfig.Pets[a].bonus > UpgradeConfig.Pets[b].bonus
	end)

	for order, petId in ipairs(ids) do
		local def = UpgradeConfig.Pets[petId]
		local count = owned[petId]

		local row = Instance.new("Frame")
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -8, 0, 46)
		row.BackgroundColor3 = Color3.fromRGB(55, 40, 70)
		row.Parent = list
		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 8)
		rowCorner.Parent = row

		local name = Instance.new("TextLabel")
		name.Position = UDim2.new(0, 10, 0, 0)
		name.Size = UDim2.new(def.golden and 1 or 0.6, -14, 1, 0)
		name.BackgroundTransparency = 1
		name.Text = L("pet_row", petName(petId), formatNumber(count), percent(def.bonus))
		name.TextColor3 = UpgradeConfig.Rarities[def.rarity].color
		name.TextScaled = true
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Font = Enum.Font.GothamBold
		name.Parent = row

		if not def.golden then
			local canFuse = count >= UpgradeConfig.FUSE_COUNT
			local fuse = Instance.new("TextButton")
			fuse.AnchorPoint = Vector2.new(1, 0.5)
			fuse.Position = UDim2.new(1, -6, 0.5, 0)
			fuse.Size = UDim2.new(0.4, -10, 0, 36)
			fuse.BackgroundColor3 = canFuse and Color3.fromRGB(230, 170, 30) or Color3.fromRGB(80, 80, 80)
			fuse.TextColor3 = Color3.fromRGB(255, 255, 255)
			fuse.TextScaled = true
			fuse.Font = Enum.Font.GothamBold
			if canFuse then
				fuse.Text = L("fuse_button", formatNumber(UpgradeConfig.FUSE_COUNT))
			else
				fuse.Text = L("fuse_progress", formatNumber(count), formatNumber(UpgradeConfig.FUSE_COUNT))
			end
			fuse.Parent = row
			local fuseCorner = Instance.new("UICorner")
			fuseCorner.CornerRadius = UDim.new(0, 8)
			fuseCorner.Parent = fuse

			fuse.Activated:Connect(function()
				if canFuse then
					fuseRemote:FireServer(petId)
				end
			end)
		end
	end
end

petsLabel.Activated:Connect(function()
	panel.Visible = not panel.Visible
	if panel.Visible then
		refreshList()
	end
end)
closeButton.Activated:Connect(function()
	panel.Visible = false
end)
player:GetAttributeChangedSignal("OwnedPets"):Connect(function()
	if panel.Visible then
		refreshList()
	end
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
	tagText.Text = petName(petId)
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

---------------------------------------------------------------------
-- 頭の上の称号と、お金持ちのオーラ（みんなの分を自分の言語で表示）
---------------------------------------------------------------------
local TITLE_COLORS = {
	newbie = Color3.fromRGB(220, 220, 220),
	collector = Color3.fromRGB(120, 230, 120),
	rich = Color3.fromRGB(100, 180, 255),
	millionaire = Color3.fromRGB(255, 210, 60),
	billionaire = Color3.fromRGB(120, 230, 255),
	god = Color3.fromRGB(255, 90, 220),
}

local function auraColor(titleKey)
	for _, title in ipairs(UpgradeConfig.Titles) do
		if title.key == titleKey then
			return title.aura
		end
	end
	return nil
end

local function applyTitle(owner)
	local character = owner.Character
	local head = character and character:FindFirstChild("Head")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not head then
		return
	end
	local titleKey = owner:GetAttribute("TitleKey") or "newbie"
	local stats = owner:FindFirstChild("leaderstats")
	local rebirths = 0
	local rebirthValue = stats and stats:FindFirstChild("Rebirths")
	if rebirthValue then
		rebirths = rebirthValue.Value
	end

	local gui = head:FindFirstChild("TitleGui")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "TitleGui"
		gui.Size = UDim2.new(0, 200, 0, 46)
		gui.StudsOffset = Vector3.new(0, 2.6, 0)
		gui.MaxDistance = 90
		gui.Parent = head
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.TextStrokeTransparency = 0
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.Parent = gui
	end
	local stars = rebirths > 0 and ("  ★" .. rebirths) or ""
	local crown = owner:GetAttribute("ServerTop") and "👑 " or ""
	gui.Label.Text = crown .. L("title_" .. titleKey) .. stars
	gui.Label.TextColor3 = TITLE_COLORS[titleKey] or Color3.fromRGB(255, 255, 255)

	-- オーラ
	local existing = root and root:FindFirstChild("RichAura")
	local colorValue = auraColor(titleKey)
	if root and colorValue then
		if not existing then
			existing = Instance.new("ParticleEmitter")
			existing.Name = "RichAura"
			existing.Rate = 14
			existing.Lifetime = NumberRange.new(0.8, 1.4)
			existing.Speed = NumberRange.new(1, 3)
			existing.SpreadAngle = Vector2.new(180, 180)
			existing.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.5),
				NumberSequenceKeypoint.new(1, 0),
			})
			existing.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			})
			existing.LightEmission = 1
			existing.Parent = root
		end
		existing.Color = ColorSequence.new(colorValue)
	elseif existing then
		existing:Destroy()
	end
end

local function watchTitle(owner)
	owner:GetAttributeChangedSignal("TitleKey"):Connect(function()
		applyTitle(owner)
	end)
	owner:GetAttributeChangedSignal("ServerTop"):Connect(function()
		applyTitle(owner)
	end)
	owner.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 10)
		character:WaitForChild("HumanoidRootPart", 10)
		applyTitle(owner)
	end)
	task.spawn(function()
		local stats = owner:WaitForChild("leaderstats", 30)
		local rebirthValue = stats and stats:WaitForChild("Rebirths", 10)
		if rebirthValue then
			rebirthValue.Changed:Connect(function()
				applyTitle(owner)
			end)
		end
		applyTitle(owner)
	end)
end

for _, other in ipairs(Players:GetPlayers()) do
	watchTitle(other)
end
Players.PlayerAdded:Connect(watchTitle)
