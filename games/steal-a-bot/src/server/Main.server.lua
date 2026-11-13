-- Steal a Bot: サーバー（基地・ベルトコンベア・買う/盗む/運ぶ・お金・保存）
local DataStoreService = game:GetService("DataStoreService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local DataStore2 = require(ServerScriptService.DataStore2)
local BotConfig = require(ReplicatedStorage.BotConfig)

---------------------------------------------------------------------
-- Studio で DataStore が使えないときはメモリ上で動かす
---------------------------------------------------------------------
if RunService:IsStudio() then
	local available = pcall(function()
		DataStoreService:GetDataStore("StealABotAccessCheck"):GetAsync("check")
	end)
	if not available then
		warn("[StealABot] DataStore unavailable; using temporary in-memory saves for Studio.")
		local stores = {}
		local service = {}
		local function newStore()
			local data = {}
			local s = {}
			function s:GetAsync(key)
				return data[key]
			end
			function s:SetAsync(key, value)
				data[key] = value
			end
			function s:UpdateAsync(key, transform)
				local v = transform(data[key])
				if v ~= nil then
					data[key] = v
				end
				return v
			end
			function s:GetSortedAsync()
				return {
					GetCurrentPage = function()
						return {}
					end,
				}
			end
			return s
		end
		function service:GetDataStore(name)
			stores[name] = stores[name] or newStore()
			return stores[name]
		end
		function service:GetOrderedDataStore(name)
			stores["o:" .. name] = stores["o:" .. name] or newStore()
			return stores["o:" .. name]
		end
		require(ServerScriptService.DataStore2.DataStoreServiceRetriever).Get = function()
			return service
		end
	end
end

DataStore2.Combine("BOT", "money", "bots", "rebirths", "lastDailyDay", "dailyStreak", "lastSeen")

---------------------------------------------------------------------
-- 通信
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "BotRemotes"
local function remote(name)
	local e = Instance.new("RemoteEvent")
	e.Name = name
	e.Parent = remotes
	return e
end
local notifyRemote = remote("Notify") -- (key, color, ...)
local actionRemote = remote("Action") -- ("lock" | "rebirth")
remotes.Parent = ReplicatedStorage

local GOLD = Color3.fromRGB(255, 215, 80)
local PINK = Color3.fromRGB(255, 120, 190)
local GREEN = Color3.fromRGB(120, 255, 140)
local RED = Color3.fromRGB(255, 90, 90)

---------------------------------------------------------------------
-- ワールド: 地面・ベルトコンベア・基地
---------------------------------------------------------------------
local world = Instance.new("Folder")
world.Name = "World"
world.Parent = Workspace

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = props.Parent or world
	return p
end

part({ Name = "Ground", Size = Vector3.new(400, 2, 400), Position = Vector3.new(0, -1, 0), Color = Color3.fromRGB(80, 150, 90), Material = Enum.Material.Grass })

local CONVEYOR_START = Vector3.new(-100, 1.5, 0)
local CONVEYOR_END = Vector3.new(100, 1.5, 0)
part({ Size = Vector3.new(206, 1, 8), Position = Vector3.new(0, 0.5, 0), Color = Color3.fromRGB(40, 40, 48), Material = Enum.Material.DiamondPlate })
for _, z in ipairs({ -4.3, 4.3 }) do
	part({ Size = Vector3.new(206, 1.4, 0.6), Position = Vector3.new(0, 0.9, z), Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Neon })
end

-- コリジョングループ（ロック中のバリアは持ち主だけ通れる）
for i = 1, BotConfig.MAX_BASES do
	pcall(function()
		PhysicsService:RegisterCollisionGroup("Owner" .. i)
		PhysicsService:RegisterCollisionGroup("Barrier" .. i)
	end)
end
for i = 1, BotConfig.MAX_BASES do
	PhysicsService:CollisionGroupSetCollidable("Owner" .. i, "Barrier" .. i, false)
end

local BASE_SIZE = 36
local bases = {}
local BASE_POSITIONS = {
	Vector3.new(-70, 0, -48),
	Vector3.new(0, 0, -48),
	Vector3.new(70, 0, -48),
	Vector3.new(-70, 0, 48),
	Vector3.new(0, 0, 48),
	Vector3.new(70, 0, 48),
}

for index, center in ipairs(BASE_POSITIONS) do
	local facing = center.Z < 0 and 1 or -1 -- ベルトコンベア側
	local base = { index = index, center = center, owner = nil, pedestals = {}, lockedUntil = 0, lockReadyAt = 0 }

	base.floor = part({
		Name = "BaseFloor" .. index,
		Size = Vector3.new(BASE_SIZE, 1, BASE_SIZE),
		Position = center + Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(70, 70, 85),
		Material = Enum.Material.Concrete,
	})

	-- 名前の看板
	local sign = part({
		Size = Vector3.new(16, 4, 1),
		Position = center + Vector3.new(0, 10, -facing * (BASE_SIZE / 2 - 1)),
		Color = Color3.fromRGB(25, 25, 35),
	})
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = facing > 0 and Enum.NormalId.Back or Enum.NormalId.Front
	signGui.LightInfluence = 0
	signGui.Parent = sign
	base.signLabel = Instance.new("TextLabel")
	base.signLabel.Size = UDim2.new(1, 0, 1, 0)
	base.signLabel.BackgroundTransparency = 1
	base.signLabel.TextScaled = true
	base.signLabel.Font = Enum.Font.GothamBlack
	base.signLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	base.signLabel.Text = "EMPTY BASE"
	base.signLabel.Parent = signGui

	-- 台座（2 列 x 5）
	for i = 1, BotConfig.PEDESTALS_PER_BASE do
		local col = (i - 1) % 5
		local row = math.floor((i - 1) / 5)
		local position = center + Vector3.new(-12 + col * 6, 1.5, -facing * (4 + row * 7))
		local pedestal = part({
			Size = Vector3.new(4, 1, 4),
			Position = position,
			Color = Color3.fromRGB(120, 120, 140),
			Material = Enum.Material.Metal,
		})
		table.insert(base.pedestals, { part = pedestal, bot = nil })
	end

	-- スポーン
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = center + Vector3.new(0, 1.2, facing * 10)
	spawn.Transparency = 0.5
	spawn.Enabled = index == 1 -- 最初は 1 つだけ（あとで持ち主ごとに使う）
	spawn.Parent = world
	base.spawn = spawn

	-- ロックボタン
	local lockButton = part({
		Size = Vector3.new(3, 1, 3),
		Position = center + Vector3.new(14, 1.2, facing * 14),
		Color = Color3.fromRGB(255, 60, 60),
		Material = Enum.Material.Neon,
	})
	local lockPrompt = Instance.new("ProximityPrompt")
	lockPrompt.ActionText = "Lock base"
	lockPrompt.ObjectText = "Barrier"
	lockPrompt.HoldDuration = 0
	lockPrompt.MaxActivationDistance = 10
	lockPrompt:SetAttribute("BaseIndex", index)
	lockPrompt:SetAttribute("OwnerOnly", true)
	lockPrompt.Parent = lockButton
	base.lockPrompt = lockPrompt

	-- バリア（ロック中だけ出す）
	base.barriers = {}
	for _, wall in ipairs({
		{ Vector3.new(BASE_SIZE, 14, 1), Vector3.new(0, 7.5, BASE_SIZE / 2) },
		{ Vector3.new(BASE_SIZE, 14, 1), Vector3.new(0, 7.5, -BASE_SIZE / 2) },
		{ Vector3.new(1, 14, BASE_SIZE), Vector3.new(BASE_SIZE / 2, 7.5, 0) },
		{ Vector3.new(1, 14, BASE_SIZE), Vector3.new(-BASE_SIZE / 2, 7.5, 0) },
	}) do
		local barrier = part({
			Size = wall[1],
			Position = center + wall[2],
			Color = Color3.fromRGB(255, 60, 60),
			Material = Enum.Material.ForceField,
			Transparency = 1,
			CanCollide = false,
			CollisionGroup = "Barrier" .. index,
		})
		table.insert(base.barriers, barrier)
	end

	bases[index] = base
end

local function setBarrier(base, on)
	for _, barrier in ipairs(base.barriers) do
		barrier.Transparency = on and 0.35 or 1
		barrier.CanCollide = on
	end
end

local function insideBase(base, position)
	local d = position - base.center
	return math.abs(d.X) <= BASE_SIZE / 2 and math.abs(d.Z) <= BASE_SIZE / 2
end

---------------------------------------------------------------------
-- ロボットの見た目
---------------------------------------------------------------------
local function buildBot(bot)
	local model = Instance.new("Model")
	model.Name = bot.id

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2.2, 2.2, 1.6)
	body.Color = bot.color
	body.Material = bot.rarity == "secret" and Enum.Material.Neon or Enum.Material.Metal
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model
	model.PrimaryPart = body

	local function attach(size, offset, colorValue, material, shape)
		local p = Instance.new("Part")
		p.Size = size
		p.Color = colorValue
		p.Material = material
		if shape then
			p.Shape = shape
		end
		p.CanCollide = false
		p.Massless = true
		p.Anchored = false
		p.CFrame = body.CFrame * CFrame.new(offset)
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = p
		weld.Parent = p
		return p
	end

	local head = attach(Vector3.new(1.8, 1.5, 1.5), Vector3.new(0, 1.9, 0), bot.color:Lerp(Color3.new(1, 1, 1), 0.3), Enum.Material.Metal)
	attach(Vector3.new(0.25, 0.25, 0.1), Vector3.new(-0.4, 2.0, -0.78), Color3.fromRGB(80, 255, 255), Enum.Material.Neon)
	attach(Vector3.new(0.25, 0.25, 0.1), Vector3.new(0.4, 2.0, -0.78), Color3.fromRGB(80, 255, 255), Enum.Material.Neon)
	attach(Vector3.new(0.15, 1, 0.15), Vector3.new(0, 3.1, 0), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
	attach(Vector3.new(0.45, 0.45, 0.45), Vector3.new(0, 3.7, 0), BotConfig.Rarities[bot.rarity].color, Enum.Material.Neon, Enum.PartType.Ball)
	attach(Vector3.new(0.6, 1, 0.6), Vector3.new(-0.6, -1.6, 0), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
	attach(Vector3.new(0.6, 1, 0.6), Vector3.new(0.6, -1.6, 0), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)

	local tag = Instance.new("BillboardGui")
	tag.Name = "Tag"
	tag.Size = UDim2.new(0, 160, 0, 52)
	tag.StudsOffset = Vector3.new(0, 4.6, 0)
	tag.MaxDistance = 80
	tag.Parent = head
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.TextColor3 = BotConfig.Rarities[bot.rarity].color
	text.TextStrokeTransparency = 0
	text.TextScaled = true
	text.Font = Enum.Font.GothamBlack
	text:SetAttribute("BotId", bot.id)
	text.Text = bot.id
	text.Parent = tag

	if BotConfig.Rarities[bot.rarity].order >= 5 then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = bot.color
		sparkles.Parent = body
	end

	model.Parent = Workspace
	return model
end

---------------------------------------------------------------------
-- プレイヤーとデータ
---------------------------------------------------------------------
local loaded = {}
local playerBase = {}
local carrying = {} -- thief -> { bot = model, botId = id, fromBase = base, fromPedestal = pedestal }

local function store(player, key)
	return DataStore2(key, player)
end

local function getMultiplier(player)
	return BotConfig.Multiplier(store(player, "rebirths"):Get(0), player:GetAttribute("FriendCount") or 0)
end

local function addMoney(player, amount)
	store(player, "money"):Increment(amount, BotConfig.STARTING_MONEY)
end

local function getMoney(player)
	return store(player, "money"):Get(BotConfig.STARTING_MONEY)
end

-- 基地のロボット一覧を保存
local function saveBots(player)
	local base = playerBase[player]
	if not base then
		return
	end
	local list = {}
	for _, pedestal in ipairs(base.pedestals) do
		if pedestal.botId then
			table.insert(list, pedestal.botId)
		end
	end
	store(player, "bots"):Set(list)
end

local function incomePerSecond(player)
	local base = playerBase[player]
	if not base then
		return 0
	end
	local total = 0
	for _, pedestal in ipairs(base.pedestals) do
		if pedestal.botId and pedestal.bot and not pedestal.away then
			total = total + BotConfig.GetBot(pedestal.botId).income
		end
	end
	return math.floor(total * getMultiplier(player))
end

local function refreshPlayerInfo(player)
	player:SetAttribute("IncomePerSecond", incomePerSecond(player))
	player:SetAttribute("Multiplier", getMultiplier(player))
end

local makeOwnedBot -- 下で定義

local function freePedestal(base)
	for _, pedestal in ipairs(base.pedestals) do
		if not pedestal.botId then
			return pedestal
		end
	end
	return nil
end

-- 台座にロボットを置く（持ち主の基地）
function makeOwnedBot(base, pedestal, botId)
	local bot = BotConfig.GetBot(botId)
	local model = buildBot(bot)
	model:PivotTo(CFrame.new(pedestal.part.Position + Vector3.new(0, 3.2, 0)) * CFrame.Angles(0, base.center.Z < 0 and math.pi or 0, 0))
	pedestal.bot = model
	pedestal.botId = botId
	pedestal.away = false

	local owner = base.owner
	local steal = Instance.new("ProximityPrompt")
	steal.ActionText = "Steal"
	steal.ObjectText = bot.id
	steal.HoldDuration = BotConfig.STEAL_HOLD
	steal.MaxActivationDistance = 9
	steal.RequiresLineOfSight = false
	steal:SetAttribute("OthersOnly", true)
	steal:SetAttribute("OwnerUserId", owner and owner.UserId or 0)
	steal:SetAttribute("Kind", "steal")
	steal.Parent = model.PrimaryPart

	local sell = Instance.new("ProximityPrompt")
	sell.ActionText = "Sell"
	sell.ObjectText = bot.id
	sell.HoldDuration = 1
	sell.MaxActivationDistance = 9
	sell.RequiresLineOfSight = false
	sell.KeyboardKeyCode = Enum.KeyCode.F
	sell:SetAttribute("OwnerOnly", true)
	sell:SetAttribute("OwnerUserId", owner and owner.UserId or 0)
	sell:SetAttribute("Kind", "sell")
	sell:SetAttribute("Price", math.floor(bot.price * BotConfig.SELL_RATE))
	sell.Parent = model.PrimaryPart

	steal.Triggered:Connect(function(thief)
		if not loaded[thief] or thief == base.owner or carrying[thief] or pedestal.away or pedestal.bot ~= model then
			return
		end
		if os.clock() < base.lockedUntil then
			notifyRemote:FireClient(thief, "toast_locked", RED)
			return
		end
		local character = thief.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid then
			return
		end

		-- 頭の上にかついで運ぶ
		pedestal.away = true
		steal.Enabled = false
		sell.Enabled = false
		model.PrimaryPart.Anchored = false
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Massless = true
			end
		end
		model:PivotTo(root.CFrame * CFrame.new(0, 5, 0))
		local weld = Instance.new("WeldConstraint")
		weld.Name = "CarryWeld"
		weld.Part0 = root
		weld.Part1 = model.PrimaryPart
		weld.Parent = model.PrimaryPart
		humanoid.WalkSpeed = BotConfig.CARRY_SPEED

		carrying[thief] = { model = model, botId = botId, fromBase = base, fromPedestal = pedestal, steal = steal, sell = sell }
		refreshPlayerInfo(base.owner)
		if base.owner then
			notifyRemote:FireClient(base.owner, "toast_being_stolen", RED, thief.DisplayName, "@bot_" .. botId)
		end
	end)

	sell.Triggered:Connect(function(seller)
		if seller ~= base.owner or pedestal.away or pedestal.bot ~= model then
			return
		end
		addMoney(seller, math.floor(bot.price * BotConfig.SELL_RATE))
		model:Destroy()
		pedestal.bot = nil
		pedestal.botId = nil
		saveBots(seller)
		refreshPlayerInfo(seller)
	end)
end

-- 運んでいる途中のロボットを元の台座に戻す
local function returnCarried(thief, reasonKey)
	local carry = carrying[thief]
	if not carry then
		return
	end
	carrying[thief] = nil
	local character = thief.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = BotConfig.NORMAL_SPEED
	end
	local weld = carry.model.PrimaryPart and carry.model.PrimaryPart:FindFirstChild("CarryWeld")
	if weld then
		weld:Destroy()
	end
	local pedestal = carry.fromPedestal
	if carry.fromBase.owner and pedestal.bot == carry.model then
		carry.model.PrimaryPart.Anchored = true
		carry.model:PivotTo(CFrame.new(pedestal.part.Position + Vector3.new(0, 3.2, 0)))
		pedestal.away = false
		carry.steal.Enabled = true
		carry.sell.Enabled = true
		refreshPlayerInfo(carry.fromBase.owner)
	else
		carry.model:Destroy()
	end
	if reasonKey then
		notifyRemote:FireClient(thief, reasonKey, RED)
	end
end

-- 自分の基地に運び込んだら自分のものになる
local function deliver(thief)
	local carry = carrying[thief]
	local myBase = playerBase[thief]
	local target = myBase and freePedestal(myBase)
	if not target then
		returnCarried(thief, "toast_no_space")
		return
	end
	carrying[thief] = nil
	local character = thief.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = BotConfig.NORMAL_SPEED
	end

	local victim = carry.fromBase.owner
	local pedestal = carry.fromPedestal
	carry.model:Destroy()
	pedestal.bot = nil
	pedestal.botId = nil
	pedestal.away = false
	if victim then
		saveBots(victim)
		refreshPlayerInfo(victim)
	end

	makeOwnedBot(myBase, target, carry.botId)
	saveBots(thief)
	refreshPlayerInfo(thief)
	local bot = BotConfig.GetBot(carry.botId)
	notifyRemote:FireAllClients(
		"announce_stolen",
		BotConfig.Rarities[bot.rarity].color,
		thief.DisplayName,
		"@bot_" .. carry.botId,
		victim and victim.DisplayName or "?"
	)
end

---------------------------------------------------------------------
-- 参加・退出
---------------------------------------------------------------------
local function setCharacterGroup(character, groupName)
	for _, p in ipairs(character:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CollisionGroup = groupName
		end
	end
	character.DescendantAdded:Connect(function(p)
		if p:IsA("BasePart") then
			p.CollisionGroup = groupName
		end
	end)
end

local function onCharacter(player, character)
	local base = playerBase[player]
	if base then
		setCharacterGroup(character, "Owner" .. base.index)
	end
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if humanoid then
		humanoid.WalkSpeed = BotConfig.NORMAL_SPEED
		humanoid.Died:Connect(function()
			returnCarried(player, "toast_dropped")
		end)
	end
	-- 持ち主にタッチされたら、運んでいるロボットを落とす
	if root then
		root.Touched:Connect(function(hit)
			local carry = carrying[player]
			if not carry then
				return
			end
			local toucher = Players:GetPlayerFromCharacter(hit.Parent)
			if toucher and toucher == carry.fromBase.owner then
				returnCarried(player, "toast_caught")
				notifyRemote:FireClient(toucher, "toast_saved", GREEN)
			end
		end)
	end
end

local function giveDaily(player)
	local today = math.floor(os.time() / 86400)
	local lastDay = store(player, "lastDailyDay"):Get(0)
	if today > lastDay then
		local streak = lastDay == today - 1 and store(player, "dailyStreak"):Get(0) + 1 or 1
		local reward = math.floor(150 * math.min(streak, 7) * getMultiplier(player))
		store(player, "lastDailyDay"):Set(today)
		store(player, "dailyStreak"):Set(streak)
		addMoney(player, reward)
		notifyRemote:FireClient(player, "announce_daily", GREEN, streak, reward)
	end
	local lastSeen = store(player, "lastSeen"):Get(0)
	local now = os.time()
	store(player, "lastSeen"):Set(now)
	if lastSeen > 0 then
		local away = math.min(now - lastSeen, 4 * 3600)
		local reward = math.floor(incomePerSecond(player) * away * 0.3)
		if away >= 60 and reward > 0 then
			addMoney(player, reward)
			notifyRemote:FireClient(player, "announce_offline", GREEN, reward, math.floor(away / 60))
		end
	end
end

local function onPlayerAdded(player)
	local base
	for _, b in ipairs(bases) do
		if not b.owner then
			base = b
			break
		end
	end
	if not base then
		player:Kick("Server full")
		return
	end
	base.owner = player
	playerBase[player] = base
	base.signLabel.Text = player.DisplayName
	base.spawn.Enabled = true
	player.RespawnLocation = base.spawn
	player:SetAttribute("BaseIndex", base.index)
	base.lockPrompt:SetAttribute("OwnerUserId", player.UserId)

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local money = Instance.new("IntValue")
	money.Name = "Money"
	money.Value = getMoney(player)
	money.Parent = leaderstats
	store(player, "money"):OnUpdate(function(v)
		money.Value = v
	end)
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = store(player, "rebirths"):Get(0)
	rebirths.Parent = leaderstats
	store(player, "rebirths"):OnUpdate(function(v)
		rebirths.Value = v
	end)
	if not player.Parent then
		return
	end
	leaderstats.Parent = player

	for i, botId in ipairs(store(player, "bots"):Get({})) do
		local pedestal = base.pedestals[i]
		if pedestal and BotConfig.GetBot(botId) then
			makeOwnedBot(base, pedestal, botId)
		end
	end

	player:SetAttribute("FriendCount", 0)
	loaded[player] = true
	refreshPlayerInfo(player)

	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		onCharacter(player, player.Character)
		player.Character:PivotTo(base.spawn.CFrame + Vector3.new(0, 4, 0))
	end

	task.delay(4, function()
		if loaded[player] then
			giveDaily(player)
		end
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	returnCarried(player)
	-- 誰かがこの人のロボットを運んでいたら消す
	for thief, carry in pairs(carrying) do
		if carry.fromBase.owner == player then
			carrying[thief] = nil
			local character = thief.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = BotConfig.NORMAL_SPEED
			end
			carry.model:Destroy()
		end
	end
	if loaded[player] then
		saveBots(player)
		store(player, "lastSeen"):Set(os.time())
	end
	local base = playerBase[player]
	if base then
		for _, pedestal in ipairs(base.pedestals) do
			if pedestal.bot then
				pedestal.bot:Destroy()
			end
			pedestal.bot = nil
			pedestal.botId = nil
			pedestal.away = false
		end
		base.owner = nil
		base.signLabel.Text = "EMPTY BASE"
		base.lockedUntil = 0
		setBarrier(base, false)
	end
	playerBase[player] = nil
	loaded[player] = nil
end)

---------------------------------------------------------------------
-- ベルトコンベア: ロボットが流れてきて、買える
---------------------------------------------------------------------
local spawnRng = Random.new()

local function spawnConveyorBot()
	local bot = BotConfig.Roll(spawnRng)
	local model = buildBot(bot)
	model:PivotTo(CFrame.new(CONVEYOR_START + Vector3.new(0, 2.7, 0)) * CFrame.Angles(0, -math.pi / 2, 0))

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Buy"
	prompt.ObjectText = bot.id
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Kind", "buy")
	prompt:SetAttribute("Price", bot.price)
	prompt.Parent = model.PrimaryPart

	local tween = TweenService:Create(
		model.PrimaryPart,
		TweenInfo.new(BotConfig.CONVEYOR_TIME, Enum.EasingStyle.Linear),
		{ CFrame = CFrame.new(CONVEYOR_END + Vector3.new(0, 2.7, 0)) * CFrame.Angles(0, -math.pi / 2, 0) }
	)
	tween.Completed:Connect(function()
		if model.Parent then
			model:Destroy()
		end
	end)
	tween:Play()

	local bought = false
	prompt.Triggered:Connect(function(buyer)
		if bought or not loaded[buyer] then
			return
		end
		local base = playerBase[buyer]
		local pedestal = base and freePedestal(base)
		if not pedestal then
			notifyRemote:FireClient(buyer, "toast_no_space", RED)
			return
		end
		if getMoney(buyer) < bot.price then
			notifyRemote:FireClient(buyer, "toast_need_money", RED, bot.price)
			return
		end
		bought = true
		tween:Cancel()
		model:Destroy()
		addMoney(buyer, -bot.price)
		makeOwnedBot(base, pedestal, bot.id)
		saveBots(buyer)
		refreshPlayerInfo(buyer)
		if BotConfig.Rarities[bot.rarity].order >= 4 then
			notifyRemote:FireAllClients("announce_bought", BotConfig.Rarities[bot.rarity].color, buyer.DisplayName, "@bot_" .. bot.id)
		end
	end)

	if BotConfig.Rarities[bot.rarity].order >= 5 then
		notifyRemote:FireAllClients("announce_spawn", BotConfig.Rarities[bot.rarity].color, "@rarity_" .. bot.rarity, "@bot_" .. bot.id)
	end
end

task.spawn(function()
	while true do
		spawnConveyorBot()
		task.wait(BotConfig.SPAWN_INTERVAL)
	end
end)

---------------------------------------------------------------------
-- 毎秒: お金・運び込みチェック・ロック
---------------------------------------------------------------------
task.spawn(function()
	local tick = 0
	while true do
		task.wait(0.25)
		tick = tick + 1
		for thief in pairs(carrying) do
			local base = playerBase[thief]
			local character = thief.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if base and root and insideBase(base, root.Position) then
				deliver(thief)
			end
		end
		for _, base in ipairs(bases) do
			local locked = os.clock() < base.lockedUntil
			if base.barriers[1].CanCollide ~= locked then
				setBarrier(base, locked)
			end
			if base.owner then
				base.owner:SetAttribute("LockLeft", locked and math.ceil(base.lockedUntil - os.clock()) or 0)
				base.owner:SetAttribute("LockReadyIn", math.max(0, math.ceil(base.lockReadyAt - os.clock())))
			end
		end
		if tick % 4 == 0 then
			for player in pairs(loaded) do
				local income = incomePerSecond(player)
				if income > 0 then
					addMoney(player, income)
				end
				player:SetAttribute("IncomePerSecond", income)
			end
		end
	end
end)

---------------------------------------------------------------------
-- 操作: ロック・転生
---------------------------------------------------------------------
local function lockBase(player)
	local base = playerBase[player]
	if not base or os.clock() < base.lockReadyAt then
		return
	end
	base.lockedUntil = os.clock() + BotConfig.LOCK_DURATION
	base.lockReadyAt = base.lockedUntil + BotConfig.LOCK_COOLDOWN
	setBarrier(base, true)
	notifyRemote:FireClient(player, "toast_lock_on", GREEN, BotConfig.LOCK_DURATION)
end

for _, base in ipairs(bases) do
	base.lockPrompt.Triggered:Connect(function(player)
		if player == base.owner then
			lockBase(player)
		end
	end)
end

actionRemote.OnServerEvent:Connect(function(player, action)
	if not loaded[player] then
		return
	end
	if action == "lock" then
		lockBase(player)
	elseif action == "rebirth" then
		local rebirths = store(player, "rebirths"):Get(0)
		local cost = BotConfig.RebirthCost(rebirths)
		if getMoney(player) < cost then
			notifyRemote:FireClient(player, "toast_need_money", RED, cost)
			return
		end
		returnCarried(player)
		local base = playerBase[player]
		for _, pedestal in ipairs(base.pedestals) do
			if pedestal.bot then
				pedestal.bot:Destroy()
			end
			pedestal.bot = nil
			pedestal.botId = nil
			pedestal.away = false
		end
		store(player, "bots"):Set({})
		store(player, "money"):Set(BotConfig.STARTING_MONEY)
		store(player, "rebirths"):Set(rebirths + 1)
		refreshPlayerInfo(player)
		notifyRemote:FireAllClients("announce_rebirth", PINK, player.DisplayName, rebirths + 1)
	end
end)

---------------------------------------------------------------------
-- フレンドボーナス
---------------------------------------------------------------------
local friendCache = {}
local function updateFriends()
	for player in pairs(loaded) do
		local count = 0
		for other in pairs(loaded) do
			if other ~= player then
				local key = math.min(player.UserId, other.UserId) .. ":" .. math.max(player.UserId, other.UserId)
				if friendCache[key] == nil then
					local ok, result = pcall(function()
						return player:IsFriendsWith(other.UserId)
					end)
					friendCache[key] = ok and result or false
				end
				if friendCache[key] then
					count = count + 1
				end
			end
		end
		player:SetAttribute("FriendCount", count)
		refreshPlayerInfo(player)
	end
end
Players.PlayerAdded:Connect(function()
	task.wait(6)
	updateFriends()
end)
Players.PlayerRemoving:Connect(function()
	task.defer(updateFriends)
end)
