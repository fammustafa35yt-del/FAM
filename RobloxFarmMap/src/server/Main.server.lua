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
local FarmingSystem = require(script.Parent:WaitForChild("FarmingSystem"))
local PlotManager = require(script.Parent:WaitForChild("PlotManager"))
local ShopSystem = require(script.Parent:WaitForChild("ShopSystem"))
local JobSystem = require(script.Parent:WaitForChild("JobSystem"))
local TradeSystem = require(script.Parent:WaitForChild("TradeSystem"))

DataManager.init(remotes)

local map = MapBuilder.build()

FarmingSystem.init(remotes)
PlotManager.init(map.Plots)
ShopSystem.init(remotes, map.ShopPrompt)
JobSystem.init(map.JobCenter)
TradeSystem.init(remotes)

print("[FAM Farm] الماب جاهز! ✅")
