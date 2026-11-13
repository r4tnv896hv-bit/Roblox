-- 表示する文字の翻訳表（英語が基本。日本語の設定の人には日本語で出す）
-- 数字はクライアント側でカンマ付きの文字にしてから渡すので、整数は %s で受け取る。
local Locale = {}

local STRINGS = {
	en = {
		-- 画面
		coins_label = "Coins: %s",
		rate = "Per click +%s · Per sec +%s · Crit %s%% · x%.1f",
		shop_title = "Upgrades",
		upgrade_button = "%s  Lv.%s\n%s\nCost: %s coins",
		upgrade_max = "%s  Lv.%s\nMAX LEVEL",
		rebirth_button = "Rebirth (#%s)\nReset all → Multiplier +%.1f\nNeed: %s coins",
		rebirth_confirm = "Are you sure?\nTap again to rebirth!",
		invite = "Invite friends! +%s%% coins each",
		special_shop = "Special Shop",
		owned = "Owned",
		crit_popup = "CRIT! +%s",
		click_me = "Click for coins!",
		ranking_title = "Top Coins",

		-- お知らせ
		announce_friend = "Friend bonus! Coins +%s%%",
		announce_daily = "Daily bonus day %s! +%s coins (come back tomorrow for more)",
		announce_rebirth = "%s rebirthed! (#%s) Multiplier x%.1f",
		announce_golden_spawn = "A Golden Coin appeared! First come, first served!",
		announce_golden_got = "%s grabbed the Golden Coin! +%s",
		announce_pass = "%s got %s!",
		announce_pack = "%s bought %s: +%s coins!",
		announce_offline = "Welcome back! You earned +%s coins while away (%s min)",
		announce_playtime = "Thanks for playing %s minutes! Gift: +%s coins",
		tutorial_click = "CLICK THE COIN!",
		announce_need_coins = "You need %s coins!",
		announce_hatch = "%s hatched a %s %s!",
		hatch_title = "You hatched...",
		hatch_result = "%s %s  (+%s%% coins)",
		pets_label = "Pets: %s  (+%s%% coins)",
		pets_none = "No pets yet - hatch an egg!",
		egg_basic = "Basic Egg\n%s coins",
		egg_golden = "Golden Egg\n%s coins",
		egg_action = "Hatch",
		rarity_common = "Common",
		rarity_uncommon = "Uncommon",
		rarity_rare = "RARE",
		rarity_epic = "EPIC",
		rarity_legendary = "LEGENDARY",
		pet_slime = "Slime",
		pet_bunny = "Bunny",
		pet_cat = "Cat",
		pet_dragon = "Dragon",
		pet_unicorn = "Unicorn",
		pet_phoenix = "Phoenix",
		golden_pet = "Golden %s",
		pets_title = "Your Pets",
		pets_hint = "Tap to see your pets",
		pet_row = "%s  x%s  (+%s%% each)",
		fuse_button = "Fuse %s → Golden!",
		fuse_progress = "Fuse: %s/%s",
		close = "Close",
		announce_fuse = "%s fused a %s!",
		tutorial_shop = "Nice! Buy upgrades in the shop on the left",
		tutorial_like = "Enjoying the game? Please Like 👍 and Favorite ⭐!",

		-- アップグレード
		upgrade_click_name = "Click Power",
		upgrade_click_desc = "+1 coin per click",
		upgrade_auto_name = "Auto Coins",
		upgrade_auto_desc = "+1 coin per second",
		upgrade_crit_name = "Lucky Crit",
		upgrade_crit_desc = "5% chance for 10x coins",
		upgrade_factory_name = "Coin Factory",
		upgrade_factory_desc = "+10 coins per second",

		-- 課金アイテム
		pass_doubleCoins_name = "2x Coins",
		pass_doubleCoins_desc = "Double coins forever!",
		pass_autoClick_name = "Auto Clicker",
		pass_autoClick_desc = "Clicks 3 times every second",
		product_smallPack_name = "Coin Pack (S)",
		product_smallPack_desc = "Get 10 minutes of coins now",
		product_bigPack_name = "Coin Pack (L)",
		product_bigPack_desc = "Get 1 hour of coins now",
	},
	ja = {
		coins_label = "コイン: %s",
		rate = "1クリック +%s ・ 毎秒 +%s ・ 大当たり %s%% ・ 倍率 x%.1f",
		shop_title = "ショップ",
		upgrade_button = "%s  Lv.%s\n%s\n費用: %s コイン",
		upgrade_max = "%s  Lv.%s\n最大レベル",
		rebirth_button = "転生（%s回目）\n全部リセット → 倍率 +%.1f\n必要: %s コイン",
		rebirth_confirm = "本当に転生する？\nもう一度押すと転生！",
		invite = "友だちを招待！ 1人ごとにコイン +%s%%",
		special_shop = "スペシャルショップ",
		owned = "購入済み",
		crit_popup = "大当たり! +%s",
		click_me = "クリックでコイン！",
		ranking_title = "コインランキング",

		announce_friend = "フレンドボーナス！ コイン +%s%%",
		announce_daily = "ログインボーナス %s日目！ +%s コイン（毎日来ると増えるよ）",
		announce_rebirth = "%s が %s回目の転生！ 倍率 x%.1f",
		announce_golden_spawn = "ゴールデンコインが出現！ 早い者勝ち！",
		announce_golden_got = "%s がゴールデンコインをゲット！ +%s",
		announce_pass = "%s が「%s」をゲット！",
		announce_pack = "%s が%sで +%s コイン！",
		announce_offline = "おかえり！ いない間に +%s コインたまったよ（%s分）",
		announce_playtime = "%s分遊んでくれてありがとう！ プレゼント +%s コイン",
		tutorial_click = "コインをクリック！",
		announce_need_coins = "コインが %s 必要です！",
		announce_hatch = "%s が %s の %s をゲット！",
		hatch_title = "卵から出てきたのは…",
		hatch_result = "%s %s  （コイン +%s%%）",
		pets_label = "ペット: %s  （コイン +%s%%）",
		pets_none = "ペットなし - 卵を割ってみよう！",
		egg_basic = "ふつうの卵\n%s コイン",
		egg_golden = "金の卵\n%s コイン",
		egg_action = "割る",
		rarity_common = "コモン",
		rarity_uncommon = "アンコモン",
		rarity_rare = "レア",
		rarity_epic = "エピック",
		rarity_legendary = "レジェンド",
		pet_slime = "スライム",
		pet_bunny = "うさぎ",
		pet_cat = "ねこ",
		pet_dragon = "ドラゴン",
		pet_unicorn = "ユニコーン",
		pet_phoenix = "フェニックス",
		golden_pet = "金色の%s",
		pets_title = "持っているペット",
		pets_hint = "タップでペット一覧",
		pet_row = "%s  x%s  （1匹 +%s%%）",
		fuse_button = "%s匹で金色に合体！",
		fuse_progress = "合体: %s/%s",
		close = "閉じる",
		announce_fuse = "%s が %s に合体させた！",
		tutorial_shop = "いいね！ 左のショップでアップグレードを買おう",
		tutorial_like = "楽しんでる？ よかったら 👍 と ⭐ お気に入りを押してね！",

		upgrade_click_name = "クリック強化",
		upgrade_click_desc = "1クリックのコイン +1",
		upgrade_auto_name = "自動コイン",
		upgrade_auto_desc = "毎秒のコイン +1",
		upgrade_crit_name = "大当たり",
		upgrade_crit_desc = "5%の確率でコイン10倍",
		upgrade_factory_name = "コイン工場",
		upgrade_factory_desc = "毎秒のコイン +10",

		pass_doubleCoins_name = "コイン2倍",
		pass_doubleCoins_desc = "ずっとコインが2倍！",
		pass_autoClick_name = "オートクリック",
		pass_autoClick_desc = "毎秒3回、自動でクリック",
		product_smallPack_name = "コインパック（小）",
		product_smallPack_desc = "10分ぶんのコインをすぐゲット",
		product_bigPack_name = "コインパック（大）",
		product_bigPack_desc = "1時間ぶんのコインをすぐゲット",
	},
}

-- プレイヤーの言語設定から "ja" か "en" を選ぶ
function Locale.GetLanguage(player)
	local localeId = string.lower(player.LocaleId or "")
	if string.sub(localeId, 1, 2) == "ja" then
		return "ja"
	end
	return "en"
end

-- ペットの名前（金色版にも対応）
function Locale.PetName(language, petId)
	local baseId = string.match(petId, "^golden_(.+)$")
	if baseId then
		return Locale.Get(language, "golden_pet", Locale.Get(language, "pet_" .. baseId))
	end
	return Locale.Get(language, "pet_" .. petId)
end

function Locale.Get(language, key, ...)
	local text = (STRINGS[language] and STRINGS[language][key]) or STRINGS.en[key] or key
	if select("#", ...) > 0 then
		local ok, result = pcall(string.format, text, ...)
		if ok then
			return result
		end
	end
	return text
end

return Locale
