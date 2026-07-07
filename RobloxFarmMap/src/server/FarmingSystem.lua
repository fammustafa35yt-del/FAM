--!strict
-- نظام الزراعة: التربة، الزراعة، النمو، السقي، السماد، والحصاد

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local DataManager = require(script.Parent:WaitForChild("DataManager"))

local FarmingSystem = {}

-- حالة كل قطعة تربة
-- soils[soilPart] = {
--   ownerUserId, state ("Empty"|"Growing"|"Ready"),
--   crop, endTime, totalTime, watered, plantPart, prompt, waterPrompt
-- }
local soils: { [BasePart]: any } = {}

local EMPTY_COLOR = Color3.fromRGB(110, 80, 55)

local function setPromptForState(soil: BasePart)
	local state = soils[soil]
	if not state then
		return
	end
	local prompt: ProximityPrompt = state.prompt
	local waterPrompt: ProximityPrompt = state.waterPrompt

	if state.state == "Empty" then
		prompt.ActionText = "ازرع البذرة المحددة"
		prompt.ObjectText = "تربة فارغة"
		prompt.Enabled = true
		waterPrompt.Enabled = false
	elseif state.state == "Growing" then
		prompt.Enabled = false
		waterPrompt.Enabled = true
	elseif state.state == "Ready" then
		prompt.ActionText = "احصد 🌾"
		prompt.ObjectText = GameConfig.Crops[state.crop].DisplayName
		prompt.Enabled = true
		waterPrompt.Enabled = false
	end
end

local function clearPlant(soil: BasePart)
	local state = soils[soil]
	if state.plantPart then
		state.plantPart:Destroy()
		state.plantPart = nil
	end
	state.state = "Empty"
	state.crop = nil
	state.watered = false
	soil.Color = EMPTY_COLOR
	setPromptForState(soil)
end

local function updatePlantVisual(soil: BasePart)
	local state = soils[soil]
	if not state or state.state == "Empty" then
		return
	end

	local cropInfo = GameConfig.Crops[state.crop]
	local progress = 1 - math.max(0, state.endTime - os.clock()) / state.totalTime
	progress = math.clamp(progress, 0.08, 1)

	if not state.plantPart then
		local plant = Instance.new("Part")
		plant.Anchored = true
		plant.CanCollide = false
		plant.Material = Enum.Material.Grass
		plant.Parent = soil.Parent
		state.plantPart = plant
	end

	local plant: Part = state.plantPart
	local maxHeight = 3.2
	local height = maxHeight * progress
	plant.Size = Vector3.new(1.4 * progress + 0.4, height, 1.4 * progress + 0.4)
	plant.Position = soil.Position + Vector3.new(0, soil.Size.Y / 2 + height / 2, 0)

	if state.state == "Ready" then
		plant.Color = cropInfo.Color
		plant.Material = Enum.Material.Neon
	else
		plant.Color = Color3.fromRGB(70, 140, 60)
		plant.Material = Enum.Material.Grass
	end
end

local function plantSeed(player: Player, soil: BasePart)
	local state = soils[soil]
	if not state or state.state ~= "Empty" then
		return
	end
	if state.ownerUserId ~= player.UserId then
		DataManager.notify(player, "هذه ليست مزرعتك!", true)
		return
	end

	local session = DataManager.getSession(player)
	local seedName = session and session.selectedSeed
	if not seedName or not GameConfig.Crops[seedName] then
		DataManager.notify(player, "اختر بذرة من الحقيبة أولًا 🎒", true)
		return
	end
	if not DataManager.tryRemoveItem(player, "Seeds", seedName, 1) then
		DataManager.notify(player, "لا تملك بذور " .. GameConfig.Crops[seedName].DisplayName, true)
		return
	end

	local growTime = GameConfig.Crops[seedName].GrowTime
	state.state = "Growing"
	state.crop = seedName
	state.totalTime = growTime
	state.endTime = os.clock() + growTime
	state.watered = false
	soil.Color = Color3.fromRGB(80, 58, 40) -- تربة مزروعة أغمق
	setPromptForState(soil)
	updatePlantVisual(soil)
	DataManager.notify(player, "زرعت " .. GameConfig.Crops[seedName].DisplayName .. " 🌱")
end

local function waterPlant(player: Player, soil: BasePart)
	local state = soils[soil]
	if not state or state.state ~= "Growing" then
		return
	end
	if state.ownerUserId ~= player.UserId then
		DataManager.notify(player, "هذه ليست مزرعتك!", true)
		return
	end

	-- السماد أولوية إن وُجد، وإلا رشاش الماء
	if DataManager.getItemCount(player, "Tools", "Fertilizer") > 0 then
		DataManager.tryRemoveItem(player, "Tools", "Fertilizer", 1)
		local remaining = math.max(0, state.endTime - os.clock())
		state.endTime = os.clock() + remaining * 0.25
		DataManager.notify(player, "استخدمت السماد! النمو تسارع 💩⚡")
	elseif DataManager.getItemCount(player, "Tools", "WateringCan") > 0 then
		if state.watered then
			DataManager.notify(player, "هذه النبتة مسقية بالفعل 💧", true)
			return
		end
		state.watered = true
		local remaining = math.max(0, state.endTime - os.clock())
		state.endTime = os.clock() + remaining * 0.5
		DataManager.notify(player, "سقيت النبتة! وقت النمو انخفض للنصف 🚿")
	else
		DataManager.notify(player, "تحتاج رشاش ماء أو سماد من المتجر", true)
	end
end

local function harvest(player: Player, soil: BasePart)
	local state = soils[soil]
	if not state or state.state ~= "Ready" then
		return
	end
	if state.ownerUserId ~= player.UserId then
		DataManager.notify(player, "هذه ليست مزرعتك!", true)
		return
	end

	local cropName = state.crop
	local amount = math.random(1, 2)
	if DataManager.getItemCount(player, "Tools", "GoldenScythe") > 0 then
		amount *= 2
	end

	DataManager.addItem(player, "Crops", cropName, amount)
	DataManager.notify(player, "حصدت " .. amount .. "x " .. GameConfig.Crops[cropName].DisplayName .. " ✅")
	clearPlant(soil)
end

-- إنشاء قطع التربة داخل أرض مزرعة تم شراؤها
function FarmingSystem.setupFarm(base: BasePart, ownerUserId: number)
	local rows = GameConfig.FarmPlot.SoilRows
	local cols = GameConfig.FarmPlot.SoilCols
	local size = GameConfig.FarmPlot.Size
	local patch = 6 -- حجم قطعة التربة

	local spacingX = size / cols
	local spacingZ = size / rows

	for r = 1, rows do
		for c = 1, cols do
			local soil = Instance.new("Part")
			soil.Name = "Soil"
			soil.Anchored = true
			soil.Size = Vector3.new(patch, 0.6, patch)
			soil.Position = base.Position + Vector3.new(
				-size / 2 + spacingX * (c - 0.5),
				base.Size.Y / 2 + 0.3,
				-size / 2 + spacingZ * (r - 0.5)
			)
			soil.Material = Enum.Material.Mud
			soil.Color = EMPTY_COLOR
			soil.Parent = base.Parent

			local prompt = Instance.new("ProximityPrompt")
			prompt.HoldDuration = 0.3
			prompt.MaxActivationDistance = 8
			prompt.RequiresLineOfSight = false
			prompt.Parent = soil

			local waterPrompt = Instance.new("ProximityPrompt")
			waterPrompt.ActionText = "اسقِ / سمّد"
			waterPrompt.ObjectText = "نبتة تنمو"
			waterPrompt.KeyboardKeyCode = Enum.KeyCode.F
			waterPrompt.HoldDuration = 0.3
			waterPrompt.MaxActivationDistance = 8
			waterPrompt.RequiresLineOfSight = false
			waterPrompt.Enabled = false
			waterPrompt.Parent = soil

			soils[soil] = {
				ownerUserId = ownerUserId,
				state = "Empty",
				prompt = prompt,
				waterPrompt = waterPrompt,
			}
			setPromptForState(soil)

			prompt.Triggered:Connect(function(player)
				local state = soils[soil]
				if not state then
					return
				end
				if state.state == "Empty" then
					plantSeed(player, soil)
				elseif state.state == "Ready" then
					harvest(player, soil)
				end
			end)

			waterPrompt.Triggered:Connect(function(player)
				waterPlant(player, soil)
			end)
		end
	end
end

function FarmingSystem.init(remotes: Folder)
	-- استقبال اختيار البذرة من واجهة اللاعب
	local selectSeed = Instance.new("RemoteEvent")
	selectSeed.Name = "SelectSeed"
	selectSeed.Parent = remotes
	selectSeed.OnServerEvent:Connect(function(player, seedName)
		if typeof(seedName) ~= "string" or not GameConfig.Crops[seedName] then
			return
		end
		local session = DataManager.getSession(player)
		if session then
			session.selectedSeed = seedName
			DataManager.pushUpdate(player)
			DataManager.notify(player, "تم اختيار بذور " .. GameConfig.Crops[seedName].DisplayName)
		end
	end)

	-- حلقة تحديث النمو
	task.spawn(function()
		while true do
			task.wait(1)
			for soil, state in pairs(soils) do
				if not soil.Parent then
					soils[soil] = nil
				elseif state.state == "Growing" then
					if os.clock() >= state.endTime then
						state.state = "Ready"
						setPromptForState(soil)
					end
					updatePlantVisual(soil)
				end
			end
		end
	end)
end

return FarmingSystem
