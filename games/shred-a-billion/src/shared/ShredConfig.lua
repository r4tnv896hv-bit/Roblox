-- Shred a Billion: 数値の設定
local ShredConfig = {}

ShredConfig.STARTING_MONEY = 0
ShredConfig.MAX_PLOTS = 8
ShredConfig.PAD_CAPACITY = 8 -- 台の上に置ける物の数

-- 壊す物: hp はかたさ、value はお金、unlock はシュレッダーのレベル
ShredConfig.Items = {
	{ id = "cash", hp = 1, value = 10, unlock = 0, size = Vector3.new(1.6, 0.6, 1), color = Color3.fromRGB(90, 190, 90), material = Enum.Material.SmoothPlastic },
	{ id = "wallet", hp = 2, value = 35, unlock = 3, size = Vector3.new(1.8, 0.5, 1.4), color = Color3.fromRGB(120, 80, 50), material = Enum.Material.Fabric },
	{ id = "piggy", hp = 4, value = 140, unlock = 7, size = Vector3.new(2.2, 2.2, 2.2), color = Color3.fromRGB(255, 150, 190), material = Enum.Material.SmoothPlastic, shape = "Ball" },
	{ id = "briefcase", hp = 7, value = 600, unlock = 11, size = Vector3.new(2.6, 2, 0.8), color = Color3.fromRGB(30, 30, 35), material = Enum.Material.Leather },
	{ id = "goldBar", hp = 12, value = 2800, unlock = 15, size = Vector3.new(2.4, 1, 1.2), color = Color3.fromRGB(255, 200, 50), material = Enum.Material.Metal },
	{ id = "safe", hp = 20, value = 14000, unlock = 20, size = Vector3.new(3, 3, 3), color = Color3.fromRGB(110, 115, 125), material = Enum.Material.DiamondPlate },
	{ id = "diamond", hp = 32, value = 75000, unlock = 25, size = Vector3.new(2, 2, 2), color = Color3.fromRGB(120, 230, 255), material = Enum.Material.Glass },
	{ id = "vault", hp = 50, value = 450000, unlock = 31, size = Vector3.new(4, 4, 4), color = Color3.fromRGB(80, 85, 95), material = Enum.Material.Metal },
	{ id = "crown", hp = 80, value = 2800000, unlock = 37, size = Vector3.new(2.6, 2, 2.6), color = Color3.fromRGB(255, 210, 60), material = Enum.Material.Foil },
	{ id = "statue", hp = 120, value = 18000000, unlock = 44, size = Vector3.new(2.5, 5, 2.5), color = Color3.fromRGB(255, 195, 40), material = Enum.Material.Metal },
	{ id = "truck", hp = 180, value = 140000000, unlock = 52, size = Vector3.new(5, 4, 8), color = Color3.fromRGB(40, 90, 60), material = Enum.Material.Metal },
}

function ShredConfig.GetItem(itemId)
	for index, item in ipairs(ShredConfig.Items) do
		if item.id == itemId then
			return item, index
		end
	end
	return nil, nil
end

-- 今のシュレッダーのレベルで出てくる物（新しい物ほど出やすい）
function ShredConfig.RollItem(rng, powerLevel)
	local unlocked = {}
	for _, item in ipairs(ShredConfig.Items) do
		if powerLevel >= item.unlock then
			table.insert(unlocked, item)
		end
	end
	local total = 0
	for i = 1, #unlocked do
		total = total + i
	end
	local roll = rng:NextNumber(0, total)
	for i, item in ipairs(unlocked) do
		roll = roll - i
		if roll <= 0 then
			return item
		end
	end
	return unlocked[#unlocked]
end

-- アップグレード
ShredConfig.Upgrades = {
	power = { baseCost = 30, growth = 1.42, maxLevel = 60 }, -- 1 秒に削る量 +0.5、新しい物の解放
	spawn = { baseCost = 60, growth = 1.65, maxLevel = 15 }, -- 物が出てくる速さ
	feeder = { baseCost = 500, growth = 2.0, maxLevel = 12 }, -- 自動でシュレッダーに入れる
	blade = { baseCost = 250, growth = 1.75, maxLevel = 40 }, -- お金 +10%
}
ShredConfig.UpgradeOrder = { "power", "blade", "spawn", "feeder" }

function ShredConfig.UpgradeCost(upgradeId, level)
	local u = ShredConfig.Upgrades[upgradeId]
	return math.floor(u.baseCost * u.growth ^ level)
end

function ShredConfig.ShredPower(level)
	return 1 + level * 0.5
end

function ShredConfig.SpawnInterval(level)
	return 3.5 * 0.88 ^ level
end

function ShredConfig.FeederInterval(level)
	if level <= 0 then
		return nil
	end
	return 3 * 0.82 ^ (level - 1)
end

function ShredConfig.BladeBonus(level)
	return 1 + level * 0.1
end

-- 目標と転生: 目標の額を持っていると転生できる（お金と強化がリセット、倍率 +100%）
ShredConfig.BASE_GOAL = 1e9

function ShredConfig.Goal(rebirths)
	return ShredConfig.BASE_GOAL * 10 ^ rebirths
end

function ShredConfig.Multiplier(rebirths, friendCount)
	return (1 + rebirths) * (1 + math.min(friendCount, 5) * 0.2)
end

-- みんなで壊す現金輸送トラック
ShredConfig.TRUCK_INTERVAL = 8 * 60
ShredConfig.TRUCK_TIME = 60
ShredConfig.TRUCK_HP_PER_PLAYER = 150

return ShredConfig
