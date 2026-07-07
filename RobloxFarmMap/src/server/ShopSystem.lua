--!strict
-- نظام المتجر: شراء البذور والأدوات وبيع المحاصيل

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local DataManager = require(script.Parent:WaitForChild("DataManager"))
local SeasonSystem = require(script.Parent:WaitForChild("SeasonSystem"))
local AnimalSystem = require(script.Parent:WaitForChild("AnimalSystem"))

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
		elseif category == "Animals" then
			-- شراء حيوان: يتطلب امتلاك مزرعة، ويُوضع حولها تلقائيًا
			AnimalSystem.buyAnimal(player, itemName)
		end
	end)

	-- بيع المحاصيل ومنتجات الحيوانات (محصول الموسم يُباع بسعر أعلى!)
	sellCrop.OnServerEvent:Connect(function(player, itemName, amount)
		if typeof(itemName) ~= "string" then
			return
		end

		local category, info, unitPrice
		local crop = GameConfig.Crops[itemName]
		local product = GameConfig.AnimalProducts[itemName]
		if crop then
			category = "Crops"
			info = crop
			unitPrice = crop.SellPrice
			if SeasonSystem.isBonusCrop(itemName) then
				unitPrice = math.floor(unitPrice * GameConfig.SeasonBonusMultiplier)
			end
		elseif product then
			category = "Products"
			info = product
			unitPrice = product.SellPrice
		else
			return
		end

		local owned = DataManager.getItemCount(player, category, itemName)
		local toSell
		if amount == "all" then
			toSell = owned
		else
			toSell = math.floor(tonumber(amount) or 1)
		end
		toSell = math.clamp(toSell, 0, owned)
		if toSell <= 0 then
			DataManager.notify(player, "لا تملك هذا الغرض للبيع", true)
			return
		end

		if DataManager.tryRemoveItem(player, category, itemName, toSell) then
			local total = toSell * unitPrice
			DataManager.addMoney(player, total)
			local bonusText = (crop and SeasonSystem.isBonusCrop(itemName)) and " ⭐ (سعر الموسم!)" or ""
			DataManager.notify(player, "بعت " .. toSell .. "x " .. info.DisplayName .. " مقابل 💰 " .. total .. bonusText)
		end
	end)
end

return ShopSystem
