"""تحميل الإعدادات من config.json أو متغيّرات البيئة."""
import json
import os

_DEFAULTS = {
    "youtube_api_key": "",
    "my_channel_handle": "@FAM-ROBLOX35",
    "niche": "roblox",
    "language": "ar",
    "timezone_offset_hours": 3,
}


def load_config(path=None):
    """يحمّل الإعدادات. الأولوية: متغيّر البيئة YOUTUBE_API_KEY > config.json > الافتراضي."""
    cfg = dict(_DEFAULTS)

    # ابحث عن config.json بجوار جذر المشروع إن لم يُحدّد مسار
    if path is None:
        here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        candidate = os.path.join(here, "config.json")
        if os.path.exists(candidate):
            path = candidate

    if path and os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        for key in _DEFAULTS:
            if key in data and data[key] not in (None, ""):
                cfg[key] = data[key]

    # متغيّر البيئة يتجاوز الملف لمفتاح الـ API
    env_key = os.environ.get("YOUTUBE_API_KEY")
    if env_key:
        cfg["youtube_api_key"] = env_key

    return cfg


def require_api_key(cfg):
    """يتأكد من وجود مفتاح API ويرفع خطأ واضح إن لم يوجد."""
    key = cfg.get("youtube_api_key", "").strip()
    if not key or key.startswith("ضع_"):
        raise SystemExit(
            "\n[!] لا يوجد مفتاح YouTube Data API.\n"
            "    1) أنشئ مفتاحاً من: https://console.cloud.google.com/apis/credentials\n"
            "    2) فعّل: YouTube Data API v3\n"
            "    3) ضعه في config.json (انسخه من config.example.json)\n"
            "       أو صدّره:  export YOUTUBE_API_KEY=مفتاحك\n"
        )
    return key
