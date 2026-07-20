"""إجراء مكالمة تحصيل على زبون.

الاستخدام — زبون واحد مباشرة:
  python make_call.py --phone +9665xxxxxxxx --name "أحمد" \
      --debt 4500 --last-payment-date 2026-05-10 --last-payment-amount 500

أو مجموعة زبائن من ملف:
  python make_call.py --file customers.json
"""

import argparse
import json
import sys
import time
from urllib.parse import urlencode

from twilio.rest import Client

import config


def start_call(client: Client, customer: dict) -> str:
    """ينشئ مكالمة Twilio ويمرر بيانات الزبون لخادم المحادثة عبر الرابط."""
    params = urlencode({
        "name": customer.get("name", ""),
        "phone": customer["phone"],
        "debt_amount": str(customer.get("debt_amount", "")),
        "last_payment_date": customer.get("last_payment_date", ""),
        "last_payment_amount": str(customer.get("last_payment_amount", "")),
        "installment": str(customer.get("installment", "")),
        "currency": customer.get("currency", "ريال"),
    })
    call = client.calls.create(
        to=customer["phone"],
        from_=config.TWILIO_FROM_NUMBER,
        url=f"{config.BASE_URL}/voice?{params}",
        method="POST",
    )
    return call.sid


def main():
    parser = argparse.ArgumentParser(description="إجراء مكالمة تحصيل ديون بالذكاء الاصطناعي")
    parser.add_argument("--phone", help="رقم هاتف الزبون بالصيغة الدولية مثل ‎+9665xxxxxxxx")
    parser.add_argument("--name", default="عميلنا العزيز", help="اسم الزبون")
    parser.add_argument("--debt", help="قيمة الدين المستحق")
    parser.add_argument("--last-payment-date", default="غير معروف", help="تاريخ آخر دفعة")
    parser.add_argument("--last-payment-amount", default="غير معروف", help="مبلغ آخر دفعة")
    parser.add_argument("--installment", default="", help="قيمة الدفعة الشهرية المتفق عليها")
    parser.add_argument("--currency", default="ريال", help="العملة")
    parser.add_argument("--file", help="ملف JSON يحتوي قائمة زبائن للاتصال بهم")
    parser.add_argument("--delay", type=float, default=5.0, help="ثوانٍ بين مكالمة وأخرى عند استخدام --file")
    args = parser.parse_args()

    missing = config.validate()
    if missing:
        sys.exit(f"إعدادات ناقصة في .env: {', '.join(missing)}")

    if args.file:
        customers = json.loads(open(args.file, encoding="utf-8").read())
    elif args.phone and args.debt:
        customers = [{
            "phone": args.phone,
            "name": args.name,
            "debt_amount": args.debt,
            "last_payment_date": args.last_payment_date,
            "last_payment_amount": args.last_payment_amount,
            "installment": args.installment,
            "currency": args.currency,
        }]
    else:
        parser.error("حدد --phone و --debt لزبون واحد، أو --file لملف زبائن")

    client = Client(config.TWILIO_ACCOUNT_SID, config.TWILIO_AUTH_TOKEN)
    for i, customer in enumerate(customers):
        sid = start_call(client, customer)
        print(f"📞 تم بدء الاتصال بـ {customer.get('name')} ({customer['phone']}) — CallSid: {sid}")
        if i < len(customers) - 1:
            time.sleep(args.delay)


if __name__ == "__main__":
    main()
