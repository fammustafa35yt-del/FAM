--!strict
-- واجهة السوق المركزي: تصفح عروض اللاعبين واشترِ، أو اعرض محاصيلك ومنتجاتك للبيع

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local marketEvent = remotes:WaitForChild("MarketEvent") :: RemoteEvent
local dataChanged = remotes:WaitForChild("DataChanged") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local currentData: any = nil
local currentListings: { any } = {}

local function displayNameOf(category: string, itemName: string): string
	if category == "Crops" then
		local crop = GameConfig.Crops[itemName]
		return crop and crop.DisplayName or itemName
	end
	local product = GameConfig.AnimalProducts[itemName]
	return product and product.DisplayName or itemName
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

local function clearList(scroll: ScrollingFrame)
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("Frame") then
			child:Destroy()
		end
	end
end

-- ================= النافذة =================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FAMMarketUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local marketButton = makeButton(screenGui, "🛒 السوق", Color3.fromRGB(220, 130, 70))
marketButton.Position = UDim2.new(0, 10, 0.5, 122)

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(760, 500)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(30, 33, 40)
panel.Visible = false
panel.Parent = screenGui
corner(panel, 14)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 0, 40)
title.BackgroundTransparency = 1
title.Text = "🛒 السوق المركزي — بيع وشراء بين اللاعبين"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = panel

local closeButton = makeButton(panel, "✕", Color3.fromRGB(200, 70, 70))
closeButton.Size = UDim2.fromOffset(34, 34)
closeButton.Position = UDim2.new(1, -40, 0, 4)
closeButton.MouseButton1Click:Connect(function()
	panel.Visible = false
end)

-- عمود العروض (يسار)
local listingsFrame = Instance.new("Frame")
listingsFrame.Size = UDim2.new(0.55, -15, 1, -55)
listingsFrame.Position = UDim2.new(0, 10, 0, 45)
listingsFrame.BackgroundColor3 = Color3.fromRGB(42, 46, 55)
listingsFrame.Parent = panel
corner(listingsFrame)

local listingsTitle = Instance.new("TextLabel")
listingsTitle.Size = UDim2.new(1, 0, 0, 32)
listingsTitle.BackgroundTransparency = 1
listingsTitle.Text = "📋 العروض المتاحة"
listingsTitle.TextColor3 = Color3.fromRGB(255, 215, 100)
listingsTitle.TextScaled = true
listingsTitle.Font = Enum.Font.GothamBold
listingsTitle.Parent = listingsFrame

local listingsBody = Instance.new("Frame")
listingsBody.Size = UDim2.new(1, -12, 1, -40)
listingsBody.Position = UDim2.new(0, 6, 0, 36)
listingsBody.BackgroundTransparency = 1
listingsBody.Parent = listingsFrame
local listingsScroll = makeScrollList(listingsBody)

-- عمود إنشاء عرض (يمين)
local sellFrame = Instance.new("Frame")
sellFrame.Size = UDim2.new(0.45, -15, 1, -55)
sellFrame.Position = UDim2.new(0.55, 5, 0, 45)
sellFrame.BackgroundColor3 = Color3.fromRGB(42, 46, 55)
sellFrame.Parent = panel
corner(sellFrame)

local sellTitle = Instance.new("TextLabel")
sellTitle.Size = UDim2.new(1, 0, 0, 32)
sellTitle.BackgroundTransparency = 1
sellTitle.Text = "💰 اعرض غرضًا للبيع"
sellTitle.TextColor3 = Color3.fromRGB(255, 215, 100)
sellTitle.TextScaled = true
sellTitle.Font = Enum.Font.GothamBold
sellTitle.Parent = sellFrame

local myItemsBody = Instance.new("Frame")
myItemsBody.Size = UDim2.new(1, -12, 1, -190)
myItemsBody.Position = UDim2.new(0, 6, 0, 36)
myItemsBody.BackgroundTransparency = 1
myItemsBody.Parent = sellFrame
local myItemsScroll = makeScrollList(myItemsBody)

local selectedLabel = Instance.new("TextLabel")
selectedLabel.Size = UDim2.new(1, -12, 0, 30)
selectedLabel.Position = UDim2.new(0, 6, 1, -148)
selectedLabel.BackgroundTransparency = 1
selectedLabel.Text = "⬆️ اختر غرضًا من الأعلى"
selectedLabel.TextColor3 = Color3.fromRGB(180, 220, 255)
selectedLabel.TextScaled = true
selectedLabel.Font = Enum.Font.Gotham
selectedLabel.Parent = sellFrame

local amountBox = Instance.new("TextBox")
amountBox.Size = UDim2.new(0.5, -10, 0, 36)
amountBox.Position = UDim2.new(0, 6, 1, -112)
amountBox.BackgroundColor3 = Color3.fromRGB(50, 54, 64)
amountBox.PlaceholderText = "الكمية"
amountBox.Text = ""
amountBox.TextColor3 = Color3.new(1, 1, 1)
amountBox.TextScaled = true
amountBox.Font = Enum.Font.Gotham
amountBox.ClearTextOnFocus = false
amountBox.Parent = sellFrame
corner(amountBox)

local priceBox = Instance.new("TextBox")
priceBox.Size = UDim2.new(0.5, -10, 0, 36)
priceBox.Position = UDim2.new(0.5, 4, 1, -112)
priceBox.BackgroundColor3 = Color3.fromRGB(50, 54, 64)
priceBox.PlaceholderText = "💰 السعر الإجمالي"
priceBox.Text = ""
priceBox.TextColor3 = Color3.new(1, 1, 1)
priceBox.TextScaled = true
priceBox.Font = Enum.Font.Gotham
priceBox.ClearTextOnFocus = false
priceBox.Parent = sellFrame
corner(priceBox)

local listButton = makeButton(sellFrame, "📢 عرض للبيع", Color3.fromRGB(90, 170, 100))
listButton.Size = UDim2.new(1, -12, 0, 44)
listButton.Position = UDim2.new(0, 6, 1, -66)

local selectedCategory: string? = nil
local selectedItem: string? = nil

listButton.MouseButton1Click:Connect(function()
	if not selectedCategory or not selectedItem then
		return
	end
	local amount = tonumber(amountBox.Text) or 0
	local price = tonumber(priceBox.Text) or 0
	marketEvent:FireServer("list", selectedCategory, selectedItem, amount, price)
	amountBox.Text = ""
	priceBox.Text = ""
end)

-- ================= بناء القوائم =================

local function rebuildMyItems()
	clearList(myItemsScroll)
	if not currentData then
		return
	end
	local any = false
	for _, category in ipairs({ "Crops", "Products" }) do
		for itemName, count in pairs(currentData.Inventory[category]) do
			if count > 0 then
				any = true
				local isSelected = selectedCategory == category and selectedItem == itemName
				local entry = makeButton(
					myItemsScroll,
					displayNameOf(category, itemName) .. " x" .. count .. (isSelected and " ✅" or ""),
					isSelected and Color3.fromRGB(90, 170, 100) or Color3.fromRGB(60, 65, 78)
				)
				entry.Size = UDim2.new(1, -10, 0, 38)
				entry.MouseButton1Click:Connect(function()
					selectedCategory = category
					selectedItem = itemName
					selectedLabel.Text = "المحدد: " .. displayNameOf(category, itemName)
					rebuildMyItems()
				end)
			end
		end
	end
	if not any then
		local none = Instance.new("TextLabel")
		none.Size = UDim2.new(1, -10, 0, 50)
		none.BackgroundTransparency = 1
		none.Text = "لا تملك محاصيل أو منتجات للبيع"
		none.TextColor3 = Color3.fromRGB(200, 200, 200)
		none.TextScaled = true
		none.Font = Enum.Font.Gotham
		none.Parent = myItemsScroll
	end
end

local function rebuildListings()
	clearList(listingsScroll)
	if #currentListings == 0 then
		local none = Instance.new("TextLabel")
		none.Size = UDim2.new(1, -10, 0, 60)
		none.BackgroundTransparency = 1
		none.Text = "لا توجد عروض حاليًا — كن أول من يبيع!"
		none.TextColor3 = Color3.fromRGB(200, 200, 200)
		none.TextScaled = true
		none.Font = Enum.Font.Gotham
		none.Parent = listingsScroll
		return
	end

	for _, listing in ipairs(currentListings) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -10, 0, 56)
		row.BackgroundColor3 = Color3.fromRGB(50, 54, 64)
		row.Parent = listingsScroll
		corner(row)

		local isMine = listing.SellerUserId == player.UserId

		local info = Instance.new("TextLabel")
		info.Size = UDim2.new(1, -110, 1, -6)
		info.Position = UDim2.fromOffset(8, 3)
		info.BackgroundTransparency = 1
		info.Text = displayNameOf(listing.Category, listing.ItemName) .. " x" .. listing.Amount
			.. "  —  💰 " .. listing.Price
			.. "\nالبائع: " .. (isMine and "أنت" or listing.SellerName)
		info.TextColor3 = Color3.new(1, 1, 1)
		info.TextScaled = true
		info.TextXAlignment = Enum.TextXAlignment.Left
		info.Font = Enum.Font.Gotham
		info.Parent = row

		local action = makeButton(
			row,
			isMine and "إلغاء" or "شراء",
			isMine and Color3.fromRGB(200, 70, 70) or Color3.fromRGB(90, 170, 100)
		)
		action.Size = UDim2.fromOffset(90, 38)
		action.Position = UDim2.new(1, -98, 0.5, -19)
		action.MouseButton1Click:Connect(function()
			marketEvent:FireServer(isMine and "cancel" or "buy", listing.Id)
		end)
	end
end

local function openPanel()
	panel.Visible = true
	rebuildListings()
	rebuildMyItems()
	marketEvent:FireServer("refresh")
end

marketButton.MouseButton1Click:Connect(function()
	if panel.Visible then
		panel.Visible = false
	else
		openPanel()
	end
end)

-- ================= استقبال أحداث السيرفر =================

marketEvent.OnClientEvent:Connect(function(action: string, payload)
	if action == "open" then
		currentListings = payload or {}
		openPanel()
	elseif action == "update" then
		currentListings = payload or {}
		if panel.Visible then
			rebuildListings()
			rebuildMyItems()
		end
	end
end)

dataChanged.OnClientEvent:Connect(function(data)
	currentData = data
	if panel.Visible then
		rebuildMyItems()
	end
end)
