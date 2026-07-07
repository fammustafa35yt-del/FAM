--!strict
-- بناء الماب برمجيًا: الأرضية، الساحة، الطرق، المتجر، مركز الوظائف، وقواعد الأراضي
-- لا تحتاج لبناء أي شيء يدويًا في ستوديو

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local MapBuilder = {}

local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		(part :: any)[key] = value
	end
	return part
end

-- لافتة نصية فوق أو على جزء
function MapBuilder.makeSign(parent: Instance, adornee: BasePart, text: string, textColor: Color3?)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 70)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 90
	gui.Adornee = adornee
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
	return label
end

local function buildShop(root: Folder)
	local shop = Instance.new("Model")
	shop.Name = "Shop"
	shop.Parent = root

	local floor = makePart({
		Name = "Floor",
		Size = Vector3.new(30, 1, 22),
		Position = Vector3.new(0, 0.5, -60),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(160, 120, 80),
		Parent = shop,
	})

	-- جدران بسيطة (الجدار الأمامي مفتوح كمدخل)
	local wallColor = Color3.fromRGB(220, 200, 160)
	makePart({ Size = Vector3.new(30, 10, 1), Position = Vector3.new(0, 6, -71), Color = wallColor, Material = Enum.Material.Brick, Parent = shop })
	makePart({ Size = Vector3.new(1, 10, 22), Position = Vector3.new(-15, 6, -60), Color = wallColor, Material = Enum.Material.Brick, Parent = shop })
	makePart({ Size = Vector3.new(1, 10, 22), Position = Vector3.new(15, 6, -60), Color = wallColor, Material = Enum.Material.Brick, Parent = shop })
	makePart({ Size = Vector3.new(32, 1, 24), Position = Vector3.new(0, 11.5, -60), Color = Color3.fromRGB(150, 60, 50), Material = Enum.Material.Slate, Parent = shop })

	-- طاولة البيع مع زر فتح المتجر
	local counter = makePart({
		Name = "Counter",
		Size = Vector3.new(10, 3.5, 3),
		Position = Vector3.new(0, 2.75, -65),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(120, 85, 55),
		Parent = shop,
	})
	MapBuilder.makeSign(shop, counter, "🏪 المتجر\nاضغط E للتسوق", Color3.fromRGB(255, 230, 130))

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "فتح المتجر"
	prompt.ObjectText = "المتجر"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	return prompt
end

local function buildJobCenter(root: Folder): Model
	local center = Instance.new("Model")
	center.Name = "JobCenter"
	center.Parent = root

	local floor = makePart({
		Name = "Floor",
		Size = Vector3.new(34, 1, 16),
		Position = Vector3.new(60, 0.5, 0),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(180, 180, 180),
		Parent = center,
	})
	MapBuilder.makeSign(center, floor, "🏢 مركز الوظائف\nاعمل واكسب المال!", Color3.fromRGB(140, 220, 255))

	-- منصة لكل وظيفة (JobSystem يضيف الأزرار عليها)
	local padColors = {
		Color3.fromRGB(120, 200, 90),
		Color3.fromRGB(240, 180, 60),
		Color3.fromRGB(90, 150, 240),
	}
	for index, job in ipairs(GameConfig.Jobs) do
		local pad = makePart({
			Name = "JobPad_" .. job.Id,
			Size = Vector3.new(8, 1.2, 8),
			Position = Vector3.new(60 + (index - 2) * 11, 1.6, 0),
			Material = Enum.Material.Neon,
			Color = padColors[((index - 1) % #padColors) + 1],
			Parent = center,
		})
		MapBuilder.makeSign(center, pad, job.DisplayName .. "\n💰 " .. job.Wage .. " لكل مهمة")
	end

	-- نقطة تسليم الطرود لوظيفة التوصيل (بعيدة عن المركز)
	local dropoff = makePart({
		Name = "DeliveryDropoff",
		Size = Vector3.new(8, 1.2, 8),
		Position = Vector3.new(-60, 1.6, 60),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(240, 100, 100),
		Parent = center,
	})
	MapBuilder.makeSign(center, dropoff, "📦 نقطة تسليم الطرود")

	return center
end

-- إنشاء قواعد الأراضي (مزارع وبيوت) وإرجاع قائمة بها لـ PlotManager
local function buildPlots(root: Folder)
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = root

	local plots = {}

	-- أراضي المزارع: صفان على الجهة الغربية
	local farmSize = GameConfig.FarmPlot.Size
	for i = 1, GameConfig.FarmPlot.Count do
		local row = math.ceil(i / 4)
		local col = ((i - 1) % 4) + 1
		local position = Vector3.new(
			-140 + (row - 1) * (farmSize + 14),
			0.55,
			-70 + (col - 1) * (farmSize + 10)
		)
		local base = makePart({
			Name = "Farm" .. i,
			Size = Vector3.new(farmSize, 1.1, farmSize),
			Position = position,
			Material = Enum.Material.Ground,
			Color = Color3.fromRGB(130, 100, 70),
			Parent = plotsFolder,
		})
		table.insert(plots, { Id = "Farm" .. i, Kind = "Farm", Base = base })
	end

	-- أراضي البيوت: صف على الجهة الشمالية
	local houseSize = GameConfig.HousePlot.Size
	for i = 1, GameConfig.HousePlot.Count do
		local position = Vector3.new(
			-105 + (i - 1) * (houseSize + 10),
			0.55,
			120
		)
		local base = makePart({
			Name = "House" .. i,
			Size = Vector3.new(houseSize, 1.1, houseSize),
			Position = position,
			Material = Enum.Material.Grass,
			Color = Color3.fromRGB(106, 170, 90),
			Parent = plotsFolder,
		})
		table.insert(plots, { Id = "House" .. i, Kind = "House", Base = base })
	end

	return plots
end

-- بناء بيت بسيط فوق أرض البيت عند شرائها
function MapBuilder.buildHouse(base: BasePart, ownerName: string)
	local house = Instance.new("Model")
	house.Name = "HouseBuilding"

	local center = base.Position + Vector3.new(0, 0.55, 0)
	local wallColor = Color3.fromRGB(235, 225, 200)

	-- أرضية البيت
	makePart({ Size = Vector3.new(20, 1, 20), Position = center + Vector3.new(0, 0.5, 0), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(170, 130, 90), Parent = house })
	-- جدران (فتحة باب في الجدار الأمامي)
	makePart({ Size = Vector3.new(20, 9, 1), Position = center + Vector3.new(0, 5.5, -9.5), Material = Enum.Material.Brick, Color = wallColor, Parent = house })
	makePart({ Size = Vector3.new(1, 9, 20), Position = center + Vector3.new(-9.5, 5.5, 0), Material = Enum.Material.Brick, Color = wallColor, Parent = house })
	makePart({ Size = Vector3.new(1, 9, 20), Position = center + Vector3.new(9.5, 5.5, 0), Material = Enum.Material.Brick, Color = wallColor, Parent = house })
	makePart({ Size = Vector3.new(7, 9, 1), Position = center + Vector3.new(-6.5, 5.5, 9.5), Material = Enum.Material.Brick, Color = wallColor, Parent = house })
	makePart({ Size = Vector3.new(7, 9, 1), Position = center + Vector3.new(6.5, 5.5, 9.5), Material = Enum.Material.Brick, Color = wallColor, Parent = house })
	makePart({ Size = Vector3.new(6, 2.5, 1), Position = center + Vector3.new(0, 8.75, 9.5), Material = Enum.Material.Brick, Color = wallColor, Parent = house })
	-- سقف
	local roof = makePart({ Size = Vector3.new(22, 1, 22), Position = center + Vector3.new(0, 10.5, 0), Material = Enum.Material.Slate, Color = Color3.fromRGB(155, 60, 50), Parent = house })

	MapBuilder.makeSign(house, roof, "🏠 بيت " .. ownerName, Color3.fromRGB(255, 210, 120))

	house.Parent = base.Parent
	return house
end

function MapBuilder.build()
	local root = Instance.new("Folder")
	root.Name = "FAMMap"
	root.Parent = workspace

	-- الأرضية الرئيسية
	makePart({
		Name = "Ground",
		Size = Vector3.new(520, 2, 520),
		Position = Vector3.new(0, -1, 0),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(96, 160, 84),
		Parent = root,
	})

	-- ساحة السباون
	makePart({
		Name = "Plaza",
		Size = Vector3.new(40, 0.4, 40),
		Position = Vector3.new(0, 0.2, 0),
		Material = Enum.Material.Cobblestone,
		Color = Color3.fromRGB(175, 165, 150),
		Parent = root,
	})

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Size = Vector3.new(8, 1, 8)
	spawnLocation.Position = Vector3.new(0, 0.9, 0)
	spawnLocation.Anchored = true
	spawnLocation.Neutral = true
	spawnLocation.Material = Enum.Material.Neon
	spawnLocation.Color = Color3.fromRGB(120, 220, 160)
	spawnLocation.TopSurface = Enum.SurfaceType.Smooth
	spawnLocation.Parent = root

	-- طرق تربط الساحة بالمناطق
	local roadColor = Color3.fromRGB(120, 115, 110)
	makePart({ Size = Vector3.new(200, 0.35, 10), Position = Vector3.new(-110, 0.2, 0), Material = Enum.Material.Asphalt, Color = roadColor, Parent = root }) -- إلى المزارع
	makePart({ Size = Vector3.new(10, 0.35, 110), Position = Vector3.new(0, 0.2, 65), Material = Enum.Material.Asphalt, Color = roadColor, Parent = root })  -- إلى البيوت
	makePart({ Size = Vector3.new(10, 0.35, 45), Position = Vector3.new(0, 0.2, -42), Material = Enum.Material.Asphalt, Color = roadColor, Parent = root }) -- إلى المتجر
	makePart({ Size = Vector3.new(45, 0.35, 10), Position = Vector3.new(42, 0.2, 0), Material = Enum.Material.Asphalt, Color = roadColor, Parent = root })  -- إلى الوظائف

	local shopPrompt = buildShop(root)
	local jobCenter = buildJobCenter(root)
	local plots = buildPlots(root)

	return {
		Root = root,
		ShopPrompt = shopPrompt,
		JobCenter = jobCenter,
		Plots = plots,
	}
end

return MapBuilder
