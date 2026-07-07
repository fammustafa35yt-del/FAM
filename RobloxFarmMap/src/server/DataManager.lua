--!strict
-- إدارة بيانات اللاعبين: المال، الحقيبة، الممتلكات + الحفظ في DataStore

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local DataManager = {}

local STORE_NAME = "FAMFarm_v1"
local store = nil
pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
end)

-- بيانات الجلسة لكل لاعب
-- sessions[player] = { data = {...}, selectedSeed = string? }
local sessions: { [Player]: any } = {}

local remotes: Folder? = nil

local function defaultData()
	return {
		Money = GameConfig.StartingMoney,
		Inventory = {
			Seeds = {},    -- { Wheat = 3 }
			Crops = {},    -- { Wheat = 5 }
			Tools = {},    -- { WateringCan = 1 }
			Products = {}, -- { Egg = 4 } منتجات الحيوانات
		},
		OwnedFarms = {},  -- { "Farm1" }
		OwnedHouses = {}, -- { "House2" }
		Animals = {},     -- { "Chicken", "Cow" }
		HouseLevel = 1,   -- مستوى البيت الحالي
	}
end

-- دوال تُستدعى قبل حفظ بيانات اللاعب (مثل إرجاع أغراض السوق المحجوزة)
local beforeSaveHooks: { (Player) -> () } = {}

function DataManager.onBeforeSave(hook: (Player) -> ())
	table.insert(beforeSaveHooks, hook)
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

-- إرسال نسخة محدثة من البيانات لواجهة اللاعب
function DataManager.pushUpdate(player: Player)
	local session = sessions[player]
	if not session or not remotes then
		return
	end
	local dataChanged = remotes:FindFirstChild("DataChanged") :: RemoteEvent?
	if dataChanged then
		dataChanged:FireClient(player, {
			Money = session.data.Money,
			Inventory = session.data.Inventory,
			OwnedFarms = session.data.OwnedFarms,
			OwnedHouses = session.data.OwnedHouses,
			Animals = session.data.Animals,
			HouseLevel = session.data.HouseLevel,
			SelectedSeed = session.selectedSeed,
		})
	end
end

function DataManager.notify(player: Player, message: string, isError: boolean?)
	if not remotes then
		return
	end
	local notifyRemote = remotes:FindFirstChild("Notify") :: RemoteEvent?
	if notifyRemote then
		notifyRemote:FireClient(player, message, isError == true)
	end
end

function DataManager.getData(player: Player)
	local session = sessions[player]
	return session and session.data or nil
end

function DataManager.getSession(player: Player)
	return sessions[player]
end

function DataManager.getMoney(player: Player): number
	local data = DataManager.getData(player)
	return data and data.Money or 0
end

function DataManager.addMoney(player: Player, amount: number)
	local data = DataManager.getData(player)
	if not data then
		return
	end
	data.Money = math.max(0, math.floor(data.Money + amount))
	DataManager.pushUpdate(player)
end

-- يخصم المبلغ فقط إذا كان الرصيد كافيًا
function DataManager.trySpend(player: Player, amount: number): boolean
	local data = DataManager.getData(player)
	if not data or data.Money < amount then
		return false
	end
	data.Money -= amount
	DataManager.pushUpdate(player)
	return true
end

function DataManager.getItemCount(player: Player, category: string, itemName: string): number
	local data = DataManager.getData(player)
	if not data then
		return 0
	end
	local bucket = data.Inventory[category]
	return bucket and bucket[itemName] or 0
end

function DataManager.addItem(player: Player, category: string, itemName: string, amount: number)
	local data = DataManager.getData(player)
	if not data then
		return
	end
	local bucket = data.Inventory[category]
	if not bucket then
		return
	end
	bucket[itemName] = math.max(0, (bucket[itemName] or 0) + amount)
	if bucket[itemName] == 0 then
		bucket[itemName] = nil
	end
	DataManager.pushUpdate(player)
end

-- يزيل الكمية فقط إذا كانت متوفرة بالكامل
function DataManager.tryRemoveItem(player: Player, category: string, itemName: string, amount: number): boolean
	if DataManager.getItemCount(player, category, itemName) < amount then
		return false
	end
	DataManager.addItem(player, category, itemName, -amount)
	return true
end

local function load(player: Player)
	local data = defaultData()
	if store then
		local ok, saved = pcall(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok and typeof(saved) == "table" then
			-- دمج البيانات المحفوظة مع الافتراضية (لحماية التحديثات المستقبلية)
			for key, value in pairs(saved) do
				data[key] = value
			end
			data.Inventory = data.Inventory or {}
			data.Inventory.Seeds = data.Inventory.Seeds or {}
			data.Inventory.Crops = data.Inventory.Crops or {}
			data.Inventory.Tools = data.Inventory.Tools or {}
			data.Inventory.Products = data.Inventory.Products or {}
			data.OwnedFarms = data.OwnedFarms or {}
			data.OwnedHouses = data.OwnedHouses or {}
			data.Animals = data.Animals or {}
			data.HouseLevel = data.HouseLevel or 1
		end
	end
	sessions[player] = { data = data, selectedSeed = nil }
	DataManager.pushUpdate(player)
end

local function save(player: Player, isFinal: boolean?)
	local session = sessions[player]
	if not session then
		return
	end
	-- عند المغادرة فقط: إرجاع أي أغراض محجوزة (عروض السوق المركزي مثلًا)
	if isFinal then
		for _, hook in ipairs(beforeSaveHooks) do
			pcall(hook, player)
		end
	end
	if not store then
		return
	end
	pcall(function()
		store:SetAsync(keyFor(player), session.data)
	end)
end

function DataManager.init(remotesFolder: Folder)
	remotes = remotesFolder

	-- يطلبها العميل عند فتح الواجهة لأول مرة
	local requestData = Instance.new("RemoteEvent")
	requestData.Name = "RequestData"
	requestData.Parent = remotesFolder
	requestData.OnServerEvent:Connect(function(player)
		DataManager.pushUpdate(player)
	end)

	Players.PlayerAdded:Connect(load)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player, true)
		sessions[player] = nil
	end)

	-- حفظ الجميع عند إغلاق السيرفر
	game:BindToClose(function()
		if RunService:IsStudio() then
			task.wait(2)
		end
		for _, player in ipairs(Players:GetPlayers()) do
			save(player, true)
		end
	end)

	-- حفظ تلقائي كل دقيقتين
	task.spawn(function()
		while true do
			task.wait(120)
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(save, player)
			end
		end
	end)
end

return DataManager
