from twilio.rest import Client

from app.config import settings

_client: Client | None = None


def get_client() -> Client:
    global _client
    if _client is None:
        _client = Client(settings.twilio_account_sid, settings.twilio_auth_token)
    return _client


def place_call(to_phone_number: str, call_id: int) -> str:
    """Dials the customer and points Twilio at our /twiml/start webhook for this call.
    Returns the Twilio Call SID."""
    call = get_client().calls.create(
        to=to_phone_number,
        from_=settings.twilio_from_number,
        url=f"{settings.public_base_url}/twiml/start/{call_id}",
        status_callback=f"{settings.public_base_url}/twiml/status/{call_id}",
        status_callback_event=["initiated", "ringing", "answered", "completed"],
        status_callback_method="POST",
        machine_detection="DetectMessageEnd",
    )
    return call.sid
