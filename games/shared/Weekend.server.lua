-- 5 本のゲームで共通: 週末（金・土・日 UTC）かどうかを Workspace の Weekend 属性に書く
-- 各ゲームの Main がこの属性を見て、お金を 2 倍にする
local Workspace = game:GetService("Workspace")

local function isWeekend()
	local wday = os.date("!*t").wday -- 1=日 … 6=金, 7=土
	return wday == 1 or wday == 6 or wday == 7
end

while true do
	Workspace:SetAttribute("Weekend", isWeekend())
	task.wait(60)
end
