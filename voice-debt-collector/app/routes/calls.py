from fastapi import APIRouter, HTTPException

from app import repository as repo
from app.compliance import within_calling_window
from app.schemas import CallOut, CustomerCreate, CustomerOut, TurnOut
from app.twilio_client import place_call

router = APIRouter()


@router.post("/customers", response_model=CustomerOut, status_code=201)
def create_customer(data: CustomerCreate):
    customer_id = repo.create_customer(data)
    return _customer_out(repo.get_customer(customer_id))


@router.get("/customers", response_model=list[CustomerOut])
def list_customers():
    return [_customer_out(c) for c in repo.list_customers()]


@router.post("/calls", response_model=CallOut, status_code=201)
def trigger_call(customer_id: int):
    customer = repo.get_customer(customer_id)
    if not customer:
        raise HTTPException(404, "customer not found")
    if customer["do_not_call"]:
        raise HTTPException(409, "customer opted out of automated calls")
    if not within_calling_window():
        raise HTTPException(409, "outside allowed calling window")

    call_id = repo.create_call(customer_id)
    call_sid = place_call(customer["phone_number"], call_id)
    repo.set_call_sid(call_id, call_sid)
    return _call_out(repo.get_call(call_id))


@router.get("/calls", response_model=list[CallOut])
def list_calls():
    return [_call_out(c) for c in repo.list_calls()]


@router.get("/calls/{call_id}", response_model=CallOut)
def get_call(call_id: int):
    call = repo.get_call(call_id)
    if not call:
        raise HTTPException(404, "call not found")
    return _call_out(call)


@router.get("/calls/{call_id}/turns", response_model=list[TurnOut])
def get_call_turns(call_id: int):
    if not repo.get_call(call_id):
        raise HTTPException(404, "call not found")
    return [
        TurnOut(turn_index=t["turn_index"], speaker=t["speaker"], text=t["text"])
        for t in repo.get_turns(call_id)
    ]


def _customer_out(c: dict) -> CustomerOut:
    return CustomerOut(
        id=c["id"],
        name=c["name"],
        phone_number=c["phone_number"],
        debt_amount=c["debt_amount"],
        currency=c["currency"],
        last_payment_date=c["last_payment_date"],
        due_date=c["due_date"],
        do_not_call=bool(c["do_not_call"]),
    )


def _call_out(c: dict) -> CallOut:
    return CallOut(
        id=c["id"],
        customer_id=c["customer_id"],
        twilio_call_sid=c["twilio_call_sid"],
        status=c["status"],
        outcome=c["outcome"],
        promised_amount=c["promised_amount"],
        promised_date=c["promised_date"],
        turn_count=c["turn_count"],
    )
