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
