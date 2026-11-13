-- Online Shop Tycoon: 数値の設定（サーバーとクライアントの両方で使う）
local ShopConfig = {}

ShopConfig.STARTING_MONEY = 50

-- 商品: cost は仕入れ値、price は標準の売値、unlock は解放に必要なお金
ShopConfig.Products = {
	{ id = "phoneCase", cost = 2, price = 6, unlock = 0, color = Color3.fromRGB(255, 120, 170) },
	{ id = "earbuds", cost = 8, price = 22, unlock = 300, color = Color3.fromRGB(240, 240, 250) },
	{ id = "ledLamp", cost = 20, price = 55, unlock = 2500, color = Color3.fromRGB(150, 110, 255) },
	{ id = "smartWatch", cost = 60, price = 160, unlock = 15000, color = Color3.fromRGB(60, 60, 70) },
	{ id = "drone", cost = 200, price = 520, unlock = 90000, color = Color3.fromRGB(90, 160, 255) },
	{ id = "gamingChair", cost = 650, price = 1700, unlock = 500000, color = Color3.fromRGB(230, 60, 60) },
	{ id = "eScooter", cost = 2200, price = 5800, unlock = 3000000, color = Color3.fromRGB(60, 200, 120) },
}

function ShopConfig.GetProduct(productId)
	for index, product in ipairs(ShopConfig.Products) do
		if product.id == productId then
			return product, index
		end
	end
	return nil, nil
end

-- 値付け: 安い・ふつう・高い（売値の倍率と売れやすさ）
ShopConfig.PriceModes = {
	cheap = { priceMultiplier = 0.8, conversion = 1.35 },
	normal = { priceMultiplier = 1.0, conversion = 1.0 },
	premium = { priceMultiplier = 1.35, conversion = 0.6 },
}

-- お客さん: 1 秒あたりの訪問者（基本 + 広告）
ShopConfig.BASE_VISITORS = 0.5
ShopConfig.BASE_CONVERSION = 0.6

-- 広告キャンペーン: cost で duration 秒のあいだ visitors 人/秒 増える
-- cost は「今いちばん高く解放した商品」に合わせて増える
ShopConfig.Ads = {
	{ id = "social", baseCost = 30, visitors = 0.6, duration = 60 },
	{ id = "video", baseCost = 150, visitors = 2.0, duration = 90 },
	{ id = "influencer", baseCost = 900, visitors = 6.0, duration = 120 },
}

function ShopConfig.AdCost(ad, unlockedCount)
	return math.floor(ad.baseCost * (2.2 ^ math.max(0, unlockedCount - 1)))
end

-- アップグレード
ShopConfig.Upgrades = {
	warehouse = { baseCost = 100, growth = 1.8, maxLevel = 30 }, -- 在庫の上限 +50/レベル
	staff = { baseCost = 250, growth = 1.9, maxLevel = 30 }, -- 1 秒に自動で発送する数 +0.5/レベル
	rating = { baseCost = 400, growth = 2.0, maxLevel = 20 }, -- 売れやすさ +8%/レベル
	restock = { baseCost = 1500, growth = 3.0, maxLevel = 1 }, -- 在庫が減ったら自動で仕入れ
}
ShopConfig.UpgradeOrder = { "warehouse", "staff", "rating", "restock" }

function ShopConfig.UpgradeCost(upgradeId, level)
	local upgrade = ShopConfig.Upgrades[upgradeId]
	return math.floor(upgrade.baseCost * upgrade.growth ^ level)
end

function ShopConfig.StockCapacity(warehouseLevel)
	return 30 + warehouseLevel * 50
end

function ShopConfig.ShipPerSecond(staffLevel)
	return staffLevel * 0.5
end

function ShopConfig.RatingBonus(ratingLevel)
	return 1 + ratingLevel * 0.08
end

-- 発送ボタン: 1 回押すと何件発送するか
ShopConfig.MANUAL_SHIP = 1

-- 会社を売る（転生）: もうけ +50%/回
ShopConfig.SELL_COMPANY_BASE = 250000
ShopConfig.SELL_COMPANY_GROWTH = 4
ShopConfig.FRANCHISE_BONUS = 0.5

function ShopConfig.SellCompanyCost(franchises)
	return math.floor(ShopConfig.SELL_COMPANY_BASE * ShopConfig.SELL_COMPANY_GROWTH ^ franchises)
end

function ShopConfig.Multiplier(franchises, friendCount, hasDouble)
	local multiplier = (1 + franchises * ShopConfig.FRANCHISE_BONUS) * (1 + math.min(friendCount, 5) * 0.2)
	if hasDouble then
		multiplier = multiplier * 2
	end
	return multiplier
end

-- ログインボーナス・オフライン報酬
ShopConfig.DAILY_BASE = 200
ShopConfig.OFFLINE_RATE = 0.4
ShopConfig.OFFLINE_MAX_SECONDS = 8 * 60 * 60

-- 課金（id は Roblox で作ったあとに入れる。0 のものは表示しない）
ShopConfig.GamePasses = {
	doubleMoney = { id = 0 },
	autoShipper = { id = 0 }, -- 発送スタッフ +5/秒
}
ShopConfig.GamePassOrder = { "doubleMoney", "autoShipper" }
ShopConfig.AUTO_SHIPPER_BONUS = 5

return ShopConfig
