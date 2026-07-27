# Business Requirements Document: Financial Dashboard (One-Page Summary)

## Purpose
Pull the single key number out of each of the three underlying reports (Cash Flow, Net Worth, Runway) plus two supporting comparisons, into one glanceable view. This is the "so what" layer — it does not recompute anything, it reads the latest output of the other three reports.

## Frequency
Generated on demand, any time after at least one run of each underlying report exists. Naturally refreshes monthly (driven by the Cash Flow Statement cadence) with quarterly and as-needed sections updated when their source reports run.

## Inputs
This report has no raw transaction/balance inputs of its own — it is a read-only rollup of:
- Latest **Cash Flow Statement** output (`cashflow_requirements.md`)
- Latest **Net Worth Statement** output (`networth_requirements.md`), plus the prior quarter's for trend
- Latest **Runway Tracker** output (`runway_requirements.md`)
- Debt accounts: interest rate per liability (user-maintained, small table)
- Investment accounts: expected/historical return per holding (user-maintained, small table)
- Asset allocation: current % by class (stocks/bonds/cash/other) and a user-defined target %

## Sections / Calculation Logic

1. **This month's surplus/deficit** — pulled directly from the latest Cash Flow Statement's headline number.
2. **Current net worth + trend arrow** — pulled from the latest Net Worth Statement; arrow = up/down/flat based on delta vs. prior quarter.
3. **Months of runway** — pulled directly from the latest Runway Tracker headline number.
4. **Debt interest rates vs. investment returns** — simple table, one row per debt and per investment holding: `name`, `type` (debt/investment), `rate` (%). Purpose is a gut-check on whether paying down debt beats investing, or vice versa — no automatic recommendation, just the side-by-side numbers.
5. **Asset allocation vs. target** — table: `asset_class`, `current_%`, `target_%`, `drift` (current − target). Flag any class where `abs(drift)` exceeds a user-defined threshold (e.g., 5 percentage points).

## Output
Single-page report containing, in order:
- Surplus/Deficit (this month)
- Net Worth (current, with trend arrow and $ delta vs. last quarter)
- Months of Runway
- Debt vs. Investment rate table
- Asset allocation vs. target table, with drift flags

Format: plain text/markdown, designed to fit on one screen/page — no multi-page detail, no charts required for v1.

## Out of Scope
- Cash flow forecasting
- Tax-loss harvesting analysis
- Detailed fee analysis
- Any calculation not already produced by one of the three underlying reports — this file only aggregates and formats, it does not introduce new financial logic

## Dependency Note
Build order: Cash Flow, Net Worth, and Runway reports should each be functional and producing output before this dashboard is built, since it has no independent data pipeline of its own.
