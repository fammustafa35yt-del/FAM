"""إعدادات البرنامج — تُقرأ من ملف .env أو من متغيرات البيئة."""

import os

from dotenv import load_dotenv

load_dotenv()

ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY", "")

TWILIO_ACCOUNT_SID = os.environ.get("TWILIO_ACCOUNT_SID", "")
TWILIO_AUTH_TOKEN = os.environ.get("TWILIO_AUTH_TOKEN", "")
TWILIO_FROM_NUMBER = os.environ.get("TWILIO_FROM_NUMBER", "")

BASE_URL = os.environ.get("BASE_URL", "http://localhost:5000").rstrip("/")

COMPANY_NAME = os.environ.get("COMPANY_NAME", "شركة التحصيل")

# Polly.Hala-Neural = عربي خليجي (لغته ar-AE)، Polly.Zeina = فصحى (لغتها arb)
TTS_VOICE = os.environ.get("TTS_VOICE", "Polly.Hala-Neural")
TTS_LANGUAGE = os.environ.get("TTS_LANGUAGE", "ar-AE")
SPEECH_LANGUAGE = os.environ.get("SPEECH_LANGUAGE", "ar-SA")


def validate() -> list[str]:
    """يرجع قائمة بالإعدادات الناقصة."""
    missing = []
    for name in ("ANTHROPIC_API_KEY", "TWILIO_ACCOUNT_SID", "TWILIO_AUTH_TOKEN", "TWILIO_FROM_NUMBER"):
        if not globals()[name]:
            missing.append(name)
    return missing
