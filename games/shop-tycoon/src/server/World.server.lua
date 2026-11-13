-- Online Shop Tycoon: ワールド（モダンなオフィス・倉庫・ランキング看板・光）
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local world = Instance.new("Folder")
world.Name = "World"
world.Parent = Workspace

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = props.Parent or world
	return p
end

---------------------------------------------------------------------
-- 光（夜のネオンが映えるオフィス）
---------------------------------------------------------------------
Lighting.ClockTime = 19.5
Lighting.Brightness = 2
Lighting.Ambient = Color3.fromRGB(60, 55, 80)
Lighting.OutdoorAmbient = Color3.fromRGB(90, 85, 120)
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 1

local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.3
atmosphere.Color = Color3.fromRGB(120, 100, 170)
atmosphere.Decay = Color3.fromRGB(60, 50, 110)
atmosphere.Haze = 1.5
atmosphere.Glare = 0.2
atmosphere.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.8
bloom.Size = 30
bloom.Threshold = 0.9
bloom.Parent = Lighting

local color = Instance.new("ColorCorrectionEffect")
color.Saturation = 0.15
color.Contrast = 0.1
color.Parent = Lighting

---------------------------------------------------------------------
-- 地面と街
---------------------------------------------------------------------
part({
	Name = "Ground",
	Size = Vector3.new(400, 2, 400),
	Position = Vector3.new(0, -1, 0),
	Color = Color3.fromRGB(45, 45, 52),
	Material = Enum.Material.Asphalt,
})

local spawn = Instance.new("SpawnLocation")
spawn.Anchored = true
spawn.Size = Vector3.new(10, 1, 10)
spawn.Position = Vector3.new(0, 1.5, 18)
spawn.Material = Enum.Material.SmoothPlastic
spawn.Color = Color3.fromRGB(255, 255, 255)
spawn.Transparency = 0.6
spawn.Parent = world

-- 店の床とガラスの壁
local FLOOR = Color3.fromRGB(235, 232, 228)
part({ Size = Vector3.new(70, 1, 50), Position = Vector3.new(0, 0.5, 0), Color = FLOOR, Material = Enum.Material.Marble })

local glass = { Color = Color3.fromRGB(170, 200, 255), Material = Enum.Material.Glass, Transparency = 0.6 }
for _, wall in ipairs({
	{ Vector3.new(70, 16, 1), Vector3.new(0, 9, -25) },
	{ Vector3.new(1, 16, 50), Vector3.new(-35, 9, 0) },
	{ Vector3.new(1, 16, 50), Vector3.new(35, 9, 0) },
}) do
	part({
		Size = wall[1],
		Position = wall[2],
		Color = glass.Color,
		Material = glass.Material,
		Transparency = glass.Transparency,
	})
end
part({ Size = Vector3.new(72, 1, 52), Position = Vector3.new(0, 17.5, 0), Color = Color3.fromRGB(30, 30, 38), Material = Enum.Material.Concrete })

-- 天井のネオン
for x = -28, 28, 14 do
	local strip = part({
		Size = Vector3.new(10, 0.3, 1),
		Position = Vector3.new(x, 16.8, 0),
		Color = Color3.fromRGB(180, 120, 255),
		Material = Enum.Material.Neon,
	})
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Color = strip.Color
	light.Range = 18
	light.Brightness = 2
	light.Parent = strip
end

-- 机とパソコン（飾り）
local DESK = Color3.fromRGB(60, 50, 45)
for i, x in ipairs({ -20, -8, 4, 16 }) do
	part({ Size = Vector3.new(8, 0.6, 4), Position = Vector3.new(x, 4, -10), Color = DESK, Material = Enum.Material.Wood })
	part({ Size = Vector3.new(0.6, 3.5, 3.6), Position = Vector3.new(x - 3.6, 2, -10), Color = DESK, Material = Enum.Material.Wood })
	part({ Size = Vector3.new(0.6, 3.5, 3.6), Position = Vector3.new(x + 3.6, 2, -10), Color = DESK, Material = Enum.Material.Wood })
	local screen = part({
		Size = Vector3.new(4.5, 2.8, 0.3),
		CFrame = CFrame.new(x, 5.8, -11.2) * CFrame.Angles(math.rad(-8), 0, 0),
		Color = Color3.fromRGB(20, 20, 25),
		Material = Enum.Material.SmoothPlastic,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.LightInfluence = 0
	gui.Parent = screen
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundColor3 = Color3.fromHSV((i * 0.18) % 1, 0.6, 0.5)
	label.Text = "NEW ORDER!"
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = gui
end

-- 倉庫の段ボール
local boxRng = Random.new(5)
for _ = 1, 40 do
	local size = boxRng:NextNumber(1.6, 3)
	part({
		Size = Vector3.new(size, size * 0.8, size),
		CFrame = CFrame.new(boxRng:NextNumber(-32, -20), size * 0.4 + 1 + boxRng:NextInteger(0, 2) * size * 0.8, boxRng:NextNumber(4, 22))
			* CFrame.Angles(0, boxRng:NextNumber(0, math.pi), 0),
		Color = Color3.fromRGB(190, 145, 95),
		Material = Enum.Material.Cardboard,
	})
end

---------------------------------------------------------------------
-- ランキング看板（サーバーの Main が中身を書く）
---------------------------------------------------------------------
local board = part({
	Name = "RankingBoard",
	Size = Vector3.new(16, 12, 1),
	Position = Vector3.new(24, 7, -23.5),
	Color = Color3.fromRGB(25, 20, 40),
	Material = Enum.Material.SmoothPlastic,
})
local surface = Instance.new("SurfaceGui")
surface.Face = Enum.NormalId.Back
surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
surface.PixelsPerStud = 40
surface.LightInfluence = 0
surface.Parent = board
local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = surface

local title = Instance.new("TextLabel")
title.Name = "Title"
title.LayoutOrder = 0
title.Size = UDim2.new(1, 0, 0.14, 0)
title.BackgroundTransparency = 1
title.Text = "TOP SELLERS"
title.TextColor3 = Color3.fromRGB(255, 215, 80)
title.TextScaled = true
title.Font = Enum.Font.GothamBlack
title:SetAttribute("LocaleKey", "ranking_title")
title.Parent = surface

for rank = 1, 10 do
	local label = Instance.new("TextLabel")
	label.Name = "Rank" .. rank
	label.LayoutOrder = rank
	label.Size = UDim2.new(1, 0, 0.086, 0)
	label.BackgroundTransparency = 1
	label.Text = ""
	label.TextColor3 = rank <= 3 and Color3.fromRGB(255, 225, 120) or Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = surface
end

-- 看板（店の名前）
local sign = part({
	Size = Vector3.new(30, 5, 1),
	Position = Vector3.new(0, 21, -25),
	Color = Color3.fromRGB(20, 20, 30),
})
local signGui = Instance.new("SurfaceGui")
signGui.Face = Enum.NormalId.Back
signGui.LightInfluence = 0
signGui.Parent = sign
local signText = Instance.new("TextLabel")
signText.Size = UDim2.new(1, 0, 1, 0)
signText.BackgroundTransparency = 1
signText.Text = "ONLINE SHOP TYCOON"
signText.TextColor3 = Color3.fromRGB(255, 120, 220)
signText.TextScaled = true
signText.Font = Enum.Font.GothamBlack
signText.Parent = signGui
