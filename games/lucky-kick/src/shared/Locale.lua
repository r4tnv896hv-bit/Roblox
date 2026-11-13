-- 表示する文字の翻訳表（英語が基本。日本語の設定の人には日本語）
local Locale = {}

local STRINGS = {
	en = {
		coins = "$%s",
		best = "Best: %sm · x%.1f",
		kick = "KICK!",
		kick_hint = "Tap when the bar is in the GREEN!",
		wait = "Wait...",
		upgrade_leg = "Leg Power Lv.%s\n$%s",
		upgrade_luck = "Luck Lv.%s\n$%s",
		upgrade_max = "%s MAX",
		rebirth = "REBIRTH\nNeed $%s",
		invite = "Invite friends! +20%% coins each",
		result = "%sm! %s block x%s · %s → +$%s",
		perfect = "PERFECT KICK!",
		block_wood = "Wood",
		block_gold = "Gold",
		block_diamond = "Diamond",
		block_rainbow = "RAINBOW",
		reward_nothing = "No bonus",
		reward_double = "Double!",
		reward_jackpot = "JACKPOT x5!",
		reward_mega = "MEGA x25!!",
		zone_meadow = "Meadow",
		zone_desert = "Desert",
		zone_snow = "Snowfield",
		zone_space = "SPACE",
		toast_need_money = "You need $%s!",
		announce_record = "%s kicked %sm! New server record!",
		announce_rainbow = "%s kicked a RAINBOW block!",
		announce_mega = "%s hit a MEGA x25 lucky reward!",
		announce_rebirth = "%s rebirthed! (#%s)",
		announce_daily = "Daily bonus day %s! +$%s",
		ranking_title = "FARTHEST KICKS",
	},
	ja = {
		coins = "$%s",
		best = "最高: %sm ・ x%.1f",
		kick = "キック！",
		kick_hint = "バーが緑のときにタップ！",
		wait = "まって…",
		upgrade_leg = "キック力 Lv.%s\n$%s",
		upgrade_luck = "運 Lv.%s\n$%s",
		upgrade_max = "%s 最大",
		rebirth = "転生\n必要 $%s",
		invite = "友だちを招待！ 1人ごとに +20%%",
		result = "%sm！ %sブロック x%s ・ %s → +$%s",
		perfect = "パーフェクトキック！",
		block_wood = "木の",
		block_gold = "金の",
		block_diamond = "ダイヤの",
		block_rainbow = "虹の",
		reward_nothing = "ボーナスなし",
		reward_double = "2倍！",
		reward_jackpot = "大当たり x5！",
		reward_mega = "超大当たり x25!!",
		zone_meadow = "草原",
		zone_desert = "砂漠",
		zone_snow = "雪原",
		zone_space = "宇宙",
		toast_need_money = "$%s 必要です！",
		announce_record = "%s が %sm 飛ばした！ サーバー新記録！",
		announce_rainbow = "%s が虹のブロックを蹴った！",
		announce_mega = "%s が超大当たり x25！",
		announce_rebirth = "%s が転生！（%s回目）",
		announce_daily = "ログインボーナス %s日目！ +$%s",
		ranking_title = "飛距離ランキング",
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
