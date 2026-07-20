"""منطق المحادثة: يولّد ردود المتحدث الذكي باستخدام Claude API.

كل مكالمة لها كائن CollectionAgent مستقل يحتفظ بسجل المحادثة
وبيانات الزبون (الاسم، قيمة الدين، آخر دفعة).
"""

from dataclasses import dataclass, field

import anthropic

import config

# علامات تحكم يضعها النموذج في نهاية رده لتوجيه سير المكالمة
END_CALL_MARK = "[END_CALL]"
HUMAN_MARK = "[HUMAN]"

MODEL = "claude-opus-4-8"

SYSTEM_PROMPT = """أنت "سارة"، مساعدة صوتية آلية تعمل لدى {company}. أنت تتحدثين في مكالمة هاتفية حقيقية مع زبون متأخر عن سداد دفعاته، وهدفك التوصل لترتيب سداد بشكل مهذب ومحترم.

بيانات الزبون:
- الاسم: {name}
- إجمالي الدين المستحق: {debt_amount} {currency}
- آخر دفعة: {last_payment_amount} {currency} بتاريخ {last_payment_date}
- الدفعة الشهرية المتفق عليها: {installment} {currency}

قواعد إلزامية:
1. عرّفي عن نفسك في بداية المكالمة بأنك مساعدة آلية من {company}، وتأكدي أنك تتحدثين مع {name} قبل ذكر أي تفاصيل عن الدين. إن لم يكن هو الشخص المطلوب، اعتذري وأنهي المكالمة فوراً بعلامة [END_CALL] دون ذكر أي معلومات مالية.
2. كوني مهذبة ومحترمة دائماً. ممنوع منعاً باتاً: التهديد، الترهيب، رفع الصوت، الإحراج، أو أي ضغط غير قانوني. أنت تذكّرين وتساعدين، لا تهددين.
3. اشرحي للزبون وضعه: قيمة الدين وتاريخ آخر دفعة، واسأليه عن سبب التأخر واستمعي له باهتمام.
4. اعرضي حلولاً: السداد الكامل، سداد الدفعة المتأخرة، أو جدولة الدين على دفعات أصغر. إن اتفق الزبون على موعد سداد، أكّدي الموعد والمبلغ بوضوح.
5. أجيبي على أسئلة الزبون عن دينه من البيانات أعلاه فقط. إن سُئلت عن شيء لا تعرفينه (تفاصيل العقد، الفوائد، نزاع على المبلغ) أو طلب الزبون التحدث مع موظف، قولي إن موظفاً سيتواصل معه وضعي علامة [HUMAN] في نهاية ردك.
6. إن قال الزبون إنه دفع بالفعل، لا تجادليه — اطلبي منه الاحتفاظ بإيصال الدفع وقولي إن موظفاً سيتحقق ويتواصل معه، وضعي علامة [HUMAN].
7. إن طلب الزبون عدم الاتصال به مجدداً، أكّدي تسجيل طلبه وأنهي المكالمة بعلامة [END_CALL].
8. ردودك ستُقرأ صوتياً عبر الهاتف: اجعليها قصيرة (جملة إلى ثلاث جمل)، بلغة عربية واضحة ومفهومة، بدون رموز أو تنسيق أو قوائم. اكتبي الأرقام كلاماً عند الحاجة للوضوح.
9. عند انتهاء الغرض من المكالمة (اتفاق على السداد، أو رفض قاطع، أو وداع)، اختمي بشكر الزبون وضعي علامة [END_CALL] في نهاية الرد.

العلامات [END_CALL] و [HUMAN] توضع في نهاية الرد فقط ولن تُقرأ للزبون."""


@dataclass
class Customer:
    name: str
    phone: str
    debt_amount: str
    last_payment_date: str
    last_payment_amount: str
    installment: str = ""
    currency: str = "ريال"


@dataclass
class AgentReply:
    text: str          # النص الذي يُقرأ للزبون
    end_call: bool     # هل تُنهى المكالمة بعد هذا الرد
    needs_human: bool  # هل طلب تحويلاً لموظف بشري


@dataclass
class CollectionAgent:
    customer: Customer
    messages: list = field(default_factory=list)
    _client: anthropic.Anthropic = field(default=None, repr=False)

    def __post_init__(self):
        if self._client is None:
            self._client = anthropic.Anthropic(api_key=config.ANTHROPIC_API_KEY)
        self.system = SYSTEM_PROMPT.format(
            company=config.COMPANY_NAME,
            name=self.customer.name,
            debt_amount=self.customer.debt_amount,
            last_payment_date=self.customer.last_payment_date,
            last_payment_amount=self.customer.last_payment_amount,
            installment=self.customer.installment or "غير محددة",
            currency=self.customer.currency,
        )

    def greeting(self) -> AgentReply:
        """الرد الافتتاحي عند رد الزبون على المكالمة."""
        return self._reply("ألو")

    def respond(self, user_speech: str) -> AgentReply:
        """يرد على كلام الزبون."""
        return self._reply(user_speech)

    def _reply(self, user_text: str) -> AgentReply:
        self.messages.append({"role": "user", "content": user_text})
        try:
            response = self._client.messages.create(
                model=MODEL,
                max_tokens=1024,
                thinking={"type": "adaptive"},
                output_config={"effort": "low"},  # مكالمة صوتية — الأولوية لسرعة الرد
                system=[{"type": "text", "text": self.system, "cache_control": {"type": "ephemeral"}}],
                messages=self.messages,
            )
        except anthropic.APIError:
            # لا نترك الزبون في صمت — نعتذر ونحوّل لموظف
            return AgentReply(
                text="عذراً، حدث خلل تقني لدينا. سيتواصل معك أحد موظفينا في أقرب وقت. شكراً لك.",
                end_call=True,
                needs_human=True,
            )

        text = "".join(b.text for b in response.content if b.type == "text").strip()
        self.messages.append({"role": "assistant", "content": response.content})

        end_call = END_CALL_MARK in text
        needs_human = HUMAN_MARK in text
        clean = text.replace(END_CALL_MARK, "").replace(HUMAN_MARK, "").strip()
        if not clean:
            clean = "شكراً لتواصلك معنا، مع السلامة."
            end_call = True
        return AgentReply(text=clean, end_call=end_call, needs_human=needs_human)
