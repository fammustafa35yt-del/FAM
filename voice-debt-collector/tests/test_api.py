from fastapi.testclient import TestClient

import app.compliance as compliance
import app.routes.calls as calls_routes
from app.main import app
from app.schemas import AgentReply, CallOutcome

client = TestClient(app)

CUSTOMER_PAYLOAD = {
    "name": "أحمد محمد",
    "phone_number": "+966500000000",
    "debt_amount": 1500,
    "currency": "SAR",
    "last_payment_date": "2026-05-01",
    "due_date": "2026-06-01",
}


def test_create_customer_rejects_bad_phone_format():
    bad = dict(CUSTOMER_PAYLOAD, phone_number="0500000000")
    resp = client.post("/customers", json=bad)
    assert resp.status_code == 422


def test_create_customer_and_trigger_call(monkeypatch):
    monkeypatch.setattr(calls_routes, "place_call", lambda phone, call_id: "CA_fake_sid")
    monkeypatch.setattr(compliance, "within_calling_window", lambda now=None: True)
    monkeypatch.setattr("app.routes.calls.within_calling_window", lambda now=None: True)

    resp = client.post("/customers", json=CUSTOMER_PAYLOAD)
    assert resp.status_code == 201
    customer = resp.json()

    resp = client.post(f"/calls?customer_id={customer['id']}")
    assert resp.status_code == 201
    call = resp.json()
    assert call["status"] == "ringing"
    assert call["twilio_call_sid"] == "CA_fake_sid"


def test_trigger_call_blocked_outside_window(monkeypatch):
    monkeypatch.setattr("app.routes.calls.within_calling_window", lambda now=None: False)
    resp = client.post("/customers", json=CUSTOMER_PAYLOAD)
    customer = resp.json()

    resp = client.post(f"/calls?customer_id={customer['id']}")
    assert resp.status_code == 409


def test_trigger_call_blocked_for_opted_out_customer(monkeypatch):
    from app import repository as repo

    monkeypatch.setattr("app.routes.calls.within_calling_window", lambda now=None: True)
    resp = client.post("/customers", json=CUSTOMER_PAYLOAD)
    customer_id = resp.json()["id"]
    repo.set_do_not_call(customer_id, True)

    resp = client.post(f"/calls?customer_id={customer_id}")
    assert resp.status_code == 409


def test_full_call_flow_promise_to_pay(monkeypatch):
    import app.routes.twilio_webhooks as webhooks

    monkeypatch.setattr(calls_routes, "place_call", lambda phone, call_id: "CA_fake_sid")
    monkeypatch.setattr("app.routes.calls.within_calling_window", lambda now=None: True)

    customer = client.post("/customers", json=CUSTOMER_PAYLOAD).json()
    call = client.post(f"/calls?customer_id={customer['id']}").json()
    call_id = call["id"]

    monkeypatch.setattr(
        webhooks,
        "opening_line",
        lambda customer: AgentReply(
            message="مرحباً، هل أتحدث مع أحمد؟", end_call=False
        ),
    )
    resp = client.post(f"/twiml/start/{call_id}")
    assert resp.status_code == 200
    assert "Gather" in resp.text

    monkeypatch.setattr(
        webhooks,
        "generate_reply",
        lambda customer, history, customer_utterance: AgentReply(
            message="تم تسجيل وعدك بالدفع، شكراً لك.",
            end_call=True,
            outcome=CallOutcome.PROMISE_TO_PAY,
            promised_amount=1500,
            promised_date="2026-08-01",
        ),
    )
    resp = client.post(f"/twiml/respond/{call_id}", data={"SpeechResult": "سأدفع بتاريخ الأول من أغسطس"})
    assert resp.status_code == 200
    assert "Hangup" in resp.text

    final_call = client.get(f"/calls/{call_id}").json()
    assert final_call["status"] == "completed"
    assert final_call["outcome"] == "promise_to_pay"
    assert final_call["promised_amount"] == 1500

    turns = client.get(f"/calls/{call_id}/turns").json()
    speakers = [t["speaker"] for t in turns]
    assert speakers == ["agent", "customer", "agent"]


def test_no_speech_input_ends_call_gracefully(monkeypatch):
    monkeypatch.setattr(calls_routes, "place_call", lambda phone, call_id: "CA_fake_sid")
    monkeypatch.setattr("app.routes.calls.within_calling_window", lambda now=None: True)

    customer = client.post("/customers", json=CUSTOMER_PAYLOAD).json()
    call = client.post(f"/calls?customer_id={customer['id']}").json()
    call_id = call["id"]

    import app.routes.twilio_webhooks as webhooks

    monkeypatch.setattr(
        webhooks,
        "opening_line",
        lambda customer: AgentReply(message="مرحباً", end_call=False),
    )
    client.post(f"/twiml/start/{call_id}")

    resp = client.post(f"/twiml/respond/{call_id}", data={"SpeechResult": ""})
    assert resp.status_code == 200
    assert "Hangup" in resp.text

    final_call = client.get(f"/calls/{call_id}").json()
    assert final_call["outcome"] == "no_answer"
