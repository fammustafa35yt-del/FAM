--!strict
-- إعدادات اللعبة الرئيسية | Main game configuration
-- عدّل الأسعار والأوقات من هنا بسهولة

local GameConfig = {}

-- المال الابتدائي عند أول دخول
GameConfig.StartingMoney = 150

-- ================= المحاصيل =================
-- SeedPrice  : سعر البذرة في المتجر
-- SellPrice  : سعر بيع المحصول الواحد
-- GrowTime   : وقت النمو بالثواني
GameConfig.Crops = {
	Wheat = {
		DisplayName = "قمح 🌾",
		SeedPrice = 10,
		SellPrice = 18,
		GrowTime = 30,
		Color = Color3.fromRGB(226, 196, 92),
	},
	Carrot = {
		DisplayName = "جزر 🥕",
		SeedPrice = 18,
		SellPrice = 32,
		GrowTime = 55,
		Color = Color3.fromRGB(235, 125, 40),
	},
	Corn = {
		DisplayName = "ذرة 🌽",
		SeedPrice = 30,
		SellPrice = 55,
		GrowTime = 90,
		Color = Color3.fromRGB(245, 215, 66),
	},
	Pumpkin = {
		DisplayName = "يقطين 🎃",
		SeedPrice = 55,
		SellPrice = 105,
		GrowTime = 150,
		Color = Color3.fromRGB(230, 126, 34),
	},
}

-- ================= الأدوات =================
-- Consumable = true : أداة تُستهلك عند الاستخدام (مثل السماد)
GameConfig.Tools = {
	WateringCan = {
		DisplayName = "رشاش ماء 🚿",
		Price = 75,
		Description = "اسقِ النبتة ليقل وقت النمو للنصف (مرة لكل نبتة)",
		Consumable = false,
	},
	Fertilizer = {
		DisplayName = "سماد 💩",
		Price = 40,
		Description = "يُنهي 75% من وقت النمو المتبقي فورًا (يُستهلك)",
		Consumable = true,
	},
	GoldenScythe = {
		DisplayName = "منجل ذهبي ⚒️",
		Price = 250,
		Description = "يضاعف كمية الحصاد",
		Consumable = false,
	},
}

-- ================= العقارات =================
GameConfig.FarmPlot = {
	Count = 8,       -- عدد أراضي المزارع في الماب
	Price = 250,     -- سعر الأرض
	Size = 28,       -- حجم الأرض (ستود)
	SoilRows = 3,    -- صفوف التربة
	SoilCols = 3,    -- أعمدة التربة
}

GameConfig.HousePlot = {
	Count = 6,       -- عدد أراضي البيوت
	Price = 600,     -- سعر الأرض مع البيت
	Size = 34,
}

-- ================= الوظائف =================
-- Wage     : الأجر
-- Cooldown : ثواني الانتظار بين كل عملية عمل
-- Hold     : مدة الضغط المطول على الزر (E)
GameConfig.Jobs = {
	{
		Id = "Farmer",
		DisplayName = "عامل مزرعة 👨‍🌾",
		Wage = 20,
		Cooldown = 6,
		Hold = 2,
	},
	{
		Id = "Builder",
		DisplayName = "عامل بناء 👷",
		Wage = 45,
		Cooldown = 15,
		Hold = 4,
	},
	{
		Id = "Delivery",
		DisplayName = "عامل توصيل 📦",
		Wage = 60,
		Cooldown = 5,
		Hold = 1,
		-- التوصيل: خذ الطرد من نقطة الاستلام ووصله لنقطة التسليم
		IsDelivery = true,
	},
}

-- أقصى مبلغ يمكن إرساله في صفقة تبادل واحدة
GameConfig.MaxTradeMoney = 100000

-- ================= منتجات الحيوانات =================
GameConfig.AnimalProducts = {
	Egg = { DisplayName = "بيض 🥚", SellPrice = 12 },
	Milk = { DisplayName = "حليب 🥛", SellPrice = 28 },
	Wool = { DisplayName = "صوف 🧶", SellPrice = 48 },
	-- منتجات الحيوانات المميزة (روبلوكس)
	GoldenEgg = { DisplayName = "بيضة ذهبية ✨🥚", SellPrice = 65 },
	RainbowDust = { DisplayName = "غبار قوس قزح 🌈", SellPrice = 160 },
	Gem = { DisplayName = "جوهرة 💎", SellPrice = 320 },
}

-- ================= حيوانات المزرعة =================
-- Product     : المنتج الذي ينتجه الحيوان
-- ProduceTime : ثواني إنتاج المنتج الواحد
GameConfig.Animals = {
	Chicken = {
		DisplayName = "دجاجة 🐔",
		Price = 120,
		Product = "Egg",
		ProduceTime = 40,
		BodySize = Vector3.new(1.6, 1.4, 2),
		BodyColor = Color3.fromRGB(240, 240, 230),
		HeadColor = Color3.fromRGB(200, 60, 50),
	},
	Cow = {
		DisplayName = "بقرة 🐄",
		Price = 350,
		Product = "Milk",
		ProduceTime = 90,
		BodySize = Vector3.new(3, 2.4, 4.5),
		BodyColor = Color3.fromRGB(245, 245, 245),
		HeadColor = Color3.fromRGB(50, 50, 50),
	},
	Sheep = {
		DisplayName = "خروف 🐑",
		Price = 520,
		Product = "Wool",
		ProduceTime = 140,
		BodySize = Vector3.new(2.4, 2, 3.4),
		BodyColor = Color3.fromRGB(230, 222, 200),
		HeadColor = Color3.fromRGB(80, 65, 55),
	},

	-- ===== حيوانات مميزة: تُشترى بالروبلوكس فقط =====
	-- Premium = true : لا تُباع بالعملات
	-- ProductId      : ضع هنا رقم الـ Developer Product من Creator Hub
	GoldenChicken = {
		DisplayName = "دجاجة ذهبية ✨🐔",
		Premium = true,
		ProductId = 0, -- ⚠️ ضع رقم المنتج هنا
		Product = "GoldenEgg",
		ProduceTime = 35,
		BodySize = Vector3.new(1.6, 1.4, 2),
		BodyColor = Color3.fromRGB(255, 200, 50),
		HeadColor = Color3.fromRGB(210, 150, 30),
	},
	Unicorn = {
		DisplayName = "يونيكورن 🦄",
		Premium = true,
		ProductId = 0, -- ⚠️ ضع رقم المنتج هنا
		Product = "RainbowDust",
		ProduceTime = 100,
		BodySize = Vector3.new(2.6, 2.6, 4),
		BodyColor = Color3.fromRGB(245, 225, 255),
		HeadColor = Color3.fromRGB(255, 150, 210),
	},
	Dragon = {
		DisplayName = "تنين 🐉",
		Premium = true,
		ProductId = 0, -- ⚠️ ضع رقم المنتج هنا
		Product = "Gem",
		ProduceTime = 150,
		BodySize = Vector3.new(3.2, 2.8, 5),
		BodyColor = Color3.fromRGB(190, 60, 60),
		HeadColor = Color3.fromRGB(120, 30, 30),
	},
}
-- أقصى عدد حيوانات عادية (تُشترى بالعملات) لكل مزرعة
GameConfig.MaxAnimalsPerFarm = 4
-- أقصى عدد حيوانات إجمالي (عادية + مميزة) — 8 مواقع حول الأرض
GameConfig.MaxAnimalsTotal = 8

-- ================= حزم العملات (روبلوكس) =================
-- أنشئ Developer Products من Creator Hub وضع أرقامها هنا
-- (سعر الروبلوكس تحدده أنت في لوحة التحكم)
GameConfig.CoinPacks = {
	{ ProductId = 0, Coins = 500, DisplayName = "كيس عملات 💰" },
	{ ProductId = 0, Coins = 1500, DisplayName = "صندوق عملات 💰💰" },
	{ ProductId = 0, Coins = 5000, DisplayName = "خزنة عملات 👑" },
}

-- ================= مستويات البيوت =================
-- UpgradePrice : تكلفة الترقية لهذا المستوى
-- Income       : دخل الإيجار الدوري
GameConfig.HouseLevels = {
	[1] = { Name = "بيت صغير 🏠", UpgradePrice = 0, Income = 15 },
	[2] = { Name = "بيت عائلي 🏡", UpgradePrice = 900, Income = 45 },
	[3] = { Name = "قصر 🏰", UpgradePrice = 2200, Income = 120 },
}
-- كل كم ثانية يُدفع دخل الإيجار
GameConfig.HouseIncomeInterval = 120

-- ================= المواسم =================
-- GrowthMultiplier : سرعة نمو المحاصيل (أكبر = أسرع)
-- BonusCrop        : محصول الموسم — يُباع بسعر أعلى في المتجر
GameConfig.Seasons = {
	{
		Id = "Spring",
		DisplayName = "الربيع 🌸",
		GrowthMultiplier = 1.3,
		BonusCrop = "Carrot",
		GroundColor = Color3.fromRGB(96, 170, 84),
	},
	{
		Id = "Summer",
		DisplayName = "الصيف ☀️",
		GrowthMultiplier = 1.0,
		BonusCrop = "Corn",
		GroundColor = Color3.fromRGB(120, 165, 70),
	},
	{
		Id = "Autumn",
		DisplayName = "الخريف 🍂",
		GrowthMultiplier = 0.85,
		BonusCrop = "Pumpkin",
		GroundColor = Color3.fromRGB(150, 135, 70),
	},
	{
		Id = "Winter",
		DisplayName = "الشتاء ❄️",
		GrowthMultiplier = 0.55,
		BonusCrop = "Wheat",
		GroundColor = Color3.fromRGB(205, 210, 218),
	},
}
-- مدة الموسم بالثواني
GameConfig.SeasonLength = 300
-- مضاعف سعر بيع محصول الموسم
GameConfig.SeasonBonusMultiplier = 1.5

-- ================= السوق المركزي =================
GameConfig.Market = {
	MaxListingsPerPlayer = 4, -- أقصى عدد عروض لكل لاعب
	MaxPrice = 1000000,
}

return GameConfig
