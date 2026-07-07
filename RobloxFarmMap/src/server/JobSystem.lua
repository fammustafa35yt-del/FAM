--!strict
-- نظام الوظائف: اعمل على منصات الوظائف واكسب المال
-- وظيفة التوصيل: استلم الطرد من المنصة ووصله لنقطة التسليم

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local DataManager = require(script.Parent:WaitForChild("DataManager"))

local JobSystem = {}

-- آخر وقت عمل لكل لاعب لكل وظيفة: cooldowns[player][jobId] = time
local cooldowns: { [Player]: { [string]: number } } = {}
-- من يحمل طردًا حاليًا
local carryingPackage: { [Player]: boolean } = {}

local function onCooldown(player: Player, jobId: string, cooldown: number): number
	local playerCooldowns = cooldowns[player]
	if not playerCooldowns then
		return 0
	end
	local last = playerCooldowns[jobId]
	if not last then
		return 0
	end
	return math.max(0, cooldown - (os.clock() - last))
end

local function markWorked(player: Player, jobId: string)
	cooldowns[player] = cooldowns[player] or {}
	cooldowns[player][jobId] = os.clock()
end

local function attachPackage(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end

	local package = Instance.new("Part")
	package.Name = "DeliveryPackage"
	package.Size = Vector3.new(2, 2, 2)
	package.Material = Enum.Material.WoodPlanks
	package.Color = Color3.fromRGB(190, 140, 80)
	package.CanCollide = false
	package.Massless = true
	package.Parent = character

	local weld = Instance.new("Weld")
	weld.Part0 = head
	weld.Part1 = package
	weld.C0 = CFrame.new(0, 2.2, 0)
	weld.Parent = package
end

local function removePackage(player: Player)
	carryingPackage[player] = nil
	local character = player.Character
	if character then
		local package = character:FindFirstChild("DeliveryPackage")
		if package then
			package:Destroy()
		end
	end
end

function JobSystem.init(jobCenter: Model)
	for _, job in ipairs(GameConfig.Jobs) do
		local pad = jobCenter:FindFirstChild("JobPad_" .. job.Id) :: BasePart?
		if not pad then
			continue
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = job.IsDelivery and "استلام طرد" or "اعمل"
		prompt.ObjectText = job.DisplayName
		prompt.HoldDuration = job.Hold
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = pad

		prompt.Triggered:Connect(function(player)
			local remaining = onCooldown(player, job.Id, job.Cooldown)
			if remaining > 0 then
				DataManager.notify(player, "استرح قليلًا! متبقي " .. math.ceil(remaining) .. " ثانية ⏳", true)
				return
			end

			if job.IsDelivery then
				if carryingPackage[player] then
					DataManager.notify(player, "أنت تحمل طردًا بالفعل! وصله لنقطة التسليم الحمراء 📦", true)
					return
				end
				carryingPackage[player] = true
				attachPackage(player)
				DataManager.notify(player, "استلمت الطرد! وصله للنقطة الحمراء 📦➡️")
			else
				markWorked(player, job.Id)
				DataManager.addMoney(player, job.Wage)
				DataManager.notify(player, "أنهيت مهمة " .. job.DisplayName .. " وكسبت 💰 " .. job.Wage)
			end
		end)
	end

	-- نقطة تسليم الطرود
	local dropoff = jobCenter:FindFirstChild("DeliveryDropoff") :: BasePart?
	if dropoff then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "تسليم الطرد"
		prompt.ObjectText = "نقطة التسليم"
		prompt.HoldDuration = 1
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = dropoff

		local deliveryJob
		for _, job in ipairs(GameConfig.Jobs) do
			if job.IsDelivery then
				deliveryJob = job
				break
			end
		end

		prompt.Triggered:Connect(function(player)
			if not carryingPackage[player] then
				DataManager.notify(player, "لا تحمل أي طرد! استلم واحدًا من مركز الوظائف", true)
				return
			end
			removePackage(player)
			if deliveryJob then
				markWorked(player, deliveryJob.Id)
				DataManager.addMoney(player, deliveryJob.Wage)
				DataManager.notify(player, "تم التوصيل بنجاح! كسبت 💰 " .. deliveryJob.Wage)
			end
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
		carryingPackage[player] = nil
	end)

	-- إسقاط الطرد عند موت الشخصية
	Players.PlayerAdded:Connect(function(player)
		player.CharacterRemoving:Connect(function()
			carryingPackage[player] = nil
		end)
	end)
end

return JobSystem
