--!strict
-- واجهة المقايضة: اختيار لاعب، طلب صفقة، نافذة التبادل

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local tradeEvent = remotes:WaitForChild("TradeEvent") :: RemoteEvent
local dataChanged = remotes:WaitForChild("DataChanged") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local currentData: any = nil
dataChanged.OnClientEvent:Connect(function(data)
	currentData = data
end)

local function displayNameOf(category: string, itemName: string): string
	if category == "Crops" or category == "Seeds" then
		local crop = GameConfig.Crops[itemName]
		local base = crop and crop.DisplayName or itemName
		return category == "Seeds" and ("بذور " .. base) or base
	elseif category == "Products" then
		local product = GameConfig.AnimalProducts[itemName]
		return product and product.DisplayName or itemName
	end
	local tool = GameConfig.Tools[itemName]
	return tool and tool.DisplayName or itemName
end

-- ================= أدوات واجهة =================

local function corner(parent: Instance, radius: number?)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius or 10)
	ui.Parent = parent
end

local function makeButton(parent: Instance, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(120, 40)
	button.BackgroundColor3 = color
	button.Text = text
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.Parent = parent
	corner(button)
	return button
end

local function makeScrollList(parent: Instance): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.Parent = scroll
	return scroll
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FAMTradeUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- زر فتح قائمة اللاعبين (تحت أزرار الواجهة الرئيسية)
local tradeButton = makeButton(screenGui, "🤝 مقايضة", Color3.fromRGB(190, 120, 220))
tradeButton.Position = UDim2.new(0, 10, 0.5, 75)

-- ================= قائمة اللاعبين =================

local playerListFrame = Instance.new("Frame")
playerListFrame.Size = UDim2.fromOffset(300, 340)
playerListFrame.Position = UDim2.new(0, 145, 0.5, -170)
playerListFrame.BackgroundColor3 = Color3.fromRGB(35, 38, 46)
playerListFrame.Visible = false
playerListFrame.Parent = screenGui
corner(playerListFrame, 14)

local playerListTitle = Instance.new("TextLabel")
playerListTitle.Size = UDim2.new(1, 0, 0, 36)
playerListTitle.BackgroundTransparency = 1
playerListTitle.Text = "اختر لاعبًا للمقايضة"
playerListTitle.TextColor3 = Color3.new(1, 1, 1)
playerListTitle.TextScaled = true
playerListTitle.Font = Enum.Font.GothamBold
playerListTitle.Parent = playerListFrame

local playerListContent = Instance.new("Frame")
playerListContent.Size = UDim2.new(1, -16, 1, -46)
playerListContent.Position = UDim2.new(0, 8, 0, 40)
playerListContent.BackgroundTransparency = 1
playerListContent.Parent = playerListFrame
local playerListScroll = makeScrollList(playerListContent)

local function rebuildPlayerList()
	for _, child in ipairs(playerListScroll:GetChildren()) do
		if child:IsA("TextButton") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local anyone = false
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			anyone = true
			local entry = makeButton(playerListScroll, "🤝 " .. other.DisplayName, Color3.fromRGB(60, 65, 78))
			entry.Size = UDim2.new(1, -10, 0, 42)
			entry.MouseButton1Click:Connect(function()
				tradeEvent:FireServer("request", other.UserId)
				playerListFrame.Visible = false
			end)
		end
	end
	if not anyone then
		local none = Instance.new("TextLabel")
		none.Size = UDim2.new(1, -10, 0, 60)
		none.BackgroundTransparency = 1
		none.Text = "لا يوجد لاعبون آخرون في السيرفر"
		none.TextColor3 = Color3.fromRGB(200, 200, 200)
		none.TextScaled = true
		none.Font = Enum.Font.Gotham
		none.Parent = playerListScroll
	end
end

tradeButton.MouseButton1Click:Connect(function()
	playerListFrame.Visible = not playerListFrame.Visible
	if playerListFrame.Visible then
		rebuildPlayerList()
	end
end)

-- ================= نافذة طلب وارد =================

local requestFrame = Instance.new("Frame")
requestFrame.Size = UDim2.fromOffset(360, 140)
requestFrame.Position = UDim2.new(0.5, 0, 0, 120)
requestFrame.AnchorPoint = Vector2.new(0.5, 0)
requestFrame.BackgroundColor3 = Color3.fromRGB(35, 38, 46)
requestFrame.Visible = false
requestFrame.Parent = screenGui
corner(requestFrame, 14)

local requestLabel = Instance.new("TextLabel")
requestLabel.Size = UDim2.new(1, -16, 0, 60)
requestLabel.Position = UDim2.fromOffset(8, 8)
requestLabel.BackgroundTransparency = 1
requestLabel.Text = ""
requestLabel.TextColor3 = Color3.new(1, 1, 1)
requestLabel.TextScaled = true
requestLabel.TextWrapped = true
requestLabel.Font = Enum.Font.GothamBold
requestLabel.Parent = requestFrame

local acceptButton = makeButton(requestFrame, "✅ قبول", Color3.fromRGB(90, 170, 100))
acceptButton.Position = UDim2.new(0.5, -130, 1, -55)
local declineButton = makeButton(requestFrame, "❌ رفض", Color3.fromRGB(200, 70, 70))
declineButton.Position = UDim2.new(0.5, 10, 1, -55)

local pendingRequesterId: number? = nil

acceptButton.MouseButton1Click:Connect(function()
	if pendingRequesterId then
		tradeEvent:FireServer("respond", pendingRequesterId, true)
		pendingRequesterId = nil
		requestFrame.Visible = false
	end
end)

declineButton.MouseButton1Click:Connect(function()
	if pendingRequesterId then
		tradeEvent:FireServer("respond", pendingRequesterId, false)
		pendingRequesterId = nil
		requestFrame.Visible = false
	end
end)

-- ================= نافذة الصفقة =================

local tradeFrame = Instance.new("Frame")
tradeFrame.Size = UDim2.fromOffset(720, 480)
tradeFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
tradeFrame.AnchorPoint = Vector2.new(0.5, 0.5)
tradeFrame.BackgroundColor3 = Color3.fromRGB(30, 33, 40)
tradeFrame.Visible = false
tradeFrame.Parent = screenGui
corner(tradeFrame, 14)

local tradeTitle = Instance.new("TextLabel")
tradeTitle.Size = UDim2.new(1, 0, 0, 38)
tradeTitle.BackgroundTransparency = 1
tradeTitle.Text = "🤝 صفقة مقايضة"
tradeTitle.TextColor3 = Color3.new(1, 1, 1)
tradeTitle.TextScaled = true
tradeTitle.Font = Enum.Font.GothamBold
tradeTitle.Parent = tradeFrame

local function makeColumn(xScale: number, title: string): (Frame, TextLabel, ScrollingFrame)
	local column = Instance.new("Frame")
	column.Size = UDim2.new(0.32, 0, 1, -110)
	column.Position = UDim2.new(xScale, 0, 0, 44)
	column.BackgroundColor3 = Color3.fromRGB(42, 46, 55)
	column.Parent = tradeFrame
	corner(column)

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 32)
	header.BackgroundTransparency = 1
	header.Text = title
	header.TextColor3 = Color3.fromRGB(255, 215, 100)
	header.TextScaled = true
	header.Font = Enum.Font.GothamBold
	header.Parent = column

	local body = Instance.new("Frame")
	body.Size = UDim2.new(1, -12, 1, -40)
	body.Position = UDim2.new(0, 6, 0, 36)
	body.BackgroundTransparency = 1
	body.Parent = column

	return column, header, makeScrollList(body)
end

local _, _, myInventoryScroll = makeColumn(0.01, "🎒 أغراضي (اضغط للإضافة)")
local _, myOfferHeader, myOfferScroll = makeColumn(0.34, "⬅️ عرضي")
local _, theirOfferHeader, theirOfferScroll = makeColumn(0.67, "➡️ عرضه")

-- حقل المال
local moneyBox = Instance.new("TextBox")
moneyBox.Size = UDim2.fromOffset(150, 38)
moneyBox.Position = UDim2.new(0, 10, 1, -55)
moneyBox.BackgroundColor3 = Color3.fromRGB(50, 54, 64)
moneyBox.PlaceholderText = "💰 مبلغ المال"
moneyBox.Text = ""
moneyBox.TextColor3 = Color3.new(1, 1, 1)
moneyBox.TextScaled = true
moneyBox.Font = Enum.Font.Gotham
moneyBox.ClearTextOnFocus = false
moneyBox.Parent = tradeFrame
corner(moneyBox)

moneyBox.FocusLost:Connect(function()
	local amount = tonumber(moneyBox.Text) or 0
	tradeEvent:FireServer("money", amount)
end)

local readyButton = makeButton(tradeFrame, "✅ جاهز", Color3.fromRGB(90, 170, 100))
readyButton.Size = UDim2.fromOffset(150, 42)
readyButton.Position = UDim2.new(0.5, -75, 1, -58)

local cancelButton = makeButton(tradeFrame, "❌ إلغاء الصفقة", Color3.fromRGB(200, 70, 70))
cancelButton.Size = UDim2.fromOffset(160, 42)
cancelButton.Position = UDim2.new(1, -170, 1, -58)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0, 250, 0, 30)
statusLabel.Position = UDim2.new(0.5, -125, 1, -95)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = ""
statusLabel.TextColor3 = Color3.fromRGB(180, 220, 255)
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.Gotham
statusLabel.Parent = tradeFrame

local iAmReady = false

readyButton.MouseButton1Click:Connect(function()
	iAmReady = not iAmReady
	tradeEvent:FireServer("ready", iAmReady)
end)

cancelButton.MouseButton1Click:Connect(function()
	tradeEvent:FireServer("cancel")
end)

local function clearList(scroll: ScrollingFrame)
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("TextButton") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
end

-- كمية غرض معين داخل عرضى الحالي
local function countInOffer(offer, category: string, itemName: string): number
	local bucket = offer.items[category]
	return bucket and bucket[itemName] or 0
end

local function rebuildTradeWindow(payload)
	local mine = payload.mine
	local theirs = payload.theirs

	-- عمود أغراضي المتاحة (المتبقي بعد ما أضفته للعرض)
	clearList(myInventoryScroll)
	if currentData then
		for _, category in ipairs({ "Crops", "Products", "Seeds", "Tools" }) do
			for itemName, count in pairs(currentData.Inventory[category]) do
				local available = count - countInOffer(mine, category, itemName)
				if available > 0 then
					local entry = makeButton(myInventoryScroll, displayNameOf(category, itemName) .. " x" .. available, Color3.fromRGB(60, 65, 78))
					entry.Size = UDim2.new(1, -10, 0, 38)
					entry.MouseButton1Click:Connect(function()
						tradeEvent:FireServer("add", category, itemName)
					end)
				end
			end
		end
	end

	-- عرضي (اضغط للإزالة)
	clearList(myOfferScroll)
	myOfferHeader.Text = mine.ready and "⬅️ عرضي ✅ جاهز" or "⬅️ عرضي"
	for category, items in pairs(mine.items) do
		for itemName, count in pairs(items) do
			local entry = makeButton(myOfferScroll, displayNameOf(category, itemName) .. " x" .. count .. " ➖", Color3.fromRGB(120, 90, 60))
			entry.Size = UDim2.new(1, -10, 0, 38)
			entry.MouseButton1Click:Connect(function()
				tradeEvent:FireServer("remove", category, itemName)
			end)
		end
	end
	if mine.money > 0 then
		local moneyEntry = Instance.new("TextLabel")
		moneyEntry.Size = UDim2.new(1, -10, 0, 38)
		moneyEntry.BackgroundColor3 = Color3.fromRGB(120, 110, 50)
		moneyEntry.Text = "💰 " .. mine.money
		moneyEntry.TextColor3 = Color3.new(1, 1, 1)
		moneyEntry.TextScaled = true
		moneyEntry.Font = Enum.Font.GothamBold
		moneyEntry.Parent = myOfferScroll
		corner(moneyEntry)
	end

	-- عرض الطرف الآخر
	clearList(theirOfferScroll)
	theirOfferHeader.Text = theirs.ready and ("➡️ عرض " .. payload.partnerName .. " ✅") or ("➡️ عرض " .. payload.partnerName)
	for category, items in pairs(theirs.items) do
		for itemName, count in pairs(items) do
			local entry = Instance.new("TextLabel")
			entry.Size = UDim2.new(1, -10, 0, 38)
			entry.BackgroundColor3 = Color3.fromRGB(60, 65, 78)
			entry.Text = displayNameOf(category, itemName) .. " x" .. count
			entry.TextColor3 = Color3.new(1, 1, 1)
			entry.TextScaled = true
			entry.Font = Enum.Font.Gotham
			entry.Parent = theirOfferScroll
			corner(entry)
		end
	end
	if theirs.money > 0 then
		local moneyEntry = Instance.new("TextLabel")
		moneyEntry.Size = UDim2.new(1, -10, 0, 38)
		moneyEntry.BackgroundColor3 = Color3.fromRGB(120, 110, 50)
		moneyEntry.Text = "💰 " .. theirs.money
		moneyEntry.TextColor3 = Color3.new(1, 1, 1)
		moneyEntry.TextScaled = true
		moneyEntry.Font = Enum.Font.GothamBold
		moneyEntry.Parent = theirOfferScroll
		corner(moneyEntry)
	end

	iAmReady = mine.ready
	readyButton.Text = mine.ready and "⏳ إلغاء الجاهزية" or "✅ جاهز"
	readyButton.BackgroundColor3 = mine.ready and Color3.fromRGB(220, 150, 60) or Color3.fromRGB(90, 170, 100)

	if mine.ready and not theirs.ready then
		statusLabel.Text = "بانتظار موافقة " .. payload.partnerName .. "..."
	elseif theirs.ready and not mine.ready then
		statusLabel.Text = payload.partnerName .. " جاهز! اضغط ✅ لإتمام الصفقة"
	else
		statusLabel.Text = ""
	end
end

-- ================= استقبال أحداث السيرفر =================

tradeEvent.OnClientEvent:Connect(function(action: string, ...)
	if action == "incoming" then
		local fromName, fromUserId = ...
		pendingRequesterId = fromUserId
		requestLabel.Text = "🤝 " .. tostring(fromName) .. " يريد المقايضة معك!"
		requestFrame.Visible = true
	elseif action == "start" then
		local partnerName = ...
		tradeTitle.Text = "🤝 مقايضة مع " .. tostring(partnerName)
		moneyBox.Text = ""
		iAmReady = false
		tradeFrame.Visible = true
		playerListFrame.Visible = false
	elseif action == "update" then
		local payload = ...
		rebuildTradeWindow(payload)
	elseif action == "closed" then
		tradeFrame.Visible = false
		iAmReady = false
	elseif action == "done" then
		tradeFrame.Visible = false
		iAmReady = false
	end
end)
