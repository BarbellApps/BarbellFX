# BarbellFX Levels + IB Strategy — guide

`BarbellFX_Levels_IB_Strategy.pine` turns the levels-trader strategy from the video
into one TradingView indicator for **NQ / MNQ and gold (GC / MGC / XAUUSD)**.
All times are **New York**.

## Install

1. TradingView → Pine Editor → paste the file → **Add to chart**.
2. Use a **1m–5m chart**. The initial balance needs bars that start on 9:30.
3. Alerts: create an alert on the indicator with **"Any alert() function call"**.

## Her rule → what the indicator does

| Her rule | In the indicator | Setting |
|---|---|---|
| Previous day high / low from the daily chart | PDH / PDL lines | Key levels |
| Weekend: previous week profile, Sunday 18:00 → Friday close: VAH, VAL, POC | Volume profile built from chart bars | Key levels, Manual weekly levels |
| Previous session profile: NQ = 09:30–16:00, gold = full 18:00–17:00 | PS VAH / POC / VAL (Auto picks by symbol) | Previous session window |
| 30m+ supply / demand: aggressive engulfing displacement, zone = body of the candle before it | Green / red boxes, deleted when a candle closes through | Supply / demand zones |
| London low, previous day low, demand zone as confluence | Counted when within *Confluence distance* of the setup | Confluence distance |
| NY anchored VWAP from the 09:30 candle | Light-blue line | VWAP |
| Initial balance 09:30–10:30, IB high / low / mid (50%) | Blue lines + dotted mid | Sessions |
| **Failed auction**: breaks out of IB, can't hold, closes back inside → target IB mid, stop beyond swing | Setup 1 | Setups |
| **Trend continuation**: IB trended, retrace to IB mid (+ AVWAP) rejects → target IB low / high | Setup 2. IB bias shown in the table | Setups |
| Asia: skip 18:00–20:00, mark that range, trade from the Tokyo open (20:00) | Orange range lines, setups only after 20:00 | Sessions |
| Asia sweep & reject / breakout & retest, target 3R or levels | Setups 3 and 4 | Asia target (R) |
| Alerts at the Asia range high and low | Built-in alert | — |
| Multiple confluences = A+ | Grade A+ (2+), A (1), B (0) on every signal | Min confluences required |
| $200 fixed risk, size from stop distance | Contracts on every signal label | Risk |
| 2 losses → done for the day | Lockout after *Max losses per day* | Stay-out rules |
| No power hour, lunch, news days, flat VWAP | NY window ends 15:00, lunch skip, news date list, flat-VWAP filter | Stay-out rules |
| Don't take the first candle of a breakout, wait for the close | Every signal fires on the candle close only | — |
| Backtest and journal | Results table: trades, win %, net R per setup and A+ only | Display |

## How the results table counts

- One trade at a time. Entry is at the signal candle's close.
- If the stop and the target are both inside one candle, the stop counts first (conservative).
- NY trades still open at 16:00 close at that bar's price. Asia trades close outside 18:00–03:00.
- Use the table to check her "best setup wins about 70%" claim on your own symbol before you size up.

## Known limits

- **Weekly profile history.** A week of 1-minute bars is about 6,900 bars, and most plans load fewer.
  On 1m the weekly profile can stay empty ("needs a full week of bars" in the table). Use a 3m–5m chart,
  or type the levels from your weekend prep into *Manual weekly levels*.
- **Profile precision.** Her tool profiles 1-minute bars. This one profiles your chart's bars, using the
  row size you set (*Profile row size*). Expect small differences from her FRVP numbers.
- **News.** Pine can't read the economic calendar, so list CPI / PPI / FOMC / NFP dates yourself.
- **Judgement calls.** "Aggressive displacement" and "rejection" are rule-of-thumb translations
  (body ≥ 1.8 × average, engulfing, close back inside). Compare them with her examples and tune them.
- **CFD sizing.** On XAUUSD the "contracts" figure is in the broker's units (point value from TradingView).
- Signals are hypothetical. The table has no slippage or commissions.
