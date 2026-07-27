# Business Requirements Document: Net Worth Statement (Quarterly)

## Purpose
Track the overall financial scoreboard — a snapshot of what you own vs. what you owe.

## Formula
```
Assets (cash, investments, property) − Liabilities (debt balances) = Net Worth
```

## Frequency
Quarterly. Monthly is intentionally not supported — market swings between months are noise the user can't control and would just add anxiety without decision value.

## Inputs
- Cash/bank account balances (as-of quarter-end)
- Investment/brokerage account balances (as-of quarter-end)
- Property value (user-provided estimate or appraisal, updated infrequently)
- Liability balances: credit cards, loans, mortgage principal remaining (as-of quarter-end)

Minimum fields per item: `name`, `type` (asset/liability), `category`, `balance`, `as_of_date`

This report needs point-in-time balances only — no transaction-level detail required (that's the Cash Flow report's job).

## Categorization
**Assets:**
- Cash (checking, savings, emergency fund)
- Investments (brokerage, retirement accounts)
- Property (real estate, vehicles if tracked)
- Other (rare/misc.)

**Liabilities:**
- Credit card balances
- Loans (auto, personal)
- Student loans
- Mortgage principal remaining

## Calculation Logic
- `Total Assets` = sum of all asset balances as of quarter-end date
- `Total Liabilities` = sum of all liability balances as of quarter-end date
- `Net Worth` = Total Assets − Total Liabilities
- `Trend` = current Net Worth − prior quarter's Net Worth (delta and % change)

## Output
Quarterly snapshot report containing:
- Total assets (with breakdown by category)
- Total liabilities (with breakdown by category)
- Net Worth (headline number)
- Trend vs. prior quarter (delta, direction arrow up/down/flat)
- Historical net worth by quarter (for trend line, once multiple quarters exist)

Format: plain text/markdown table; CSV export for quarter-over-quarter history storage.

## Out of Scope
- Monthly snapshots
- Real-time market value tracking
- Tax-basis or unrealized-gain calculations
- Detailed asset allocation breakdown (that lives in the dashboard, not this report)
