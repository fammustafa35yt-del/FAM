"""Builds the TwiML documents Twilio expects at each webhook step."""
from twilio.twiml.voice_response import Gather, VoiceResponse

from app.config import settings


def gather_response(say_text: str, action_url: str) -> str:
    """Speak `say_text`, then listen for the customer's speech and POST it to
    `action_url`. If nothing is heard, Twilio retries the same TwiML action
    once (Twilio's default 'no input' fallback is to re-request this URL),
    so a no-input branch is handled by the caller via voicemail/timeout on
    Twilio's status callback rather than here."""
    vr = VoiceResponse()
    gather = Gather(
        input="speech",
        action=action_url,
        method="POST",
        language=settings.call_language,
        speech_timeout="auto",
        timeout=6,
    )
    gather.say(say_text, voice=settings.tts_voice, language=settings.call_language)
    vr.append(gather)
    # Customer said nothing at all: end politely instead of looping forever.
    vr.say(
        "لم يصلنا أي رد، سيتم إنهاء المكالمة. شكراً لوقتكم.",
        voice=settings.tts_voice,
        language=settings.call_language,
    )
    vr.hangup()
    return str(vr)


def say_and_hangup(say_text: str) -> str:
    vr = VoiceResponse()
    vr.say(say_text, voice=settings.tts_voice, language=settings.call_language)
    vr.hangup()
    return str(vr)
