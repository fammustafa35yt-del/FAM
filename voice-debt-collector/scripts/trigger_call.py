#!/usr/bin/env python3
"""Create a customer record and immediately place a call, against a running
API server.

Usage:
    python scripts/trigger_call.py \
        --name "أحمد" --phone +9665XXXXXXXX \
        --amount 1500 --currency SAR \
        --last-payment 2026-05-01 --due-date 2026-06-01 \
        --api http://localhost:8000
"""
import argparse
import sys
import urllib.error
import urllib.request
import json


def post(api: str, path: str, payload: dict) -> dict:
    req = urllib.request.Request(
        f"{api}{path}",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code}: {e.read().decode()}", file=sys.stderr)
        raise


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--name", required=True)
    p.add_argument("--phone", required=True, help="E.164 format, e.g. +9665XXXXXXXX")
    p.add_argument("--amount", required=True, type=float)
    p.add_argument("--currency", default="SAR")
    p.add_argument("--last-payment", dest="last_payment")
    p.add_argument("--due-date", dest="due_date")
    p.add_argument("--api", default="http://localhost:8000")
    args = p.parse_args()

    customer = post(
        args.api,
        "/customers",
        {
            "name": args.name,
            "phone_number": args.phone,
            "debt_amount": args.amount,
            "currency": args.currency,
            "last_payment_date": args.last_payment,
            "due_date": args.due_date,
        },
    )
    print(f"Created customer #{customer['id']}")

    call = post(args.api, f"/calls?customer_id={customer['id']}", {})
    print(f"Call #{call['id']} placed, status={call['status']}")


if __name__ == "__main__":
    main()
