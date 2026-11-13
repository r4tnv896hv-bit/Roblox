-- コインクリッカー: 見た目（光・台座・景色）
-- Main が作ったワールドに飾りを足すだけで、ゲームの動きには関係しません。
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

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
-- 光と空気（夕方のあたたかい雰囲気）
---------------------------------------------------------------------
Lighting.ClockTime = 16.8
Lighting.Brightness = 2.5
Lighting.OutdoorAmbient = Color3.fromRGB(150, 135, 125)

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmosphere.Density = 0.3
atmosphere.Offset = 0.25
atmosphere.Color = Color3.fromRGB(255, 220, 190)
atmosphere.Decay = Color3.fromRGB(120, 110, 140)
atmosphere.Glare = 0.4
atmosphere.Haze = 1.5
atmosphere.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.6
bloom.Size = 24
bloom.Threshold = 0.9
bloom.Parent = Lighting

local sunRays = Instance.new("SunRaysEffect")
sunRays.Intensity = 0.08
sunRays.Spread = 0.8
sunRays.Parent = Lighting

local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Saturation = 0.15
colorCorrection.Contrast = 0.08
colorCorrection.TintColor = Color3.fromRGB(255, 245, 235)
colorCorrection.Parent = Lighting

---------------------------------------------------------------------
-- コインの玉: 台座に乗せて、光らせて、ふわふわ浮かせる
---------------------------------------------------------------------
local coinButton = Workspace:WaitForChild("CoinButton")
local BALL_X, BALL_Z = coinButton.Position.X, coinButton.Position.Z
local center = Vector3.new(BALL_X, 0, BALL_Z)

local STONE = Color3.fromRGB(225, 220, 210)
local GOLD = Color3.fromRGB(255, 190, 40)

cylinder(1, 14, center + Vector3.new(0, 0.5, 0), STONE, Enum.Material.Marble)
cylinder(1.5, 10, center + Vector3.new(0, 1.75, 0), STONE, Enum.Material.Marble)
cylinder(0.3, 10.6, center + Vector3.new(0, 2.4, 0), GOLD, Enum.Material.Metal)

local light = Instance.new("PointLight")
light.Color = GOLD
light.Range = 18
light.Brightness = 2
light.Parent = coinButton

local sparkles = Instance.new("ParticleEmitter")
sparkles.Rate = 8
sparkles.Lifetime = NumberRange.new(1.5, 2.5)
sparkles.Speed = NumberRange.new(1, 2.5)
sparkles.SpreadAngle = Vector2.new(180, 180)
sparkles.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.5),
	NumberSequenceKeypoint.new(1, 0),
})
sparkles.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(1, 1),
})
sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 235, 120))
sparkles.LightEmission = 1
sparkles.Parent = coinButton

-- 台座の少し上で上下にふわふわ
coinButton.Position = Vector3.new(BALL_X, 6.2, BALL_Z)
TweenService:Create(
	coinButton,
	TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ Position = Vector3.new(BALL_X, 6.9, BALL_Z) }
):Play()

---------------------------------------------------------------------
-- スポーン地点から台座までの石の道
---------------------------------------------------------------------
for z = -7.2, BALL_Z + 6.5, -2.2 do
	part({
		Size = Vector3.new(6, 0.2, 2),
		Position = Vector3.new(0, 0.1, z),
		Color = Color3.fromRGB(170, 160, 150),
		Material = Enum.Material.Slate,
	})
end

---------------------------------------------------------------------
-- ランキング看板の柱と屋根
---------------------------------------------------------------------
local board = Workspace:WaitForChild("RankingBoard")
local WOOD = Color3.fromRGB(110, 75, 45)

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
	Color = GOLD,
	Material = Enum.Material.Metal,
})

---------------------------------------------------------------------
-- 景色: 木・岩・花（毎回同じ配置になるよう種を固定）
---------------------------------------------------------------------
local rng = Random.new(2026)

local function randomSpot(minRadius, maxRadius)
	local angle = rng:NextNumber(0, math.pi * 2)
	local radius = rng:NextNumber(minRadius, maxRadius)
	return Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

local LEAF_COLORS = {
	Color3.fromRGB(75, 150, 70),
	Color3.fromRGB(95, 170, 80),
	Color3.fromRGB(60, 130, 65),
}

for _ = 1, 40 do
	local spot = randomSpot(45, 170)
	local scale = rng:NextNumber(0.8, 1.5)
	local leafColor = LEAF_COLORS[rng:NextInteger(1, #LEAF_COLORS)]

	part({
		Size = Vector3.new(1.4, 7, 1.4) * scale,
		Position = spot + Vector3.new(0, 3.5 * scale, 0),
		Color = WOOD,
		Material = Enum.Material.Wood,
	})
	part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(8, 8, 8) * scale,
		Position = spot + Vector3.new(0, 8 * scale, 0),
		Color = leafColor,
		Material = Enum.Material.Grass,
	})
	part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(5, 5, 5) * scale,
		Position = spot + Vector3.new(1.5, 11 * scale, 1),
		Color = leafColor,
		Material = Enum.Material.Grass,
	})
end

for _ = 1, 20 do
	local spot = randomSpot(30, 160)
	local size = rng:NextNumber(2, 5)
	part({
		Size = Vector3.new(size * 1.3, size, size),
		CFrame = CFrame.new(spot + Vector3.new(0, size * 0.3, 0))
			* CFrame.Angles(rng:NextNumber(0, 0.5), rng:NextNumber(0, math.pi), rng:NextNumber(0, 0.5)),
		Color = Color3.fromRGB(130, 130, 135),
		Material = Enum.Material.Slate,
	})
end

local FLOWER_COLORS = {
	Color3.fromRGB(255, 120, 170),
	Color3.fromRGB(255, 230, 90),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(180, 140, 255),
}

-- 台座と道の上には置かない
local function isClear(spot)
	local nearPedestal = (spot - center).Magnitude < 9
	local onPath = math.abs(spot.X) < 4 and spot.Z < 0 and spot.Z > BALL_Z
	return not nearPedestal and not onPath
end

local flowers = 0
while flowers < 80 do
	local spot = randomSpot(14, 70)
	if isClear(spot) then
		flowers = flowers + 1
		part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.7, 0.7, 0.7),
			Position = spot + Vector3.new(0, 0.35, 0),
			Color = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)],
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
	end
end
