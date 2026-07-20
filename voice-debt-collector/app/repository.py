"""CRUD helpers on top of app.db. Keeps SQL out of the route handlers."""
from __future__ import annotations

from typing import Optional

from app.db import get_conn
from app.schemas import AgentReply, CustomerCreate


def create_customer(data: CustomerCreate) -> int:
    with get_conn() as conn:
        cur = conn.execute(
            """INSERT INTO customers
               (name, phone_number, debt_amount, currency, last_payment_date, due_date)
               VALUES (?, ?, ?, ?, ?, ?)""",
            (
                data.name,
                data.phone_number,
                data.debt_amount,
                data.currency,
                data.last_payment_date.isoformat() if data.last_payment_date else None,
                data.due_date.isoformat() if data.due_date else None,
            ),
        )
        return cur.lastrowid


def get_customer(customer_id: int) -> Optional[dict]:
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM customers WHERE id = ?", (customer_id,)).fetchone()
        return dict(row) if row else None


def list_customers() -> list[dict]:
    with get_conn() as conn:
        rows = conn.execute("SELECT * FROM customers ORDER BY id DESC").fetchall()
        return [dict(r) for r in rows]


def set_do_not_call(customer_id: int, value: bool = True) -> None:
    with get_conn() as conn:
        conn.execute("UPDATE customers SET do_not_call = ? WHERE id = ?", (int(value), customer_id))


def create_call(customer_id: int) -> int:
    with get_conn() as conn:
        cur = conn.execute(
            "INSERT INTO calls (customer_id, status) VALUES (?, 'queued')",
            (customer_id,),
        )
        return cur.lastrowid


def get_call(call_id: int) -> Optional[dict]:
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM calls WHERE id = ?", (call_id,)).fetchone()
        return dict(row) if row else None


def list_calls() -> list[dict]:
    with get_conn() as conn:
        rows = conn.execute("SELECT * FROM calls ORDER BY id DESC").fetchall()
        return [dict(r) for r in rows]


def set_call_sid(call_id: int, twilio_call_sid: str) -> None:
    with get_conn() as conn:
        conn.execute(
            "UPDATE calls SET twilio_call_sid = ?, status = 'ringing' WHERE id = ?",
            (twilio_call_sid, call_id),
        )


def set_call_status(call_id: int, status: str) -> None:
    with get_conn() as conn:
        conn.execute("UPDATE calls SET status = ? WHERE id = ?", (status, call_id))


def finalize_call(call_id: int, reply: AgentReply) -> None:
    with get_conn() as conn:
        conn.execute(
            """UPDATE calls
               SET status = 'completed', outcome = ?, promised_amount = ?,
                   promised_date = ?, ended_at = datetime('now')
               WHERE id = ?""",
            (
                reply.outcome.value if reply.outcome else None,
                reply.promised_amount,
                reply.promised_date,
                call_id,
            ),
        )


def add_turn(call_id: int, speaker: str, text: str) -> int:
    with get_conn() as conn:
        turn_index = conn.execute(
            "SELECT COALESCE(MAX(turn_index), -1) + 1 FROM turns WHERE call_id = ?", (call_id,)
        ).fetchone()[0]
        conn.execute(
            "INSERT INTO turns (call_id, turn_index, speaker, text) VALUES (?, ?, ?, ?)",
            (call_id, turn_index, speaker, text),
        )
        conn.execute("UPDATE calls SET turn_count = ? WHERE id = ?", (turn_index + 1, call_id))
        return turn_index


def get_turns(call_id: int) -> list[dict]:
    with get_conn() as conn:
        rows = conn.execute(
            "SELECT * FROM turns WHERE call_id = ? ORDER BY turn_index", (call_id,)
        ).fetchall()
        return [dict(r) for r in rows]
