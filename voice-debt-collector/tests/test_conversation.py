from types import SimpleNamespace
from unittest.mock import MagicMock

import app.conversation as conversation
from app.schemas import CallOutcome


def _fake_tool_response(input_payload: dict):
    block = SimpleNamespace(type="tool_use", name="respond_to_customer", input=input_payload)
    return SimpleNamespace(content=[block])


def test_opening_line_forces_disclosure_tool_call(monkeypatch):
    fake_client = MagicMock()
    fake_client.messages.create.return_value = _fake_tool_response(
        {
            "message": "مرحباً، هذه مكالمة آلية مسجلة بخصوص حساب متأخر السداد.",
            "end_call": False,
        }
    )
    monkeypatch.setattr(conversation, "_get_client", lambda: fake_client)

    customer = {
        "name": "أحمد",
        "debt_amount": 1500,
        "currency": "SAR",
        "last_payment_date": "2026-05-01",
        "due_date": "2026-06-01",
    }
    reply = conversation.opening_line(customer)

    assert reply.end_call is False
    assert "مكالمة آلية" in reply.message

    _, kwargs = fake_client.messages.create.call_args
    assert kwargs["tool_choice"] == {"type": "tool", "name": "respond_to_customer"}
    assert kwargs["tools"][0]["name"] == "respond_to_customer"
    assert customer["name"] in kwargs["system"]


def test_generate_reply_parses_promise_to_pay(monkeypatch):
    fake_client = MagicMock()
    fake_client.messages.create.return_value = _fake_tool_response(
        {
            "message": "شكراً لالتزامك، سنسجل الدفع بتاريخ 2026-08-01.",
            "end_call": True,
            "outcome": "promise_to_pay",
            "promised_amount": 1500,
            "promised_date": "2026-08-01",
        }
    )
    monkeypatch.setattr(conversation, "_get_client", lambda: fake_client)

    customer = {
        "name": "أحمد",
        "debt_amount": 1500,
        "currency": "SAR",
        "last_payment_date": "2026-05-01",
        "due_date": "2026-06-01",
    }
    reply = conversation.generate_reply(
        customer=customer,
        history=[{"speaker": "agent", "text": "هل أتحدث مع أحمد؟"}],
        customer_utterance="نعم سأدفع بتاريخ الأول من أغسطس",
    )

    assert reply.end_call is True
    assert reply.outcome == CallOutcome.PROMISE_TO_PAY
    assert reply.promised_amount == 1500
    assert reply.promised_date == "2026-08-01"


def test_generate_reply_raises_if_model_skips_tool(monkeypatch):
    fake_client = MagicMock()
    fake_client.messages.create.return_value = SimpleNamespace(
        content=[SimpleNamespace(type="text", text="oops, plain text")]
    )
    monkeypatch.setattr(conversation, "_get_client", lambda: fake_client)

    try:
        conversation.generate_reply(
            customer={"name": "أحمد", "debt_amount": 1, "currency": "SAR"},
            history=[],
            customer_utterance="hi",
        )
        assert False, "expected RuntimeError"
    except RuntimeError:
        pass
