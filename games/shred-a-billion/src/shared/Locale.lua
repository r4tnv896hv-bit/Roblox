-- 表示する文字の翻訳表（英語が基本。日本語の設定の人には日本語）
local Locale = {}

local STRINGS = {
	en = {
		money = "$%s",
		goal = "SHRED A BILLION: $%s / $%s",
		goal_done = "GOAL REACHED! Rebirth for x%s money!",
		rate = "Shred power %s/s · x%.1f",
		upgrade_power = "Shredder Power Lv.%s\n$%s",
		upgrade_blade = "Sharper Blades Lv.%s\n$%s",
		upgrade_spawn = "Faster Spawns Lv.%s\n$%s",
		upgrade_feeder = "Auto Feeder Lv.%s\n$%s",
		upgrade_max = "MAX",
		rebirth = "REBIRTH\nReach $%s",
		invite = "Invite friends! +20%% money each",
		tutorial = "Click items to throw them in YOUR shredder!",
		item_tag = "%s\n$%s",
		truck_tag = "ARMORED TRUCK\n%s HP",
		next_unlock = "Next: %s at Power Lv.%s",
		ranking_title = "TOP SHREDDERS",
		plot_empty = "EMPTY",

		item_cash = "Cash Stack",
		item_wallet = "Wallet",
		item_piggy = "Piggy Bank",
		item_briefcase = "Briefcase",
		item_goldBar = "Gold Bar",
		item_safe = "Safe",
		item_diamond = "Diamond",
		item_vault = "Bank Vault",
		item_crown = "Royal Crown",
		item_statue = "Gold Statue",
		item_truck = "Money Truck",

		toast_need_money = "You need $%s!",
		toast_not_yours = "That's not your shredder!",
		announce_unlock = "%s can now shred %s!",
		announce_truck = "ARMORED TRUCK appeared! Everyone click it!",
		announce_truck_done = "Truck destroyed! Top hitter: %s",
		announce_truck_reward = "You got +$%s from the truck!",
		announce_rebirth = "%s shredded a BILLION and rebirthed! (#%s)",
		announce_daily = "Daily bonus day %s! +$%s",
		announce_friend = "Friend bonus! Money +%s%%",
	},
	ja = {
		money = "$%s",
		goal = "10億をシュレッダー！ $%s / $%s",
		goal_done = "目標達成！ 転生でお金 x%s！",
		rate = "削る力 %s/秒 ・ x%.1f",
		upgrade_power = "シュレッダー強化 Lv.%s\n$%s",
		upgrade_blade = "刃をとがらせる Lv.%s\n$%s",
		upgrade_spawn = "出てくる速さ Lv.%s\n$%s",
		upgrade_feeder = "自動投入 Lv.%s\n$%s",
		upgrade_max = "最大",
		rebirth = "転生\n$%s 必要",
		invite = "友だちを招待！ 1人ごとに +20%%",
		tutorial = "物をクリックして自分のシュレッダーに入れよう！",
		item_tag = "%s\n$%s",
		truck_tag = "現金輸送トラック\nHP %s",
		next_unlock = "次: %s（強化 Lv.%s で解放）",
		ranking_title = "シュレッダーランキング",
		plot_empty = "空き",

		item_cash = "札束",
		item_wallet = "財布",
		item_piggy = "ブタの貯金箱",
		item_briefcase = "アタッシュケース",
		item_goldBar = "金塊",
		item_safe = "金庫",
		item_diamond = "ダイヤモンド",
		item_vault = "銀行の金庫室",
		item_crown = "王冠",
		item_statue = "黄金の像",
		item_truck = "現金輸送車",

		toast_need_money = "$%s 必要です！",
		toast_not_yours = "それは他の人のシュレッダー！",
		announce_unlock = "%s が %s を壊せるようになった！",
		announce_truck = "現金輸送トラックが出現！ みんなでクリック！",
		announce_truck_done = "トラック破壊！ 一番叩いた人: %s",
		announce_truck_reward = "トラックから +$%s ゲット！",
		announce_rebirth = "%s が10億を達成して転生！（%s回目）",
		announce_daily = "ログインボーナス %s日目！ +$%s",
		announce_friend = "フレンドボーナス！ お金 +%s%%",
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
