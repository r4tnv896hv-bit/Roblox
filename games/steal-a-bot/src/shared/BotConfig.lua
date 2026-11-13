-- Steal a Bot: 数値の設定
local BotConfig = {}

BotConfig.STARTING_MONEY = 100
BotConfig.PEDESTALS_PER_BASE = 10
BotConfig.MAX_BASES = 6

-- ロボット: price は買う値段、income は 1 秒あたりのお金、weight は出やすさ
BotConfig.Bots = {
	{ id = "beep", rarity = "common", price = 50, income = 1, weight = 40, color = Color3.fromRGB(180, 190, 200) },
	{ id = "boop", rarity = "common", price = 120, income = 3, weight = 30, color = Color3.fromRGB(120, 200, 255) },
	{ id = "spark", rarity = "uncommon", price = 600, income = 12, weight = 14, color = Color3.fromRGB(120, 230, 120) },
	{ id = "bolt", rarity = "rare", price = 4000, income = 60, weight = 8, color = Color3.fromRGB(80, 120, 255) },
	{ id = "nova", rarity = "epic", price = 30000, income = 350, weight = 4.5, color = Color3.fromRGB(190, 90, 255) },
	{ id = "titan", rarity = "legendary", price = 250000, income = 2500, weight = 1.8, color = Color3.fromRGB(255, 190, 40) },
	{ id = "glitch", rarity = "secret", price = 2500000, income = 20000, weight = 0.25, color = Color3.fromRGB(255, 60, 120) },
}

BotConfig.Rarities = {
	common = { order = 1, color = Color3.fromRGB(200, 200, 200) },
	uncommon = { order = 2, color = Color3.fromRGB(90, 220, 90) },
	rare = { order = 3, color = Color3.fromRGB(70, 150, 255) },
	epic = { order = 4, color = Color3.fromRGB(190, 90, 255) },
	legendary = { order = 5, color = Color3.fromRGB(255, 200, 40) },
	secret = { order = 6, color = Color3.fromRGB(255, 60, 120) },
}

function BotConfig.GetBot(botId)
	for _, bot in ipairs(BotConfig.Bots) do
		if bot.id == botId then
			return bot
		end
	end
	return nil
end

function BotConfig.Roll(rng)
	local total = 0
	for _, bot in ipairs(BotConfig.Bots) do
		total = total + bot.weight
	end
	local roll = rng:NextNumber(0, total)
	for _, bot in ipairs(BotConfig.Bots) do
		roll = roll - bot.weight
		if roll <= 0 then
			return bot
		end
	end
	return BotConfig.Bots[1]
end

-- ベルトコンベア
BotConfig.SPAWN_INTERVAL = 2.5
BotConfig.CONVEYOR_TIME = 30 -- 端から端まで流れる秒数

-- 盗む
BotConfig.STEAL_HOLD = 1.5 -- 長押しの秒数
BotConfig.CARRY_SPEED = 11 -- 運んでいる間の歩く速さ
BotConfig.NORMAL_SPEED = 16

-- ロック（基地にバリア）
BotConfig.LOCK_DURATION = 40
BotConfig.LOCK_COOLDOWN = 20

-- 転生: お金 +50%/回、ロボットとお金はリセット
BotConfig.REBIRTH_BASE = 1000000
BotConfig.REBIRTH_GROWTH = 5
BotConfig.REBIRTH_BONUS = 0.5

function BotConfig.RebirthCost(rebirths)
	return math.floor(BotConfig.REBIRTH_BASE * BotConfig.REBIRTH_GROWTH ^ rebirths)
end

function BotConfig.Multiplier(rebirths, friendCount)
	return (1 + rebirths * BotConfig.REBIRTH_BONUS) * (1 + math.min(friendCount, 5) * 0.2)
end

-- 売る: 買値の半分
BotConfig.SELL_RATE = 0.5

return BotConfig
