"""مولّد أفكار محتوى وأفكار صور مصغّرة (Thumbnails) لقناة Roblox/Shorts."""
import random

# قوالب أفكار فيديو (تُملأ باسم لعبة)
IDEA_TEMPLATES = [
    "تحدي: إنهاء {game} بأسرع وقت ممكن ⏱️",
    "POV: أول مرة تلعب {game} 😂",
    "أغرب 3 أشياء لقيتها في {game} 🤯",
    "{game} لكن بقواعد مستحيلة 😱",
    "ردة فعل على أصعب لحظة في {game}",
    "بنيت/صنعت شيئاً جنونياً في {game} 🏗️",
    "أسرار ونصائح يحتاجها كل لاعب {game} 💡",
    "حاولت أكسر/أخدع {game} 👀",
    "لعبت {game} لمدة 24 ساعة! النتيجة...",
    "أنت تختار، أنا ألعب — {game} حسب تعليقاتكم 💬",
    "أفضل لحظاتي في {game} هذا الأسبوع 🔥",
    "{game} ضد صديقي — مين يفوز؟ 🆚",
]

GAMES = [
    "Brookhaven", "Adopt Me", "Blox Fruits", "Doors",
    "Murder Mystery 2", "Pet Simulator", "Tower Defense Simulator",
    "Obby مرعب", "Blade Ball", "Grow a Garden",
]

# عناصر تصميم الصورة المصغّرة (Thumbnail) — للـ Shorts الأهم أول إطار
THUMBNAIL_TIPS = [
    "وجه بتعبير مبالغ (صدمة/ضحك) في زاوية الصورة — يرفع النقر كثيراً.",
    "نص كبير من 2-4 كلمات بحد أبيض/أسود واضح (مثل: «مستحيل!» «شوف!»).",
    "ألوان متباينة وزاهية (أصفر/أحمر/أزرق) تبرز في خلاصة Shorts.",
    "سهم أو دائرة حمراء تشير للعنصر المهم في الصورة.",
    "تجنّب الزحام — عنصر رئيسي واحد فقط يُفهم خلال جزء من الثانية.",
    "اجعل أول إطار من الـ Short هو نفسه الصورة المصغّرة (اتساق).",
]

HOOK_IDEAS = [
    "ابدأ بالنتيجة المثيرة ثم ارجع للقصة («شوفوا وش صار قبل شوي...»).",
    "اطرح سؤالاً في أول ثانية: «تتوقع وش صار؟».",
    "حركة/صوت مفاجئ في أول 0.5 ثانية لإيقاف التمرير.",
    "نص على الشاشة من أول لحظة يوضّح الوعد («كيف أصير محترف بـ30 ثانية»).",
    "اعرض «قبل/بعد» بسرعة لتشويق المشاهد.",
]


def content_ideas(count=10, game=None):
    """يولّد أفكار فيديو."""
    ideas = []
    templates = IDEA_TEMPLATES[:]
    random.shuffle(templates)
    for i in range(count):
        tpl = templates[i % len(templates)]
        g = game or random.choice(GAMES)
        ideas.append(tpl.format(game=g))
    return ideas


def render_ideas(count=10, game=None):
    lines = []
    lines.append("=" * 58)
    lines.append("💡  أفكار محتوى لقناتك" + (" — {}".format(game) if game else ""))
    lines.append("=" * 58)
    lines.append("\n🎬 أفكار فيديوهات/Shorts:")
    for i, idea in enumerate(content_ideas(count, game), 1):
        lines.append("  {}. {}".format(i, idea))

    lines.append("\n🪝 أفكار «خطّاف» (Hook) لأول 3 ثوانٍ — الأهم في الـ Shorts:")
    for tip in HOOK_IDEAS:
        lines.append("  • " + tip)

    lines.append("\n🖼️  نصائح الصورة المصغّرة (Thumbnail):")
    for tip in THUMBNAIL_TIPS:
        lines.append("  • " + tip)

    lines.append("\n📌 قاعدة ذهبية للـ Shorts: اجعل الفيديو يُعاد تلقائياً (Loop) بسلاسة")
    lines.append("   — النهاية تتصل بالبداية = وقت مشاهدة أعلى = توزيع أوسع.")
    return "\n".join(lines)
