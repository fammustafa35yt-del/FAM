from datetime import date
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field, field_validator


class CallOutcome(str, Enum):
    PROMISE_TO_PAY = "promise_to_pay"
    ALREADY_PAID = "already_paid"
    DISPUTE = "dispute"
    REFUSED = "refused"
    CALLBACK_REQUESTED = "callback_requested"
    ASKED_FOR_HUMAN = "asked_for_human"
    OPTED_OUT = "opted_out"
    NO_ANSWER = "no_answer"
    VOICEMAIL = "voicemail"
    UNDETERMINED = "undetermined"


class CustomerCreate(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    phone_number: str = Field(min_length=6, max_length=32)
    debt_amount: float = Field(gt=0)
    currency: str = Field(default="SAR", min_length=3, max_length=3)
    last_payment_date: Optional[date] = None
    due_date: Optional[date] = None

    @field_validator("phone_number")
    @classmethod
    def must_be_e164(cls, v: str) -> str:
        v = v.strip()
        if not v.startswith("+") or not v[1:].isdigit():
            raise ValueError("phone_number must be in E.164 format, e.g. +9665XXXXXXXX")
        return v


class CustomerOut(BaseModel):
    id: int
    name: str
    phone_number: str
    debt_amount: float
    currency: str
    last_payment_date: Optional[str] = None
    due_date: Optional[str] = None
    do_not_call: bool


class CallOut(BaseModel):
    id: int
    customer_id: int
    twilio_call_sid: Optional[str] = None
    status: str
    outcome: Optional[str] = None
    promised_amount: Optional[float] = None
    promised_date: Optional[str] = None
    turn_count: int


class TurnOut(BaseModel):
    turn_index: int
    speaker: str
    text: str


class AgentReply(BaseModel):
    """Structured shape the LLM must return for every conversational turn."""

    message: str = Field(description="What to say to the customer next, in the call language.")
    end_call: bool = Field(description="True if the call should end after this line.")
    outcome: Optional[CallOutcome] = Field(
        default=None, description="Set only when end_call is true."
    )
    promised_amount: Optional[float] = Field(default=None, ge=0)
    promised_date: Optional[str] = Field(default=None, description="ISO date, if promised.")
