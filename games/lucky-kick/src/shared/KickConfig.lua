-- Lucky Block Kick: 数値の設定
local KickConfig = {}

KickConfig.TEE = Vector3.new(0, 3, 0) -- ブロックを置く場所（ここから +Z 方向に飛ぶ）
KickConfig.FIELD_LENGTH = 6000
KickConfig.KICK_COOLDOWN = 2.5
KickConfig.MAX_FLIGHT_TIME = 12

-- キックの強さ: power(0〜1) と足のレベルで決まる
function KickConfig.KickVelocity(power, legLevel)
	local forward = (60 + legLevel * 25) * (0.35 + 0.65 * power)
	return Vector3.new(0, forward * 0.6, forward)
end

-- ブロックの種類（運で選ばれる）
KickConfig.Blocks = {
	{ id = "wood", multiplier = 1, weight = 70, color = Color3.fromRGB(170, 120, 70), material = Enum.Material.Wood },
	{ id = "gold", multiplier = 3, weight = 22, color = Color3.fromRGB(255, 200, 50), material = Enum.Material.Metal },
	{ id = "diamond", multiplier = 10, weight = 6.5, color = Color3.fromRGB(110, 230, 255), material = Enum.Material.Glass },
	{ id = "rainbow", multiplier = 50, weight = 1.5, color = Color3.fromRGB(255, 80, 200), material = Enum.Material.Neon },
}

-- 運のレベルが上がると、レアなブロックの重みが増える
function KickConfig.RollBlock(rng, luckLevel)
	local weights = {}
	local total = 0
	for i, block in ipairs(KickConfig.Blocks) do
		local w = block.weight
		if i > 1 then
			w = w * (1 + luckLevel * 0.15)
		end
		weights[i] = w
		total = total + w
	end
	local roll = rng:NextNumber(0, total)
	for i, block in ipairs(KickConfig.Blocks) do
		roll = roll - weights[i]
		if roll <= 0 then
			return block
		end
	end
	return KickConfig.Blocks[1]
end

-- 着地したときのラッキー報酬（ブロックを開けると出る）
KickConfig.LuckyRewards = {
	{ id = "nothing", multiplier = 1, weight = 60 },
	{ id = "double", multiplier = 2, weight = 25 },
	{ id = "jackpot", multiplier = 5, weight = 12 },
	{ id = "mega", multiplier = 25, weight = 3 },
}

function KickConfig.RollReward(rng)
	local total = 0
	for _, r in ipairs(KickConfig.LuckyRewards) do
		total = total + r.weight
	end
	local roll = rng:NextNumber(0, total)
	for _, r in ipairs(KickConfig.LuckyRewards) do
		roll = roll - r.weight
		if roll <= 0 then
			return r
		end
	end
	return KickConfig.LuckyRewards[1]
end

-- アップグレード
KickConfig.Upgrades = {
	leg = { baseCost = 25, growth = 1.32, maxLevel = 60 },
	luck = { baseCost = 200, growth = 1.6, maxLevel = 25 },
}
KickConfig.UpgradeOrder = { "leg", "luck" }

function KickConfig.UpgradeCost(upgradeId, level)
	local u = KickConfig.Upgrades[upgradeId]
	return math.floor(u.baseCost * u.growth ^ level)
end

-- お金 = 距離 x ブロック倍率 x ラッキー倍率 x 転生・フレンド
KickConfig.COINS_PER_STUD = 0.5

KickConfig.REBIRTH_BASE = 200000
KickConfig.REBIRTH_GROWTH = 4
KickConfig.REBIRTH_BONUS = 0.5

function KickConfig.RebirthCost(rebirths)
	return math.floor(KickConfig.REBIRTH_BASE * KickConfig.REBIRTH_GROWTH ^ rebirths)
end

function KickConfig.Multiplier(rebirths, friendCount)
	return (1 + rebirths * KickConfig.REBIRTH_BONUS) * (1 + math.min(friendCount, 5) * 0.2)
end

-- 地帯（距離ごとに景色が変わる）
KickConfig.Zones = {
	{ id = "meadow", start = 0, color = Color3.fromRGB(90, 170, 80), material = Enum.Material.Grass },
	{ id = "desert", start = 800, color = Color3.fromRGB(230, 200, 130), material = Enum.Material.Sand },
	{ id = "snow", start = 2000, color = Color3.fromRGB(240, 245, 255), material = Enum.Material.Snow },
	{ id = "space", start = 3800, color = Color3.fromRGB(60, 30, 110), material = Enum.Material.Neon },
}

return KickConfig
