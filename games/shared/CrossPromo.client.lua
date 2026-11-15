-- 5 本のゲームで共通: 「他のゲーム」ボタン（ワンタップでワープ）と週末イベントの帯
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local japanese = string.sub(string.lower(player.LocaleId or ""), 1, 2) == "ja"

local GAMES = {
	{ placeId = 110580446151597, en = "Coin Clicker", ja = "コインクリッカー", color = Color3.fromRGB(255, 200, 50) },
	{ placeId = 93118600225288, en = "Steal a Bot", ja = "Steal a Bot（ロボットを盗め）", color = Color3.fromRGB(255, 90, 130) },
	{ placeId = 100433605048455, en = "Shred a Billion", ja = "Shred a Billion（10億シュレッダー）", color = Color3.fromRGB(60, 190, 100) },
	{ placeId = 102480658680221, en = "Lucky Block Kick", ja = "Lucky Block Kick（ブロックキック）", color = Color3.fromRGB(70, 170, 255) },
	{ placeId = 70531981839347, en = "Online Shop Tycoon", ja = "Online Shop Tycoon（ネットショップ）", color = Color3.fromRGB(150, 90, 255) },
}

-- コインクリッカーは自分で週末の帯を出しているので、ここでは出さない
local SHOWS_OWN_WEEKEND_BANNER = { [110580446151597] = true }

local function text(en, ja)
	return japanese and ja or en
end

local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local screen = Instance.new("ScreenGui")
screen.Name = "CrossPromo"
screen.ResetOnSpawn = false
screen.DisplayOrder = 5

local openButton = Instance.new("TextButton")
openButton.AnchorPoint = Vector2.new(0, 0)
openButton.Position = UDim2.new(0, 16, 0, 100)
openButton.Size = UDim2.new(0, 170, 0, 38)
openButton.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
openButton.TextColor3 = Color3.fromRGB(255, 255, 255)
openButton.TextScaled = true
openButton.Font = Enum.Font.GothamBold
openButton.Text = text("🎮 More Games", "🎮 他のゲーム")
openButton.Parent = screen
corner(openButton, 10)

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0, 420, 0, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
panel.Visible = false
panel.Parent = screen
corner(panel, 14)

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 12)
padding.PaddingBottom = UDim.new(0, 12)
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = panel

local title = Instance.new("TextLabel")
title.LayoutOrder = 0
title.Size = UDim2.new(1, 0, 0, 32)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 220, 80)
title.TextScaled = true
title.Font = Enum.Font.GothamBlack
title.Text = text("Play our other games!", "他のゲームも遊んでね！")
title.Parent = panel

for index, info in ipairs(GAMES) do
	if info.placeId ~= game.PlaceId then
		local b = Instance.new("TextButton")
		b.LayoutOrder = index
		b.Size = UDim2.new(1, 0, 0, 50)
		b.BackgroundColor3 = info.color
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
		b.TextStrokeTransparency = 0.5
		b.TextScaled = true
		b.Font = Enum.Font.GothamBlack
		b.Text = "▶ " .. text(info.en, info.ja)
		b.Parent = panel
		corner(b, 10)
		b.Activated:Connect(function()
			b.Text = text("Teleporting...", "ワープ中…")
			local ok = pcall(function()
				TeleportService:Teleport(info.placeId, player)
			end)
			if not ok then
				b.Text = "▶ " .. text(info.en, info.ja)
			end
		end)
	end
end

local close = Instance.new("TextButton")
close.LayoutOrder = 100
close.Size = UDim2.new(1, 0, 0, 36)
close.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
close.TextColor3 = Color3.fromRGB(255, 255, 255)
close.TextScaled = true
close.Font = Enum.Font.GothamBold
close.Text = text("Close", "閉じる")
close.Parent = panel
corner(close, 10)

openButton.Activated:Connect(function()
	panel.Visible = not panel.Visible
end)
close.Activated:Connect(function()
	panel.Visible = false
end)

-- 週末イベントの帯（金・土・日 UTC はお金 2 倍。サーバー側も同じ判定）
if not SHOWS_OWN_WEEKEND_BANNER[game.PlaceId] then
	local banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0, 0)
	banner.Position = UDim2.new(0, 16, 0, 60)
	banner.Size = UDim2.new(0, 230, 0, 34)
	banner.BackgroundColor3 = Color3.fromRGB(230, 60, 120)
	banner.TextColor3 = Color3.fromRGB(255, 255, 255)
	banner.TextScaled = true
	banner.Font = Enum.Font.GothamBlack
	banner.Text = text("WEEKEND 2x MONEY!", "週末イベント お金2倍！")
	banner.Parent = screen
	corner(banner, 10)
	task.spawn(function()
		while true do
			banner.Visible = Workspace:GetAttribute("Weekend") == true
			task.wait(5)
		end
	end)
end

local uiScale = Instance.new("UIScale")
uiScale.Parent = screen
local camera = Workspace.CurrentCamera
local function updateScale()
	if camera then
		uiScale.Scale = math.clamp(camera.ViewportSize.Y / 700, 0.55, 1)
	end
end
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end
updateScale()

screen.Parent = playerGui
