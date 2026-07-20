# بوت اتصال صوتي آلي بالذكاء الاصطناعي لتحصيل الديون

خدمة مستقلة (FastAPI) تقوم تلقائياً بالاتصال بالعملاء المتأخرين عن سداد
دفعاتهم، وتجري معهم محادثة صوتية طبيعية بالعربية حول الدين المستحق، وترد على
أسئلتهم، وتسجل نتيجة كل مكالمة (وعد بالدفع، نزاع، طلب التحدث مع موظف، رفض
الاتصال مستقبلاً... إلخ).

## المكوّنات

| الطبقة | الأداة |
|---|---|
| الاتصال الهاتفي (طلب الرقم، بث الصوت) | [Twilio Voice](https://www.twilio.com/voice) |
| تحويل كلام العميل إلى نص | التعرف الصوتي المدمج في Twilio (`<Gather input="speech">`) |
| "عقل" المحادثة (فهم الرد وصياغة الرد التالي) | Claude عبر Anthropic API |
| تحويل رد البوت إلى صوت | Amazon Polly (عبر `<Say>` في Twilio) |
| التخزين | SQLite (عملاء، مكالمات، كل جملة في كل مكالمة) |
| الواجهة البرمجية | FastAPI |

المحادثة تتم على شكل أدوار (turn-based): يتحدث البوت جملة أو جملتين، يستمع
لرد العميل عبر `<Gather>`، يرسل نص الرد إلى Claude مع بيانات الدين وتاريخ
المحادثة، ويحصل على رد منظّم (نص للنطق + قرار إنهاء المكالمة أو الاستمرار +
النتيجة المسجَّلة). هذا التصميم لا يحتاج خوادم بث صوت لحظي معقّدة، ويعمل
بشكل موثوق عبر HTTP webhooks عادية.

## التشغيل محلياً

```bash
cd voice-debt-collector
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

cp .env.example .env
# عدّل .env وضع فيه:
#   TWILIO_ACCOUNT_SID / TWILIO_AUTH_TOKEN / TWILIO_FROM_NUMBER (من لوحة Twilio)
#   ANTHROPIC_API_KEY
#   PUBLIC_BASE_URL (رابط https يستطيع Twilio الوصول إليه، انظر أدناه)

uvicorn app.main:app --reload --port 8000
```

Twilio يحتاج أن يصل إلى خادمك عبر رابط عام. في التطوير المحلي استخدم
[ngrok](https://ngrok.com):

```bash
ngrok http 8000
# انسخ رابط https الذي يعطيك إياه ngrok وضعه في PUBLIC_BASE_URL داخل .env،
# ثم أعد تشغيل uvicorn.
```

## تشغيل مكالمة

### عميل واحد

```bash
python scripts/trigger_call.py \
  --name "أحمد محمد" --phone +9665XXXXXXXX \
  --amount 1500 --currency SAR \
  --last-payment 2026-05-01 --due-date 2026-06-01
```

### دفعة عملاء من ملف CSV

```bash
cp scripts/customers.sample.csv my_customers.csv   # عدّله بأرقام حقيقية
python scripts/import_csv.py my_customers.csv --delay 2
```

### مباشرة عبر الـ API

```bash
curl -X POST http://localhost:8000/customers \
  -H 'Content-Type: application/json' \
  -d '{"name":"أحمد محمد","phone_number":"+9665XXXXXXXX","debt_amount":1500,
       "currency":"SAR","last_payment_date":"2026-05-01","due_date":"2026-06-01"}'

curl -X POST "http://localhost:8000/calls?customer_id=1"

curl http://localhost:8000/calls/1
curl http://localhost:8000/calls/1/turns   # نص المحادثة كاملاً، دور بدور
```

## كيف تسير المكالمة

1. `POST /calls?customer_id=...` ينشئ سجل مكالمة ويطلب من Twilio الاتصال
   بالعميل، مشيراً إلى `/twiml/start/{call_id}`.
2. عند الرد، Twilio يطلب TwiML من `/twiml/start` فيبدأ البوت بجملة الإفصاح
   الإلزامية ("مكالمة آلية مسجلة من ...") والتحقق من الهوية، ثم يستمع.
3. كل رد من العميل يُرسل إلى `/twiml/respond/{call_id}`، والذي يمرره مع
   بيانات الدين وتاريخ المحادثة إلى Claude، ويحصل على الجملة التالية وقرار
   الاستمرار/الإنهاء.
4. عند انتهاء المكالمة تُسجَّل النتيجة (`promise_to_pay`, `dispute`,
   `already_paid`, `refused`, `asked_for_human`, `opted_out`,
   `callback_requested`, `no_answer`, ...) مع أي مبلغ/تاريخ التزم به العميل.
5. `/twiml/status/{call_id}` يستقبل تحديثات حالة المكالمة من Twilio (لا رد،
   مشغول، فشل...) ويسجلها إن لم تُسجَّل نتيجة أخرى بالفعل.

## ⚠️ الجوانب القانونية والامتثال — مسؤوليتك

الاتصال الآلي لتحصيل الديون خاضع لقوانين صارمة تختلف من بلد لآخر (مثل قواعد
TCPA/FDCPA في الولايات المتحدة، أو الأنظمة المحلية لجهات حماية المستهلك
والاتصالات في بلدك). هذا الكود يوفر بنية تقنية فقط، وقد ضُمِّنت فيه بعض
الضمانات الأساسية، لكنه **ليس بديلاً عن مراجعة قانونية**:

- **الإفصاح الإلزامي**: أول جملة في كل مكالمة تخبر العميل أنها مكالمة آلية
  مسجّلة (`app/conversation.py`، القاعدة رقم 1). تأكد أن هذا يتوافق مع
  التنظيم في بلدك (بعض الدول تشترط صيغة محددة).
- **إيقاف الاتصال عند الطلب**: إذا طلب العميل عدم الاتصال به مرة أخرى، يُسجَّل
  `do_not_call = true` على حسابه فوراً (`opted_out`)، ويرفض النظام تشغيل أي
  مكالمة جديدة له (`409` من `/calls`). راجع `app/repository.set_do_not_call`.
- **نافذة أوقات الاتصال**: `CALL_WINDOW_START_HOUR` / `CALL_WINDOW_END_HOUR`
  في `.env` يمنعان تشغيل مكالمات خارج ساعات محددة (`app/compliance.py`).
  هذا الفحص **بدائي** (يعتمد على ساعة الخادم المحلية فقط) ولا يعرف المنطقة
  الزمنية الفعلية للعميل — طوّره ليلائم قاعدة عملائك قبل أي استخدام حقيقي.
  لم يُنفَّذ فحص "قائمة عدم الاتصال" الوطنية (مثل Do Not Call Registry) —
  إن كانت مطلوبة في نطاق عملك، أضِفها.
- **عدم التهديد**: يمنع النظام صراحة أي تهديد أو ذكر إجراءات قانونية غير
  مؤكدة ضمن تعليمات النظام (system prompt).
- **تسجيل المكالمات**: تحقق من قوانين بلدك بخصوص تسجيل المكالمات وإبلاغ
  الطرف الآخر (one-party / two-party consent).

**لا تستخدم هذا النظام على عملاء حقيقيين قبل أن يراجعه مختص قانوني/امتثال في
جهتك.**

## هيكل المشروع

```
voice-debt-collector/
  app/
    main.py            نقطة دخول FastAPI
    config.py           الإعدادات من متغيرات البيئة
    db.py / repository.py   طبقة التخزين (SQLite)
    schemas.py           نماذج pydantic
    conversation.py      محرك المحادثة (Claude)
    twilio_client.py      طلب المكالمات عبر Twilio
    twiml.py               بناء ردود TwiML
    compliance.py          فحص نافذة أوقات الاتصال
    routes/
      calls.py             إنشاء عملاء/مكالمات، الاستعلام عنها
      twilio_webhooks.py   استقبال أحداث Twilio أثناء المكالمة
  scripts/
    trigger_call.py        تشغيل مكالمة واحدة من سطر الأوامر
    import_csv.py           تشغيل دفعة مكالمات من CSV
  tests/                    اختبارات (Anthropic و Twilio ممثَّلة بـ mocks)
```

## الاختبارات

```bash
source .venv/bin/activate
pytest -q
```

الاختبارات تستبدل عميلي Anthropic و Twilio بمحاكيات (mocks) — لا تحتاج
مفاتيح API حقيقية ولا تُجري أي اتصال شبكي فعلي.
