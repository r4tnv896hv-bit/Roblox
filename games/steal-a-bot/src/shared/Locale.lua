-- 表示する文字の翻訳表（英語が基本。日本語の設定の人には日本語）
local Locale = {}

local STRINGS = {
	en = {
		money = "$%s",
		income = "+$%s/s · x%.1f",
		lock = "LOCK BASE",
		lock_on = "LOCKED %ss",
		lock_wait = "Lock ready in %ss",
		rebirth = "REBIRTH\nNeed $%s",
		invite = "Invite friends! +20%% money each",
		tutorial = "Buy bots on the conveyor! Steal bots from other bases and bring them home!",
		bot_tag = "%s\n+$%s/s",
		prompt_buy = "Buy $%s",
		prompt_steal = "Steal",
		prompt_sell = "Sell $%s",
		prompt_lock = "Lock base",

		rarity_common = "Common",
		rarity_uncommon = "Uncommon",
		rarity_rare = "RARE",
		rarity_epic = "EPIC",
		rarity_legendary = "LEGENDARY",
		rarity_secret = "SECRET",
		bot_beep = "Beep",
		bot_boop = "Boop",
		bot_spark = "Spark",
		bot_bolt = "Bolt",
		bot_nova = "Nova",
		bot_titan = "Titan",
		bot_glitch = "GLITCH",

		toast_locked = "That base is locked!",
		toast_no_space = "No space in your base! Sell a bot.",
		toast_need_money = "You need $%s!",
		toast_being_stolen = "%s is stealing your %s! Touch them to get it back!",
		toast_caught = "Caught! The bot went back.",
		toast_saved = "You got your bot back!",
		toast_dropped = "You dropped the bot!",
		toast_lock_on = "Base locked for %s seconds!",
		announce_stolen = "%s stole %s from %s!",
		announce_bought = "%s bought %s!",
		announce_spawn = "A %s %s is on the conveyor!",
		announce_rebirth = "%s rebirthed! (#%s)",
		announce_daily = "Daily bonus day %s! +$%s",
		announce_offline = "Welcome back! Your bots made +$%s (%s min)",
	},
	ja = {
		money = "$%s",
		income = "+$%s/秒 ・ x%.1f",
		lock = "基地をロック",
		lock_on = "ロック中 %s秒",
		lock_wait = "ロックまで %s秒",
		rebirth = "転生\n必要 $%s",
		invite = "友だちを招待！ 1人ごとに +20%%",
		tutorial = "ベルトのロボットを買おう！ 他の基地から盗んで自分の基地に運ぼう！",
		bot_tag = "%s\n+$%s/秒",
		prompt_buy = "買う $%s",
		prompt_steal = "盗む",
		prompt_sell = "売る $%s",
		prompt_lock = "基地をロック",

		rarity_common = "コモン",
		rarity_uncommon = "アンコモン",
		rarity_rare = "レア",
		rarity_epic = "エピック",
		rarity_legendary = "レジェンド",
		rarity_secret = "シークレット",
		bot_beep = "ビープ",
		bot_boop = "ブープ",
		bot_spark = "スパーク",
		bot_bolt = "ボルト",
		bot_nova = "ノヴァ",
		bot_titan = "タイタン",
		bot_glitch = "グリッチ",

		toast_locked = "その基地はロック中！",
		toast_no_space = "基地がいっぱい！ ロボットを売ろう",
		toast_need_money = "$%s 必要です！",
		toast_being_stolen = "%s が %s を盗んでいる！ タッチして取り返せ！",
		toast_caught = "つかまった！ ロボットは戻された",
		toast_saved = "ロボットを取り返した！",
		toast_dropped = "ロボットを落とした！",
		toast_lock_on = "基地を %s秒 ロックした！",
		announce_stolen = "%s が %s を %s から盗んだ！",
		announce_bought = "%s が %s を買った！",
		announce_spawn = "%s の %s がベルトに登場！",
		announce_rebirth = "%s が転生！（%s回目）",
		announce_daily = "ログインボーナス %s日目！ +$%s",
		announce_offline = "おかえり！ ロボットが +$%s 稼いだよ（%s分）",
	},
}

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
