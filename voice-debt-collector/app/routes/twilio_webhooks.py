import logging

from fastapi import APIRouter, HTTPException, Request, Response

from app import repository as repo
from app.conversation import generate_reply, opening_line
from app.schemas import AgentReply, CallOutcome
from app.twiml import gather_response, say_and_hangup

router = APIRouter()
logger = logging.getLogger("twilio_webhooks")


def _load_call_and_customer(call_id: int) -> tuple[dict, dict]:
    call = repo.get_call(call_id)
    if not call:
        raise HTTPException(404, "call not found")
    customer = repo.get_customer(call["customer_id"])
    if not customer:
        raise HTTPException(404, "customer not found")
    return call, customer


def _apply_reply(call_id: int, customer: dict, reply: AgentReply) -> Response:
    repo.add_turn(call_id, "agent", reply.message)

    if reply.outcome == CallOutcome.OPTED_OUT:
        repo.set_do_not_call(customer["id"], True)

    if reply.end_call:
        if reply.outcome is None:
            reply.outcome = CallOutcome.UNDETERMINED
        repo.finalize_call(call_id, reply)
        return Response(content=say_and_hangup(reply.message), media_type="application/xml")

    action_url = f"/twiml/respond/{call_id}"
    return Response(
        content=gather_response(reply.message, action_url), media_type="application/xml"
    )


@router.post("/twiml/start/{call_id}")
def twiml_start(call_id: int):
    call, customer = _load_call_and_customer(call_id)
    repo.set_call_status(call_id, "in-progress")
    reply = opening_line(customer)
    return _apply_reply(call_id, customer, reply)


@router.post("/twiml/respond/{call_id}")
async def twiml_respond(call_id: int, request: Request):
    call, customer = _load_call_and_customer(call_id)
    form = await request.form()
    speech_result = (form.get("SpeechResult") or "").strip()

    if not speech_result:
        # Twilio's speech Gather timed out with no input; end the call gracefully.
        reply = AgentReply(
            message="لم يصلنا أي رد منكم، سنحاول التواصل معكم لاحقاً. شكراً لوقتكم ويوماً سعيداً.",
            end_call=True,
            outcome=CallOutcome.NO_ANSWER,
        )
        return _apply_reply(call_id, customer, reply)

    repo.add_turn(call_id, "customer", speech_result)
    history = [
        {"speaker": t["speaker"], "text": t["text"]} for t in repo.get_turns(call_id)
    ]
    reply = generate_reply(customer=customer, history=history[:-1], customer_utterance=speech_result)
    return _apply_reply(call_id, customer, reply)


@router.post("/twiml/status/{call_id}")
async def twiml_status(call_id: int, request: Request):
    form = await request.form()
    call_status = form.get("CallStatus", "")
    call = repo.get_call(call_id)
    if not call:
        return Response(status_code=204)

    if call_status in ("busy", "failed", "no-answer", "canceled"):
        repo.set_call_status(call_id, call_status)
        if not call["outcome"]:
            reply = AgentReply(message="", end_call=True, outcome=CallOutcome.NO_ANSWER)
            repo.finalize_call(call_id, reply)
    elif call_status == "completed" and call["status"] != "completed":
        repo.set_call_status(call_id, "completed")

    return Response(status_code=204)
