-- アップグレードの設定（サーバーとクライアントの両方で使う）
local UpgradeConfig = {}

UpgradeConfig.MAX_LEVEL = 50

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
}

-- ショップに並べる順番
UpgradeConfig.Order = { "click", "auto" }

-- 今のレベルから次のレベルに上げる費用
function UpgradeConfig.GetCost(upgradeId, level)
	local upgrade = UpgradeConfig.Upgrades[upgradeId]
	return math.floor(upgrade.baseCost * upgrade.growth ^ level)
end

function UpgradeConfig.CoinsPerClick(clickLevel)
	return 1 + clickLevel
end

function UpgradeConfig.CoinsPerSecond(autoLevel)
	return autoLevel
end

return UpgradeConfig
