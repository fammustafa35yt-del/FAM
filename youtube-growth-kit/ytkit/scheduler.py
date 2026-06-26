"""خطة نشر وأفضل الأوقات.

إذا توفّر اتصال بالـ API يحلّل أوقات نشر أفضل فيديوهاتك فعلياً.
وإلا يعطي توصيات عامة مبنية على أفضل الممارسات لجمهور Roblox العربي.
"""
from collections import defaultdict

DAYS_AR = ["الإثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت", "الأحد"]

# أفضل أوقات عامة لجمهور الألعاب/الأطفال العربي (بتوقيت محلي تقريبي)
DEFAULT_BEST_SLOTS = [
    ("الجمعة", "16:00 - 21:00", "عطلة + بعد المدرسة = أعلى نشاط"),
    ("السبت", "14:00 - 22:00", "ذروة المشاهدة الأسبوعية"),
    ("الأربعاء", "17:00 - 20:00", "منتصف الأسبوع بعد المدرسة"),
    ("الأحد", "16:00 - 20:00", "بداية الأسبوع الدراسي مساءً"),
    ("يومياً", "19:00 - 21:00", "ذروة المساء العامة"),
]


def best_times_from_data(report, tz_offset=3):
    """يحلّل أوقات نشر فيديوهاتك الأعلى مشاهدةً (إن توفّرت بيانات)."""
    buckets = defaultdict(lambda: {"views": 0, "count": 0})
    for v in report.get("all", []):
        dt = v.get("published_dt")
        if not dt:
            continue
        local_hour = (dt.hour + tz_offset) % 24
        weekday = (dt.weekday())  # 0=الإثنين
        key = (weekday, local_hour // 3 * 3)  # نوافذ 3 ساعات
        buckets[key]["views"] += v["views"]
        buckets[key]["count"] += 1
    ranked = []
    for (wd, h), data in buckets.items():
        if data["count"] == 0:
            continue
        avg = data["views"] / data["count"]
        ranked.append((avg, wd, h, data["count"]))
    ranked.sort(reverse=True)
    return ranked[:5]


def weekly_plan(posts_per_week=5):
    """يبني جدول نشر أسبوعي مقترحاً للـ Shorts."""
    # للـ Shorts الأفضل النشر يومياً تقريباً للحفاظ على الزخم
    slots = [
        ("السبت", "15:00", "Short — تحدٍّ أو لحظة مضحكة"),
        ("الأحد", "18:00", "Short — تختيم/جيم بلاي سريع"),
        ("الثلاثاء", "17:00", "Short — تريند اللعبة الحالية"),
        ("الأربعاء", "19:00", "Short — رد فعل / POV"),
        ("الخميس", "18:00", "Short — سؤال للجمهور (تفاعل)"),
        ("الجمعة", "16:00", "Short مميّز للأسبوع (أفضل فكرة)"),
        ("الإثنين", "19:00", "فيديو/مونتاج أطول (اختياري)"),
    ]
    return slots[:max(1, min(posts_per_week, len(slots)))]


def render_schedule(report=None, tz_offset=3, posts_per_week=5):
    lines = []
    lines.append("=" * 58)
    lines.append("🗓️  خطة النشر وأفضل الأوقات")
    lines.append("=" * 58)

    data_slots = best_times_from_data(report, tz_offset) if report else []
    if data_slots:
        lines.append("\n📈 أفضل أوقاتك (من تحليل فيديوهاتك الفعلية):")
        for avg, wd, h, n in data_slots:
            lines.append("  • {} حوالي الساعة {:02d}:00 — متوسط {:,} مشاهدة ({} فيديو)".format(
                DAYS_AR[wd], h, round(avg), n))
        lines.append("  (الأوقات بتوقيتك المحلي UTC+{})".format(tz_offset))
    else:
        lines.append("\n📈 أفضل الأوقات العامة لجمهور Roblox العربي:")
        for day, window, why in DEFAULT_BEST_SLOTS:
            lines.append("  • {}  {}  — {}".format(day, window, why))

    lines.append("\n🗓️  جدول نشر أسبوعي مقترح ({} منشورات):".format(posts_per_week))
    for day, time_, what in weekly_plan(posts_per_week):
        lines.append("  • {}  {}  →  {}".format(day, time_, what))

    lines.append("\n💡 نصائح للـ Shorts:")
    lines.append("  • الانتظام أهم من الكمية — التزم بالجدول حتى لو قلّت المشاهدات بالبداية.")
    lines.append("  • انشر قبل ذروة جمهورك بساعة ليلتقطه التوزيع الأولي.")
    lines.append("  • أعِد نشر أفضل فكرة بصيغة جديدة بعد أسبوعين.")
    return "\n".join(lines)
