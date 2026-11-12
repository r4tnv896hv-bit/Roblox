-- コインクリッカー: 画面上部にコイン数を表示する
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local coins = player:WaitForChild("leaderstats"):WaitForChild("Coins")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CoinGui"
screenGui.ResetOnSpawn = false

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0, 12)
label.Size = UDim2.new(0, 240, 0, 48)
label.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
label.BackgroundTransparency = 0.3
label.TextColor3 = Color3.fromRGB(255, 220, 80)
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = label

local function update()
	label.Text = "コイン: " .. coins.Value
end

coins.Changed:Connect(update)
update()

screenGui.Parent = player:WaitForChild("PlayerGui")
