# Business Requirements Document: Cash Flow Statement (Monthly)

## Purpose
Generate a monthly report answering: "Where does my money go?" and "Am I paying myself first?"

## Formula
```
Income − Fixed Costs − Variable Spending = Surplus / Deficit
```

## Frequency
Monthly.

## Inputs
- Bank statements (checking/savings) — CSV or OFX export
- Credit/debit card statements — CSV export
- Minimum fields per transaction: `date`, `description`, `amount`, `account`

No brokerage, property, or balance-sheet data required for this report.

## Categorization
Each transaction must be assigned to exactly one of the following buckets (~6-8, no finer granularity needed):

1. **Income** — paychecks, transfers in, reimbursements
2. **Housing** — rent/mortgage, utilities, insurance
3. **Food** — groceries, dining out
4. **Transport** — car payment, gas, transit, rideshare
5. **Debt Payments** — credit card, loan, student loan payments (principal + interest)
6. **Discretionary** — shopping, entertainment, subscriptions, misc.
7. **Savings** — transfers to savings/investment accounts (this is a category, not a leftover — "pay yourself first")

Categorization approach:
- Rule-based matching first (keyword/merchant → category mapping, user-maintained lookup table)
- Uncategorized transactions flagged for manual review, not silently dropped or guessed

## Calculation Logic
- `Fixed Costs` = Housing + Debt Payments + any recurring bill tagged fixed
- `Variable Spending` = Food + Transport + Discretionary
- `Surplus/Deficit` = Income − Fixed Costs − Variable Spending
- Savings is tracked as its own line (money already moved), not derived from the surplus — the surplus is what's left *after* paying yourself first, not before

## Output
Single-month report containing:
- Total income
- Total by each of the 6-8 buckets
- Fixed costs subtotal
- Variable spending subtotal
- Surplus/Deficit (final number, headline)
- List of uncategorized transactions requiring review

Format: plain text/markdown table to start; CSV export optional for archiving month-over-month history.

## Out of Scope
- Cash flow forecasting/projections
- Sub-category granularity beyond the 6-8 buckets
- Multi-currency handling (assume single currency unless stated otherwise)
