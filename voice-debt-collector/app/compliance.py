from datetime import datetime

from app.config import settings


def within_calling_window(now: datetime | None = None) -> bool:
    """Very basic local-hours guardrail. Callers are responsible for knowing
    the customer's actual timezone; this only checks the server's local hour
    against the configured window, which is not a substitute for real
    jurisdiction-specific compliance review."""
    now = now or datetime.now()
    return settings.call_window_start_hour <= now.hour < settings.call_window_end_hour
