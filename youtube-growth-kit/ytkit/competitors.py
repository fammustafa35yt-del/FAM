"""تحليل المنافسين: ماذا ينجح في نفس المجال الآن."""
from collections import Counter
from datetime import datetime, timedelta, timezone

from .analytics import summarize_video


def _recent_iso(days):
    dt = datetime.now(timezone.utc) - timedelta(days=days)
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def find_trending(client, query, days=30, limit=20):
    """يبحث عن أكثر الفيديوهات الحديثة مشاهدةً لموضوع/مجال معيّن."""
    items = client.search(
        query=query,
        limit=limit,
        order="viewCount",
        published_after=_recent_iso(days),
    )
    video_ids = [it["id"]["videoId"] for it in items if it.get("id", {}).get("videoId")]
    if not video_ids:
        return {"query": query, "days": days, "videos": [], "keywords": [], "channels": []}

    videos = [summarize_video(v) for v in client.get_videos(video_ids)]
    videos.sort(key=lambda v: v["views"], reverse=True)

    # استخراج الكلمات الشائعة من العناوين
    words = Counter()
    stop = {"في", "the", "a", "to", "of", "and", "i", "روبلوكس", "roblox", "|", "-", "#shorts"}
    for v in videos:
        for w in v["title"].lower().replace("|", " ").replace("#", " ").split():
            w = w.strip("!؟.,()")
            if len(w) > 2 and w not in stop:
                words[w] += 1

    # القنوات المتكرّرة (منافسون نشطون)
    raw = {it["id"]["videoId"]: it for it in items if it.get("id", {}).get("videoId")}
    channels = Counter()
    for vid in video_ids:
        snip = raw.get(vid, {}).get("snippet", {})
        title = snip.get("channelTitle")
        if title:
            channels[title] += 1

    return {
        "query": query,
        "days": days,
        "videos": videos,
        "keywords": words.most_common(15),
        "channels": channels.most_common(10),
    }


def render_competitors(result):
    lines = []
    lines.append("=" * 58)
    lines.append("🔍  تحليل المنافسين: «{}» (آخر {} يوم)".format(result["query"], result["days"]))
    lines.append("=" * 58)
    if not result["videos"]:
        lines.append("لم يتم العثور على نتائج. جرّب كلمة بحث مختلفة.")
        return "\n".join(lines)

    lines.append("\n🔥 أكثر الفيديوهات نجاحاً مؤخراً:")
    for i, v in enumerate(result["videos"][:10], 1):
        kind = "Short" if v["is_short"] else "فيديو"
        lines.append("  {}. [{}] {:,} مشاهدة — {}".format(
            i, kind, v["views"], v["title"][:55]))
        lines.append("       {}".format(v["url"]))

    lines.append("\n🏷️  كلمات متكرّرة في عناوينهم (استخدمها أنت أيضاً):")
    kws = ["{} ({})".format(w, c) for w, c in result["keywords"]]
    lines.append("  " + "، ".join(kws))

    lines.append("\n📺 قنوات منافسة نشطة (راقبها وتعلّم منها):")
    for name, c in result["channels"]:
        lines.append("  • {} — ظهر {} مرّة في النتائج".format(name, c))

    lines.append("\n💡 الخلاصة: العناوين القصيرة + الكلمات أعلاه + موضوع رائج = فرصة أكبر للظهور.")
    return "\n".join(lines)
