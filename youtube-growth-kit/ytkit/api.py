"""عميل خفيف لـ YouTube Data API v3 (يعتمد على requests فقط)."""
import re
import time

try:
    import requests
except ImportError:  # رسالة واضحة بدل تتبّع غامض
    raise SystemExit("[!] مكتبة requests غير مثبّتة. شغّل:  pip install -r requirements.txt")

API_BASE = "https://www.googleapis.com/youtube/v3"

_DURATION_RE = re.compile(
    r"P(?:(?P<days>\d+)D)?T(?:(?P<h>\d+)H)?(?:(?P<m>\d+)M)?(?:(?P<s>\d+)S)?"
)


class YouTubeAPIError(Exception):
    pass


def parse_duration_seconds(iso):
    """يحوّل مدّة ISO-8601 (مثل PT1M30S) إلى ثوانٍ."""
    if not iso:
        return 0
    match = _DURATION_RE.fullmatch(iso)
    if not match:
        return 0
    parts = match.groupdict()
    days = int(parts["days"] or 0)
    h = int(parts["h"] or 0)
    m = int(parts["m"] or 0)
    s = int(parts["s"] or 0)
    return days * 86400 + h * 3600 + m * 60 + s


class YouTubeClient:
    def __init__(self, api_key, retries=3):
        self.api_key = api_key
        self.retries = retries
        self.session = requests.Session()

    def _get(self, endpoint, params):
        params = dict(params)
        params["key"] = self.api_key
        url = "{}/{}".format(API_BASE, endpoint)
        last_err = None
        for attempt in range(self.retries):
            try:
                resp = self.session.get(url, params=params, timeout=30)
            except requests.RequestException as exc:
                last_err = exc
                time.sleep(2 ** attempt)
                continue
            if resp.status_code == 200:
                return resp.json()
            # أخطاء الحصّة/المفتاح لا فائدة من إعادتها
            if resp.status_code in (400, 401, 403):
                try:
                    msg = resp.json()["error"]["message"]
                except Exception:
                    msg = resp.text[:300]
                raise YouTubeAPIError(
                    "خطأ من الـ API ({}): {}".format(resp.status_code, msg)
                )
            last_err = YouTubeAPIError("HTTP {}".format(resp.status_code))
            time.sleep(2 ** attempt)
        raise YouTubeAPIError("فشل الاتصال بعد عدة محاولات: {}".format(last_err))

    # ---- القنوات ----
    def get_channel_by_handle(self, handle):
        handle = handle.lstrip("@")
        data = self._get("channels", {
            "part": "snippet,statistics,contentDetails",
            "forHandle": handle,
        })
        items = data.get("items") or []
        return items[0] if items else None

    def get_channel_by_id(self, channel_id):
        data = self._get("channels", {
            "part": "snippet,statistics,contentDetails",
            "id": channel_id,
        })
        items = data.get("items") or []
        return items[0] if items else None

    @staticmethod
    def uploads_playlist_id(channel):
        return channel["contentDetails"]["relatedPlaylists"]["uploads"]

    # ---- الفيديوهات ----
    def playlist_video_ids(self, playlist_id, limit=50):
        ids, token = [], None
        while len(ids) < limit:
            params = {
                "part": "contentDetails",
                "playlistId": playlist_id,
                "maxResults": min(50, limit - len(ids)),
            }
            if token:
                params["pageToken"] = token
            data = self._get("playlistItems", params)
            for item in data.get("items", []):
                ids.append(item["contentDetails"]["videoId"])
            token = data.get("nextPageToken")
            if not token:
                break
        return ids

    def get_videos(self, video_ids):
        """يجلب تفاصيل فيديوهات (دفعات 50)."""
        out = []
        for i in range(0, len(video_ids), 50):
            chunk = video_ids[i:i + 50]
            data = self._get("videos", {
                "part": "snippet,statistics,contentDetails",
                "id": ",".join(chunk),
            })
            out.extend(data.get("items", []))
        return out

    # ---- البحث ----
    def search(self, query, limit=15, order="relevance", video_only=True,
               published_after=None):
        params = {
            "part": "snippet",
            "q": query,
            "maxResults": min(50, limit),
            "order": order,
        }
        if video_only:
            params["type"] = "video"
        if published_after:
            params["publishedAfter"] = published_after
        data = self._get("search", params)
        return data.get("items", [])
