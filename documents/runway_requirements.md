# Business Requirements Document: Emergency Fund / Runway Tracker

## Purpose
Answer the safety question directly, in one number: how long could I survive on savings alone if income stopped today?

## Formula
```
Liquid Savings ÷ Monthly Essential Expenses = Months of Runway
```

## Frequency
Not calendar-based — recalculated whenever cash flow changes (e.g., after each monthly Cash Flow Statement run, or when liquid savings balance changes materially).

## Inputs
- Liquid savings balance (cash, savings accounts, money-market — excludes retirement accounts, property, or anything not accessible within days without penalty)
- Monthly essential expenses — derived from the Cash Flow Statement's "Fixed Costs" + "Food" + "Transport" buckets (i.e., what you'd still have to pay even with no income). Discretionary spending is excluded since it's the first thing cut in an emergency.

Minimum fields: `liquid_savings_balance`, `monthly_essential_expenses` (or a reference to pull the latest Cash Flow Statement output for the denominator)

## Calculation Logic
- `Monthly Essential Expenses` = Fixed Costs + Food + Transport (from most recent Cash Flow Statement; excludes Discretionary and Savings buckets)
- `Months of Runway` = Liquid Savings ÷ Monthly Essential Expenses
- Optional: flag if runway falls below a user-defined threshold (e.g., 3 or 6 months) as a warning

## Output
Single number report:
- Liquid savings (input)
- Monthly essential expenses (input, with source noted — which Cash Flow Statement period it came from)
- Months of Runway (headline number)
- Status flag: below target / on target / above target (if threshold configured)

Format: plain text/markdown, single-line or small table — this is meant to be glanceable, not a full report.

## Out of Scope
- Scenario modeling (e.g., "what if I lost my job in a recession")
- Multiple runway scenarios (partial income loss, etc.)
- Automatic recalculation triggers — recalculation is invoked manually or on a schedule the user chooses, not event-driven within the script itself
