--!strict
-- نظام المتجر: شراء البذور والأدوات وبيع المحاصيل

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local DataManager = require(script.Parent:WaitForChild("DataManager"))

local ShopSystem = {}

function ShopSystem.init(remotes: Folder, shopPrompt: ProximityPrompt)
	local openShop = Instance.new("RemoteEvent")
	openShop.Name = "OpenShop"
	openShop.Parent = remotes

	local buyItem = Instance.new("RemoteEvent")
	buyItem.Name = "BuyItem"
	buyItem.Parent = remotes

	local sellCrop = Instance.new("RemoteEvent")
	sellCrop.Name = "SellCrop"
	sellCrop.Parent = remotes

	-- فتح واجهة المتجر عند الاقتراب من الطاولة
	shopPrompt.Triggered:Connect(function(player)
		openShop:FireClient(player)
	end)

	buyItem.OnServerEvent:Connect(function(player, category, itemName)
		if typeof(category) ~= "string" or typeof(itemName) ~= "string" then
			return
		end

		if category == "Seeds" then
			local crop = GameConfig.Crops[itemName]
			if not crop then
				return
			end
			if DataManager.trySpend(player, crop.SeedPrice) then
				DataManager.addItem(player, "Seeds", itemName, 1)
				DataManager.notify(player, "اشتريت بذور " .. crop.DisplayName)
			else
				DataManager.notify(player, "لا تملك مالًا كافيًا 💸", true)
			end
		elseif category == "Tools" then
			local tool = GameConfig.Tools[itemName]
			if not tool then
				return
			end
			-- الأدوات غير المستهلكة تُشترى مرة واحدة فقط
			if not tool.Consumable and DataManager.getItemCount(player, "Tools", itemName) > 0 then
				DataManager.notify(player, "تملك هذه الأداة بالفعل!", true)
				return
			end
			if DataManager.trySpend(player, tool.Price) then
				DataManager.addItem(player, "Tools", itemName, 1)
				DataManager.notify(player, "اشتريت " .. tool.DisplayName)
			else
				DataManager.notify(player, "لا تملك مالًا كافيًا 💸", true)
			end
		end
	end)

	sellCrop.OnServerEvent:Connect(function(player, cropName, amount)
		if typeof(cropName) ~= "string" then
			return
		end
		local crop = GameConfig.Crops[cropName]
		if not crop then
			return
		end

		local owned = DataManager.getItemCount(player, "Crops", cropName)
		local toSell
		if amount == "all" then
			toSell = owned
		else
			toSell = math.floor(tonumber(amount) or 1)
		end
		toSell = math.clamp(toSell, 0, owned)
		if toSell <= 0 then
			DataManager.notify(player, "لا تملك هذا المحصول للبيع", true)
			return
		end

		if DataManager.tryRemoveItem(player, "Crops", cropName, toSell) then
			local total = toSell * crop.SellPrice
			DataManager.addMoney(player, total)
			DataManager.notify(player, "بعت " .. toSell .. "x " .. crop.DisplayName .. " مقابل 💰 " .. total)
		end
	end)
end

return ShopSystem
