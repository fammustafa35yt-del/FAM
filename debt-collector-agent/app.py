"""خادم المكالمات: يستقبل Webhooks من Twilio ويدير المحادثة الصوتية.

المسارات:
  POST /voice   — بداية المكالمة: تحية افتتاحية ثم استماع لكلام الزبون
  POST /respond — استقبال كلام الزبون (تحويل صوت إلى نص من Twilio) والرد عليه
"""

import logging

from flask import Flask, request
from twilio.twiml.voice_response import VoiceResponse, Gather

import config
from agent import CollectionAgent, Customer

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("debt-collector")

app = Flask(__name__)

# جلسات المكالمات النشطة: CallSid -> CollectionAgent
sessions: dict[str, CollectionAgent] = {}


def say(vr, text: str):
    vr.say(text, voice=config.TTS_VOICE, language=config.TTS_LANGUAGE)


def gather_speech(vr: VoiceResponse, prompt_text: str | None = None) -> VoiceResponse:
    """يضيف قراءة النص ثم الاستماع لرد الزبون."""
    gather = Gather(
        input="speech",
        language=config.SPEECH_LANGUAGE,
        action="/respond",
        method="POST",
        speech_timeout="auto",
        timeout=6,
    )
    if prompt_text:
        say(gather, prompt_text)
    vr.append(gather)
    # لم يتكلم الزبون — نعيد المحاولة مرة عبر /respond بدون نص
    vr.redirect("/respond?retry=1", method="POST")
    return vr


@app.route("/voice", methods=["POST"])
def voice():
    """بداية المكالمة — بيانات الزبون تصل في باراميترات الرابط من make_call.py."""
    call_sid = request.form.get("CallSid", "")
    customer = Customer(
        name=request.args.get("name", "عميلنا العزيز"),
        phone=request.args.get("phone", request.form.get("To", "")),
        debt_amount=request.args.get("debt_amount", ""),
        last_payment_date=request.args.get("last_payment_date", "غير معروف"),
        last_payment_amount=request.args.get("last_payment_amount", "غير معروف"),
        installment=request.args.get("installment", ""),
        currency=request.args.get("currency", "ريال"),
    )
    ai = CollectionAgent(customer=customer)
    sessions[call_sid] = ai
    log.info("بدء مكالمة %s مع %s (دين: %s)", call_sid, customer.name, customer.debt_amount)

    reply = ai.greeting()
    vr = VoiceResponse()
    if reply.end_call:
        say(vr, reply.text)
        vr.hangup()
    else:
        gather_speech(vr, reply.text)
    return str(vr), 200, {"Content-Type": "text/xml"}


@app.route("/respond", methods=["POST"])
def respond():
    call_sid = request.form.get("CallSid", "")
    speech = (request.form.get("SpeechResult") or "").strip()
    ai = sessions.get(call_sid)
    vr = VoiceResponse()

    if ai is None:
        say(vr, "عذراً، انتهت الجلسة. سنتواصل معك لاحقاً. مع السلامة.")
        vr.hangup()
        return str(vr), 200, {"Content-Type": "text/xml"}

    if not speech:
        # صمت من الزبون
        if request.args.get("retry"):
            gather_speech(vr, "هل ما زلت معي؟ تفضل.")
        else:
            say(vr, "لم أسمعك جيداً. سنتواصل معك في وقت آخر. شكراً لك ومع السلامة.")
            vr.hangup()
            sessions.pop(call_sid, None)
        return str(vr), 200, {"Content-Type": "text/xml"}

    log.info("الزبون [%s]: %s", call_sid, speech)
    reply = ai.respond(speech)
    log.info("المساعد [%s]%s: %s", call_sid, " (تحويل لموظف)" if reply.needs_human else "", reply.text)

    if reply.needs_human:
        # هنا يمكن ربط إشعار للفريق البشري (بريد، Slack، CRM...)
        log.warning("مكالمة %s تحتاج متابعة موظف بشري — الزبون: %s", call_sid, ai.customer.name)

    if reply.end_call:
        say(vr, reply.text)
        vr.hangup()
        sessions.pop(call_sid, None)
    else:
        gather_speech(vr, reply.text)
    return str(vr), 200, {"Content-Type": "text/xml"}


@app.route("/health", methods=["GET"])
def health():
    return {"status": "ok", "active_calls": len(sessions)}


if __name__ == "__main__":
    missing = config.validate()
    if missing:
        raise SystemExit(f"إعدادات ناقصة في .env: {', '.join(missing)}")
    app.run(host="0.0.0.0", port=5000)
