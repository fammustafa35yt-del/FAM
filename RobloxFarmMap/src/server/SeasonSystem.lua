--!strict
-- نظام المواسم: الربيع والصيف والخريف والشتاء
-- كل موسم يغيّر سرعة نمو المحاصيل، ولون الأرض، ويرفع سعر "محصول الموسم"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local SeasonSystem = {}

local currentIndex = 1
local seasonEndsAt = 0
local seasonChanged: RemoteEvent

function SeasonSystem.getSeason()
	return GameConfig.Seasons[currentIndex]
end

function SeasonSystem.getGrowthMultiplier(): number
	return SeasonSystem.getSeason().GrowthMultiplier
end

function SeasonSystem.isBonusCrop(cropName: string): boolean
	return SeasonSystem.getSeason().BonusCrop == cropName
end

local function seasonPayload()
	local season = SeasonSystem.getSeason()
	local bonusCrop = GameConfig.Crops[season.BonusCrop]
	return {
		Id = season.Id,
		DisplayName = season.DisplayName,
		SecondsLeft = math.max(0, seasonEndsAt - os.clock()),
		BonusCropName = bonusCrop and bonusCrop.DisplayName or "",
		GrowthMultiplier = season.GrowthMultiplier,
	}
end

local function applyVisuals()
	local season = SeasonSystem.getSeason()

	-- تلوين أرضية الماب حسب الموسم
	local map = workspace:FindFirstChild("FAMMap")
	local ground = map and map:FindFirstChild("Ground")
	if ground and ground:IsA("BasePart") then
		TweenService:Create(ground, TweenInfo.new(3), { Color = season.GroundColor }):Play()
	end

	-- إضاءة الشتاء أبرد قليلًا
	if season.Id == "Winter" then
		Lighting.OutdoorAmbient = Color3.fromRGB(150, 160, 180)
	else
		Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
	end
end

function SeasonSystem.init(remotes: Folder)
	seasonChanged = Instance.new("RemoteEvent")
	seasonChanged.Name = "SeasonChanged"
	seasonChanged.Parent = remotes

	-- إرسال الموسم الحالي لأي لاعب جديد
	Players.PlayerAdded:Connect(function(player)
		seasonChanged:FireClient(player, seasonPayload())
	end)

	task.spawn(function()
		while true do
			seasonEndsAt = os.clock() + GameConfig.SeasonLength
			applyVisuals()
			seasonChanged:FireAllClients(seasonPayload())
			task.wait(GameConfig.SeasonLength)
			currentIndex = (currentIndex % #GameConfig.Seasons) + 1
		end
	end)
end

return SeasonSystem
