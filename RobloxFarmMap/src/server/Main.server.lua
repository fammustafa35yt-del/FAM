--!strict
-- نقطة تشغيل السيرفر: يبني الماب ويشغّل كل الأنظمة بالترتيب

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- مجلد الريموتات المشتركة بين السيرفر والعميل
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"

local dataChanged = Instance.new("RemoteEvent")
dataChanged.Name = "DataChanged"
dataChanged.Parent = remotes

local notify = Instance.new("RemoteEvent")
notify.Name = "Notify"
notify.Parent = remotes

remotes.Parent = ReplicatedStorage

local DataManager = require(script.Parent:WaitForChild("DataManager"))
local MapBuilder = require(script.Parent:WaitForChild("MapBuilder"))
local SeasonSystem = require(script.Parent:WaitForChild("SeasonSystem"))
local FarmingSystem = require(script.Parent:WaitForChild("FarmingSystem"))
local AnimalSystem = require(script.Parent:WaitForChild("AnimalSystem"))
local PlotManager = require(script.Parent:WaitForChild("PlotManager"))
local ShopSystem = require(script.Parent:WaitForChild("ShopSystem"))
local JobSystem = require(script.Parent:WaitForChild("JobSystem"))
local TradeSystem = require(script.Parent:WaitForChild("TradeSystem"))
local MarketSystem = require(script.Parent:WaitForChild("MarketSystem"))
local MonetizationSystem = require(script.Parent:WaitForChild("MonetizationSystem"))

DataManager.init(remotes)

local map = MapBuilder.build()

SeasonSystem.init(remotes)
FarmingSystem.init(remotes)
AnimalSystem.init()
PlotManager.init(map.Plots)
ShopSystem.init(remotes, map.ShopPrompt)
JobSystem.init(map.JobCenter)
TradeSystem.init(remotes)
MarketSystem.init(remotes, map.MarketPrompt)
MonetizationSystem.init()

print("[FAM Farm] الماب جاهز! ✅")
