#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
FX1.FAM35 — Gold Trade Advisor (مستشار صفقات الذهب)
====================================================
Studies the gold market with the same FX1.FAM35 engine (EMA trend + wave
structure + ADX + RSI + pullback pivots) and produces a complete trade
plan in Arabic:

  - القرار: BUY / SELL / لا صفقة (مع الأسباب)
  - الدخول، وقف الخسارة، الأهداف TP1 (1R) / TP2 (2R) / TP3 (3R)
  - حجم اللوت المحسوب من رصيدك ونسبة المخاطرة (يدعم حسابات السنت)
  - حالة السوق: الاتجاه، قوة ADX، زخم RSI، البنية الموجية

It can print the plan, or send it to your Telegram, and can watch the
market in a loop and alert you when a new signal appears.

Data sources (first available wins):
  --csv file.csv            offline OHLC file (TradingView/MT5/generic)
  yfinance (pip install yfinance)  GC=F / XAUUSD=X pulled live

Examples:
  # one-shot analysis on live data, $100 account, 2% risk
  python3 advisor/fam35_advisor.py --equity 100 --risk 2

  # send the plan to Telegram
  python3 advisor/fam35_advisor.py --equity 100 --risk 2 \
      --telegram-token 123:ABC --chat-id 55512345

  # watch mode: re-check every 15 minutes, alert only on NEW signals
  python3 advisor/fam35_advisor.py --equity 100 --watch 15 \
      --telegram-token 123:ABC --chat-id 55512345

  # goal planner (honest math)
  python3 advisor/fam35_advisor.py --goal 10000 --days 29 --equity 100

Telegram setup:
  1. Talk to @BotFather -> /newbot -> copy the token.
  2. Send any message to your bot, then open
     https://api.telegram.org/bot<TOKEN>/getUpdates to find your chat id.
  3. Pass --telegram-token/--chat-id (or env TG_TOKEN / TG_CHAT).
"""
import argparse
import io
import json
import math
import os
import sys
import time
import urllib.parse
import urllib.request

import numpy as np
import pandas as pd

OZ_PER_LOT = 100.0          # 1.00 standard lot of XAUUSD = 100 oz -> $100 per $1 move
MIN_LOT_STD = 0.01
MIN_LOT_CENT = 0.01         # on a cent account balance is in cents -> 100x smaller $ risk


# ----------------------------- indicators (same engine) -----------------------------

def ema(s, n):
    return s.ewm(span=n, adjust=False).mean()


def rma(s, n):
    return s.ewm(alpha=1.0 / n, adjust=False).mean()


def rsi(close, n=14):
    d = close.diff()
    up = rma(d.clip(lower=0), n)
    dn = rma((-d).clip(lower=0), n)
    rs = up / dn.replace(0, np.nan)
    return (100 - 100 / (1 + rs)).fillna(50.0)


def atr(df, n=14):
    pc = df["close"].shift()
    tr = pd.concat([df["high"] - df["low"], (df["high"] - pc).abs(),
                    (df["low"] - pc).abs()], axis=1).max(axis=1)
    return rma(tr, n)


def adx(df, n=14):
    up = df["high"].diff()
    dn = -df["low"].diff()
    plus_dm = np.where((up > dn) & (up > 0), up, 0.0)
    minus_dm = np.where((dn > up) & (dn > 0), dn, 0.0)
    tr_n = atr(df, n)
    p = 100 * rma(pd.Series(plus_dm, index=df.index), n) / tr_n
    m = 100 * rma(pd.Series(minus_dm, index=df.index), n) / tr_n
    dx = 100 * (p - m).abs() / (p + m).replace(0, np.nan)
    return rma(dx.fillna(0), n)


# ----------------------------- data -----------------------------

def load_csv(path):
    raw = open(path, "r", encoding="utf-8-sig", errors="replace").read()
    sep = "\t" if "\t" in raw.splitlines()[0] else ","
    df = pd.read_csv(io.StringIO(raw), sep=sep)
    df.columns = [c.strip().strip("<>").lower() for c in df.columns]
    if "date" in df.columns and "time" in df.columns:
        ts = pd.to_datetime(df["date"].astype(str) + " " + df["time"].astype(str))
    elif "time" in df.columns:
        t = df["time"]
        ts = (pd.to_datetime(t, unit="s")
              if pd.api.types.is_numeric_dtype(t) else pd.to_datetime(t))
    else:
        ts = pd.to_datetime(df["date"])
    out = df[["open", "high", "low", "close"]].astype(float)
    out.index = pd.DatetimeIndex(ts)
    return out[~out.index.duplicated(keep="first")].sort_index().dropna()


def load_live(symbol, interval, lookback):
    try:
        import yfinance as yf
    except ImportError:
        sys.exit("yfinance غير مثبت. ثبّته بـ:  pip install yfinance  "
                 "أو استخدم --csv مع ملف بيانات مُصدَّر.")
    data = yf.download(symbol, period=lookback, interval=interval,
                       progress=False, auto_adjust=True)
    if data is None or data.empty:
        sys.exit(f"تعذر تحميل بيانات {symbol}. جرّب رمزاً آخر (GC=F أو XAUUSD=X) "
                 "أو استخدم --csv.")
    if isinstance(data.columns, pd.MultiIndex):
        data.columns = [c[0].lower() for c in data.columns]
    else:
        data.columns = [c.lower() for c in data.columns]
    return data[["open", "high", "low", "close"]].dropna()


# ----------------------------- analysis -----------------------------

def analyze(df, p):
    """Evaluate the FX1.FAM35 conditions on the last CLOSED bar."""
    c = df["close"]
    ema_f, ema_s, ema_t = ema(c, p.fast_ema), ema(c, p.slow_ema), ema(c, p.trend_ema)
    rsi_v, atr_v, adx_v = rsi(c, p.rsi_len), atr(df, p.atr_len), adx(df, p.adx_len)

    h, l = df["high"].to_numpy(), df["low"].to_numpy()
    L, R = p.pivot_left, p.pivot_right
    last_ph = prev_ph = last_pl = prev_pl = math.nan
    bars_ph = bars_pl = -1
    for i in range(len(df)):
        j = i - R
        if j - L < 0:
            continue
        wh, wl = h[j - L: j + R + 1], l[j - L: j + R + 1]
        if h[j] == wh.max() and (wh == h[j]).sum() == 1:
            prev_ph, last_ph, bars_ph = last_ph, h[j], R
        elif bars_ph >= 0:
            bars_ph += 1
        if l[j] == wl.min() and (wl == l[j]).sum() == 1:
            prev_pl, last_pl, bars_pl = last_pl, l[j], R
        elif bars_pl >= 0:
            bars_pl += 1

    i = -1
    px = float(c.iloc[i])
    trend_up = ema_f.iloc[i] > ema_s.iloc[i] and px > ema_s.iloc[i] and px >= ema_t.iloc[i]
    trend_dn = ema_f.iloc[i] < ema_s.iloc[i] and px < ema_s.iloc[i] and px <= ema_t.iloc[i]
    struct_ok = not any(map(math.isnan, (last_ph, prev_ph, last_pl, prev_pl)))
    wave_up = struct_ok and last_ph > prev_ph and last_pl > prev_pl
    wave_dn = struct_ok and last_ph < prev_ph and last_pl < prev_pl
    a, r_, at = float(adx_v.iloc[i]), float(rsi_v.iloc[i]), float(atr_v.iloc[i])
    fresh_pl = 0 <= bars_pl <= p.max_pullback
    fresh_ph = 0 <= bars_ph <= p.max_pullback

    buy = (trend_up and not wave_dn and 50 < r_ < 78 and not math.isnan(last_pl)
           and px > last_pl and fresh_pl and a >= p.adx_min)
    sell = (trend_dn and not wave_up and 22 < r_ < 50 and not math.isnan(last_ph)
            and px < last_ph and fresh_ph and a >= p.adx_min)

    plan = None
    if buy:
        sl = last_pl - at * p.sl_buf_atr
        r1 = px - sl
        if 0 < r1 <= at * p.max_risk_atr:
            plan = dict(side="BUY", entry=px, sl=sl, r=r1,
                        tp1=px + r1, tp2=px + 2 * r1, tp3=px + p.rr * r1)
    elif sell:
        sl = last_ph + at * p.sl_buf_atr
        r1 = sl - px
        if 0 < r1 <= at * p.max_risk_atr:
            plan = dict(side="SELL", entry=px, sl=sl, r=r1,
                        tp1=px - r1, tp2=px - 2 * r1, tp3=px - p.rr * r1)

    state = dict(price=px, time=str(df.index[i]),
                 trend="صاعد ⬆" if trend_up else "هابط ⬇" if trend_dn else "عرضي ↔",
                 wave="قمم/قيعان صاعدة" if wave_up else "قمم/قيعان هابطة" if wave_dn else "غير محسومة",
                 adx=a, rsi=r_, atr=at,
                 last_support=last_pl, last_resistance=last_ph)
    return state, plan


def lot_size(equity, risk_pct, r_distance):
    """Risk-based lot for XAUUSD. Returns (std_lot, risk_money, cent_lot)."""
    risk_money = equity * risk_pct / 100.0
    lot = risk_money / (r_distance * OZ_PER_LOT)
    return lot, risk_money


# ----------------------------- message -----------------------------

def build_message(state, plan, p):
    L = []
    L.append("🥇 FX1.FAM35 — مستشار الذهب")
    L.append(f"🕐 {state['time']}  |  السعر: {state['price']:.2f}$")
    L.append(f"📈 الاتجاه: {state['trend']}  |  الموجات: {state['wave']}")
    L.append(f"💪 ADX: {state['adx']:.1f}  |  RSI: {state['rsi']:.1f}  |  ATR: {state['atr']:.2f}$")
    if not math.isnan(state.get("last_support") or math.nan):
        L.append(f"🧱 دعم: {state['last_support']:.2f} | مقاومة: {state['last_resistance']:.2f}")
    L.append("―" * 18)
    if plan is None:
        L.append("⛔ القرار: لا صفقة الآن")
        L.append("الشروط غير مكتملة — الانتظار أفضل صفقة. لا تدخل عشوائياً.")
    else:
        lot, risk_money = lot_size(p.equity, p.risk, plan["r"])
        side_ar = "شراء 🟢" if plan["side"] == "BUY" else "بيع 🔴"
        L.append(f"✅ القرار: {side_ar}  ({plan['side']})")
        L.append(f"🎯 الدخول : {plan['entry']:.2f}")
        L.append(f"🛑 الوقف  : {plan['sl']:.2f}   (R = {plan['r']:.2f}$)")
        L.append(f"🥉 TP1 (1R): {plan['tp1']:.2f}  ← أغلق ⅓ وانقل الوقف للتعادل")
        L.append(f"🥈 TP2 (2R): {plan['tp2']:.2f}  ← أغلق ⅓ وثبّت الوقف عند +1R")
        L.append(f"🥇 TP3 ({p.rr:g}R): {plan['tp3']:.2f}  ← الثلث الأخير")
        L.append("―" * 18)
        L.append(f"💰 إدارة المال (رصيد {p.equity:.2f}$ ، مخاطرة {p.risk:g}%):")
        L.append(f"   المخاطرة بالدولار: {risk_money:.2f}$")
        if lot >= MIN_LOT_STD:
            L.append(f"   حجم اللوت: {lot:.2f} لوت (حساب ستاندرد)")
        else:
            cent_lot = lot * 100  # cent account: same nominal lot risks 1/100 of the $
            if cent_lot >= MIN_LOT_CENT:
                L.append(f"   ⚠ الرصيد صغير للحساب الستاندرد (يتطلب {lot:.4f} لوت).")
                L.append(f"   استخدم حساب سنت: {cent_lot:.2f} لوت-سنت "
                         f"(= {risk_money:.2f}$ مخاطرة)")
            else:
                L.append("   ⚠ الصفقة أكبر من رصيدك حتى على حساب سنت — تخطَّ هذه الصفقة.")
        L.append("📌 لا تخاطر أبداً بأكثر من النسبة المحددة، ولا تحرك الوقف ضد اتجاهك.")
    return "\n".join(L)


def send_telegram(token, chat_id, text):
    url = f"https://api.telegram.org/bot{token}/sendMessage"
    data = urllib.parse.urlencode({"chat_id": chat_id, "text": text}).encode()
    with urllib.request.urlopen(urllib.request.Request(url, data=data), timeout=30) as r:
        ok = json.load(r).get("ok", False)
    print("✓ أُرسلت الرسالة إلى تيليغرام" if ok else "✗ فشل إرسال تيليغرام")


# ----------------------------- goal planner -----------------------------

def goal_planner(equity, goal, days):
    total_x = goal / equity
    daily = total_x ** (1.0 / max(days, 1)) - 1
    monthly_double_steps = math.ceil(math.log2(total_x))
    print("=" * 60)
    print(f"🎯 حاسبة الهدف: {equity:.0f}$ → {goal:.0f}$ خلال {days} يوم")
    print("=" * 60)
    print(f"المطلوب: ×{total_x:.0f} إجمالاً = {daily*100:.1f}% مركّبة كل يوم بدون خسارة")
    if daily > 0.03:
        print("الحكم: ❌ هذا ليس تداولاً — هذا قمار سينهي الحساب.")
    elif daily > 0.01:
        print("الحكم: ⚠ عدواني جداً — احتمال النجاح ضئيل.")
    else:
        print("الحكم: ✅ ضمن الممكن مع انضباط صارم.")
    print()
    print("📈 الطريق الواقعي البديل — سلّم المضاعفة (هدف +100% لكل مرحلة،")
    print("   وهو بحد ذاته هدف عدواني يتطلب شهوراً ممتازة):")
    eq = equity
    for step in range(1, monthly_double_steps + 1):
        nxt = min(eq * 2, goal)
        print(f"   المرحلة {step}: {eq:>9.0f}$ → {nxt:>9.0f}$")
        eq = nxt
    print(f"   أي ~{monthly_double_steps} مراحل. لو أنجزت مرحلة كل شهر (نادر جداً)")
    print(f"   تصل خلال ~{monthly_double_steps} شهراً — وليس شهراً واحداً.")
    print()
    print("قواعد النجاة حتى تصل:")
    print(" 1) مخاطرة 1–2% لكل صفقة (لحساب 100$: استخدم حساب سنت).")
    print(" 2) حد خسارة يومي 5% — توقف فوراً عند بلوغه.")
    print(" 3) صفقة واحدة مفتوحة فقط، وبإشارة مكتملة الشروط فقط.")
    print(" 4) أضف لرأس المال من دخلك — أسرع طريق مضمون لتكبير الحساب.")
    print("=" * 60)


# ----------------------------- main -----------------------------

def main():
    ap = argparse.ArgumentParser(description="FX1.FAM35 gold trade advisor")
    ap.add_argument("--csv", help="ملف OHLC بدلاً من البيانات الحية")
    ap.add_argument("--symbol", default="GC=F", help="رمز yfinance (GC=F أو XAUUSD=X)")
    ap.add_argument("--interval", default="1h", help="الفريم: 15m / 30m / 1h / 4h / 1d")
    ap.add_argument("--lookback", default="60d", help="عمق التاريخ للتحميل الحي")
    ap.add_argument("--equity", type=float, default=100.0, help="رصيد الحساب $")
    ap.add_argument("--risk", type=float, default=2.0, help="المخاطرة %% لكل صفقة")
    ap.add_argument("--rr", type=float, default=3.0)
    ap.add_argument("--adx-min", type=float, default=18.0)
    ap.add_argument("--fast-ema", type=int, default=21)
    ap.add_argument("--slow-ema", type=int, default=50)
    ap.add_argument("--trend-ema", type=int, default=200)
    ap.add_argument("--rsi-len", type=int, default=14)
    ap.add_argument("--atr-len", type=int, default=14)
    ap.add_argument("--adx-len", type=int, default=14)
    ap.add_argument("--pivot-left", type=int, default=3)
    ap.add_argument("--pivot-right", type=int, default=3)
    ap.add_argument("--max-pullback", type=int, default=25)
    ap.add_argument("--sl-buf-atr", type=float, default=0.5)
    ap.add_argument("--max-risk-atr", type=float, default=6.0)
    ap.add_argument("--telegram-token", default=os.environ.get("TG_TOKEN"))
    ap.add_argument("--chat-id", default=os.environ.get("TG_CHAT"))
    ap.add_argument("--watch", type=int, metavar="MIN",
                    help="وضع المراقبة: إعادة الفحص كل N دقيقة وإرسال الإشارات الجديدة فقط")
    ap.add_argument("--goal", type=float, help="حاسبة الهدف: المبلغ المستهدف $")
    ap.add_argument("--days", type=int, default=30, help="عدد الأيام للهدف")
    p = ap.parse_args()

    if p.goal:
        goal_planner(p.equity, p.goal, p.days)
        return

    def run_once(last_sig):
        df = load_csv(p.csv) if p.csv else load_live(p.symbol, p.interval, p.lookback)
        state, plan = analyze(df, p)
        sig = None if plan is None else (plan["side"], round(plan["entry"], 2))
        msg = build_message(state, plan, p)
        is_new = sig is not None and sig != last_sig
        if not p.watch or is_new:
            print(msg)
            print()
            if p.telegram_token and p.chat_id and (plan is not None or not p.watch):
                try:
                    send_telegram(p.telegram_token, p.chat_id, msg)
                except Exception as e:
                    print(f"✗ خطأ تيليغرام: {e}")
        elif p.watch:
            print(f"[{state['time']}] لا جديد — السعر {state['price']:.2f} "
                  f"({state['trend']}) ننتظر إشارة مكتملة...")
        return sig if sig is not None else last_sig

    if p.watch:
        print(f"👁 وضع المراقبة: فحص كل {p.watch} دقيقة (Ctrl+C للإيقاف)")
        last = None
        while True:
            try:
                last = run_once(last)
            except SystemExit as e:
                print(e)
            except Exception as e:
                print(f"✗ خطأ مؤقت: {e}")
            time.sleep(p.watch * 60)
    else:
        run_once(None)


if __name__ == "__main__":
    main()
