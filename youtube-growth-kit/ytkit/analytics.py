"""تحليل أداء القناة والفيديوهات عبر YouTube Data API."""
from datetime import datetime, timezone

from .api import YouTubeClient, parse_duration_seconds

SHORT_MAX_SECONDS = 180  # الفيديو يُعدّ Short إذا كان <= 3 دقائق


def _int(stats, key):
    try:
        return int(stats.get(key, 0))
    except (TypeError, ValueError):
        return 0


def _parse_dt(iso):
    if not iso:
        return None
    try:
        return datetime.fromisoformat(iso.replace("Z", "+00:00"))
    except ValueError:
        return None


def summarize_video(video):
    """يحوّل عنصر فيديو خام إلى ملخّص مفيد."""
    stats = video.get("statistics", {})
    snippet = video.get("snippet", {})
    duration = parse_duration_seconds(
        video.get("contentDetails", {}).get("duration", "")
    )
    views = _int(stats, "viewCount")
    likes = _int(stats, "likeCount")
    comments = _int(stats, "commentCount")
    engagement = round((likes + comments) / views * 100, 2) if views else 0.0
    published = _parse_dt(snippet.get("publishedAt"))
    return {
        "id": video.get("id"),
        "title": snippet.get("title", ""),
        "published": snippet.get("publishedAt", ""),
        "published_dt": published,
        "duration_s": duration,
        "is_short": duration <= SHORT_MAX_SECONDS and duration > 0,
        "views": views,
        "likes": likes,
        "comments": comments,
        "engagement_pct": engagement,
        "tags": snippet.get("tags", []),
        "url": "https://youtu.be/{}".format(video.get("id")),
    }


def analyze_channel(client, handle=None, channel_id=None, video_limit=50):
    """يرجع تقريراً شاملاً عن القناة وأحدث فيديوهاتها."""
    if channel_id:
        channel = client.get_channel_by_id(channel_id)
    else:
        channel = client.get_channel_by_handle(handle)
    if not channel:
        raise SystemExit("[!] لم يتم العثور على القناة: {}".format(handle or channel_id))

    cstats = channel.get("statistics", {})
    csnip = channel.get("snippet", {})
    uploads = YouTubeClient.uploads_playlist_id(channel)
    vid_ids = client.playlist_video_ids(uploads, limit=video_limit)
    videos = [summarize_video(v) for v in client.get_videos(vid_ids)]
    videos.sort(key=lambda v: v["published_dt"] or datetime.min.replace(tzinfo=timezone.utc),
                reverse=True)

    total_views = sum(v["views"] for v in videos)
    avg_views = round(total_views / len(videos)) if videos else 0
    avg_eng = round(sum(v["engagement_pct"] for v in videos) / len(videos), 2) if videos else 0
    shorts = [v for v in videos if v["is_short"]]
    longs = [v for v in videos if not v["is_short"]]

    top = sorted(videos, key=lambda v: v["views"], reverse=True)[:5]
    top_eng = sorted(videos, key=lambda v: v["engagement_pct"], reverse=True)[:5]

    return {
        "channel": {
            "title": csnip.get("title", ""),
            "id": channel.get("id"),
            "subscribers": _int(cstats, "subscriberCount"),
            "total_views": _int(cstats, "viewCount"),
            "total_videos": _int(cstats, "videoCount"),
            "published": csnip.get("publishedAt", ""),
        },
        "sample_size": len(videos),
        "avg_views": avg_views,
        "avg_engagement_pct": avg_eng,
        "shorts_count": len(shorts),
        "longs_count": len(longs),
        "shorts_avg_views": round(sum(v["views"] for v in shorts) / len(shorts)) if shorts else 0,
        "longs_avg_views": round(sum(v["views"] for v in longs) / len(longs)) if longs else 0,
        "top_by_views": top,
        "top_by_engagement": top_eng,
        "recent": videos[:10],
        "all": videos,
    }


def render_report(report):
    """يطبع تقرير القناة بشكل مقروء في الطرفية."""
    ch = report["channel"]
    lines = []
    lines.append("=" * 58)
    lines.append("📊  تقرير قناة: {}".format(ch["title"]))
    lines.append("=" * 58)
    lines.append("المشتركون      : {:,}".format(ch["subscribers"]))
    lines.append("إجمالي المشاهدات: {:,}".format(ch["total_views"]))
    lines.append("عدد الفيديوهات  : {:,}".format(ch["total_videos"]))
    lines.append("")
    lines.append("— تحليل آخر {} فيديو —".format(report["sample_size"]))
    lines.append("متوسط المشاهدات        : {:,}".format(report["avg_views"]))
    lines.append("متوسط نسبة التفاعل     : {}%".format(report["avg_engagement_pct"]))
    lines.append("Shorts: {} (متوسط {:,} مشاهدة) | عادي: {} (متوسط {:,} مشاهدة)".format(
        report["shorts_count"], report["shorts_avg_views"],
        report["longs_count"], report["longs_avg_views"]))
    lines.append("")
    lines.append("🏆 الأعلى مشاهدةً:")
    for i, v in enumerate(report["top_by_views"], 1):
        kind = "Short" if v["is_short"] else "فيديو"
        lines.append("  {}. [{}] {:,} مشاهدة | تفاعل {}% — {}".format(
            i, kind, v["views"], v["engagement_pct"], v["title"][:55]))
    lines.append("")
    lines.append("💬 الأعلى تفاعلاً (مؤشر على جودة المحتوى):")
    for i, v in enumerate(report["top_by_engagement"], 1):
        lines.append("  {}. {}% ({:,} مشاهدة) — {}".format(
            i, v["engagement_pct"], v["views"], v["title"][:55]))
    lines.append("")
    lines.append("💡 ملاحظات سريعة:")
    for note in _insights(report):
        lines.append("  • " + note)
    return "\n".join(lines)


def _insights(report):
    """يستنتج توصيات بسيطة من الأرقام."""
    notes = []
    s_avg, l_avg = report["shorts_avg_views"], report["longs_avg_views"]
    if report["shorts_count"] and report["longs_count"]:
        if s_avg > l_avg * 1.3:
            notes.append("الـ Shorts تتفوّق بوضوح — ركّز عليها أكثر (إيقاع نشر أسرع).")
        elif l_avg > s_avg * 1.3:
            notes.append("الفيديوهات الطويلة تجلب مشاهدات أعلى للفيديو الواحد — وازِن بينهما.")
    if report["avg_engagement_pct"] < 3:
        notes.append("التفاعل أقل من 3% — أضِف نداء واضح (اشترك/علّق) وحسّن أول 3 ثوانٍ.")
    else:
        notes.append("نسبة تفاعل جيدة — استمر على نفس نمط أفضل الفيديوهات.")
    if report["top_by_views"]:
        best = report["top_by_views"][0]
        notes.append("أفضل فيديو: «{}» — اصنع محتوى مشابهاً له.".format(best["title"][:40]))
    return notes
