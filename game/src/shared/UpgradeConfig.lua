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

return UpgradeConfig
