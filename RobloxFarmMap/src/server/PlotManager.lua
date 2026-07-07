--!strict
-- إدارة العقارات: شراء أراضي المزارع والبيوت واستعادتها عند العودة للسيرفر

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local DataManager = require(script.Parent:WaitForChild("DataManager"))
local FarmingSystem = require(script.Parent:WaitForChild("FarmingSystem"))
local MapBuilder = require(script.Parent:WaitForChild("MapBuilder"))
local AnimalSystem = require(script.Parent:WaitForChild("AnimalSystem"))

local PlotManager = {}

-- plotStates[plotId] = { Id, Kind, Base, OwnerUserId?, Prompt, SignLabel }
local plotStates: { [string]: any } = {}

local function priceFor(kind: string): number
	return kind == "Farm" and GameConfig.FarmPlot.Price or GameConfig.HousePlot.Price
end

local function labelFor(plot): string
	local kindName = plot.Kind == "Farm" and "🌾 مزرعة للبيع" or "🏠 بيت للبيع"
	if plot.OwnerUserId then
		local owner = Players:GetPlayerByUserId(plot.OwnerUserId)
		local ownerName = owner and owner.DisplayName or "مالك غائب"
		return (plot.Kind == "Farm" and "🌾 مزرعة " or "🏠 بيت ") .. ownerName
	end
	return kindName .. "\n💰 " .. priceFor(plot.Kind)
end

local function refreshSign(plot)
	plot.SignLabel.Text = labelFor(plot)
	plot.Prompt.Enabled = plot.OwnerUserId == nil
end

-- لافتة/عمود ترقية البيت أمام الأرض
local function updateUpgradePrompt(plot, level: number)
	local nextLevel = GameConfig.HouseLevels[level + 1]
	if nextLevel then
		plot.UpgradePrompt.Enabled = true
		plot.UpgradePrompt.ActionText = "تطوير البيت"
		plot.UpgradePrompt.ObjectText = nextLevel.Name .. " — 💰 " .. nextLevel.UpgradePrice
	else
		plot.UpgradePrompt.Enabled = false
	end
end

local function setupUpgradePost(player: Player, plot)
	if plot.UpgradePost then
		return
	end
	local base: BasePart = plot.Base
	local post = Instance.new("Part")
	post.Name = "UpgradePost"
	post.Anchored = true
	post.Size = Vector3.new(1.5, 4, 1.5)
	post.Position = base.Position + Vector3.new(base.Size.X / 2 - 2, 2.5, base.Size.Z / 2 + 2)
	post.Material = Enum.Material.Wood
	post.Color = Color3.fromRGB(120, 85, 55)
	post.Parent = base.Parent
	MapBuilder.makeSign(post, post, "⬆️ لوحة تطوير البيت")

	local prompt = Instance.new("ProximityPrompt")
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = post

	plot.UpgradePost = post
	plot.UpgradePrompt = prompt

	prompt.Triggered:Connect(function(byPlayer)
		if byPlayer.UserId ~= plot.OwnerUserId then
			DataManager.notify(byPlayer, "هذا ليس بيتك!", true)
			return
		end
		local data = DataManager.getData(byPlayer)
		if not data then
			return
		end
		local nextLevel = data.HouseLevel + 1
		local nextInfo = GameConfig.HouseLevels[nextLevel]
		if not nextInfo then
			return
		end
		if not DataManager.trySpend(byPlayer, nextInfo.UpgradePrice) then
			DataManager.notify(byPlayer, "لا تملك مالًا كافيًا للترقية (السعر: " .. nextInfo.UpgradePrice .. ") 💸", true)
			return
		end
		data.HouseLevel = nextLevel
		DataManager.pushUpdate(byPlayer)
		if plot.HouseModel then
			plot.HouseModel:Destroy()
		end
		plot.HouseModel = MapBuilder.buildHouse(plot.Base, byPlayer.DisplayName, nextLevel)
		updateUpgradePrompt(plot, nextLevel)
		DataManager.notify(byPlayer, "مبروك! تطور بيتك إلى " .. nextInfo.Name .. " — دخل الإيجار زاد! 🎉")
	end)
end

local function giveOwnership(player: Player, plot, announce: boolean)
	plot.OwnerUserId = player.UserId
	refreshSign(plot)

	if plot.Kind == "Farm" then
		plot.Base.Color = Color3.fromRGB(150, 111, 70)
		FarmingSystem.setupFarm(plot.Base, player.UserId)
		-- تسجيل المزرعة لنظام الحيوانات (يعيد إحياء الحيوانات المحفوظة)
		AnimalSystem.registerFarm(player, plot.Base)
	else
		local data = DataManager.getData(player)
		local level = (data and data.HouseLevel) or 1
		plot.HouseModel = MapBuilder.buildHouse(plot.Base, player.DisplayName, level)
		setupUpgradePost(player, plot)
		updateUpgradePrompt(plot, level)
	end

	if announce then
		DataManager.notify(player, "مبروك! أصبحت مالك " .. (plot.Kind == "Farm" and "المزرعة" or "البيت") .. " 🎉")
	end
end

local function tryPurchase(player: Player, plot)
	if plot.OwnerUserId then
		return
	end

	local data = DataManager.getData(player)
	if not data then
		return
	end

	-- حد أقصى: مزرعة واحدة وبيت واحد لكل لاعب (عدّل حسب رغبتك)
	local ownedList = plot.Kind == "Farm" and data.OwnedFarms or data.OwnedHouses
	if #ownedList >= 1 then
		DataManager.notify(player, "تملك واحدة بالفعل من هذا النوع!", true)
		return
	end

	local price = priceFor(plot.Kind)
	if not DataManager.trySpend(player, price) then
		DataManager.notify(player, "لا تملك مالًا كافيًا (السعر: " .. price .. ") 💸", true)
		return
	end

	table.insert(ownedList, plot.Id)
	DataManager.pushUpdate(player)
	giveOwnership(player, plot, true)
end

-- عند دخول لاعب سبق أن اشترى أرضًا: نعيد له نفس الأرض إن كانت متاحة
local function reclaimPlots(player: Player)
	local data = DataManager.getData(player)
	if not data then
		return
	end

	local function reclaimList(list: { string })
		for index, plotId in ipairs(list) do
			local plot = plotStates[plotId]
			if plot and plot.OwnerUserId == nil then
				giveOwnership(player, plot, false)
			elseif plot and plot.OwnerUserId ~= player.UserId then
				-- الأرض محجوزة في هذا السيرفر: نبحث عن بديل شاغر من نفس النوع
				for _, candidate in pairs(plotStates) do
					if candidate.Kind == plot.Kind and candidate.OwnerUserId == nil then
						list[index] = candidate.Id
						giveOwnership(player, candidate, false)
						break
					end
				end
			end
		end
	end

	reclaimList(data.OwnedFarms)
	reclaimList(data.OwnedHouses)
	DataManager.pushUpdate(player)
end

function PlotManager.init(plots: { any })
	for _, plotInfo in ipairs(plots) do
		local base: BasePart = plotInfo.Base

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "شراء"
		prompt.ObjectText = plotInfo.Kind == "Farm" and "أرض مزرعة" or "أرض بيت"
		prompt.HoldDuration = 1
		prompt.MaxActivationDistance = 15
		prompt.RequiresLineOfSight = false
		prompt.Parent = base

		local plot = {
			Id = plotInfo.Id,
			Kind = plotInfo.Kind,
			Base = base,
			OwnerUserId = nil,
			Prompt = prompt,
			SignLabel = MapBuilder.makeSign(base, base, ""),
		}
		plotStates[plotInfo.Id] = plot
		refreshSign(plot)

		prompt.Triggered:Connect(function(player)
			tryPurchase(player, plot)
		end)
	end

	-- استعادة الممتلكات بعد تحميل البيانات
	local function onPlayer(player: Player)
		task.spawn(function()
			-- ننتظر تحميل بيانات اللاعب
			local tries = 0
			while not DataManager.getData(player) and tries < 50 do
				task.wait(0.2)
				tries += 1
			end
			if DataManager.getData(player) then
				reclaimPlots(player)
			end
		end)
	end

	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end

	-- دخل الإيجار الدوري لأصحاب البيوت (يزيد مع مستوى البيت)
	task.spawn(function()
		while true do
			task.wait(GameConfig.HouseIncomeInterval)
			for _, plot in pairs(plotStates) do
				if plot.Kind == "House" and plot.OwnerUserId then
					local owner = Players:GetPlayerByUserId(plot.OwnerUserId)
					if owner then
						local data = DataManager.getData(owner)
						local level = (data and data.HouseLevel) or 1
						local levelInfo = GameConfig.HouseLevels[level]
						if levelInfo then
							DataManager.addMoney(owner, levelInfo.Income)
							DataManager.notify(owner, "🏠 دخل الإيجار: +" .. levelInfo.Income .. " 💰")
						end
					end
				end
			end
		end
	end)
end

return PlotManager
