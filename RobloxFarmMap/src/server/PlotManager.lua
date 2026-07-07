--!strict
-- إدارة العقارات: شراء أراضي المزارع والبيوت واستعادتها عند العودة للسيرفر

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local DataManager = require(script.Parent:WaitForChild("DataManager"))
local FarmingSystem = require(script.Parent:WaitForChild("FarmingSystem"))
local MapBuilder = require(script.Parent:WaitForChild("MapBuilder"))

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

local function giveOwnership(player: Player, plot, announce: boolean)
	plot.OwnerUserId = player.UserId
	refreshSign(plot)

	if plot.Kind == "Farm" then
		plot.Base.Color = Color3.fromRGB(150, 111, 70)
		FarmingSystem.setupFarm(plot.Base, player.UserId)
	else
		MapBuilder.buildHouse(plot.Base, player.DisplayName)
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
end

return PlotManager
