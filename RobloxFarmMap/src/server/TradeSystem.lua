--!strict
-- نظام المقايضة بين اللاعبين
-- كل لاعب يضيف أغراضًا (بذور/محاصيل/أدوات) ومالًا، وعند موافقة الطرفين يتم التبادل

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local DataManager = require(script.Parent:WaitForChild("DataManager"))

local TradeSystem = {}

local tradeEvent: RemoteEvent

-- طلبات معلقة: pendingRequests[targetPlayer] = requesterPlayer
local pendingRequests: { [Player]: Player } = {}

-- الصفقات النشطة: activeTrades[player] = trade
-- trade = { players = {p1, p2}, offers = { [player] = { items = { [category] = { [itemName] = count } }, money = 0, ready = false } } }
local activeTrades: { [Player]: any } = {}

local VALID_CATEGORIES = { Seeds = true, Crops = true, Tools = true, Products = true }

local function partnerOf(trade, player: Player): Player
	return trade.players[1] == player and trade.players[2] or trade.players[1]
end

local function serializeOffer(offer)
	return { items = offer.items, money = offer.money, ready = offer.ready }
end

-- إرسال حالة الصفقة الحالية للطرفين
local function broadcastUpdate(trade)
	for _, player in ipairs(trade.players) do
		local partner = partnerOf(trade, player)
		tradeEvent:FireClient(player, "update", {
			partnerName = partner.DisplayName,
			mine = serializeOffer(trade.offers[player]),
			theirs = serializeOffer(trade.offers[partner]),
		})
	end
end

local function closeTrade(trade, reason: string)
	for _, player in ipairs(trade.players) do
		activeTrades[player] = nil
		tradeEvent:FireClient(player, "closed", reason)
	end
end

-- التحقق من أن اللاعب يملك فعلًا كل ما عرضه
local function validateOffer(player: Player, offer): boolean
	if DataManager.getMoney(player) < offer.money then
		return false
	end
	for category, items in pairs(offer.items) do
		for itemName, count in pairs(items) do
			if DataManager.getItemCount(player, category, itemName) < count then
				return false
			end
		end
	end
	return true
end

local function executeTrade(trade)
	local p1, p2 = trade.players[1], trade.players[2]
	local offer1, offer2 = trade.offers[p1], trade.offers[p2]

	-- تحقق نهائي قبل التنفيذ (منع الغش/البيع أثناء الصفقة)
	if not validateOffer(p1, offer1) or not validateOffer(p2, offer2) then
		closeTrade(trade, "فشلت الصفقة: أحد الطرفين لا يملك ما عرضه!")
		return
	end

	local function transfer(from: Player, to: Player, offer)
		DataManager.addMoney(from, -offer.money)
		DataManager.addMoney(to, offer.money)
		for category, items in pairs(offer.items) do
			for itemName, count in pairs(items) do
				DataManager.tryRemoveItem(from, category, itemName, count)
				DataManager.addItem(to, category, itemName, count)
			end
		end
	end

	transfer(p1, p2, offer1)
	transfer(p2, p1, offer2)

	for _, player in ipairs(trade.players) do
		activeTrades[player] = nil
		tradeEvent:FireClient(player, "done")
		DataManager.notify(player, "تمت الصفقة بنجاح! 🤝")
	end
end

local function startTrade(p1: Player, p2: Player)
	local trade = {
		players = { p1, p2 },
		offers = {
			[p1] = { items = {}, money = 0, ready = false },
			[p2] = { items = {}, money = 0, ready = false },
		},
	}
	activeTrades[p1] = trade
	activeTrades[p2] = trade
	for _, player in ipairs(trade.players) do
		tradeEvent:FireClient(player, "start", partnerOf(trade, player).DisplayName)
	end
	broadcastUpdate(trade)
end

-- أي تعديل على العرض يلغي حالة "جاهز" للطرفين (حماية من التبديل الخادع)
local function resetReady(trade)
	for _, player in ipairs(trade.players) do
		trade.offers[player].ready = false
	end
end

local handlers: { [string]: (Player, ...any) -> () } = {}

-- طلب صفقة من لاعب آخر
handlers.request = function(player, targetUserId)
	if activeTrades[player] then
		return
	end
	local target = Players:GetPlayerByUserId(tonumber(targetUserId) or 0)
	if not target or target == player then
		return
	end
	if activeTrades[target] then
		DataManager.notify(player, target.DisplayName .. " مشغول بصفقة أخرى", true)
		return
	end
	pendingRequests[target] = player
	tradeEvent:FireClient(target, "incoming", player.DisplayName, player.UserId)
	DataManager.notify(player, "أرسلت طلب مقايضة إلى " .. target.DisplayName .. " ⏳")
end

-- الرد على طلب صفقة
handlers.respond = function(player, requesterUserId, accepted)
	local requester = pendingRequests[player]
	if not requester or requester.UserId ~= tonumber(requesterUserId) then
		return
	end
	pendingRequests[player] = nil
	if not requester.Parent then
		return -- الطالب خرج من اللعبة
	end
	if accepted == true then
		if activeTrades[player] or activeTrades[requester] then
			return
		end
		startTrade(requester, player)
	else
		DataManager.notify(requester, player.DisplayName .. " رفض طلب المقايضة", true)
	end
end

-- إضافة غرض للعرض
handlers.add = function(player, category, itemName)
	local trade = activeTrades[player]
	if not trade then
		return
	end
	if typeof(category) ~= "string" or typeof(itemName) ~= "string" or not VALID_CATEGORIES[category] then
		return
	end

	local offer = trade.offers[player]
	local items = offer.items
	items[category] = items[category] or {}
	local newCount = (items[category][itemName] or 0) + 1

	if DataManager.getItemCount(player, category, itemName) < newCount then
		DataManager.notify(player, "لا تملك المزيد من هذا الغرض", true)
		return
	end

	items[category][itemName] = newCount
	resetReady(trade)
	broadcastUpdate(trade)
end

-- إزالة غرض من العرض
handlers.remove = function(player, category, itemName)
	local trade = activeTrades[player]
	if not trade then
		return
	end
	if typeof(category) ~= "string" or typeof(itemName) ~= "string" then
		return
	end

	local offer = trade.offers[player]
	local bucket = offer.items[category]
	if not bucket or not bucket[itemName] then
		return
	end
	bucket[itemName] -= 1
	if bucket[itemName] <= 0 then
		bucket[itemName] = nil
	end
	resetReady(trade)
	broadcastUpdate(trade)
end

-- تحديد مبلغ المال في العرض
handlers.money = function(player, amount)
	local trade = activeTrades[player]
	if not trade then
		return
	end
	local money = math.floor(tonumber(amount) or 0)
	money = math.clamp(money, 0, math.min(DataManager.getMoney(player), GameConfig.MaxTradeMoney))
	trade.offers[player].money = money
	resetReady(trade)
	broadcastUpdate(trade)
end

-- تبديل حالة "جاهز"، وعند جاهزية الطرفين تُنفذ الصفقة
handlers.ready = function(player, isReady)
	local trade = activeTrades[player]
	if not trade then
		return
	end
	trade.offers[player].ready = isReady == true

	local p1, p2 = trade.players[1], trade.players[2]
	if trade.offers[p1].ready and trade.offers[p2].ready then
		executeTrade(trade)
	else
		broadcastUpdate(trade)
	end
end

handlers.cancel = function(player)
	local trade = activeTrades[player]
	if trade then
		closeTrade(trade, "تم إلغاء الصفقة")
	end
end

function TradeSystem.init(remotes: Folder)
	tradeEvent = Instance.new("RemoteEvent")
	tradeEvent.Name = "TradeEvent"
	tradeEvent.Parent = remotes

	tradeEvent.OnServerEvent:Connect(function(player, action, ...)
		local handler = typeof(action) == "string" and handlers[action]
		if handler then
			handler(player, ...)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		pendingRequests[player] = nil
		for target, requester in pairs(pendingRequests) do
			if requester == player then
				pendingRequests[target] = nil
			end
		end
		local trade = activeTrades[player]
		if trade then
			closeTrade(trade, "خرج اللاعب الآخر من اللعبة")
		end
	end)
end

return TradeSystem
