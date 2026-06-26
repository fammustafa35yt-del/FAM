"""واجهة سطر الأوامر لأدوات نمو يوتيوب.

أمثلة:
    python -m ytkit.cli analyze
    python -m ytkit.cli seo "تختيم دورز" --game doors
    python -m ytkit.cli competitors "roblox brookhaven" --days 30
    python -m ytkit.cli schedule
    python -m ytkit.cli ideas --count 12 --game "Blox Fruits"
"""
import argparse
import sys

from . import analytics, competitors, ideas, scheduler, seo
from .config import load_config, require_api_key


def _client(cfg):
    from .api import YouTubeClient
    return YouTubeClient(require_api_key(cfg))


def cmd_analyze(args, cfg):
    client = _client(cfg)
    handle = args.handle or cfg["my_channel_handle"]
    report = analytics.analyze_channel(client, handle=handle, video_limit=args.limit)
    print(analytics.render_report(report))


def cmd_seo(args, cfg):
    pack = seo.build_seo_pack(args.topic, game=args.game)
    print(seo.render_seo(pack))


def cmd_competitors(args, cfg):
    client = _client(cfg)
    result = competitors.find_trending(client, args.query, days=args.days, limit=args.limit)
    print(competitors.render_competitors(result))


def cmd_schedule(args, cfg):
    report = None
    if args.live:
        client = _client(cfg)
        handle = args.handle or cfg["my_channel_handle"]
        report = analytics.analyze_channel(client, handle=handle, video_limit=args.limit)
    print(scheduler.render_schedule(
        report=report,
        tz_offset=cfg.get("timezone_offset_hours", 3),
        posts_per_week=args.posts,
    ))


def cmd_ideas(args, cfg):
    print(ideas.render_ideas(count=args.count, game=args.game))


def build_parser():
    p = argparse.ArgumentParser(
        prog="ytkit",
        description="أدوات نمو قناة يوتيوب (شرعية) — تحليلات، SEO، منافسون، جدولة، أفكار.",
    )
    p.add_argument("--config", help="مسار ملف الإعدادات (افتراضي: config.json)")
    sub = p.add_subparsers(dest="command", required=True)

    a = sub.add_parser("analyze", help="تحليل أداء قناتك")
    a.add_argument("--handle", help="معرّف القناة (افتراضي من الإعدادات)")
    a.add_argument("--limit", type=int, default=50, help="عدد آخر الفيديوهات للتحليل")
    a.set_defaults(func=cmd_analyze)

    s = sub.add_parser("seo", help="توليد عناوين/وصف/كلمات مفتاحية")
    s.add_argument("topic", help="موضوع الفيديو، مثلاً: «تختيم دورز»")
    s.add_argument("--game", help="اسم اللعبة (اختياري)")
    s.set_defaults(func=cmd_seo)

    c = sub.add_parser("competitors", help="تحليل المنافسين والمواضيع الرائجة")
    c.add_argument("query", help="كلمة البحث، مثلاً: «roblox blox fruits»")
    c.add_argument("--days", type=int, default=30, help="نافذة الأيام")
    c.add_argument("--limit", type=int, default=20, help="عدد النتائج")
    c.set_defaults(func=cmd_competitors)

    sc = sub.add_parser("schedule", help="خطة نشر وأفضل الأوقات")
    sc.add_argument("--live", action="store_true", help="حلّل أوقاتك الفعلية عبر الـ API")
    sc.add_argument("--handle", help="معرّف القناة (مع --live)")
    sc.add_argument("--limit", type=int, default=50, help="عدد الفيديوهات للتحليل")
    sc.add_argument("--posts", type=int, default=5, help="عدد المنشورات الأسبوعية")
    sc.set_defaults(func=cmd_schedule)

    i = sub.add_parser("ideas", help="أفكار محتوى وصور مصغّرة")
    i.add_argument("--count", type=int, default=10, help="عدد الأفكار")
    i.add_argument("--game", help="اسم اللعبة (اختياري)")
    i.set_defaults(func=cmd_ideas)

    return p


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)
    cfg = load_config(args.config)
    try:
        args.func(args, cfg)
    except KeyboardInterrupt:
        print("\nتم الإلغاء.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
