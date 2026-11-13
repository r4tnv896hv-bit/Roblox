-- アップグレードの設定（サーバーとクライアントの両方で使う）
local UpgradeConfig = {}

UpgradeConfig.MAX_LEVEL = 50 -- maxLevel を書かなかったときの上限

-- 大当たり: 1レベルごとの確率と倍率
UpgradeConfig.CRIT_CHANCE_PER_LEVEL = 0.05
UpgradeConfig.CRIT_MULTIPLIER = 10

-- コイン工場: 1レベルごとの毎秒コイン
UpgradeConfig.FACTORY_COINS_PER_LEVEL = 10

UpgradeConfig.Upgrades = {
	click = {
		key = "clickLevel", -- DataStore2 のキー名
		name = "クリック強化",
		description = "1クリックのコイン +1",
		baseCost = 10,
		growth = 1.5,
	},
	auto = {
		key = "autoLevel",
		name = "自動コイン",
		description = "毎秒のコイン +1",
		baseCost = 25,
		growth = 1.6,
	},
	crit = {
		key = "critLevel",
		name = "大当たり",
		description = "5%の確率でコイン10倍",
		baseCost = 100,
		growth = 1.8,
		maxLevel = 10, -- 最大 50%
	},
	factory = {
		key = "factoryLevel",
		name = "コイン工場",
		description = "毎秒のコイン +10",
		baseCost = 500,
		growth = 1.7,
	},
}

-- ショップに並べる順番
UpgradeConfig.Order = { "click", "auto", "crit", "factory" }

function UpgradeConfig.GetMaxLevel(upgradeId)
	return UpgradeConfig.Upgrades[upgradeId].maxLevel or UpgradeConfig.MAX_LEVEL
end

-- 今のレベルから次のレベルに上げる費用
function UpgradeConfig.GetCost(upgradeId, level)
	local upgrade = UpgradeConfig.Upgrades[upgradeId]
	return math.floor(upgrade.baseCost * upgrade.growth ^ level)
end

function UpgradeConfig.CoinsPerClick(clickLevel)
	return 1 + clickLevel
end

function UpgradeConfig.CritChance(critLevel)
	return critLevel * UpgradeConfig.CRIT_CHANCE_PER_LEVEL
end

function UpgradeConfig.CoinsPerSecond(autoLevel, factoryLevel)
	return autoLevel + factoryLevel * UpgradeConfig.FACTORY_COINS_PER_LEVEL
end

---------------------------------------------------------------------
-- 転生・ボーナス
---------------------------------------------------------------------
UpgradeConfig.REBIRTH_BASE_COST = 10000
UpgradeConfig.REBIRTH_COST_GROWTH = 3
UpgradeConfig.REBIRTH_BONUS = 0.5 -- 転生1回ごとに倍率 +0.5

UpgradeConfig.FRIEND_BONUS = 0.2 -- 同じサーバーのフレンド1人ごとに +20%
UpgradeConfig.MAX_FRIENDS_COUNTED = 5

UpgradeConfig.DAILY_BASE_REWARD = 100
UpgradeConfig.DAILY_MAX_STREAK = 7

function UpgradeConfig.RebirthCost(rebirths)
	return math.floor(UpgradeConfig.REBIRTH_BASE_COST * UpgradeConfig.REBIRTH_COST_GROWTH ^ rebirths)
end

-- コインの倍率（転生 × フレンド × コイン2倍パス）
function UpgradeConfig.Multiplier(rebirths, friendCount, hasDoubleCoins)
	local friends = math.min(friendCount, UpgradeConfig.MAX_FRIENDS_COUNTED)
	local multiplier = (1 + rebirths * UpgradeConfig.REBIRTH_BONUS) * (1 + friends * UpgradeConfig.FRIEND_BONUS)
	if hasDoubleCoins then
		multiplier = multiplier * 2
	end
	return multiplier
end

-- 連続ログイン n 日目の報酬
function UpgradeConfig.DailyReward(streak, rebirths)
	local day = math.min(streak, UpgradeConfig.DAILY_MAX_STREAK)
	return UpgradeConfig.DAILY_BASE_REWARD * day * (1 + rebirths)
end

---------------------------------------------------------------------
-- 課金アイテム（Robux）
-- id は Creator Dashboard で作ったアイテムの ID。0 のものはショップに出さない。
-- price は表示用の目安（実際の値段は Roblox から取得して表示する）。
---------------------------------------------------------------------
UpgradeConfig.GamePasses = {
	doubleCoins = {
		id = 2087840383,
		name = "コイン2倍",
		description = "ずっとコインが2倍！",
		price = 99,
	},
	autoClick = {
		id = 2088056363,
		name = "オートクリック",
		description = "毎秒3回、自動でクリック",
		price = 149,
	},
}
UpgradeConfig.GamePassOrder = { "doubleCoins", "autoClick" }
UpgradeConfig.AUTO_CLICKS_PER_SECOND = 3

UpgradeConfig.Products = {
	smallPack = {
		id = 3730798651,
		name = "コインパック（小）",
		description = "10分ぶんのコインをすぐゲット",
		price = 25,
		minutes = 10,
		minimum = 1000,
	},
	bigPack = {
		id = 3730798682,
		name = "コインパック（大）",
		description = "1時間ぶんのコインをすぐゲット",
		price = 99,
		minutes = 60,
		minimum = 10000,
	},
}
UpgradeConfig.ProductOrder = { "smallPack", "bigPack" }

-- コインパックでもらえる量（今の稼ぎに合わせて増える）
function UpgradeConfig.PackReward(product, perClick, perSecond, multiplier)
	local base = (perSecond * 60 + perClick * 30) * product.minutes
	return math.floor(math.max(product.minimum, base) * multiplier)
end

return UpgradeConfig
