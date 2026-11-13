-- リアルな木と岩: Creator Store のモデルを読み込んで並べる
-- 読み込めるのは「ゲームの持ち主が入手したモデル」だけ。読み込めないときは地形の木と岩で代わりに作る。
-- 安全のため、読み込んだモデルに入っているスクリプトはすべて消す。
local InsertService = game:GetService("InsertService")
local Workspace = game:GetService("Workspace")

local terrain = Workspace.Terrain

local TREE_ASSETS = { 3256343670, 9271152246 }
local ROCK_ASSETS = { 1192366796, 8442632450 }
local LAKE = Vector3.new(70, 0, 40)

local props = Instance.new("Folder")
props.Name = "Props"
props.Parent = Workspace

-- アセットを読み込んで、使えるモデルの一覧（パックなら中の1つ1つ）を返す
local function loadVariants(assetIds)
	local variants = {}
	for _, assetId in ipairs(assetIds) do
		local ok, container = pcall(function()
			return InsertService:LoadAsset(assetId)
		end)
		if ok and container then
			for _, object in ipairs(container:GetDescendants()) do
				if object:IsA("LuaSourceContainer") then
					object:Destroy()
				end
			end

			local root = container:GetChildren()[1]
			if root then
				local models = {}
				for _, child in ipairs(root:GetChildren()) do
					if child:IsA("Model") then
						table.insert(models, child)
					end
				end
				if root:IsA("Model") and #models >= 2 then
					for _, model in ipairs(models) do
						table.insert(variants, model)
					end
				elseif root:IsA("Model") then
					table.insert(variants, root)
				elseif root:IsA("BasePart") then
					local wrapper = Instance.new("Model")
					root.Parent = wrapper
					table.insert(variants, wrapper)
				end
			end
		else
			warn("[Props] could not load asset", assetId, "- using terrain instead")
		end
	end
	return variants
end

-- モデルを高さ targetHeight に合わせて、地面（高さ 0）に置く
local function place(template, spot, targetHeight, rng)
	local model = template:Clone()
	for _, object in ipairs(model:GetDescendants()) do
		if object:IsA("BasePart") then
			object.Anchored = true
		end
	end

	local _, size = model:GetBoundingBox()
	if size.Y > 0 then
		pcall(function()
			model:ScaleTo(model:GetScale() * (targetHeight / size.Y))
		end)
	end

	model:PivotTo(CFrame.new(model:GetPivot().Position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	local boxCFrame, boxSize = model:GetBoundingBox()
	local bottom = boxCFrame.Position.Y - boxSize.Y / 2
	model:PivotTo(model:GetPivot() + Vector3.new(spot.X - boxCFrame.Position.X, -0.4 - bottom, spot.Z - boxCFrame.Position.Z))
	model.Parent = props
end

local function randomSpot(rng, minRadius, maxRadius, avoidLakeBy)
	for _ = 1, 10 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(minRadius, maxRadius)
		local spot = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		if (spot - LAKE).Magnitude > avoidLakeBy then
			return spot
		end
	end
	return nil
end

---------------------------------------------------------------------
-- 木
---------------------------------------------------------------------
local treeRng = Random.new(2026)
local trees = loadVariants(TREE_ASSETS)

for _ = 1, 40 do
	local spot = randomSpot(treeRng, 45, 160, 34)
	if spot then
		if #trees > 0 then
			place(trees[treeRng:NextInteger(1, #trees)], spot, treeRng:NextNumber(18, 28), treeRng)
		else
			-- 代わり: 木の幹と地形の葉っぱ
			local height = treeRng:NextNumber(9, 15)
			local trunk = Instance.new("Part")
			trunk.Shape = Enum.PartType.Cylinder
			trunk.Anchored = true
			trunk.Size = Vector3.new(height, 1.6, 1.6)
			trunk.CFrame = CFrame.new(spot + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
			trunk.Color = Color3.fromRGB(95, 70, 50)
			trunk.Material = Enum.Material.Wood
			trunk.Parent = props
			local leaf = treeRng:NextNumber(5, 7.5)
			terrain:FillBall(spot + Vector3.new(0, height, 0), leaf, Enum.Material.LeafyGrass)
			terrain:FillBall(
				spot + Vector3.new(treeRng:NextNumber(-2, 2), height + leaf * 0.8, treeRng:NextNumber(-2, 2)),
				leaf * 0.7,
				Enum.Material.LeafyGrass
			)
		end
	end
end

---------------------------------------------------------------------
-- 岩
---------------------------------------------------------------------
local rockRng = Random.new(77)
local rocks = loadVariants(ROCK_ASSETS)

for _ = 1, 22 do
	local spot = randomSpot(rockRng, 30, 150, 30)
	if spot then
		if #rocks > 0 then
			place(rocks[rockRng:NextInteger(1, #rocks)], spot, rockRng:NextNumber(3, 7), rockRng)
		else
			terrain:FillBall(spot, rockRng:NextNumber(2, 4.5), Enum.Material.Rock)
		end
	end
end
