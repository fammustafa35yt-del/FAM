"""Conversation brain: turns (customer speech -> what to say next) using Claude.

The model is always forced to answer through the `respond_to_customer` tool so
every turn comes back as structured data (spoken line + call-control decision)
instead of free text we'd have to parse.
"""
from __future__ import annotations

import json
from typing import Optional

import anthropic

from app.config import settings
from app.schemas import AgentReply, CallOutcome

_client: Optional[anthropic.Anthropic] = None


def _get_client() -> anthropic.Anthropic:
    global _client
    if _client is None:
        _client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
    return _client


RESPOND_TOOL = {
    "name": "respond_to_customer",
    "description": "Say the next line to the customer and report the call-control decision.",
    "input_schema": {
        "type": "object",
        "properties": {
            "message": {
                "type": "string",
                "description": "The exact sentence(s) to speak to the customer next, in the "
                "call language. Keep it short (1-3 sentences), natural to read aloud, "
                "no markdown, no numbers-as-digits-only formatting issues for TTS.",
            },
            "end_call": {
                "type": "boolean",
                "description": "True if this message should be the last thing said before "
                "hanging up (goodbye / farewell already included in `message`).",
            },
            "outcome": {
                "type": "string",
                "enum": [o.value for o in CallOutcome],
                "description": "Required when end_call is true: the result of the call.",
            },
            "promised_amount": {
                "type": "number",
                "description": "If the customer promised to pay a specific amount, put it here.",
            },
            "promised_date": {
                "type": "string",
                "description": "ISO date (YYYY-MM-DD) if the customer promised a payment date.",
            },
        },
        "required": ["message", "end_call"],
    },
}


def _system_prompt(customer: dict) -> str:
    return f"""أنت مساعد صوتي آلي يعمل لصالح "{settings.company_name}" ومهمتك إجراء مكالمة
مع عميل متأخر عن سداد دفعة، بأسلوب مهني، محترم، وهادئ تماماً.

بيانات الحساب:
- اسم العميل: {customer['name']}
- المبلغ المستحق: {customer['debt_amount']} {customer['currency']}
- تاريخ آخر دفعة: {customer.get('last_payment_date') or 'غير مسجل'}
- تاريخ الاستحقاق: {customer.get('due_date') or 'غير مسجل'}

قواعد إلزامية يجب الالتزام بها في كل رد:
1. في أول رد فقط: أفصح أن هذه مكالمة آلية مسجّلة من "{settings.company_name}" بخصوص حساب متأخر
   السداد، وتأكد من التحدث مع الشخص الصحيح قبل ذكر أي تفاصيل مالية.
2. لا تهدد العميل أبداً، ولا تذكر إجراءات قانونية أو نتائج مبالغ فيها أو غير مؤكدة.
3. كن متفهماً لظروف العميل، واعرض خيارات عملية: الدفع الكامل الآن، خطة تقسيط، أو تحديد موعد
   دفع جديد.
4. أجب عن أي سؤال يطرحه العميل عن الدين (المبلغ، تاريخ آخر دفعة، سبب الاتصال) بدقة من البيانات
   أعلاه فقط. إن كان السؤال خارج هذه البيانات، أخبره أن ممثلاً بشرياً سيتواصل معه لاحقاً.
5. إن طلب العميل التحدث مع شخص حقيقي: وافق فوراً، اشكره، واختم المكالمة بـ outcome
   "asked_for_human".
6. إن طلب العميل عدم الاتصال به مرة أخرى (وقف الاتصال/الإزعاج): اعتذر، أكّد أنه لن يتم الاتصال
   به مرة أخرى بخصوص هذا الأمر آلياً، واختم بـ outcome "opted_out".
7. إن أنكر العميل الدين أو قال إنه سدده بالفعل: دوّن ذلك بأدب واختم بـ outcome "dispute" أو
   "already_paid" حسب الحالة، دون جدال معه.
8. إن التزم العميل بمبلغ و/أو تاريخ للدفع: سجله في promised_amount/promised_date واختم بـ
   outcome "promise_to_pay".
9. حافظ على كل رد قصيراً (جملة إلى ثلاث جمل) لأنه سيُقرأ بصوت آلي، وتجنب أي رموز أو تنسيق غير
   قابل للنطق.
10. لا تُنهِ المكالمة قبل الوصول لنتيجة واضحة، لكن إذا تجاوزت المكالمة عدداً معقولاً من الردود
    دون نتيجة، اختم بأدب بـ outcome "callback_requested".
11. أجب دائماً عبر أداة respond_to_customer فقط، بلا أي نص خارجها."""


def opening_line(customer: dict) -> AgentReply:
    return generate_reply(customer=customer, history=[], customer_utterance=None)


def generate_reply(
    customer: dict,
    history: list[dict],
    customer_utterance: Optional[str],
) -> AgentReply:
    """history: list of {"speaker": "agent"|"customer", "text": str} prior turns."""
    messages = []
    for turn in history:
        role = "assistant" if turn["speaker"] == "agent" else "user"
        messages.append({"role": role, "content": turn["text"]})

    if customer_utterance is None:
        messages.append(
            {
                "role": "user",
                "content": "[بدء المكالمة - لم يتحدث العميل بعد. ابدأ بالإفصاح والتحقق من الهوية.]",
            }
        )
    else:
        messages.append({"role": "user", "content": customer_utterance})

    response = _get_client().messages.create(
        model=settings.anthropic_model,
        max_tokens=500,
        system=_system_prompt(customer),
        tools=[RESPOND_TOOL],
        tool_choice={"type": "tool", "name": "respond_to_customer"},
        messages=messages,
    )

    for block in response.content:
        if block.type == "tool_use" and block.name == "respond_to_customer":
            return AgentReply.model_validate(block.input)

    raise RuntimeError("Model did not return a respond_to_customer tool call")
