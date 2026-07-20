#!/usr/bin/env python3
"""Bulk-import customers from a CSV and place a call for each one.

CSV columns (header required): name,phone_number,debt_amount,currency,
last_payment_date,due_date  (currency/last_payment_date/due_date optional)

Usage:
    python scripts/import_csv.py customers.csv --api http://localhost:8000
"""
import argparse
import csv
import sys
import time

from trigger_call import post  # reuse the tiny HTTP helper


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("csv_path")
    p.add_argument("--api", default="http://localhost:8000")
    p.add_argument(
        "--delay", type=float, default=1.0, help="seconds to wait between calls (rate limiting)"
    )
    args = p.parse_args()

    with open(args.csv_path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        rows = list(reader)

    print(f"Loaded {len(rows)} customers from {args.csv_path}")
    for i, row in enumerate(rows, 1):
        try:
            customer = post(
                args.api,
                "/customers",
                {
                    "name": row["name"],
                    "phone_number": row["phone_number"],
                    "debt_amount": float(row["debt_amount"]),
                    "currency": row.get("currency") or "SAR",
                    "last_payment_date": row.get("last_payment_date") or None,
                    "due_date": row.get("due_date") or None,
                },
            )
            call = post(args.api, f"/calls?customer_id={customer['id']}", {})
            print(f"[{i}/{len(rows)}] {row['name']}: call #{call['id']} -> {call['status']}")
        except Exception as e:  # noqa: BLE001 - keep the batch going on a single bad row
            print(f"[{i}/{len(rows)}] FAILED for {row.get('name')}: {e}", file=sys.stderr)

        if i < len(rows):
            time.sleep(args.delay)


if __name__ == "__main__":
    main()
