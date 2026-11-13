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
		baseCost = 10,
		growth = 1.5,
	},
	auto = {
		key = "autoLevel",
		baseCost = 25,
		growth = 1.6,
	},
	crit = {
		key = "critLevel",
		baseCost = 100,
		growth = 1.8,
		maxLevel = 10, -- 最大 50%
	},
	factory = {
		key = "factoryLevel",
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

-- オフライン報酬: いない間も自動コインの一部がたまる
UpgradeConfig.OFFLINE_RATE = 0.5 -- 自動コインの 50%
UpgradeConfig.OFFLINE_MAX_SECONDS = 8 * 60 * 60 -- 最大 8 時間ぶん
UpgradeConfig.OFFLINE_MIN_SECONDS = 60

-- プレイ時間ボーナス: 遊び続けると 10 分ごとにプレゼント
UpgradeConfig.PLAYTIME_GIFT_SECONDS = 10 * 60

function UpgradeConfig.PlaytimeGift(perClick, perSecond, multiplier)
	return math.floor(math.max(200, perSecond * 120 + perClick * 60) * multiplier)
end

UpgradeConfig.DAILY_BASE_REWARD = 100
UpgradeConfig.DAILY_MAX_STREAK = 7

function UpgradeConfig.RebirthCost(rebirths)
	return math.floor(UpgradeConfig.REBIRTH_BASE_COST * UpgradeConfig.REBIRTH_COST_GROWTH ^ rebirths)
end

-- コインの倍率（転生 × フレンド × ペット × コイン2倍パス）
function UpgradeConfig.Multiplier(rebirths, friendCount, hasDoubleCoins, petBonus)
	local friends = math.min(friendCount, UpgradeConfig.MAX_FRIENDS_COUNTED)
	local multiplier = (1 + rebirths * UpgradeConfig.REBIRTH_BONUS)
		* (1 + friends * UpgradeConfig.FRIEND_BONUS)
		* (1 + (petBonus or 0))
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
-- ペット（卵から出る。強い順に MAX_EQUIPPED 匹が自動でついてくる）
---------------------------------------------------------------------
UpgradeConfig.MAX_EQUIPPED_PETS = 3

UpgradeConfig.Rarities = {
	common = { order = 1, color = Color3.fromRGB(200, 200, 200) },
	uncommon = { order = 2, color = Color3.fromRGB(90, 220, 90) },
	rare = { order = 3, color = Color3.fromRGB(70, 150, 255) },
	epic = { order = 4, color = Color3.fromRGB(190, 90, 255) },
	legendary = { order = 5, color = Color3.fromRGB(255, 200, 40) },
}

-- bonus はコインの倍率に足される量（0.5 なら +50%）
UpgradeConfig.Pets = {
	slime = { rarity = "common", bonus = 0.1, color = Color3.fromRGB(110, 220, 110), size = 1.6 },
	bunny = { rarity = "common", bonus = 0.15, color = Color3.fromRGB(245, 245, 245), size = 1.7 },
	cat = { rarity = "uncommon", bonus = 0.25, color = Color3.fromRGB(255, 160, 60), size = 1.8 },
	dragon = { rarity = "rare", bonus = 0.5, color = Color3.fromRGB(230, 60, 60), size = 2.1 },
	unicorn = { rarity = "epic", bonus = 1.0, color = Color3.fromRGB(255, 140, 220), size = 2.2, neon = true },
	phoenix = { rarity = "legendary", bonus = 2.5, color = Color3.fromRGB(255, 190, 40), size = 2.4, neon = true },
}

-- 金色のペット: 同じペットを FUSE_COUNT 匹で合体すると、ボーナス GOLDEN_MULTIPLIER 倍の金色版になる
UpgradeConfig.FUSE_COUNT = 5
UpgradeConfig.GOLDEN_MULTIPLIER = 3
do
	local baseIds = {}
	for petId in pairs(UpgradeConfig.Pets) do
		table.insert(baseIds, petId)
	end
	for _, petId in ipairs(baseIds) do
		local base = UpgradeConfig.Pets[petId]
		UpgradeConfig.Pets["golden_" .. petId] = {
			rarity = base.rarity,
			bonus = base.bonus * UpgradeConfig.GOLDEN_MULTIPLIER,
			color = base.color:Lerp(Color3.fromRGB(255, 210, 50), 0.6),
			size = base.size * 1.15,
			neon = true,
			golden = true,
			base = petId,
		}
	end
end

-- 卵: cost コインで1回。weights は出やすさ（合計に対する割合が確率）
UpgradeConfig.Eggs = {
	basic = {
		cost = 500,
		color = Color3.fromRGB(240, 230, 210),
		position = Vector3.new(-16, 0, -12),
		weights = { slime = 45, bunny = 30, cat = 17, dragon = 6.5, unicorn = 1.4, phoenix = 0.1 },
	},
	golden = {
		cost = 25000,
		color = Color3.fromRGB(255, 200, 40),
		position = Vector3.new(-26, 0, -12),
		weights = { cat = 40, dragon = 35, unicorn = 20, phoenix = 5 },
	},
}
UpgradeConfig.EggOrder = { "basic", "golden" }

-- 持っているペット（{ cat = 2, ... }）から、ついてくるペットと合計ボーナスを決める
function UpgradeConfig.EquippedPets(ownedPets)
	local list = {}
	for petId, count in pairs(ownedPets) do
		if UpgradeConfig.Pets[petId] then
			for _ = 1, math.min(count, UpgradeConfig.MAX_EQUIPPED_PETS) do
				table.insert(list, petId)
			end
		end
	end
	table.sort(list, function(a, b)
		return UpgradeConfig.Pets[a].bonus > UpgradeConfig.Pets[b].bonus
	end)

	local equipped, bonus = {}, 0
	for i = 1, math.min(#list, UpgradeConfig.MAX_EQUIPPED_PETS) do
		equipped[i] = list[i]
		bonus = bonus + UpgradeConfig.Pets[list[i]].bonus
	end
	return equipped, bonus
end

-- 卵の中身を1つ決める（rng は Random）
-- lucky が true ならレア以上の出やすさを LUCKY_MULTIPLIER 倍にする
function UpgradeConfig.RollEgg(eggId, rng, lucky)
	local weights = {}
	local total = 0
	for petId, weight in pairs(UpgradeConfig.Eggs[eggId].weights) do
		local rarity = UpgradeConfig.Rarities[UpgradeConfig.Pets[petId].rarity]
		if lucky and rarity.order >= UpgradeConfig.Rarities.rare.order then
			weight = weight * UpgradeConfig.LUCKY_MULTIPLIER
		end
		weights[petId] = weight
		total = total + weight
	end
	local roll = rng:NextNumber(0, total)
	local fallback
	for petId, weight in pairs(weights) do
		fallback = petId
		roll = roll - weight
		if roll <= 0 then
			return petId
		end
	end
	return fallback
end

---------------------------------------------------------------------
-- 課金アイテム（Robux）
-- id は Creator Dashboard で作ったアイテムの ID。0 のものはショップに出さない。
-- price は表示用の目安（実際の値段は Roblox から取得して表示する）。
---------------------------------------------------------------------
UpgradeConfig.GamePasses = {
	doubleCoins = {
		id = 2087840383,
		price = 99,
	},
	luckyEggs = {
		id = 2089172365,
		price = 199,
	},
	tripleHatch = {
		id = 2089364357,
		price = 249,
	},
	autoClick = {
		id = 2088056363,
		price = 149,
	},
}
UpgradeConfig.GamePassOrder = { "doubleCoins", "autoClick", "luckyEggs", "tripleHatch" }
UpgradeConfig.LUCKY_MULTIPLIER = 2 -- ラッキー卵パス: レア以上が出やすくなる倍率
UpgradeConfig.AUTO_CLICKS_PER_SECOND = 3

UpgradeConfig.Products = {
	smallPack = {
		id = 3730798651,
		price = 25,
		minutes = 10,
		minimum = 1000,
	},
	bigPack = {
		id = 3730798682,
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
