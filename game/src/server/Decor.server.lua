-- コインクリッカー: 見た目（リアル寄り）
-- 光・地形（草地/丘/岩山/湖/石畳）・雲・台座・金属のコインの玉など。ゲームの動きには関係しない。
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local terrain = Workspace.Terrain

local decor = Instance.new("Folder")
decor.Name = "Decor"
decor.Parent = Workspace

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = props.Parent or decor
	return p
end

-- 縦向きの円柱（Roblox の円柱は X 軸向きなので 90 度回す）
local function cylinder(height, diameter, center, color, material)
	return part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
	})
end

---------------------------------------------------------------------
-- 光と空気（夕方の自然な光。Future ライティングはプロジェクト設定で有効）
---------------------------------------------------------------------
Lighting.ClockTime = 16.6
Lighting.Brightness = 3
Lighting.OutdoorAmbient = Color3.fromRGB(110, 105, 100)
Lighting.Ambient = Color3.fromRGB(40, 40, 45)
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 1
Lighting.GlobalShadows = true

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmosphere.Density = 0.32
atmosphere.Offset = 0.2
atmosphere.Color = Color3.fromRGB(205, 185, 170)
atmosphere.Decay = Color3.fromRGB(110, 115, 130)
atmosphere.Glare = 0.35
atmosphere.Haze = 1.2
atmosphere.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.4
bloom.Size = 24
bloom.Threshold = 1.2
bloom.Parent = Lighting

local sunRays = Instance.new("SunRaysEffect")
sunRays.Intensity = 0.05
sunRays.Spread = 0.6
sunRays.Parent = Lighting

local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Saturation = 0.08
colorCorrection.Contrast = 0.1
colorCorrection.Brightness = 0.02
colorCorrection.TintColor = Color3.fromRGB(255, 248, 240)
colorCorrection.Parent = Lighting

-- 遠くを少しぼかして写真っぽくする
local depthOfField = Instance.new("DepthOfFieldEffect")
depthOfField.FarIntensity = 0.12
depthOfField.FocusDistance = 40
depthOfField.InFocusRadius = 60
depthOfField.NearIntensity = 0
depthOfField.Parent = Lighting

-- 動く雲
local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
clouds.Cover = 0.55
clouds.Density = 0.6
clouds.Color = Color3.fromRGB(255, 250, 245)
clouds.Parent = terrain

---------------------------------------------------------------------
-- 地形: 草地・丘・遠くの岩山・湖・石畳の道
---------------------------------------------------------------------
-- 地面（上面が高さ 0 になるように）
terrain:FillBlock(CFrame.new(0, -6, 0), Vector3.new(1024, 12, 1024), Enum.Material.Grass)

-- 元の平らな地面は見えなくする（当たり判定は残す）
local baseplate = Workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate.Transparency = 1
end

local rng = Random.new(2026)

-- まわりのなだらかな丘
for _ = 1, 28 do
	local angle = rng:NextNumber(0, math.pi * 2)
	local radius = rng:NextNumber(170, 260)
	local size = rng:NextNumber(35, 70)
	terrain:FillBall(Vector3.new(math.cos(angle) * radius, -size * 0.55, math.sin(angle) * radius), size, Enum.Material.Grass)
end

-- 遠くの岩山
for _ = 1, 14 do
	local angle = rng:NextNumber(0, math.pi * 2)
	local radius = rng:NextNumber(300, 420)
	local size = rng:NextNumber(60, 110)
	local center = Vector3.new(math.cos(angle) * radius, -size * 0.3, math.sin(angle) * radius)
	terrain:FillBall(center, size, Enum.Material.Rock)
	terrain:FillBall(center + Vector3.new(0, size * 0.55, 0), size * 0.45, Enum.Material.Snow)
end

-- 砂浜のある湖
local LAKE = Vector3.new(70, 0, 40)
terrain:FillBlock(CFrame.new(LAKE + Vector3.new(0, -3, 0)), Vector3.new(52, 6, 40), Enum.Material.Sand)
terrain:FillBlock(CFrame.new(LAKE + Vector3.new(0, -2.5, 0)), Vector3.new(40, 5, 28), Enum.Material.Water)

-- スポーン地点から台座までの石畳
local coinButton = Workspace:WaitForChild("CoinButton")
local BALL_X, BALL_Z = coinButton.Position.X, coinButton.Position.Z
terrain:FillBlock(CFrame.new(0, -1, (-6 + BALL_Z + 6) / 2), Vector3.new(8, 2, math.abs(BALL_Z) - 4), Enum.Material.Cobblestone)

-- 木（幹は木の部品、葉は地形の葉っぱで自然な形に）
local WOOD = Color3.fromRGB(95, 70, 50)
for _ = 1, 45 do
	local angle = rng:NextNumber(0, math.pi * 2)
	local radius = rng:NextNumber(45, 160)
	local spot = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	if (spot - LAKE).Magnitude > 34 then
		local height = rng:NextNumber(9, 15)
		part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, 1.6, 1.6),
			CFrame = CFrame.new(spot + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = WOOD,
			Material = Enum.Material.Wood,
		})
		local leaf = rng:NextNumber(5, 7.5)
		terrain:FillBall(spot + Vector3.new(0, height, 0), leaf, Enum.Material.LeafyGrass)
		terrain:FillBall(spot + Vector3.new(rng:NextNumber(-2, 2), height + leaf * 0.8, rng:NextNumber(-2, 2)), leaf * 0.7, Enum.Material.LeafyGrass)
	end
end

-- 岩
for _ = 1, 22 do
	local angle = rng:NextNumber(0, math.pi * 2)
	local radius = rng:NextNumber(30, 150)
	local spot = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	if (spot - LAKE).Magnitude > 30 then
		terrain:FillBall(spot, rng:NextNumber(2, 4.5), Enum.Material.Rock)
	end
end

---------------------------------------------------------------------
-- コインの玉: 大理石の台座に乗せて、本物の金属の金色にして、ふわふわ浮かせる
---------------------------------------------------------------------
local center = Vector3.new(BALL_X, 0, BALL_Z)
local STONE = Color3.fromRGB(230, 226, 218)
local GOLD = Color3.fromRGB(255, 196, 70)

cylinder(1, 14, center + Vector3.new(0, 0.5, 0), STONE, Enum.Material.Marble)
cylinder(1.5, 10, center + Vector3.new(0, 1.75, 0), STONE, Enum.Material.Marble)
cylinder(0.3, 10.6, center + Vector3.new(0, 2.4, 0), GOLD, Enum.Material.Metal)

coinButton.Material = Enum.Material.Metal
coinButton.Color = GOLD
coinButton.Reflectance = 0.25

local light = Instance.new("PointLight")
light.Color = Color3.fromRGB(255, 210, 120)
light.Range = 16
light.Brightness = 1.5
light.Shadows = true
light.Parent = coinButton

local sparkles = Instance.new("ParticleEmitter")
sparkles.Rate = 6
sparkles.Lifetime = NumberRange.new(1.5, 2.5)
sparkles.Speed = NumberRange.new(0.8, 2)
sparkles.SpreadAngle = Vector2.new(180, 180)
sparkles.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.35),
	NumberSequenceKeypoint.new(1, 0),
})
sparkles.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.2),
	NumberSequenceKeypoint.new(1, 1),
})
sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 235, 160))
sparkles.LightEmission = 1
sparkles.Parent = coinButton

coinButton.Position = Vector3.new(BALL_X, 6.2, BALL_Z)
TweenService:Create(
	coinButton,
	TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ Position = Vector3.new(BALL_X, 6.9, BALL_Z) }
):Play()

---------------------------------------------------------------------
-- ランキング看板の柱と屋根（木と真鍮）
---------------------------------------------------------------------
local board = Workspace:WaitForChild("RankingBoard")
board.Material = Enum.Material.WoodPlanks
board.Color = Color3.fromRGB(70, 50, 35)

for _, side in ipairs({ -1, 1 }) do
	part({
		Size = Vector3.new(1, 19, 1),
		CFrame = board.CFrame * CFrame.new(side * 7.5, 0.5, 0),
		Color = WOOD,
		Material = Enum.Material.Wood,
	})
end
part({
	Size = Vector3.new(17, 1, 2),
	CFrame = board.CFrame * CFrame.new(0, 9.5, 0),
	Color = Color3.fromRGB(200, 160, 80),
	Material = Enum.Material.Metal,
})

---------------------------------------------------------------------
-- ワールド2: 浮島を氷河の地形にする
---------------------------------------------------------------------
local island = Workspace:WaitForChild("CrystalIsland", 30)
if island then
	terrain:FillBlock(island.CFrame, island.Size, Enum.Material.Glacier)
	island.Transparency = 1
end
