--!strict
-- نظام البيع بالروبلوكس (Developer Products)
-- حزم العملات + الحيوانات المميزة
--
-- ⚠️ الإعداد المطلوب:
-- 1) افتح creator.roblox.com ← تجربتك ← Monetization ← Developer Products
-- 2) أنشئ منتجًا لكل حزمة عملات ولكل حيوان مميز وحدد سعره بالروبلوكس
-- 3) انسخ رقم كل منتج (Product ID) وضعه في GameConfig:
--    - CoinPacks[n].ProductId
--    - Animals.GoldenChicken.ProductId وهكذا

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local DataManager = require(script.Parent:WaitForChild("DataManager"))
local AnimalSystem = require(script.Parent:WaitForChild("AnimalSystem"))

local MonetizationSystem = {}

-- handlers[productId] = دالة المنح، ترجع false إذا يجب إعادة المحاولة لاحقًا
local handlers: { [number]: (Player) -> boolean } = {}

-- منع تكرار المنح لنفس عملية الشراء في هذه الجلسة
local processedReceipts: { [string]: boolean } = {}

local function buildHandlers()
	-- حزم العملات
	for _, pack in ipairs(GameConfig.CoinPacks) do
		if pack.ProductId and pack.ProductId > 0 then
			handlers[pack.ProductId] = function(player)
				DataManager.addMoney(player, pack.Coins)
				DataManager.notify(player, "شكرًا لدعمك! حصلت على +" .. pack.Coins .. " 💰")
				return true
			end
		end
	end

	-- الحيوانات المميزة
	for animalType, info in pairs(GameConfig.Animals) do
		if info.Premium and info.ProductId and info.ProductId > 0 then
			handlers[info.ProductId] = function(player)
				return AnimalSystem.grantAnimal(player, animalType)
			end
		end
	end
end

function MonetizationSystem.init()
	buildHandlers()

	MarketplaceService.ProcessReceipt = function(receiptInfo)
		-- منع التكرار داخل نفس السيرفر
		if processedReceipts[receiptInfo.PurchaseId] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			-- اللاعب خرج: روبلوكس سيعيد المحاولة عند عودته
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if not DataManager.getData(player) then
			-- بياناته لم تُحمّل بعد
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local handler = handlers[receiptInfo.ProductId]
		if not handler then
			warn("[FAM Farm] منتج غير معروف: " .. receiptInfo.ProductId)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local ok, granted = pcall(handler, player)
		if ok and granted == true then
			processedReceipts[receiptInfo.PurchaseId] = true
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

return MonetizationSystem
