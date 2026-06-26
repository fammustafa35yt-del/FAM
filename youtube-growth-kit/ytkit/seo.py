"""توليد عناوين وأوصاف وكلمات مفتاحية محسّنة للبحث (SEO).

يعمل بدون اتصال بالإنترنت (offline) — مبني على قوالب وكلمات مفتاحية
مخصّصة لمحتوى الألعاب، خاصةً Roblox والـ Shorts.
"""
import random

# ألعاب/مواضيع Roblox شائعة + كلمات مفتاحية مرتبطة بها
ROBLOX_GAMES = {
    "brookhaven": ["brookhaven rp", "بروكهافن", "story", "قصة"],
    "adopt me": ["adopt me", "ادوبت مي", "pets", "trade", "تطوير"],
    "blox fruits": ["blox fruits", "بلوكس فروت", "fruit", "devil fruit", "update"],
    "doors": ["doors roblox", "دورز", "rush", "seek", "monster"],
    "tower defense": ["tower defense", "tds", "strategy"],
    "obby": ["obby", "obby roblox", "parkour", "تحدي"],
    "mm2": ["murder mystery 2", "mm2", "knife", "godly"],
    "pet simulator": ["pet simulator", "pet sim", "huge pet", "secret"],
    "general": ["roblox", "روبلوكس", "gameplay", "تختيم", "جيم بلاي"],
}

# قوالب عناوين عالية النقر (CTR) — {topic} = الموضوع، {game} = اللعبة
TITLE_TEMPLATES = [
    "🤯 {topic} في {game}!",
    "لا تجرّب هذا في {game} 😱 ({topic})",
    "أفضل طريقة لـ {topic} في {game} 🔥",
    "{topic}؟! شوف اللي صار 👀 #shorts",
    "حاولت {topic} في {game} والنتيجة... 😂",
    "سر {topic} اللي محد يعرفه في {game}",
    "POV: {topic} في {game} 🎮",
    "كيف {topic} في {game} خلال 30 ثانية ⏱️",
    "ردة فعلي على {topic} في {game} 😳",
    "تحدي {topic} في {game} — هل أنجح؟",
]

# هاشتاقات أساسية للـ Shorts (يوتيوب يحبّ #Shorts في أول الوصف)
CORE_HASHTAGS = ["#shorts", "#roblox", "#روبلوكس", "#ألعاب", "#gaming"]

DESCRIPTION_TEMPLATE = """{hook}

🎮 في هذا الفيديو: {topic}{game_part}
🔔 اشترك وفعّل الجرس عشان ما يفوتك أي فيديو جديد!
👍 لايك لو استمتعت + اكتب رأيك في الكومنت.

{hashtags}

{tags_line}
"""

HOOKS = [
    "شوف لين النهاية 🔥 ما راح تصدّق اللي صار!",
    "أقوى لحظة جاتني في اللعبة 👇",
    "جرّبت شي جنوني اليوم 😂",
    "تابع القناة لمحتوى Roblox يومي 🎮",
    "اللي طلب هذا الفيديو يحط لايك ❤️",
]


def _detect_game(text):
    low = text.lower()
    for game in ROBLOX_GAMES:
        if game != "general" and game in low:
            return game
    return None


def generate_titles(topic, game=None, count=8):
    """يولّد عناوين مقترحة لموضوع معيّن."""
    game = game or _detect_game(topic) or "Roblox"
    game_disp = game.title() if game.islower() else game
    templates = random.sample(TITLE_TEMPLATES, min(count, len(TITLE_TEMPLATES)))
    titles = []
    for tpl in templates:
        t = tpl.format(topic=topic, game=game_disp)
        # يوتيوب يقصّ العنوان بعد ~70 حرفاً تقريباً
        titles.append(t if len(t) <= 80 else t[:77] + "…")
    return titles


def generate_keywords(topic, game=None, limit=20):
    """يبني قائمة كلمات مفتاحية (tags) للفيديو."""
    game_key = (game or _detect_game(topic) or "general").lower()
    base = list(ROBLOX_GAMES.get(game_key, ROBLOX_GAMES["general"]))
    base += ROBLOX_GAMES["general"]
    # كلمات من الموضوع نفسه
    topic_words = [w for w in topic.replace("#", "").split() if len(w) > 1]
    combos = [topic] + topic_words
    combos += ["{} roblox".format(topic), "{} shorts".format(topic)]
    combos += ["roblox {}".format(topic), "روبلوكس {}".format(topic)]
    seen, out = set(), []
    for kw in combos + base:
        kw = kw.strip().lower()
        if kw and kw not in seen:
            seen.add(kw)
            out.append(kw)
        if len(out) >= limit:
            break
    return out


def generate_description(topic, game=None):
    """يبني وصفاً كاملاً للفيديو مع هاشتاقات."""
    game = game or _detect_game(topic)
    game_part = " في {}".format(game.title()) if game else ""
    hashtags = " ".join(CORE_HASHTAGS)
    if game and "#" + game.replace(" ", "") not in hashtags:
        hashtags += " #" + game.replace(" ", "")
    keywords = generate_keywords(topic, game, limit=12)
    tags_line = "كلمات مفتاحية: " + ", ".join(keywords)
    return DESCRIPTION_TEMPLATE.format(
        hook=random.choice(HOOKS),
        topic=topic,
        game_part=game_part,
        hashtags=hashtags,
        tags_line=tags_line,
    ).strip()


def build_seo_pack(topic, game=None):
    """حزمة SEO كاملة: عناوين + وصف + كلمات مفتاحية."""
    return {
        "topic": topic,
        "game": game or _detect_game(topic),
        "titles": generate_titles(topic, game),
        "description": generate_description(topic, game),
        "keywords": generate_keywords(topic, game),
    }


def render_seo(pack):
    lines = []
    lines.append("=" * 58)
    lines.append("🎯  حزمة SEO للموضوع: {}".format(pack["topic"]))
    if pack["game"]:
        lines.append("    اللعبة: {}".format(pack["game"]))
    lines.append("=" * 58)
    lines.append("\n📌 عناوين مقترحة (اختر الأنسب):")
    for i, t in enumerate(pack["titles"], 1):
        lines.append("  {}. {}".format(i, t))
    lines.append("\n📝 الوصف المقترح:\n")
    lines.append(pack["description"])
    lines.append("\n🏷️  الكلمات المفتاحية (Tags) — انسخها في حقل الوسوم:")
    lines.append("  " + ", ".join(pack["keywords"]))
    return "\n".join(lines)
