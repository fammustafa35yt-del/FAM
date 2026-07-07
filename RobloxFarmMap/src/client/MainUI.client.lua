--!strict
-- واجهة اللاعب الرئيسية: المال، الإشعارات، الحقيبة، والمتجر

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local dataChanged = remotes:WaitForChild("DataChanged") :: RemoteEvent
local notify = remotes:WaitForChild("Notify") :: RemoteEvent
local openShop = remotes:WaitForChild("OpenShop") :: RemoteEvent
local buyItem = remotes:WaitForChild("BuyItem") :: RemoteEvent
local sellCrop = remotes:WaitForChild("SellCrop") :: RemoteEvent
local selectSeed = remotes:WaitForChild("SelectSeed") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- آخر بيانات وصلت من السيرفر
local currentData: any = nil
-- معلومات الموسم الحالي (من SeasonChanged)
local seasonInfo: any = nil
local seasonEndsAt = 0

-- ================= أدوات بناء الواجهة =================

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
	button.AutoButtonColor = true
	button.Parent = parent
	corner(button)
	return button
end

local function makePanel(parent: Instance, title: string, size: UDim2): (Frame, Frame)
	local panel = Instance.new("Frame")
	panel.Size = size
	panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = Color3.fromRGB(35, 38, 46)
	panel.Visible = false
	panel.Parent = parent
	corner(panel, 14)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -50, 0, 40)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = panel

	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.fromOffset(34, 34)
	closeButton.Position = UDim2.new(1, -40, 0, 4)
	closeButton.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
	closeButton.Text = "✕"
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.TextScaled = true
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Parent = panel
	corner(closeButton, 8)
	closeButton.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)

	local content = Instance.new("Frame")
	content.Size = UDim2.new(1, -20, 1, -55)
	content.Position = UDim2.new(0, 10, 0, 45)
	content.BackgroundTransparency = 1
	content.Parent = panel

	return panel, content
end

local function makeScroll(parent: Instance): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	return scroll
end

local function makeRow(parent: Instance, text: string): (Frame, TextLabel)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, 46)
	row.BackgroundColor3 = Color3.fromRGB(50, 54, 64)
	row.Parent = parent
	corner(row)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -140, 1, 0)
	label.Position = UDim2.fromOffset(8, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = Enum.Font.Gotham
	label.Parent = row

	return row, label
end

-- ================= الواجهة الرئيسية =================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FAMUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- شريط المال
local moneyFrame = Instance.new("Frame")
moneyFrame.Size = UDim2.fromOffset(180, 44)
moneyFrame.Position = UDim2.new(0.5, 0, 0, 8)
moneyFrame.AnchorPoint = Vector2.new(0.5, 0)
moneyFrame.BackgroundColor3 = Color3.fromRGB(35, 38, 46)
moneyFrame.Parent = screenGui
corner(moneyFrame, 12)

local moneyLabel = Instance.new("TextLabel")
moneyLabel.Size = UDim2.fromScale(1, 1)
moneyLabel.BackgroundTransparency = 1
moneyLabel.Text = "💰 0"
moneyLabel.TextColor3 = Color3.fromRGB(255, 215, 100)
moneyLabel.TextScaled = true
moneyLabel.Font = Enum.Font.GothamBold
moneyLabel.Parent = moneyFrame

-- أزرار جانبية
local buttonBar = Instance.new("Frame")
buttonBar.Size = UDim2.fromOffset(130, 150)
buttonBar.Position = UDim2.new(0, 10, 0.5, -75)
buttonBar.BackgroundTransparency = 1
buttonBar.Parent = screenGui

local barLayout = Instance.new("UIListLayout")
barLayout.Padding = UDim.new(0, 8)
barLayout.Parent = buttonBar

local inventoryButton = makeButton(buttonBar, "🎒 الحقيبة", Color3.fromRGB(80, 130, 200))
local shopButton = makeButton(buttonBar, "🏪 المتجر", Color3.fromRGB(90, 170, 100))

-- الإشعارات
local notifLabel = Instance.new("TextLabel")
notifLabel.Size = UDim2.new(0, 420, 0, 40)
notifLabel.Position = UDim2.new(0.5, 0, 0, 60)
notifLabel.AnchorPoint = Vector2.new(0.5, 0)
notifLabel.BackgroundColor3 = Color3.fromRGB(35, 38, 46)
notifLabel.BackgroundTransparency = 1
notifLabel.Text = ""
notifLabel.TextColor3 = Color3.new(1, 1, 1)
notifLabel.TextScaled = true
notifLabel.Font = Enum.Font.GothamBold
notifLabel.TextTransparency = 1
notifLabel.Parent = screenGui
corner(notifLabel, 10)

local notifToken = 0
notify.OnClientEvent:Connect(function(message: string, isError: boolean)
	notifToken += 1
	local myToken = notifToken
	notifLabel.Text = message
	notifLabel.TextColor3 = isError and Color3.fromRGB(255, 120, 120) or Color3.fromRGB(160, 255, 170)
	notifLabel.TextTransparency = 0
	notifLabel.BackgroundTransparency = 0.25
	task.delay(3, function()
		if notifToken == myToken then
			TweenService:Create(notifLabel, TweenInfo.new(0.6), {
				TextTransparency = 1,
				BackgroundTransparency = 1,
			}):Play()
		end
	end)
end)

-- ================= الحقيبة =================

local inventoryPanel, inventoryContent = makePanel(screenGui, "🎒 الحقيبة", UDim2.fromOffset(420, 460))
local inventoryScroll = makeScroll(inventoryContent)

local function rebuildInventory()
	if not currentData then
		return
	end
	for _, child in ipairs(inventoryScroll:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	local order = 0
	local function addHeader(text: string)
		order += 1
		local header = Instance.new("TextLabel")
		header.Size = UDim2.new(1, -8, 0, 30)
		header.BackgroundTransparency = 1
		header.Text = text
		header.TextColor3 = Color3.fromRGB(255, 215, 100)
		header.TextScaled = true
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.Font = Enum.Font.GothamBold
		header.LayoutOrder = order
		header.Parent = inventoryScroll
	end

	-- البذور: اضغط لاختيارها للزراعة
	addHeader("🌱 البذور (اضغط للاختيار ثم ازرعها في مزرعتك)")
	local hasSeeds = false
	for seedName, count in pairs(currentData.Inventory.Seeds) do
		local crop = GameConfig.Crops[seedName]
		if crop and count > 0 then
			hasSeeds = true
			order += 1
			local row = makeRow(inventoryScroll, crop.DisplayName .. "  x" .. count)
			row.LayoutOrder = order
			local isSelected = currentData.SelectedSeed == seedName
			local pick = makeButton(row, isSelected and "✅ محددة" or "اختيار", isSelected and Color3.fromRGB(90, 170, 100) or Color3.fromRGB(80, 130, 200))
			pick.Size = UDim2.fromOffset(110, 34)
			pick.Position = UDim2.new(1, -118, 0.5, -17)
			pick.MouseButton1Click:Connect(function()
				selectSeed:FireServer(seedName)
			end)
		end
	end
	if not hasSeeds then
		order += 1
		local row = makeRow(inventoryScroll, "لا تملك بذورًا — اشترِ من المتجر")
		row.LayoutOrder = order
	end

	addHeader("🌾 المحاصيل (بِعها في المتجر أو قايض بها)")
	for cropName, count in pairs(currentData.Inventory.Crops) do
		local crop = GameConfig.Crops[cropName]
		if crop and count > 0 then
			order += 1
			local row = makeRow(inventoryScroll, crop.DisplayName .. "  x" .. count)
			row.LayoutOrder = order
		end
	end

	addHeader("🥚 منتجات الحيوانات (بِعها أو قايض بها)")
	for productName, count in pairs(currentData.Inventory.Products) do
		local product = GameConfig.AnimalProducts[productName]
		if product and count > 0 then
			order += 1
			local row = makeRow(inventoryScroll, product.DisplayName .. "  x" .. count)
			row.LayoutOrder = order
		end
	end

	addHeader("🐔 حيواناتك (" .. #currentData.Animals .. "/" .. GameConfig.MaxAnimalsTotal .. ")")
	for _, animalType in ipairs(currentData.Animals) do
		local animal = GameConfig.Animals[animalType]
		if animal then
			order += 1
			local row = makeRow(inventoryScroll, animal.DisplayName)
			row.LayoutOrder = order
		end
	end

	addHeader("🛠️ الأدوات")
	for toolName, count in pairs(currentData.Inventory.Tools) do
		local tool = GameConfig.Tools[toolName]
		if tool and count > 0 then
			order += 1
			local row = makeRow(inventoryScroll, tool.DisplayName .. (tool.Consumable and ("  x" .. count) or ""))
			row.LayoutOrder = order
		end
	end
end

inventoryButton.MouseButton1Click:Connect(function()
	inventoryPanel.Visible = not inventoryPanel.Visible
	if inventoryPanel.Visible then
		rebuildInventory()
	end
end)

-- ================= المتجر =================

local shopPanel, shopContent = makePanel(screenGui, "🏪 المتجر", UDim2.fromOffset(460, 500))
local shopScroll = makeScroll(shopContent)

local function rebuildShop()
	for _, child in ipairs(shopScroll:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	local order = 0
	local function addHeader(text: string)
		order += 1
		local header = Instance.new("TextLabel")
		header.Size = UDim2.new(1, -8, 0, 30)
		header.BackgroundTransparency = 1
		header.Text = text
		header.TextColor3 = Color3.fromRGB(255, 215, 100)
		header.TextScaled = true
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.Font = Enum.Font.GothamBold
		header.LayoutOrder = order
		header.Parent = shopScroll
	end

	addHeader("🌱 بذور للبيع")
	for seedName, crop in pairs(GameConfig.Crops) do
		order += 1
		local row = makeRow(shopScroll, crop.DisplayName .. "  💰 " .. crop.SeedPrice)
		row.LayoutOrder = order
		local buy = makeButton(row, "شراء", Color3.fromRGB(90, 170, 100))
		buy.Size = UDim2.fromOffset(90, 34)
		buy.Position = UDim2.new(1, -98, 0.5, -17)
		buy.MouseButton1Click:Connect(function()
			buyItem:FireServer("Seeds", seedName)
		end)
	end

	addHeader("🛠️ أدوات المزرعة")
	for toolName, tool in pairs(GameConfig.Tools) do
		order += 1
		local row = makeRow(shopScroll, tool.DisplayName .. "  💰 " .. tool.Price)
		row.LayoutOrder = order
		local buy = makeButton(row, "شراء", Color3.fromRGB(90, 170, 100))
		buy.Size = UDim2.fromOffset(90, 34)
		buy.Position = UDim2.new(1, -98, 0.5, -17)
		buy.MouseButton1Click:Connect(function()
			buyItem:FireServer("Tools", toolName)
		end)
	end

	addHeader("🐔 حيوانات المزرعة (تحتاج مزرعة!)")
	for animalName, animal in pairs(GameConfig.Animals) do
		if not animal.Premium then
			local product = GameConfig.AnimalProducts[animal.Product]
			order += 1
			local row = makeRow(shopScroll, animal.DisplayName .. "  💰 " .. animal.Price .. "  (تنتج " .. (product and product.DisplayName or "") .. ")")
			row.LayoutOrder = order
			local buy = makeButton(row, "شراء", Color3.fromRGB(90, 170, 100))
			buy.Size = UDim2.fromOffset(90, 34)
			buy.Position = UDim2.new(1, -98, 0.5, -17)
			buy.MouseButton1Click:Connect(function()
				buyItem:FireServer("Animals", animalName)
			end)
		end
	end

	-- زر شراء بالروبلوكس: يجلب السعر الحقيقي من روبلوكس، أو يظهر تحذيرًا إن لم يُعد المنتج
	local function addRobuxButton(row: Frame, productId: number)
		if productId <= 0 then
			local warnButton = makeButton(row, "⚠️ غير مُعد", Color3.fromRGB(110, 110, 120))
			warnButton.Size = UDim2.fromOffset(110, 34)
			warnButton.Position = UDim2.new(1, -118, 0.5, -17)
			warnButton.MouseButton1Click:Connect(function()
				notifLabel.Text = "ضع رقم المنتج (ProductId) في GameConfig أولًا"
				notifLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
				notifLabel.TextTransparency = 0
				notifLabel.BackgroundTransparency = 0.25
			end)
			return
		end
		local buy = makeButton(row, "شراء", Color3.fromRGB(70, 190, 120))
		buy.Size = UDim2.fromOffset(110, 34)
		buy.Position = UDim2.new(1, -118, 0.5, -17)
		-- جلب السعر بالروبلوكس لعرضه على الزر
		task.spawn(function()
			local ok, productInfo = pcall(function()
				return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
			end)
			if ok and productInfo and buy.Parent then
				buy.Text = "R$ " .. tostring(productInfo.PriceInRobux or "?")
			end
		end)
		buy.MouseButton1Click:Connect(function()
			MarketplaceService:PromptProductPurchase(player, productId)
		end)
	end

	addHeader("💎 شراء عملات (روبلوكس)")
	for _, pack in ipairs(GameConfig.CoinPacks) do
		order += 1
		local row = makeRow(shopScroll, pack.DisplayName .. "  (+" .. pack.Coins .. " 💰)")
		row.LayoutOrder = order
		addRobuxButton(row, pack.ProductId or 0)
	end

	addHeader("💎 حيوانات مميزة (روبلوكس)")
	for _, animalName in ipairs({ "GoldenChicken", "Unicorn", "Dragon" }) do
		local animal = GameConfig.Animals[animalName]
		if animal and animal.Premium then
			local product = GameConfig.AnimalProducts[animal.Product]
			order += 1
			local row = makeRow(shopScroll, animal.DisplayName .. "  (تنتج " .. (product and product.DisplayName or "") .. ")")
			row.LayoutOrder = order
			addRobuxButton(row, animal.ProductId or 0)
		end
	end

	addHeader("💵 بيع محاصيلك ومنتجاتك")
	local hasItems = false
	if currentData then
		for cropName, count in pairs(currentData.Inventory.Crops) do
			local crop = GameConfig.Crops[cropName]
			if crop and count > 0 then
				hasItems = true
				order += 1
				local isBonus = seasonInfo and GameConfig.Crops[cropName].DisplayName == seasonInfo.BonusCropName
				local priceText = isBonus and ("⭐ 💰 " .. math.floor(crop.SellPrice * GameConfig.SeasonBonusMultiplier) .. " سعر الموسم!") or ("💰 " .. crop.SellPrice)
				local row = makeRow(shopScroll, crop.DisplayName .. "  x" .. count .. "  (" .. priceText .. ")")
				row.LayoutOrder = order
				local sellAll = makeButton(row, "بيع الكل", Color3.fromRGB(220, 150, 60))
				sellAll.Size = UDim2.fromOffset(100, 34)
				sellAll.Position = UDim2.new(1, -108, 0.5, -17)
				sellAll.MouseButton1Click:Connect(function()
					sellCrop:FireServer(cropName, "all")
				end)
			end
		end
		for productName, count in pairs(currentData.Inventory.Products) do
			local product = GameConfig.AnimalProducts[productName]
			if product and count > 0 then
				hasItems = true
				order += 1
				local row = makeRow(shopScroll, product.DisplayName .. "  x" .. count .. "  (💰 " .. product.SellPrice .. " للواحدة)")
				row.LayoutOrder = order
				local sellAll = makeButton(row, "بيع الكل", Color3.fromRGB(220, 150, 60))
				sellAll.Size = UDim2.fromOffset(100, 34)
				sellAll.Position = UDim2.new(1, -108, 0.5, -17)
				sellAll.MouseButton1Click:Connect(function()
					sellCrop:FireServer(productName, "all")
				end)
			end
		end
	end
	if not hasItems then
		order += 1
		local row = makeRow(shopScroll, "لا تملك ما تبيعه — ازرع واحصد أولًا!")
		row.LayoutOrder = order
	end
end

local function showShop()
	shopPanel.Visible = true
	rebuildShop()
end

shopButton.MouseButton1Click:Connect(showShop)
openShop.OnClientEvent:Connect(showShop)

-- ================= تحديث البيانات =================

dataChanged.OnClientEvent:Connect(function(data)
	currentData = data
	moneyLabel.Text = "💰 " .. tostring(data.Money)
	if inventoryPanel.Visible then
		rebuildInventory()
	end
	if shopPanel.Visible then
		rebuildShop()
	end
end)

-- ================= لوحة الموسم =================

local seasonFrame = Instance.new("Frame")
seasonFrame.Size = UDim2.fromOffset(210, 64)
seasonFrame.Position = UDim2.new(1, -220, 0, 8)
seasonFrame.BackgroundColor3 = Color3.fromRGB(35, 38, 46)
seasonFrame.Parent = screenGui
corner(seasonFrame, 12)

local seasonLabel = Instance.new("TextLabel")
seasonLabel.Size = UDim2.new(1, -10, 0.55, 0)
seasonLabel.Position = UDim2.fromOffset(5, 2)
seasonLabel.BackgroundTransparency = 1
seasonLabel.Text = "..."
seasonLabel.TextColor3 = Color3.new(1, 1, 1)
seasonLabel.TextScaled = true
seasonLabel.Font = Enum.Font.GothamBold
seasonLabel.Parent = seasonFrame

local seasonBonusLabel = Instance.new("TextLabel")
seasonBonusLabel.Size = UDim2.new(1, -10, 0.4, 0)
seasonBonusLabel.Position = UDim2.new(0, 5, 0.55, 0)
seasonBonusLabel.BackgroundTransparency = 1
seasonBonusLabel.Text = ""
seasonBonusLabel.TextColor3 = Color3.fromRGB(255, 215, 100)
seasonBonusLabel.TextScaled = true
seasonBonusLabel.Font = Enum.Font.Gotham
seasonBonusLabel.Parent = seasonFrame

local seasonChanged = remotes:WaitForChild("SeasonChanged") :: RemoteEvent
seasonChanged.OnClientEvent:Connect(function(payload)
	seasonInfo = payload
	seasonEndsAt = os.clock() + payload.SecondsLeft
	seasonBonusLabel.Text = payload.BonusCropName ~= "" and ("⭐ محصول الموسم: " .. payload.BonusCropName) or ""
	if shopPanel.Visible then
		rebuildShop()
	end
end)

-- عدّاد الوقت المتبقي للموسم
task.spawn(function()
	while true do
		task.wait(1)
		if seasonInfo then
			local remaining = math.max(0, seasonEndsAt - os.clock())
			local minutes = math.floor(remaining / 60)
			local seconds = math.floor(remaining % 60)
			seasonLabel.Text = seasonInfo.DisplayName .. "  " .. string.format("%d:%02d", minutes, seconds)
		end
	end
end)

-- طلب البيانات الأولية (قد تكون وصلت قبل تشغيل هذا السكربت)
local requestData = remotes:WaitForChild("RequestData") :: RemoteEvent
requestData:FireServer()
