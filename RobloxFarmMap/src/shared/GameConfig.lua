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

return GameConfig
