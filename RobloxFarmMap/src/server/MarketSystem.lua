--!strict
-- السوق المركزي: اعرض محاصيلك ومنتجاتك للبيع بسعرك، ويشتريها أي لاعب
-- الأغراض المعروضة تُحجز من حقيبتك، وتُعاد إليك عند الإلغاء أو الخروج

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local DataManager = require(script.Parent:WaitForChild("DataManager"))

local MarketSystem = {}

local marketEvent: RemoteEvent

-- listings[id] = { Id, Seller (Player), SellerName, Category, ItemName, Amount, Price }
local listings: { [number]: any } = {}
local nextId = 1

-- الفئات المسموح بيعها في السوق
local function itemInfo(category: string, itemName: string)
	if category == "Crops" then
		return GameConfig.Crops[itemName]
	elseif category == "Products" then
		return GameConfig.AnimalProducts[itemName]
	end
	return nil
end

local function serializeListings()
	local result = {}
	for _, listing in pairs(listings) do
		table.insert(result, {
			Id = listing.Id,
			SellerName = listing.SellerName,
			SellerUserId = listing.Seller.UserId,
			Category = listing.Category,
			ItemName = listing.ItemName,
			Amount = listing.Amount,
			Price = listing.Price,
		})
	end
	table.sort(result, function(a, b)
		return a.Id < b.Id
	end)
	return result
end

local function broadcast()
	marketEvent:FireAllClients("update", serializeListings())
end

local function listingsCountOf(player: Player): number
	local count = 0
	for _, listing in pairs(listings) do
		if listing.Seller == player then
			count += 1
		end
	end
	return count
end

-- إرجاع الأغراض المحجوزة للبائع وحذف العرض
-- (يعمل حتى أثناء خروج البائع — جلسة بياناته ما زالت موجودة قبل الحفظ)
local function cancelListing(listing, silent: boolean?)
	listings[listing.Id] = nil
	DataManager.addItem(listing.Seller, listing.Category, listing.ItemName, listing.Amount)
	if not silent and listing.Seller.Parent then
		DataManager.notify(listing.Seller, "أُلغي عرضك وأُعيدت الأغراض لحقيبتك")
	end
end

local handlers: { [string]: (Player, ...any) -> () } = {}

-- إنشاء عرض جديد
handlers.list = function(player, category, itemName, amount, price)
	if typeof(category) ~= "string" or typeof(itemName) ~= "string" then
		return
	end
	local info = itemInfo(category, itemName)
	if not info then
		return
	end

	local sellAmount = math.floor(tonumber(amount) or 0)
	local sellPrice = math.floor(tonumber(price) or 0)
	if sellAmount < 1 or sellPrice < 1 or sellPrice > GameConfig.Market.MaxPrice then
		DataManager.notify(player, "أدخل كمية وسعرًا صحيحين", true)
		return
	end
	if listingsCountOf(player) >= GameConfig.Market.MaxListingsPerPlayer then
		DataManager.notify(player, "وصلت للحد الأقصى من العروض (" .. GameConfig.Market.MaxListingsPerPlayer .. ")", true)
		return
	end
	-- حجز الأغراض من الحقيبة
	if not DataManager.tryRemoveItem(player, category, itemName, sellAmount) then
		DataManager.notify(player, "لا تملك هذه الكمية!", true)
		return
	end

	local listing = {
		Id = nextId,
		Seller = player,
		SellerName = player.DisplayName,
		Category = category,
		ItemName = itemName,
		Amount = sellAmount,
		Price = sellPrice,
	}
	nextId += 1
	listings[listing.Id] = listing
	DataManager.notify(player, "عرضت " .. sellAmount .. "x " .. info.DisplayName .. " بسعر 💰 " .. sellPrice)
	broadcast()
end

-- إلغاء عرض (للبائع فقط)
handlers.cancel = function(player, listingId)
	local listing = listings[tonumber(listingId) or 0]
	if listing and listing.Seller == player then
		cancelListing(listing)
		broadcast()
	end
end

-- شراء عرض
handlers.buy = function(player, listingId)
	local listing = listings[tonumber(listingId) or 0]
	if not listing then
		DataManager.notify(player, "هذا العرض لم يعد متاحًا", true)
		return
	end
	if listing.Seller == player then
		DataManager.notify(player, "لا يمكنك شراء عرضك! اضغط إلغاء لاسترجاعه", true)
		return
	end
	if not DataManager.trySpend(player, listing.Price) then
		DataManager.notify(player, "لا تملك مالًا كافيًا (السعر: " .. listing.Price .. ") 💸", true)
		return
	end

	listings[listing.Id] = nil
	DataManager.addItem(player, listing.Category, listing.ItemName, listing.Amount)

	local info = itemInfo(listing.Category, listing.ItemName)
	local itemDisplay = info and info.DisplayName or listing.ItemName
	DataManager.notify(player, "اشتريت " .. listing.Amount .. "x " .. itemDisplay .. " من " .. listing.SellerName .. " 🛒")

	if listing.Seller.Parent then
		DataManager.addMoney(listing.Seller, listing.Price)
		DataManager.notify(listing.Seller, "بيع عرضك! " .. listing.Amount .. "x " .. itemDisplay .. " مقابل 💰 " .. listing.Price)
	end
	broadcast()
end

handlers.refresh = function(player)
	marketEvent:FireClient(player, "update", serializeListings())
end

function MarketSystem.init(remotes: Folder, marketPrompt: ProximityPrompt)
	marketEvent = Instance.new("RemoteEvent")
	marketEvent.Name = "MarketEvent"
	marketEvent.Parent = remotes

	marketPrompt.Triggered:Connect(function(player)
		marketEvent:FireClient(player, "open", serializeListings())
	end)

	marketEvent.OnServerEvent:Connect(function(player, action, ...)
		local handler = typeof(action) == "string" and handlers[action]
		if handler then
			handler(player, ...)
		end
	end)

	-- عند خروج البائع: تُعاد أغراض عروضه لحقيبته قبل الحفظ النهائي
	DataManager.onBeforeSave(function(player)
		local changed = false
		for _, listing in pairs(listings) do
			if listing.Seller == player then
				cancelListing(listing, true)
				changed = true
			end
		end
		if changed then
			task.defer(broadcast)
		end
	end)

	-- إرسال العروض الحالية للاعبين الجدد
	Players.PlayerAdded:Connect(function(player)
		task.delay(3, function()
			if player.Parent then
				marketEvent:FireClient(player, "update", serializeListings())
			end
		end)
	end)
end

return MarketSystem
