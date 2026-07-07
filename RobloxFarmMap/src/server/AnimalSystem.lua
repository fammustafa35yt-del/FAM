--!strict
-- نظام حيوانات المزرعة: شراء الحيوانات، وضعها حول مزرعتك، وجمع منتجاتها

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local DataManager = require(script.Parent:WaitForChild("DataManager"))
local MapBuilder = require(script.Parent:WaitForChild("MapBuilder"))

local AnimalSystem = {}

-- مزرعة كل لاعب في هذا السيرفر: farms[player] = base
local farms: { [Player]: BasePart } = {}
-- الحيوانات الحية: spawned[player] = { {Model, Type, ReadyAt, Prompt, Sign} }
local spawned: { [Player]: { any } } = {}

local function slotPosition(base: BasePart, slot: number): Vector3
	-- الحيوانات تقف على العشب حول الأرض (8 مواقع: الجهات الأربع + الزوايا)
	local distance = base.Size.X / 2 + 3.5
	local offsets = {
		Vector3.new(0, 0, -distance),
		Vector3.new(0, 0, distance),
		Vector3.new(-distance, 0, 0),
		Vector3.new(distance, 0, 0),
		Vector3.new(-distance, 0, -distance),
		Vector3.new(distance, 0, -distance),
		Vector3.new(-distance, 0, distance),
		Vector3.new(distance, 0, distance),
	}
	local offset = offsets[((slot - 1) % 8) + 1]
	return Vector3.new(base.Position.X + offset.X, 0, base.Position.Z + offset.Z)
end

local function spawnAnimal(player: Player, animalType: string, slot: number)
	local base = farms[player]
	local info = GameConfig.Animals[animalType]
	if not base or not info then
		return
	end

	local groundPos = slotPosition(base, slot)
	local productInfo = GameConfig.AnimalProducts[info.Product]

	local model = Instance.new("Model")
	model.Name = animalType

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.Size = info.BodySize
	body.Position = groundPos + Vector3.new(0, info.BodySize.Y / 2 + 0.6, 0)
	body.Color = info.BodyColor
	-- الحيوانات المميزة تلمع ✨
	body.Material = info.Premium and Enum.Material.Neon or Enum.Material.SmoothPlastic
	body.Parent = model

	local headSize = info.BodySize * 0.45
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Anchored = true
	head.Size = headSize
	head.Position = body.Position + Vector3.new(0, info.BodySize.Y * 0.45, -(info.BodySize.Z / 2 + headSize.Z / 4))
	head.Color = info.HeadColor
	head.Material = Enum.Material.SmoothPlastic
	head.Parent = model

	-- أرجل بسيطة
	for _, legOffset in ipairs({
		Vector3.new(-info.BodySize.X / 2 + 0.3, 0, -info.BodySize.Z / 2 + 0.3),
		Vector3.new(info.BodySize.X / 2 - 0.3, 0, -info.BodySize.Z / 2 + 0.3),
		Vector3.new(-info.BodySize.X / 2 + 0.3, 0, info.BodySize.Z / 2 - 0.3),
		Vector3.new(info.BodySize.X / 2 - 0.3, 0, info.BodySize.Z / 2 - 0.3),
	}) do
		local leg = Instance.new("Part")
		leg.Anchored = true
		leg.Size = Vector3.new(0.5, 0.6, 0.5)
		leg.Position = groundPos + legOffset + Vector3.new(0, 0.3, 0)
		leg.Color = info.HeadColor
		leg.Material = Enum.Material.SmoothPlastic
		leg.Parent = model
	end

	local sign = MapBuilder.makeSign(model, body, info.DisplayName)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "اجمع " .. (productInfo and productInfo.DisplayName or "المنتج")
	prompt.ObjectText = info.DisplayName
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = body

	model.Parent = base.Parent

	local entry = {
		Model = model,
		Type = animalType,
		ReadyAt = os.clock() + info.ProduceTime,
		Prompt = prompt,
		Sign = sign,
	}
	spawned[player] = spawned[player] or {}
	table.insert(spawned[player], entry)

	prompt.Triggered:Connect(function(collector)
		if collector ~= player then
			DataManager.notify(collector, "هذا ليس حيوانك!", true)
			return
		end
		if os.clock() < entry.ReadyAt then
			return
		end
		entry.ReadyAt = os.clock() + info.ProduceTime
		prompt.Enabled = false
		DataManager.addItem(player, "Products", info.Product, 1)
		DataManager.notify(player, "جمعت " .. (productInfo and productInfo.DisplayName or info.Product) .. " ✅")
	end)
end

local function despawnAll(player: Player)
	local animals = spawned[player]
	if animals then
		for _, entry in ipairs(animals) do
			entry.Model:Destroy()
		end
	end
	spawned[player] = nil
end

-- يستدعيها PlotManager عند شراء/استعادة مزرعة: تسجيل الأرض وإحياء الحيوانات المحفوظة
function AnimalSystem.registerFarm(player: Player, base: BasePart)
	farms[player] = base
	despawnAll(player)
	local data = DataManager.getData(player)
	if data then
		for slot, animalType in ipairs(data.Animals) do
			spawnAnimal(player, animalType, slot)
		end
	end
end

-- يستدعيها ShopSystem عند شراء حيوان عادي بالعملات
function AnimalSystem.buyAnimal(player: Player, animalType: string)
	local info = GameConfig.Animals[animalType]
	if not info then
		return
	end
	if info.Premium then
		DataManager.notify(player, "هذا حيوان مميز ✨ — يُشترى بالروبلوكس من قسم 💎 في المتجر", true)
		return
	end
	if not farms[player] then
		DataManager.notify(player, "اشترِ مزرعة أولًا لتربية الحيوانات! 🌾", true)
		return
	end
	local data = DataManager.getData(player)
	if not data then
		return
	end
	-- الحد يُحسب على الحيوانات العادية فقط (المميزة لها حد إجمالي أعلى)
	local regularCount = 0
	for _, ownedType in ipairs(data.Animals) do
		local ownedInfo = GameConfig.Animals[ownedType]
		if ownedInfo and not ownedInfo.Premium then
			regularCount += 1
		end
	end
	if regularCount >= GameConfig.MaxAnimalsPerFarm then
		DataManager.notify(player, "وصلت لحد الحيوانات العادية (" .. GameConfig.MaxAnimalsPerFarm .. ")", true)
		return
	end
	if #data.Animals >= GameConfig.MaxAnimalsTotal then
		DataManager.notify(player, "مزرعتك ممتلئة! (الحد الأقصى " .. GameConfig.MaxAnimalsTotal .. " حيوانات)", true)
		return
	end
	if not DataManager.trySpend(player, info.Price) then
		DataManager.notify(player, "لا تملك مالًا كافيًا 💸", true)
		return
	end
	table.insert(data.Animals, animalType)
	spawnAnimal(player, animalType, #data.Animals)
	DataManager.pushUpdate(player)
	DataManager.notify(player, "اشتريت " .. info.DisplayName .. " — ستنتج قريبًا!")
end

-- منح حيوان (مميز عادةً) بعد شراء ناجح بالروبلوكس — يستدعيها MonetizationSystem
-- ترجع false إذا تعذر المنح الآن (ProcessReceipt سيعيد المحاولة لاحقًا فلا تضيع الأموال)
function AnimalSystem.grantAnimal(player: Player, animalType: string): boolean
	local info = GameConfig.Animals[animalType]
	if not info then
		return false
	end
	local data = DataManager.getData(player)
	if not data then
		return false
	end
	if #data.Animals >= GameConfig.MaxAnimalsTotal then
		DataManager.notify(player, "مزرعتك ممتلئة! أفسح مكانًا وسيصلك الحيوان تلقائيًا", true)
		return false
	end
	table.insert(data.Animals, animalType)
	if farms[player] then
		spawnAnimal(player, animalType, #data.Animals)
	else
		DataManager.notify(player, "سيظهر " .. info.DisplayName .. " فور امتلاكك مزرعة! 🌾")
	end
	DataManager.pushUpdate(player)
	DataManager.notify(player, "حصلت على " .. info.DisplayName .. " — مبروك! ✨")
	return true
end

function AnimalSystem.init()
	-- حلقة تحديث حالة الإنتاج واللافتات
	task.spawn(function()
		while true do
			task.wait(2)
			for player, animals in pairs(spawned) do
				for _, entry in ipairs(animals) do
					local info = GameConfig.Animals[entry.Type]
					local remaining = entry.ReadyAt - os.clock()
					if remaining <= 0 then
						entry.Prompt.Enabled = true
						entry.Sign.Text = info.DisplayName .. "\n✨ المنتج جاهز للجمع!"
					else
						entry.Sign.Text = info.DisplayName .. "\n⏳ " .. math.ceil(remaining) .. " ثانية"
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		despawnAll(player)
		farms[player] = nil
	end)
end

return AnimalSystem
