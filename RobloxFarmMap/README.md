# 🌾 FAM Farm — ماب المزرعة والعقارات والمقايضة

لعبة روبلوكس كاملة: ابنِ بيتك، ازرع مزرعتك، اعمل واكسب المال، اشترِ العقارات، وقايض اللاعبين الآخرين!

## ✨ مميزات اللعبة

| النظام | الوصف |
|--------|-------|
| 🏠 **العقارات** | اشترِ أرض مزرعة (250💰) أو بيتًا جاهزًا (600💰) — يُبنى البيت تلقائيًا باسمك |
| 🌱 **الزراعة** | 4 محاصيل (قمح، جزر، ذرة، يقطين) — ازرع، انتظر النمو، واحصد |
| 🚿 **أدوات المزرعة** | رشاش ماء (يسرّع النمو)، سماد (تسريع فوري)، منجل ذهبي (حصاد مضاعف) |
| 🏪 **المتجر** | اشترِ البذور والأدوات، وبِع محاصيلك |
| 👷 **الوظائف** | عامل مزرعة، عامل بناء، وعامل توصيل (خذ الطرد ووصله للنقطة الحمراء!) |
| 🤝 **المقايضة** | نظام تبادل آمن بين اللاعبين: أغراض + مال، لا تتم الصفقة إلا بموافقة الطرفين |
| 💾 **الحفظ** | المال والحقيبة والممتلكات تُحفظ تلقائيًا (DataStore) |

الماب بالكامل يُبنى **برمجيًا** عند تشغيل السيرفر — لا تحتاج لبناء أي شيء يدويًا!

---

## 🛠️ طريقة التركيب في Roblox Studio (يدويًا — الأسهل)

1. افتح **Roblox Studio** وأنشئ مكانًا جديدًا (Baseplate).

2. **ReplicatedStorage**:
   - أنشئ `Folder` باسم `Shared`.
   - داخله أنشئ `ModuleScript` باسم `GameConfig` والصق فيه محتوى `src/shared/GameConfig.lua`.

3. **ServerScriptService**:
   - أنشئ `Folder` باسم `Server` وداخله:
     - `Script` باسم `Main` ← محتوى `src/server/Main.server.lua`
     - `ModuleScript` باسم `DataManager` ← محتوى `src/server/DataManager.lua`
     - `ModuleScript` باسم `MapBuilder` ← محتوى `src/server/MapBuilder.lua`
     - `ModuleScript` باسم `FarmingSystem` ← محتوى `src/server/FarmingSystem.lua`
     - `ModuleScript` باسم `PlotManager` ← محتوى `src/server/PlotManager.lua`
     - `ModuleScript` باسم `ShopSystem` ← محتوى `src/server/ShopSystem.lua`
     - `ModuleScript` باسم `JobSystem` ← محتوى `src/server/JobSystem.lua`
     - `ModuleScript` باسم `TradeSystem` ← محتوى `src/server/TradeSystem.lua`

   ⚠️ مهم: كل الملفات ما عدا `Main` يجب أن تكون **ModuleScript** وليس Script عادي.

4. **StarterPlayer ← StarterPlayerScripts**:
   - أنشئ `LocalScript` باسم `MainUI` ← محتوى `src/client/MainUI.client.lua`
   - أنشئ `LocalScript` باسم `TradeUI` ← محتوى `src/client/TradeUI.client.lua`

5. **تفعيل حفظ البيانات**:
   - من `Home ← Game Settings ← Security` فعّل **Enable Studio Access to API Services**.
   - يجب أن تكون اللعبة منشورة (Publish) ليعمل الحفظ.

6. اضغط **Play** وجرّب! 🎮

## 🧩 طريقة التركيب باستخدام Rojo (للمطورين)

```bash
rojo serve default.project.json
```
ثم وصّل إضافة Rojo من داخل ستوديو.

---

## 🎮 طريقة اللعب

1. **اكسب المال أولًا**: اذهب لمركز الوظائف (المنصات الملونة شرق الساحة) واعمل.
   - وظيفة التوصيل: استلم الطرد 📦 من المنصة الزرقاء ووصله للمنصة الحمراء البعيدة.
2. **اشترِ مزرعة**: اذهب للأراضي البنية غرب الساحة واضغط E مطولًا على اللافتة.
3. **ازرع**:
   - اشترِ بذورًا من المتجر 🏪 (جنوب الساحة).
   - افتح الحقيبة 🎒 واختر البذرة.
   - اقترب من التربة في مزرعتك واضغط **E** للزراعة.
   - اضغط **F** على النبتة للسقي/التسميد (يسرّع النمو).
   - عندما تلمع النبتة بلون المحصول اضغط **E** للحصاد.
4. **بِع أو قايض**:
   - بِع المحاصيل في المتجر.
   - أو اضغط زر 🤝 **مقايضة** واختر لاعبًا: أضيفا الأغراض والمال، وعند ضغط "جاهز" من الطرفين تتم الصفقة.
5. **اشترِ بيتًا**: الأراضي الخضراء شمال الساحة — يُبنى البيت فورًا باسمك!

## ⚙️ التخصيص

كل الأسعار وأوقات النمو وأجور الوظائف وعدد الأراضي في ملف واحد: `src/shared/GameConfig.lua` — عدّل الأرقام كما تشاء.

## 📁 هيكل المشروع

```
RobloxFarmMap/
├── default.project.json      # ملف Rojo
└── src/
    ├── shared/
    │   └── GameConfig.lua    # كل إعدادات اللعبة (أسعار، محاصيل، وظائف)
    ├── server/
    │   ├── Main.server.lua   # نقطة التشغيل
    │   ├── DataManager.lua   # بيانات اللاعبين والحفظ
    │   ├── MapBuilder.lua    # بناء الماب برمجيًا
    │   ├── FarmingSystem.lua # الزراعة والنمو والحصاد
    │   ├── PlotManager.lua   # شراء العقارات
    │   ├── ShopSystem.lua    # المتجر
    │   ├── JobSystem.lua     # الوظائف
    │   └── TradeSystem.lua   # المقايضة بين اللاعبين
    └── client/
        ├── MainUI.client.lua # الواجهة: مال، حقيبة، متجر، إشعارات
        └── TradeUI.client.lua# واجهة المقايضة
```
