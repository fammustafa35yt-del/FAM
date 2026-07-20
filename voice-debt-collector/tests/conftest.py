import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

os.environ.setdefault("DATABASE_PATH", "./data/test_calls.db")
os.environ.setdefault("ANTHROPIC_API_KEY", "test-key")
os.environ.setdefault("TWILIO_ACCOUNT_SID", "ACtest")
os.environ.setdefault("TWILIO_AUTH_TOKEN", "test-token")
os.environ.setdefault("TWILIO_FROM_NUMBER", "+15550000000")
os.environ.setdefault("PUBLIC_BASE_URL", "https://example.test")

import pytest

from app.db import _db_path, init_db


@pytest.fixture(autouse=True)
def fresh_db():
    db_file = Path(_db_path())
    if db_file.exists():
        db_file.unlink()
    init_db()
    yield
    if db_file.exists():
        db_file.unlink()
