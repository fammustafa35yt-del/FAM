#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
FX1.FAM35 — Gold (XAU) backtest engine
=======================================
Python port of the FX1.FAM35 strategy (same logic as FX1.FAM35.mq5 and
FX1.FAM35.strategy.pine):

  - EMA(21/50/200) trend + wave/pivot structure (HH/HL vs LH/LL)
  - ADX(14) strength filter + RSI(14) momentum window
  - Entry at bar close on multi-confluence, SL behind pullback pivot + ATR buffer
  - TP1 = 1R (close 1/3, SL -> break-even)
  - TP2 = 2R (close 1/3, SL -> +1R)
  - TP3 = 3R (close rest; ATR trailing active after +1R)
  - Optional close on trend reversal
  - Risk-% of equity position sizing
  - Conservative intrabar rule: if SL and TP are both touched in the same
    bar, the STOP is assumed to fill first (pessimistic).

Data input (CSV), auto-detected:
  - TradingView chart export:  time,open,high,low,close[,volume,...]
  - MetaTrader 5 export:       <DATE>\t<TIME>\t<OPEN>\t<HIGH>\t<LOW>\t<CLOSE>...
  - Generic / Stooq:           Date,Open,High,Low,Close[,Volume]

Usage:
  python3 fam35_backtest.py data.csv                     # defaults
  python3 fam35_backtest.py data.csv --style swing --direction both
  python3 fam35_backtest.py data.csv --risk 1.0 --equity 10000 --spread 0.30
  python3 fam35_backtest.py data.csv --out results_dir

Outputs: stats to stdout, plus trades.csv and equity.csv in --out dir.
"""
import argparse
import io
import math
import os
import sys

import numpy as np
import pandas as pd


# ----------------------------- indicators -----------------------------

def ema(s: pd.Series, n: int) -> pd.Series:
    return s.ewm(span=n, adjust=False).mean()


def rma(s: pd.Series, n: int) -> pd.Series:
    """Wilder smoothing (same as Pine ta.rma / MT5)."""
    return s.ewm(alpha=1.0 / n, adjust=False).mean()


def rsi(close: pd.Series, n: int) -> pd.Series:
    d = close.diff()
    up = rma(d.clip(lower=0), n)
    dn = rma((-d).clip(lower=0), n)
    rs = up / dn.replace(0, np.nan)
    return (100 - 100 / (1 + rs)).fillna(50.0)


def atr(df: pd.DataFrame, n: int) -> pd.Series:
    pc = df["close"].shift()
    tr = pd.concat([df["high"] - df["low"],
                    (df["high"] - pc).abs(),
                    (df["low"] - pc).abs()], axis=1).max(axis=1)
    return rma(tr, n)


def dmi(df: pd.DataFrame, n: int):
    """Wilder +DI / -DI / ADX (same as Pine ta.dmi)."""
    up = df["high"].diff()
    dn = -df["low"].diff()
    plus_dm = np.where((up > dn) & (up > 0), up, 0.0)
    minus_dm = np.where((dn > up) & (dn > 0), dn, 0.0)
    tr_n = atr(df, n)
    plus_di = 100 * rma(pd.Series(plus_dm, index=df.index), n) / tr_n
    minus_di = 100 * rma(pd.Series(minus_dm, index=df.index), n) / tr_n
    dx = 100 * (plus_di - minus_di).abs() / (plus_di + minus_di).replace(0, np.nan)
    adx = rma(dx.fillna(0), n)
    return plus_di, minus_di, adx


# ----------------------------- data loading -----------------------------

def load_csv(path: str) -> pd.DataFrame:
    raw = open(path, "r", encoding="utf-8-sig", errors="replace").read()
    sep = "\t" if "\t" in raw.splitlines()[0] else ","
    df = pd.read_csv(io.StringIO(raw), sep=sep)
    df.columns = [c.strip().strip("<>").lower() for c in df.columns]

    if "date" in df.columns and "time" in df.columns and "open" in df.columns:
        # MT5 export: separate date + time columns
        ts = pd.to_datetime(df["date"].astype(str) + " " + df["time"].astype(str))
    elif "time" in df.columns:
        t = df["time"]
        ts = (pd.to_datetime(t, unit="s")
              if pd.api.types.is_numeric_dtype(t) else pd.to_datetime(t))
    elif "date" in df.columns:
        ts = pd.to_datetime(df["date"])
    else:
        raise SystemExit("CSV must contain a time/date column plus open,high,low,close")

    need = ["open", "high", "low", "close"]
    for c in need:
        if c not in df.columns:
            raise SystemExit(f"CSV missing column: {c}")

    out = df[need].astype(float).copy()
    out.index = pd.DatetimeIndex(ts)
    out = out[~out.index.duplicated(keep="first")].sort_index().dropna()
    return out


# ----------------------------- backtest core -----------------------------

def backtest(df: pd.DataFrame, p: argparse.Namespace):
    n = len(df)
    o, h, l, c = (df[k].to_numpy() for k in ("open", "high", "low", "close"))

    ema_f = ema(df["close"], p.fast_ema).to_numpy()
    ema_s = ema(df["close"], p.slow_ema).to_numpy()
    ema_t = ema(df["close"], p.trend_ema).to_numpy()
    rsi_v = rsi(df["close"], p.rsi_len).to_numpy()
    atr_v = atr(df, p.atr_len).to_numpy()
    _, _, adx_v = dmi(df, p.adx_len)
    adx_v = adx_v.to_numpy()

    # Higher-TF bias: resample closes to the HTF and take the last *completed*
    # HTF bar (no lookahead). Only meaningful for intraday data.
    htf_up = np.zeros(n, bool)
    htf_dn = np.zeros(n, bool)
    try:
        htf = df["close"].resample(p.htf).last().dropna()
        htf_ema = ema(htf, p.slow_ema)
        bias = pd.Series(np.where(htf > htf_ema, 1, np.where(htf < htf_ema, -1, 0)),
                         index=htf.index).shift(1)  # completed bar only
        aligned = bias.reindex(df.index, method="ffill").fillna(0).to_numpy()
        htf_up, htf_dn = aligned > 0, aligned < 0
    except Exception:
        pass

    allow_scalp = p.style in ("scalp", "both")
    allow_swing = p.style in ("swing", "both")
    allow_buy = p.direction in ("buy", "both")
    allow_sell = p.direction in ("sell", "both")

    L, R = p.pivot_left, p.pivot_right

    equity = p.equity
    peak = equity
    max_dd = 0.0
    equity_curve = []
    trades = []

    # pivot state (confirmed with R bars delay, like Pine ta.pivothigh/low)
    last_ph = prev_ph = last_pl = prev_pl = math.nan
    bars_ph = bars_pl = -1

    # position state
    pos = 0           # +1 long, -1 short, 0 flat
    entry = sl = r1 = tp1 = tp2 = tp3 = 0.0
    qty = qty_third = 0.0
    tp1_done = tp2_done = False
    entry_time = None
    realized = 0.0    # cash already banked from partials of the open trade

    def book(exit_price, exit_qty, reason, i):
        nonlocal realized
        pnl = (exit_price - entry) * exit_qty * pos - p.commission
        realized += pnl
        return pnl

    def close_all_remaining(price, reason, i):
        nonlocal pos, equity, realized, peak, max_dd
        remaining = qty - (qty_third * (int(tp1_done) + int(tp2_done)))
        if remaining > 1e-12:
            book(price, remaining, reason, i)
        equity += realized
        trades.append(dict(open_time=entry_time, close_time=df.index[i],
                           dir="BUY" if pos == 1 else "SELL",
                           entry=round(entry, 2), sl_init=round(sl_init, 2),
                           exit=round(price, 2), reason=reason,
                           r_multiple=round(realized / max(risk_money, 1e-9), 2),
                           pnl=round(realized, 2),
                           equity=round(equity, 2)))
        peak = max(peak, equity)
        max_dd = max(max_dd, (peak - equity) / peak * 100 if peak > 0 else 0)
        pos = 0
        realized = 0.0

    warm = max(p.trend_ema, p.adx_len * 3, p.slow_ema) + 5
    sl_init = 0.0
    risk_money = 0.0

    for i in range(n):
        # ---- update confirmed pivots (delay = R bars) ----
        j = i - R
        if j - L >= 0:
            win_h = h[j - L: j + R + 1]
            win_l = l[j - L: j + R + 1]
            if h[j] == win_h.max() and (win_h == h[j]).sum() == 1:
                prev_ph, last_ph, bars_ph = last_ph, h[j], R
            elif bars_ph >= 0:
                bars_ph += 1
            if l[j] == win_l.min() and (win_l == l[j]).sum() == 1:
                prev_pl, last_pl, bars_pl = last_pl, l[j], R
            elif bars_pl >= 0:
                bars_pl += 1
        else:
            bars_ph += 1 if bars_ph >= 0 else 0
            bars_pl += 1 if bars_pl >= 0 else 0

        equity_curve.append((df.index[i], equity))
        if i < warm:
            continue

        trend_up = ema_f[i] > ema_s[i] and c[i] > ema_s[i] and c[i] >= ema_t[i]
        trend_dn = ema_f[i] < ema_s[i] and c[i] < ema_s[i] and c[i] <= ema_t[i]

        # ---- manage open position on this bar (intrabar, stop first) ----
        if pos != 0:
            hit_sl = (l[i] <= sl) if pos == 1 else (h[i] >= sl)
            if hit_sl:                       # pessimistic: stop fills first
                close_all_remaining(sl, "SL", i)
            else:
                if pos == 1:
                    if not tp1_done and h[i] >= tp1:
                        tp1_done = True
                        book(tp1, qty_third, "TP1", i)
                        if p.move_be:
                            sl = max(sl, entry)
                    if tp1_done and not tp2_done and h[i] >= tp2:
                        tp2_done = True
                        book(tp2, qty_third, "TP2", i)
                        sl = max(sl, entry + r1)
                    if pos != 0 and h[i] >= tp3:
                        close_all_remaining(tp3, "TP3", i)
                    elif pos != 0:
                        if p.trail and (c[i] - entry) >= r1 * p.trail_start_r:
                            sl = max(sl, c[i] - atr_v[i] * p.trail_atr_mult)
                        if p.close_on_reversal and trend_dn:
                            close_all_remaining(c[i], "Reversal", i)
                else:
                    if not tp1_done and l[i] <= tp1:
                        tp1_done = True
                        book(tp1, qty_third, "TP1", i)
                        if p.move_be:
                            sl = min(sl, entry)
                    if tp1_done and not tp2_done and l[i] <= tp2:
                        tp2_done = True
                        book(tp2, qty_third, "TP2", i)
                        sl = min(sl, entry - r1)
                    if pos != 0 and l[i] <= tp3:
                        close_all_remaining(tp3, "TP3", i)
                    elif pos != 0:
                        if p.trail and (entry - c[i]) >= r1 * p.trail_start_r:
                            sl = min(sl, c[i] + atr_v[i] * p.trail_atr_mult)
                        if p.close_on_reversal and trend_up:
                            close_all_remaining(c[i], "Reversal", i)

        # ---- evaluate entry at bar close ----
        if pos != 0:
            continue

        struct_ok = not any(map(math.isnan, (last_ph, prev_ph, last_pl, prev_pl)))
        wave_up = struct_ok and last_ph > prev_ph and last_pl > prev_pl
        wave_dn = struct_ok and last_ph < prev_ph and last_pl < prev_pl
        fresh_pl = 0 <= bars_pl <= p.max_pullback
        fresh_ph = 0 <= bars_ph <= p.max_pullback

        buy_base = (trend_up and not wave_dn and 50 < rsi_v[i] < 78
                    and not math.isnan(last_pl) and c[i] > last_pl and fresh_pl)
        buy_ok = allow_buy and buy_base and (
            (allow_scalp and adx_v[i] >= p.adx_min_scalp) or
            (allow_swing and adx_v[i] >= p.adx_min_swing and htf_up[i]))

        sell_base = (trend_dn and not wave_up and 22 < rsi_v[i] < 50
                     and not math.isnan(last_ph) and c[i] < last_ph and fresh_ph)
        sell_ok = allow_sell and sell_base and (
            (allow_scalp and adx_v[i] >= p.adx_min_scalp) or
            (allow_swing and adx_v[i] >= p.adx_min_swing and htf_dn[i]))

        if buy_ok:
            slp = last_pl - atr_v[i] * p.sl_buf_atr
            r = c[i] + p.spread - slp
            if 0 < r <= atr_v[i] * p.max_risk_atr:
                pos, entry = 1, c[i] + p.spread
                sl = sl_init = slp
                r1 = r
                tp1, tp2, tp3 = entry + r * p.tp1_r, entry + r * p.tp2_r, entry + r * p.rr
                risk_money = equity * p.risk / 100.0
                qty = risk_money / r
                qty_third = qty / 3.0 if p.partials else 0.0
                tp1_done = tp2_done = False
                entry_time = df.index[i]
        elif sell_ok:
            slp = last_ph + atr_v[i] * p.sl_buf_atr
            r = slp - (c[i] - p.spread)
            if 0 < r <= atr_v[i] * p.max_risk_atr:
                pos, entry = -1, c[i] - p.spread
                sl = sl_init = slp
                r1 = r
                tp1, tp2, tp3 = entry - r * p.tp1_r, entry - r * p.tp2_r, entry - r * p.rr
                risk_money = equity * p.risk / 100.0
                qty = risk_money / r
                qty_third = qty / 3.0 if p.partials else 0.0
                tp1_done = tp2_done = False
                entry_time = df.index[i]

    # force-close at end of data
    if pos != 0:
        close_all_remaining(c[-1], "EndOfData", n - 1)

    return trades, equity_curve, equity, max_dd


# ----------------------------- reporting -----------------------------

def report(trades, equity_curve, final_eq, max_dd, p, df):
    t = pd.DataFrame(trades)
    print("=" * 64)
    print("FX1.FAM35 — Gold backtest report")
    print("=" * 64)
    print(f"Data     : {df.index[0]}  ->  {df.index[-1]}   ({len(df)} bars)")
    print(f"Settings : style={p.style} direction={p.direction} risk={p.risk}% "
          f"RR=1:{p.rr:g} spread={p.spread} commission={p.commission}")
    print("-" * 64)
    if t.empty:
        print("No trades were generated on this data / settings.")
        return t
    wins = t[t.pnl > 0]
    losses = t[t.pnl <= 0]
    gp, gl = wins.pnl.sum(), -losses.pnl.sum()
    print(f"Trades          : {len(t)}   (BUY {sum(t.dir=='BUY')} / SELL {sum(t.dir=='SELL')})")
    print(f"Win rate        : {len(wins)/len(t)*100:.1f}%   ({len(wins)} W / {len(losses)} L)")
    print(f"Profit factor   : {gp/gl if gl>0 else float('inf'):.2f}")
    print(f"Avg R multiple  : {t.r_multiple.mean():+.2f} R   (best {t.r_multiple.max():+.2f} / worst {t.r_multiple.min():+.2f})")
    print(f"Expectancy      : {t.pnl.mean():+.2f} $/trade")
    print(f"Net profit      : {t.pnl.sum():+.2f} $  ({t.pnl.sum()/p.equity*100:+.1f}%)")
    print(f"Final equity    : {final_eq:.2f} $  (start {p.equity:.2f} $)")
    print(f"Max drawdown    : {max_dd:.1f}%")
    by_reason = t.groupby("reason").size().to_dict()
    print(f"Exits           : {by_reason}")
    print("=" * 64)
    return t


def main():
    ap = argparse.ArgumentParser(description="FX1.FAM35 gold backtest")
    ap.add_argument("csv", help="OHLC CSV (TradingView / MT5 / generic export)")
    ap.add_argument("--style", choices=["scalp", "swing", "both"], default="both")
    ap.add_argument("--direction", choices=["buy", "sell", "both"], default="both")
    ap.add_argument("--equity", type=float, default=10000)
    ap.add_argument("--risk", type=float, default=1.0, help="risk %% of equity per trade")
    ap.add_argument("--rr", type=float, default=3.0)
    ap.add_argument("--tp1-r", dest="tp1_r", type=float, default=1.0)
    ap.add_argument("--tp2-r", dest="tp2_r", type=float, default=2.0)
    ap.add_argument("--no-partials", dest="partials", action="store_false")
    ap.add_argument("--no-be", dest="move_be", action="store_false")
    ap.add_argument("--no-trail", dest="trail", action="store_false")
    ap.add_argument("--trail-start-r", type=float, default=1.0)
    ap.add_argument("--trail-atr-mult", type=float, default=2.0)
    ap.add_argument("--no-reversal-close", dest="close_on_reversal", action="store_false")
    ap.add_argument("--fast-ema", type=int, default=21)
    ap.add_argument("--slow-ema", type=int, default=50)
    ap.add_argument("--trend-ema", type=int, default=200)
    ap.add_argument("--adx-len", type=int, default=14)
    ap.add_argument("--adx-min-scalp", type=float, default=18.0)
    ap.add_argument("--adx-min-swing", type=float, default=22.0)
    ap.add_argument("--rsi-len", type=int, default=14)
    ap.add_argument("--atr-len", type=int, default=14)
    ap.add_argument("--pivot-left", type=int, default=3)
    ap.add_argument("--pivot-right", type=int, default=3)
    ap.add_argument("--max-pullback", type=int, default=25)
    ap.add_argument("--sl-buf-atr", type=float, default=0.5)
    ap.add_argument("--max-risk-atr", type=float, default=6.0)
    ap.add_argument("--htf", default="4h", help="higher timeframe for swing bias (pandas rule, e.g. 4h, 1D)")
    ap.add_argument("--spread", type=float, default=0.30, help="spread cost in price units (XAUUSD ~0.2-0.5 $)")
    ap.add_argument("--commission", type=float, default=0.0, help="commission $ per fill")
    ap.add_argument("--out", default=None, help="directory for trades.csv / equity.csv")
    p = ap.parse_args()

    df = load_csv(p.csv)
    trades, eq_curve, final_eq, max_dd = backtest(df, p)
    t = report(trades, eq_curve, final_eq, max_dd, p, df)

    if p.out:
        os.makedirs(p.out, exist_ok=True)
        t.to_csv(os.path.join(p.out, "trades.csv"), index=False)
        pd.DataFrame(eq_curve, columns=["time", "equity"]).to_csv(
            os.path.join(p.out, "equity.csv"), index=False)
        print(f"Saved: {p.out}/trades.csv , {p.out}/equity.csv")


if __name__ == "__main__":
    main()
