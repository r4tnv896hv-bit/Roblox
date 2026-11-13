-- 表示する文字の翻訳表（英語が基本。日本語の設定の人には日本語）
local Locale = {}

local STRINGS = {
	en = {
		money = "$%s",
		status = "Orders waiting: %s · Visitors %s/s · Auto-ship %s/s · x%.1f",
		ship = "SHIP ORDERS (%s)",
		dashboard = "DASHBOARD",
		tab_products = "Products",
		tab_ads = "Ads",
		tab_upgrades = "Upgrades",
		tab_company = "Company",
		close = "Close",
		price_mode = "Pricing:",
		mode_cheap = "Cheap",
		mode_normal = "Normal",
		mode_premium = "Premium",
		product_row = "%s\nStock %s · Sells for $%s",
		buy_stock = "Buy 10\n$%s",
		unlock_product = "Unlock %s\n$%s",
		all_unlocked = "All products unlocked!",
		warehouse_info = "Warehouse: %s / %s",
		ad_row = "%s\n+%s visitors/s for %ss",
		ad_buy = "Launch\n$%s",
		ad_running = "Running\n%ss",
		upgrade_row = "%s  Lv.%s\n%s",
		upgrade_buy = "Upgrade\n$%s",
		upgrade_max = "MAX",
		sell_company = "Sell your company\nReset everything, earn +%s%% forever\nNeed $%s",
		franchise_info = "Companies sold: %s · Bonus +%s%%",
		invite = "Invite friends! +20%% money each",
		new_order = "NEW ORDER! %s  +$%s",
		ranking_title = "TOP SELLERS",
		tutorial = "1) Buy stock  2) Orders come in  3) SHIP to get paid!",

		product_phoneCase = "Phone Case",
		product_earbuds = "Wireless Earbuds",
		product_ledLamp = "LED Galaxy Lamp",
		product_smartWatch = "Smart Watch",
		product_drone = "Camera Drone",
		product_gamingChair = "Gaming Chair",
		product_eScooter = "E-Scooter",

		ad_social = "Social Media Ads",
		ad_video = "Short Video Ads",
		ad_influencer = "Influencer Deal",

		upgrade_warehouse = "Bigger Warehouse",
		upgrade_warehouse_desc = "+50 stock space",
		upgrade_staff = "Hire Shipping Staff",
		upgrade_staff_desc = "+0.5 auto-shipped orders/s",
		upgrade_rating = "Store Rating",
		upgrade_rating_desc = "+8% more customers buy",
		upgrade_restock = "Auto-Restock",
		upgrade_restock_desc = "Staff buys stock for you",

		pass_doubleMoney = "2x Money",
		pass_autoShipper = "Robot Shippers (+5/s)",

		toast_shipped = "Shipped! +$%s",
		toast_need_money = "You need $%s!",
		toast_warehouse_full = "Warehouse full! Upgrade it.",
		toast_ad_started = "%s launched! Customers incoming...",
		announce_unlock = "%s started selling %s!",
		announce_sold = "%s sold their company! (#%s)",
		announce_friend = "Friend bonus! Money +%s%%",
		announce_daily = "Daily bonus day %s! +$%s",
		announce_offline = "Welcome back! Your staff earned +$%s (%s min)",
		announce_pass = "%s got %s!",
	},
	ja = {
		money = "$%s",
		status = "発送待ち: %s件 ・ お客さん %s人/秒 ・ 自動発送 %s/秒 ・ x%.1f",
		ship = "発送する（%s件）",
		dashboard = "管理画面",
		tab_products = "商品",
		tab_ads = "広告",
		tab_upgrades = "強化",
		tab_company = "会社",
		close = "閉じる",
		price_mode = "値段:",
		mode_cheap = "安く",
		mode_normal = "ふつう",
		mode_premium = "高く",
		product_row = "%s\n在庫 %s ・ 売値 $%s",
		buy_stock = "10個仕入れ\n$%s",
		unlock_product = "%s を解放\n$%s",
		all_unlocked = "全部の商品を解放した！",
		warehouse_info = "倉庫: %s / %s",
		ad_row = "%s\nお客さん +%s人/秒・%s秒間",
		ad_buy = "出す\n$%s",
		ad_running = "実施中\nあと%s秒",
		upgrade_row = "%s  Lv.%s\n%s",
		upgrade_buy = "強化\n$%s",
		upgrade_max = "最大",
		sell_company = "会社を売る\n全部リセット → ずっと +%s%%\n必要 $%s",
		franchise_info = "売った会社: %s ・ ボーナス +%s%%",
		invite = "友だちを招待！ 1人ごとに +20%%",
		new_order = "新しい注文！ %s  +$%s",
		ranking_title = "売上ランキング",
		tutorial = "① 仕入れる ② 注文が来る ③ 発送してお金ゲット！",

		product_phoneCase = "スマホケース",
		product_earbuds = "ワイヤレスイヤホン",
		product_ledLamp = "LEDギャラクシーランプ",
		product_smartWatch = "スマートウォッチ",
		product_drone = "カメラドローン",
		product_gamingChair = "ゲーミングチェア",
		product_eScooter = "電動キックボード",

		ad_social = "SNS広告",
		ad_video = "ショート動画広告",
		ad_influencer = "インフルエンサー案件",

		upgrade_warehouse = "倉庫を広げる",
		upgrade_warehouse_desc = "在庫 +50個",
		upgrade_staff = "発送スタッフを雇う",
		upgrade_staff_desc = "自動発送 +0.5件/秒",
		upgrade_rating = "お店の評価",
		upgrade_rating_desc = "買ってくれる人 +8%",
		upgrade_restock = "自動仕入れ",
		upgrade_restock_desc = "スタッフが仕入れてくれる",

		pass_doubleMoney = "お金2倍",
		pass_autoShipper = "ロボット発送（+5/秒）",

		toast_shipped = "発送完了！ +$%s",
		toast_need_money = "$%s 必要です！",
		toast_warehouse_full = "倉庫がいっぱい！ 強化しよう",
		toast_ad_started = "%s を開始！ お客さんが来るよ",
		announce_unlock = "%s が %s の販売を開始！",
		announce_sold = "%s が会社を売った！（%s回目）",
		announce_friend = "フレンドボーナス！ お金 +%s%%",
		announce_daily = "ログインボーナス %s日目！ +$%s",
		announce_offline = "おかえり！ スタッフが +$%s 稼いだよ（%s分）",
		announce_pass = "%s が「%s」をゲット！",
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
