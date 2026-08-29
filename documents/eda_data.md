# EDA: Transaction Explorer

## Purpose
Specification for a single Python script that reads a raw transaction CSV and produces exploratory views — summary tables and charts — across two time framings (financial year and calendar year), broken down by account and category hierarchy.

This document is the instruction set. The deliverable it describes is `scripts/eda_data.py`.

## Development constraint: written blind

The real CSV is never shared with Claude — only its header and this spec. The script is therefore written without ever having seen a row of data, which drives several requirements:

- **Validate the header explicitly** and fail with a clear message naming the missing/unexpected columns. Do not assume column order.
- **Normalise header names on read**: strip surrounding whitespace, collapse internal runs of whitespace, match case-insensitively. The source header is known to contain irregular spacing.
- **Assume every field can be dirty**: blank, whitespace-only, currency-symbol-prefixed, thousands-separated, parenthesised, or absent entirely.
- **Fail loudly with actionable messages**, not silently with wrong numbers. The user is the only one who can see the data, so an error message is the entire debugging channel — it must name the column, the row number, and the offending value.
- Provide a `--validate-only` mode that reads the file and reports: row count, date range, per-column null/blank counts, unparseable-value counts, negative-value counts in `Debit`/`Credit` with examples, exact-duplicate count, candidate transfer-pair count, and distinct Account/Category/Subcategory values — then exits without writing reports. **This is the first thing to run against a new file.**
- Ship a **synthetic fixture generator** (`scripts/make_fixture.py`, fixed random seed for reproducibility) emitting a fake CSV with the same header and deliberate edge cases: blank subcategories, parenthesised negatives, a duplicate pair, an unparseable date, a UTF-8 BOM, a matched transfer pair, and the same subcategory name under two different categories.

Only aggregated output is passed back into Claude. Row-level free-text columns must never appear in shareable output — see [Privacy boundary](#privacy-boundary).

## Input

CSV with header:

```
Transaction Date, Details, Account, Category, Subcategory, Tags, Notes, Debit, Credit, Original Description
```

**File-level handling.** Default encoding `utf-8-sig` (transparently strips the BOM that bank exports frequently carry), overridable with `--encoding`; on `UnicodeDecodeError`, fail with a message naming `cp1252` and `latin-1` as likely alternatives. Sniff the delimiter with `csv.Sniffer` across the first few KB, falling back to comma, overridable with `--delimiter`.

| Column | Role | Handling |
|---|---|---|
| `Transaction Date` | Time key | Parse to date. Try ISO first, then `DD/MM/YYYY`. Ambiguous formats must be resolved by an explicit `--date-format` flag rather than guessed per row. Unparseable → quarantine. |
| `Account` | Split dimension | Trim; blank → `"Unknown Account"`. |
| `Category` | Group level 1 | Trim; blank → `"Uncategorised"`. |
| `Subcategory` | Group level 2 | Trim; blank → `"(none)"`, so a category with no subcategory still forms a valid leaf. |
| `Debit` | Measure | Strip currency symbols, commas, spaces; parenthesised values → negative. Blank → `0`. |
| `Credit` | Measure | Same as Debit. |
| `Details`, `Notes`, `Original Description` | Not aggregated | Retained in memory for the quarantine, duplicate, and transfer reports only. Excluded from all other outputs. |
| `Tags` | **Unused** | Read and ignored by design. Not aggregated, not filtered on, not reported. |

### Sign convention

`Debit` and `Credit` are **normally** positive magnitudes, and Net is computed as `Debit − Credit`, so **a positive Net means net outflow** (money spent). This is the inverse of the surplus convention in `cashflow_requirements.md`, where `Income − costs` positive means money kept. Label the column `Net (Debit − Credit)` in every output so the direction is never ambiguous.

Negative values in `Debit` or `Credit` (refunds, reversals, corrections) are **kept as-is in their original column** — not normalised into the opposite column. Consequently **none of the three measures is guaranteed non-negative**, and the sign handling described under [Hierarchy charts](#hierarchy-charts-and-negative-values) applies to Debit and Credit exactly as it does to Net. If a row has both Debit and Credit populated, keep both and net them — that is not an error.

### Quarantine and duplicates

- **Quarantine:** rows failing date or amount parsing are excluded from aggregates and written to `output/quarantine.csv` with a `reason` column. The count is reported in the console summary and at the top of every HTML report. Never silently dropped.
- **Duplicates:** rows identical across *every* column are **flagged, never dropped** — two identical coffees on one day are legitimate, and automatic deduplication would erase them. Duplicate groups are written to `output/duplicates.csv` for review and the count is surfaced in the report header. All rows remain in the aggregates.

### Inter-account transfers

Moving $2,000 from Checking to Savings appears twice in the file: a Debit on Checking and a Credit on Savings. Left alone, the all-accounts view counts both, inflating total debits and total credits and letting transfers dominate the top-N charts while saying nothing about actual spending.

**Detection** — a candidate transfer pair is two rows where:

- one has a Debit and the other a Credit,
- the amounts are equal to the cent,
- the accounts differ,
- the dates fall within `--transfer-window` days of each other (default `3`, to absorb settlement lag),
- and neither row is already matched — pairing is strictly one-to-one, matched nearest-date-first so a repeating fixed transfer doesn't cross-match against the wrong month.

Rows whose Category matches `--transfer-categories` (default: any category or subcategory containing `"transfer"`, case-insensitive) are also treated as transfers even if unpaired, since a transfer to an untracked external account has no counterpart row in the file.

**Treatment** — detected transfers are **excluded from the all-accounts scope only**. Per-account scope keeps them, because a transfer is a genuine movement for the account it touches. Every excluded row is written to `output/transfers_excluded.csv` with its matched-pair ID and the reason it matched, so the exclusion is fully auditable. `--no-transfer-detection` disables the whole mechanism.

> **Consequence that must be stated in the report:** once transfers are excluded from all-accounts but retained per-account, **the all-accounts totals will not equal the sum of the per-account totals.** This is intended, not a bug. Every report must carry a note near the totals giving the excluded transfer count and value, so the discrepancy reconciles on inspection.

Detection is heuristic and can produce false positives — two unrelated equal-amount transactions a day apart across accounts will match. This is why the exclusions are written out in full rather than merely counted.

## Views

Two independent framings of the same data. Each is a separate report file.

1. **Financial year** — 1 July to 30 June, labelled by the **ending** year: `FY2026` = 1 Jul 2025 → 30 Jun 2026. Start month is `--fy-start-month`, default `7`, so other jurisdictions need no code change.
2. **Calendar year** — 1 January to 31 December, labelled `CY2026`.

### Partial periods

A period is **partial** when its end date falls after the latest transaction date in the file — this catches both an in-progress period and a mid-period export. Partial periods are **included and explicitly labelled** everywhere they appear:

```
FY2027 (partial — 1 Jul 2026 to 29 Jul 2026)
```

The label must appear in section headings, chart titles, and the `period` column of the summary CSVs, so a short bar is never misread as a collapse in spending. No pro-rating or annualisation is performed.

## Summary tables

Per (period, account, category, subcategory), aggregate `Debit`, `Credit`, and `Net (Debit − Credit)`.

Rendered in HTML with subtotal rows at the Category level, a total per account, and a grand total per period. Row order is controlled by `--sort-by {debit,credit,net}` (default `debit`, descending); **this flag affects table ordering only** — the top-N charts sort by their own measure by definition.

**Tables cover the full history in the file**, regardless of how many periods are charted.

Written to `fy_summary.csv` / `cy_summary.csv` as tidy long format — `period, is_partial, account, category, subcategory, debit, credit, net` — so they can be re-read and pivoted. Subtotal and grand-total rows are **not** written to the CSVs; they would double-count on re-aggregation and exist in the HTML only.

## Charts

All charts are Plotly.

### Period selection

Charts are produced for the **most recent N periods**, `--periods`, default `3`. Only periods actually containing transactions count toward N, so a gap year does not consume a slot. Summary tables are unaffected and always span all history.

### Scope

Each charted period gets **two scopes**, and — unlike the previous revision — **both scopes get the full chart set**:

1. **All accounts** — transfers excluded. Hierarchy rooted at `Account`.
2. **Per account** — one section per account, transfers retained. Hierarchy rooted at `Category`, since the Account level is degenerate inside a single-account section.

Top-N selection is computed **within the scope being charted** — a per-account chart shows that account's own top 15, not the global top 15 filtered down.

### Chart set (produced for each scope)

Four top-N bar charts (`--top-n`, default 15):

1. Top debits by Category — horizontal bar
2. Top credits by Category — horizontal bar
3. Top debits by Subcategory — labelled `Category › Subcategory`, so leaf names are unambiguous across parents
4. Top credits by Subcategory — same

Ranking is by signed sum descending, so a net-negative category (refunds exceeding spend) correctly sorts to the bottom rather than being ranked by magnitude.

Plus three clickable hierarchy charts (Debit, Credit, Net) and one structural tree, below.

### Structural tree

A top-down node-link diagram of the hierarchy — a **structural** tree reflecting the real category structure, not a clustering dendrogram. **One tree per scope, encoding Net (Debit − Credit)**, on the diverging blue↔red scale described under [Colour](#colour): intensity by magnitude, neutral grey at zero. Node size encodes absolute value. Hover states the signed value. Labels are drawn only on the largest nodes by absolute value; the rest are reachable on hover, so a wide tree doesn't collapse into overlapping text.

Layout is computed directly (leaves evenly spaced on the x-axis, each parent centred over its children, depth on the y-axis) and drawn with Plotly scatter + line traces. No graph-layout dependency is needed, since the data is a strict tree.

### Hierarchy charts and negative values

Clickable drill-down charts: Plotly `sunburst` (alternative `icicle` via `--hierarchy-style`). Clicking a segment zooms into that branch. In all-accounts scope, all accounts are parented to a single synthetic root (`"All Accounts"`), since sunburst requires one root.

**Node IDs must be composite paths** (`Account|Category|Subcategory`), with short display labels. Using bare names as IDs silently merges same-named leaves under different parents — an "Insurance" subcategory under both Housing and Transport would collapse into one segment carrying a wrong total.

**Three hierarchy charts per scope — Debit, Credit, and Net** — not one chart with a toggle.

Sunburst/treemap/icicle cannot render negative or mixed-sign values: a parent's value must equal the sum of its children, which breaks when signs mix. Because negatives are kept as-is, **this applies to all three measures**. For each:

- Split into two charts — *outflow* and *inflow* — by partitioning at the **leaf** (subcategory) level on the sign of the measure, then recomputing every parent total from the surviving leaves. Partitioning at leaf level rather than by branch total guarantees no parent ever receives mixed-sign children, which is the precise condition sunburst cannot represent. The inflow chart plots absolute values. In practice the Debit-inflow and Credit-outflow charts will often be empty; **omit an empty chart with a one-line note rather than rendering a blank frame.**
- Size by absolute value, colour by sign, and state the actual signed value in hover text.
- Flag any branch whose children mix signs — its rolled-up total hides offsetting movements.

### Colour

**Bar charts are single-colour.** Each top-N chart is one series (magnitude by category), so every bar takes the same hue: blue `#2a78d6` for debit charts, aqua `#1baf7a` for credit charts. Colouring the 15 bars by category would mean cycling or generating hues well past the eight that can be held apart under colour-vision deficiency, and would burn the colour channel re-encoding what bar length already shows. Measure identity (debit vs credit) is what colour carries here, and it stays fixed across every chart and period.

**Hierarchy charts** encode magnitude, so they use a single-hue sequential ramp (blue, light→dark) with a scale legend.

**The structural tree encodes Net, so it uses the diverging pair: blue ↔ red with a neutral grey midpoint** (`#2a78d6` inflow ← `#f0efec` zero → `#e34948` outflow). Not red/green — that pair is indistinguishable for the most common form of colour-vision deficiency, and the midpoint must read as "nothing", which only a neutral grey does. The red pole is the categorical red, deliberately not the status red, so a tree node never impersonates an alert.

The two-hue categorical set validates clean (worst-pair ΔE 24.0 normal-vision, 23.1 under protanopia). Aqua sits below 3:1 against the light chart surface, which obliges visible relief: bar values are direct-labelled at the bar end, and every chart has its summary table above it.

**Light mode only in v1.** Plotly bakes colours into each figure, so a working dark mode needs a JS relayout pass across ~120 figures. Out of scope here; the surface is fixed at `#fcfcfb`.

## Report layout

Each report is one self-contained HTML file with a **sticky table of contents** linking to each charted period.

Within a period: the all-accounts chart set is **expanded by default**; each per-account section is a **collapsed `<details>` block**.

```
┌─ CONTENTS ──┐  FY2026
│ › FY2026    │  ─────────────────────────
│   FY2025    │  Summary table
│   FY2024    │  ALL ACCOUNTS  (transfers excluded)
│             │  [top debits] [top credits]
│             │  [top debit subcats] [top credit subcats]
│             │  [sunburst ×3] [net tree]
│             │
│             │  ▸ Everyday Checking
│             │  ▸ Savings
│             │  ▸ Credit Card
└─────────────┘
```

Header block on every report: source filename, row count, date range, quarantine count, duplicate count, transfers excluded (count and value), partial-period notice, and generation timestamp.

> **Size warning.** Both scopes getting the full set means roughly `periods × (8 + 8 × accounts)` charts — with 3 periods and 4 accounts, about 120. Collapsed `<details>` blocks defer rendering but the data still ships in the file. If reports become slow to open, reduce `--periods` first; splitting into one file per period is the fallback.

## Number formatting

Display amounts as **whole dollars with a currency symbol and thousands separators** — `$1,235` — in all tables, chart labels, axis ticks, and hover text. **CSV outputs retain full precision** (two decimal places). Where rounded subtotals do not visibly sum to a rounded total, the total is computed from unrounded values and rounded once — never summed from rounded parts.

## Output

Written to `output/` (`--outdir`):

- **`report_fy.html`, `report_cy.html`** — self-contained: tables and charts inline, no network access needed to view.
- **`fy_summary.csv`, `cy_summary.csv`** — tidy summary tables, all history. These are the artefacts safe to paste back into the engine.
- **`quarantine.csv`, `duplicates.csv`, `transfers_excluded.csv`** — local review only.

> **Implementation note — embed the Plotly bundle exactly once.** Calling `fig.to_html(include_plotlyjs="inline")` per figure embeds the full ~3 MB library in every chart; at 120 charts that is an unopenable file. Use `include_plotlyjs="inline"` on the **first** figure only and `include_plotlyjs=False` on all subsequent ones, with `full_html=False` throughout, assembling the page yourself.

## Edge cases

Defined behaviour, not crashes:

- **Empty CSV or header-only** — clear message, exit non-zero, no outputs written.
- **All rows quarantined** — write `quarantine.csv`, report prominently, skip report generation.
- **An account with no rows in a charted period** — render the section with an explicit "no transactions in this period" note rather than an empty chart.
- **Fewer categories than `--top-n`** — chart whatever exists, no padding.
- **Single account in the file** — all-accounts and per-account scopes are near-identical; emit the all-accounts scope only, with a note.
- **A period with zero net movement** — still listed in tables.

## Acceptance criteria

The script is correct when, on the synthetic fixture:

1. `quarantined + aggregated == input rows` — every row accounted for exactly once.
2. In per-account scope, per-account sums reconcile to the period total, and per-category subtotals sum to the account total.
3. **All-accounts total == sum of per-account totals − excluded transfer value.** The two scopes are expected to differ by exactly the transfers removed; any other gap is a bug.
4. `net == debit − credit` at every level of aggregation.
5. Every transaction falls into exactly one FY bucket and exactly one CY bucket; boundary dates (30 Jun / 1 Jul, 31 Dec / 1 Jan) land in the expected period.
6. Transfer matching is one-to-one — no row appears in `transfers_excluded.csv` twice, and the fixture's planted transfer pair is detected while its planted equal-amount non-transfer pair is not.
7. Same-named subcategories under different parents remain distinct in every sunburst.
8. Re-running on identical input produces byte-identical CSV outputs.
9. The report opens offline with no console errors, and every TOC link resolves.

## Privacy boundary

`quarantine.csv`, `duplicates.csv`, and `transfers_excluded.csv` contain raw row content including free text, and stay local — debugging aids, not things to paste back. HTML reports and summary CSVs contain only aggregates over Account/Category/Subcategory and are safe to share back into the engine. Keep `output/` and any raw data directory out of version control.

## Dependencies

Python 3.11+. `pandas`, `plotly`, pinned in `requirements.txt`. Standard library otherwise. No Kaleido/static-image export in v1 — charts are interactive HTML only.

## CLI

```
python scripts/eda_data.py --input path/to/transactions.csv [options]

  --input PATH              Source CSV (required)
  --outdir PATH             Output directory (default: ./output)
  --validate-only           Profile the file and exit without writing reports
  --periods N               Most recent N periods to chart (default: 3)
  --fy-start-month N        Financial year start month, 1-12 (default: 7)
  --date-format FMT         Explicit strptime format; skips inference
  --encoding ENC            File encoding (default: utf-8-sig)
  --delimiter CHAR          Override delimiter sniffing
  --top-n N                 Bars per top-N chart (default: 15)
  --sort-by {debit,credit,net}   Summary table ordering (default: debit)
  --hierarchy-style {sunburst,icicle}
  --transfer-window DAYS    Max date gap for transfer pairing (default: 3)
  --transfer-categories STR Comma-separated category name matches (default: transfer)
  --no-transfer-detection   Disable transfer detection entirely
```

## Out of scope

- Categorisation logic — `Category`/`Subcategory` are taken as given. Rule-based categorisation belongs to the Cash Flow report.
- Any mapping onto the 7 cash-flow buckets in `cashflow_requirements.md`. This is exploratory analysis of the raw category tree as it exists.
- Tag-based filtering or breakdown.
- Multi-currency handling.
- Month-over-month trend, forecasting, and pro-rated projections.
- Writing back to or modifying the source CSV — strictly read-only on input.
