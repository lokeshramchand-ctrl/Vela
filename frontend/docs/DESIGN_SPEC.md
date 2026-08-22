# Vela Mobile App v2 — Implementation Spec (from Claude Design source)

Source: Claude Design project `6f29813d-e9c1-48a3-bd73-8d1567258312`, file `Vela Mobile App v2.dc.html` (all 12 screens + design-system section), device chrome cross-checked against `android-frame.jsx`. `Vela Mobile App.dc.html` (v1) intentionally superseded — see §7.

## 0. Product framing (verbatim from source intro copy)

> "A financial analyst in your pocket. Rebuilt around periods and signals instead of files and sections — dark money surfaces, light reading surfaces, one luminous accent, tabular numerals throughout."

- **CUT FROM V1**: statement-card shelf on Home, desktop drag-and-drop upload sheet, decorative donut, 4-tab bar with a data table as a peer of Home.
- **NEW MODEL**: A statement becomes a **period**, switched from one header pill. Home answers three questions in order: what came in and out, what should I know, where did it go.
- **BACKED BY REAL ENDPOINTS**: Every number maps to `statements/{id}/analytics`, `/insights`, `/transactions`, `jobs/{id}`, `/v1/feedback`. No invented capabilities.

Bottom nav is **3 tabs only**: Overview, Signals, Activity. Profile ("You") is reached via avatar tap, not a tab. No donut/pie chart, no desktop drag-drop.

## 1. Screen inventory

| # | Screen | Group |
|---|---|---|
| 01 | Overview — flow → signals → breakdown | 01 The Period Loop |
| 02 | Period switcher — replaces the file list | 01 The Period Loop |
| 03 | Category drill-down | 01 The Period Loop |
| 04 | Activity — sticky filters, day totals, skeleton row | 01 The Period Loop |
| 05 | Transaction sheet — grounded explanation + feedback | 01 The Period Loop |
| 06 | Signals — headline + ranked, typed insights | 02 Intelligence |
| 07 | Recurring — rhythm strip, not a list | 02 Intelligence |
| 08 | You — dark mode (Profile/Settings) | 02 Intelligence |
| 09 | First run — empty state doing the teaching | 03 First Run & System States |
| 10 | Uploading — native picker result, early validation | 03 First Run & System States |
| 11 | Analysing — job stages as progress you can read | 03 First Run & System States |
| 12 | Rejected file — error that fixes itself | 03 First Run & System States |

All screens mocked in an `AndroidDevice` frame, 412×892, 18px bezel radius, 8px border `rgba(116,119,117,.5)`. Frame chrome: 40px status bar (clock left, camera punch-hole center, signal/wifi/battery right), 24px gesture nav bar (108×4px pill, centered). No Material top app-bar used anywhere — every screen builds its own custom header.

## 2. Design tokens

### 2.1 Color (OKLCH, exact — see `lib/core/theme/app_colors.dart` for the Dart port)

| Token | OKLCH | Role |
|---|---|---|
| ink900 | oklch(17% .012 265) | Darkest app surface (dark screen backgrounds) |
| ink850 | oklch(19.5% .013 265) | Dark elevated surface (sheets, cards, tiles) |
| ink800 | oklch(22% .014 265) | Dark surface level 2 |
| ink700 | oklch(27% .015 265) | Dark surface level 3 (active nav pill, toggle-off track) |
| hairline-d | oklch(100% 0 0 / .09) | Hairline border on dark |
| on-dark | oklch(97% .004 265) | Primary text on dark |
| on-dark-muted | oklch(73% .014 265) | Secondary text on dark |
| on-dark-faint | oklch(56% .015 265) | Tertiary/disabled on dark |
| paper | oklch(97.6% .004 265) | Light screen background |
| card | oklch(100% 0 0) | Light card surface |
| hairline-l | oklch(92% .006 265) | Hairline border on light |
| on-light | oklch(21% .015 265) | Primary text on light |
| on-light-muted | oklch(50% .015 265) | Secondary text on light |
| on-light-faint | oklch(66% .012 265) | Tertiary text on light |
| accent | oklch(85% .17 148) | Brand/positive ("money kept") |
| accent-dim | oklch(62% .13 150) | Links, secondary bars, chart fills |
| accent-ink | oklch(26% .07 150) | Text/icons on accent fills |
| accent-tint | oklch(94% .05 148) | Light tint bg for accent chips |
| violet | oklch(72% .13 292) | Category: Travel/Personal care |
| sky | oklch(76% .11 238) | Category: Shopping/Uber |
| amber | oklch(82% .13 80) | Warning/"Watch", Bills category |
| rose | oklch(69% .15 15) | Outflow/negative/error |
| amber-tint | oklch(95% .04 80) | Amber chip/banner bg |
| rose-tint | oklch(95% .035 15) | Rose chip/error icon bg |

Inline sub-tokens (recur repeatedly, treat as real tokens):
amber-ink `oklch(45% .1 70)`, amber-text-on-tint `oklch(38% .09 70)`, violet-ink `oklch(38% .1 292)`, violet-tint `oklch(95% .02 292)`, sky-ink `oklch(38% .09 238)`, sky-tint `oklch(95% .02 238)`, rose-ink `oklch(40% .12 15)`, rose-avatar-tint `oklch(95% .03 15)`, progress-track-light `oklch(93% .006 265)`, skeleton-base `oklch(94% .005 265)`, skeleton-highlight `oklch(96% .004 265)`, analysing-glow-center `oklch(24% .04 155)`, scrim-heavy `oklch(10% .01 265/.7-.72)`, scrim-medium `oklch(20% .01 265/.35)`.

**Category → color**: Food = accent-dim, Travel = violet, Bills = amber, Shopping = sky, Personal Care = violet, Income = accent, generic negative = rose.

### 2.2 Typography

Fonts: **Space Grotesk** (500/600/700, amounts & headlines), **Instrument Sans** (400/500/600/700, body), **IBM Plex Mono** (400/500/600, micro-labels/meta/tabular). Global `font-variant-numeric: tabular-nums`.

| Role | Font/weight | Size/line-height | Tracking |
|---|---|---|---|
| Hero amount | Space Grotesk 700 | 44/1 (Home) · 40/1 (Recurring) · 36/1 (drill-down) · 34 (Analysing %) | −0.02 to −0.03em |
| Screen title | Space Grotesk 700 | 24 | −0.02em |
| Big headline | Space Grotesk 700 | 32/1.2 · 26/1.25 · 22/1.3 | −0.02 to −0.03em |
| Signal body | Instrument Sans 500 | 17/1.45 | — |
| Card body | Instrument Sans 500 | 15/1.45 | — |
| Row label | Instrument Sans 600 | 14-14.5 | — |
| Row meta | IBM Plex Mono 500 | 11.5-12 | slight |
| Micro label (ALL CAPS) | IBM Plex Mono 600 | 10.5-11 | +0.1 to +0.12em |
| Buttons | Instrument Sans 600 | 12-15 | — |

Currency: `₹` symbol, Indian comma grouping (`₹80,634`), true minus before symbol for negatives (`−₹4,500`), tabular numerals. Dates: `28 JUN · SUN`, `04:47 PM`, `Jan – Jun 2026`, `28 JUN 2026 · 04:47 PM`.

### 2.3 Spacing / radius / elevation

- Spacing scale: 4·8·12·16·22·26·32px. Screen gutter = **22px**.
- Radius: 8 (chip) · 12 (field) · 18 (card) · 28 (sheet, top corners only) · pill/100 (buttons, badges, avatars, nav, toggles).
- Elevation: Flat `0 1px 2px oklch(0 0 0/.05)`; Card `0 1px 2px oklch(0 0 0/.04), 0 14px 30px -18px oklch(0 0 0/.18)`; Sheet `0 -20px 60px -20px oklch(0 0 0/.35)` or `0 18px 40px -14px oklch(0 0 0/.5)` (floating nav). **Dark mode uses hairlines only, never shadows.**

### 2.4 Motion

| Interaction | Spec |
|---|---|
| Signal reveal | 6px rise + fade, 240ms, 60ms stagger |
| Chart draw | Bars grow from baseline, 420ms `cubic-bezier(.2,.8,.2,1)`, left→right |
| Period switch | Numbers count-morph 300ms, hero hue crossfades, **no page slide** |
| Progress ring | Sweeps to each job stage, never loops idly |
| Haptics | Light tick on period switch/filter change; success thud on analysis complete; nothing else |
| Pull to refresh | Only re-polls an in-flight job; completed periods are immutable |

Keyframes: `vshimmer` (skeleton sweep, 1.4s linear infinite), `vpulse` (opacity .35↔.9 + scale 1↔1.35, 1.4-1.6s ease-in-out infinite — analysing dots, live period indicator), `vsweep` (diagonal progress-bar shine, 1.5s ease-in-out infinite), `vrise` (entrance: opacity 0→1, translateY 6px→0, .4s ease both, staggered delay).

### 2.5 Accessibility rules

Amount color never the only signal (±sign + icon also carry direction). Body text ≥4.5:1 contrast. Tap targets ≥44px (floating nav clears OS gesture area). Category hues stay distinguishable in deuteranopia because rank/label/amount are always co-present. Reduced-motion drops rise/sweep animations, shows final states instantly.

## 3. Screen-by-screen spec

### 01 · Overview (Home) — dark frame
1. **Header** (bg ink900, padding 6/22/26px):
   - Period pill (dot + "Jan – Jun 2026" + ▾caret, ink800 bg, hairline-d border, pill radius) → tap opens **Period switcher (02)**.
   - Bell icon button (34px circle, ink800, unread dot) + Avatar chip "AK" (34px, gradient accent→accent-dim) → tap avatar → **You (08)**.
   - Label "NET FLOW · 6 MONTHS" (mono 11px tracked).
   - Hero "−₹51,659" (44/1) + delta chip "▲ 12%" (rose tint).
   - Split flow bar: 8px pill, two proportional segments — Sent (rose→orange gradient, flex 80634) / Received (accent, flex 28975).
   - Stat row: SENT ₹80,634 (left) / RECEIVED ₹28,975 (right, accent-dim color).
   - Reconciliation pill: "✓ Reconciled against the statement's own totals".
2. **Body** (padding 24/22/108px):
   - SIGNALS section header + "All 5 →" link → **Signals (06)**.
     - WATCH card (amber): "Salon spend jumped to ₹4,500 — 18× your usual ₹250 visit." + "Based on 6 visits" + "See transaction" → **Transaction sheet (05)**.
     - GOOD card (accent): "Food spend fell 18% versus the previous statement."
   - WHERE IT WENT section + "of ₹52,300".
     - 4 ranked category rows (bar width relative to largest category, not absolute %): Food ₹16,736/32%/100% width/accent-dim + "↓18% vs previous period"; Travel ₹11,506/22%/69%/violet; Bills ₹9,414/18%/56%/amber; Shopping ₹7,322/14%/44%/sky.
     - "Show 4 more categories" link (8 categories exist total).
   - Tapping a category row → **Category drill-down (03)**.
3. **Floating bottom nav pill** (3 segments: Overview[active] / Signals / Activity).

Empty-state variant of this screen = **First run (09)** when zero periods.

### 02 · Period switcher — modal sheet over Overview, dark
Sheet (ink850, radius 28/28/0/0). Title "Choose a period" + subtitle. 3 rows:
1. Selected/current "Jan – Jun 2026" / "184 txns · ₹80,634 out" — highlighted (ink700 bg, accent border, checkmark badge).
2. In-progress "Jul 2026" — pulsing dot + "ANALYSING · 64%" (amber, vpulse) → tap → **Analysing (11)**.
3. Past "Jul – Dec 2025" / "203 txns · ₹91,120 out".
Add-statement row (dashed border): "+" tile + "Add a statement" / "Google Pay → Transaction statement → PDF" → **Upload flow (10)**.
Footer: "Periods never overlap twice — re-uploading the same statement updates it in place."
Selecting a completed period switches Overview's data (count-morph 300ms, no slide) and closes the sheet.

### 03 · Category drill-down — light body, dark-painted header
Header (ink900): back "‹" → **Overview (01)** / "Jan – Jun 2026" centered / "⋯" more-menu. Category label (dot + "Food"). Hero "₹16,736" (36/1) + delta chip "↓ 18%" (accent tint).
Monthly mini bar chart: 6 bars JAN-JUN, heights 54/72/100/66/47/38%, translucent white except current month (JUN, accent-filled, floating tooltip "₹1.9k").
Body: "MERCHANTS IN FOOD" list card — Swiggy "S" ₹6,240 (28 orders·₹223 avg); Zomato "Z" ₹3,880 (17 orders·₹228 avg); Blue Tokai "B" ₹3,410 (11 visits·₹310 avg).
AI insight card: "✦ Weekday lunches make up 61% of your food spend. Ordering in twice less per week would free about ₹1,800 a month."

### 04 · Activity (transaction list) — light
Sticky header (paper @92% + blur(12px)): "Activity" (24px) / "184 TXNS". Search bar (placeholder "Search merchant, amount, UPI ID"). Filter chips: All[active] / Out / In / Category▾ / ₹▾.
Body grouped by day, day header = date + day total:
- "28 JUN · SUN" / total "−₹4,950" — Toni and Guy (violet avatar "T") "−₹4,500" + "UNUSUAL" badge (amber) → tap → **Transaction sheet (05)**; Swiggy (accent avatar "S") "−₹450".
- "27 JUN · SAT" / total "+₹41,690" (accent-dim, positive day) — Salary credit ("↓" accent icon) "+₹42,000"; Uber (sky avatar "U") "−₹310".
- Skeleton loading row (shimmer placeholder) representing lazy pagination.

### 05 · Transaction sheet — modal sheet over Activity, light
Sheet (card/white, radius 28/28/0/0). Header: avatar "T" (46px violet) — Toni and Guy / "28 JUN 2026 · 04:47 PM" — amount "−₹4,500" (22px).
Anomaly banner (amber-tint): "18× higher than your typical ₹250 spend here — flagged by the anomaly check, not a payment failure."
Details table: Category → Personal Care [EDIT link]; UPI transaction ID → 116512346960; Paid by → HDFC BANK ···5488; Period → Jan – Jun 2026.
AI explanation card (dark ink900 embedded in light sheet): "✦ WHY THIS CATEGORY" / "HIGH CONFIDENCE" — "Matched to a salon you've paid 6 times, always between ₹200–₹300 on weekends. Grounded in your own history — never guessed."
Feedback row: "Looks right" / "Wrong category" buttons → **POST /v1/feedback/**.
Footer: "Your correction trains Vela's merchant memory."

### 06 · Signals — dark, full screen
Header: "Signals" (24px) / "JAN–JUN 2026".
Headline card (accent gradient): "You spent ₹80,634 across six months and kept ₹28,975 coming in. Food and travel are 54% of everything — and both are trending down."
Filter chips: All 5[active] / Watch 2 / Good 2.
Signal cards (ink850, radius 18):
1. WATCH/ANOMALY: "Salon spend jumped to ₹4,500 — 18× your usual ₹250 visit." Evidence row: "z-score 4.8 · 6 visits observed" + "Open" link → **Transaction sheet (05)**.
2. GOOD/TREND: "Food spend fell 18% versus your previous statement, saving about ₹3,600."
3. WATCH/RECURRING: "Two subscriptions bill ₹698 every month — 1.3% of your outflow." → tap → **Recurring (07)**.
4. CONTEXT: "Uber was your most frequent merchant — 34 rides at ₹150 average."
Footer: "Signals are written from your computed analytics only. If a figure isn't in your statement, Vela won't claim it."
Note: header count (All 5/Watch 2/Good 2) is a mock placeholder inconsistency (only 4 cards shown) — build the list dynamically counted from real signal data, don't hardcode counts.

### 07 · Recurring — dark header / light body
Header: back "‹" + "Recurring" → **Signals (06)**. Label "COMMITTED EVERY MONTH". Hero "₹698" (40/1). Stat row: DETECTED 2 / SHARE OF OUTFLOW 1.3% / NEXT 7 DAYS ₹499 (amber).
Body: 2 subscription cards, each with avatar + name + "BILLED Nth · NEXT date" + amount/month, and a **regularity strip** (7 rounded segments = months, filled=paid on schedule, lighter=skipped, dashed outline=upcoming/projected):
- Netflix (rose avatar "N") ₹499/mo, 94% regular, 7 filled segments.
- StreamPlus (violet avatar "S") ₹199/mo, 88% regular · 1 skip (one mid segment lighter).
Footer: "Detected from payment regularity in your statements — no bank connection, no card access."

### 08 · You (Profile/Settings) — dark, full screen
Title "You" (24px). Profile row: avatar "AK" (54px) — Aditi Kulkarni / aditi.kulkarni@gmail.com — "Edit" button.
Stat tiles (3, equal width): PERIODS 3 / TXNS ANALYSED 571 / CORRECTIONS 7.
**DATA** section: "Manage periods" → "3 ›"; "Keep original PDFs" toggle ON; "Export my data" ›.
**APPEARANCE & ALERTS** section: "Theme" 3-way segmented control Light/Dark[active]/Auto; "Analysis finished" (sub: "Push when a period is ready") toggle ON; "Unusual spend" (sub: "Only WATCH-level signals") toggle OFF.
"Sign out" button (outline pill). "Delete account and all data" (rose text link).

### 09 · First run (empty state / onboarding) — dark, flex column
Logo row: "V" mark + "Vela" wordmark.
Illustration: 7-bar mini chart, 2 highlighted bars.
Headline: "Six months of spending, explained in a minute." (32/1.2).
Subcopy: "Add one Google Pay statement. Vela reads every transaction, names the merchants, finds the patterns and tells you what changed."
3 numbered steps: (1) "Open Google Pay → Transaction statement" (2) "Pick any date range and export the PDF" (3) "Add it here — analysis takes under a minute".
Primary CTA: "Add your first statement" (full-width accent pill) → native file picker → **Uploading (10)**.
Footer: "Stays on your account. Never shared, never sold."
This is the empty state for Overview when zero periods exist.

### 10 · Uploading (native picker result) — dark, overlays blurred First-run
Sheet (ink850, radius 28/28/0/0). File row: "PDF" tile + "gpay_statement_jan–jun.pdf" / "2.4 MB · 19 PAGES" + "×" remove.
Progress bar: 6px pill, 78% fill, `vsweep` shine overlay. Labels: "UPLOADING · 78%" / "2s LEFT".
Early-validation card: "✓ Recognised as a Google Pay statement" + "PERIOD 01 JAN – 30 JUN 2026 · SENT ₹80,634 · RECEIVED ₹28,975".
Encrypted-PDF checkbox row: "Encrypted PDF? We'll ask for the password before parsing — it is never stored."
"Cancel upload" button.
On completion → **Analysing (11)**. On rejection → **Rejected file (12)**.

### 11 · Analysing (background job progress) — dark, radial gradient bg
Header: "Jan – Jun 2026" / "RUNNING IN BACKGROUND".
Progress ring (172px, conic-gradient, glow): "64%" (34px) + "118 / 184 TXNS" centered.
Headline "Finding your patterns" (22/1.3). Subcopy "Profiling merchant behaviour — how often you pay them, and how much is normal."
Job-stage checklist (5 stages): (1) done "Read 19 pages · 1.2s" (2) done "Named 47 merchants · 3.8s" (3) **active** (pulsing dot) "Profiling behaviour" (4) pending "Computing analytics" (5) pending "Writing your signals".
Teaser card: "Already know something: Swiggy is your most-paid merchant so far, 28 orders."
"Notify me when it's done" button.
This is the visual state for an in-progress period (polls **GET /jobs/{id}**).

### 12 · Rejected file (error state) — light, flex column
Nav: back "‹" / "Add statement" title.
Error icon (rose-tint, "!"). Headline: "This PDF isn't a Google Pay statement" (26/1.25).
Body: "We look for the "Transaction statement" header and UPI transaction IDs. This file has neither — it may be a bank statement or an invoice."
Instructional card "HOW TO GET THE RIGHT FILE": (1) "Google Pay → profile → Transaction statement" (2) "Choose a date range, tap Get statement" (3) "Share the PDF straight into Vela".
Reassurance: "Nothing was saved. Your other periods are untouched."
Buttons: "Choose a different file" (primary) → reopens file picker (10). "Open Google Pay" (secondary) → deep link to Google Pay app.

## 4. Component inventory

- **Floating bottom nav pill**: ink900 bg, hairline-d, radius 100, 3 segments, active gets ink700 pill + icon(accent outline) + label; inactive text-only faint.
- **Period pill chip**: ink800 bg, hairline-d, pill — dot + label + ▾caret.
- **Avatar chip**: circle/squircle, initials Space Grotesk 700; user = accent→accent-dim gradient; merchant = category-tint/ink pair.
- **Delta/change chip**: pill, tint bg + colored text + ▲/↓ glyph.
- **Signal card**: ink850(dark)/card(light), radius 18, icon chip + mono type label + optional subtype tag + body + optional evidence row/CTA. Entrance `vrise` 240ms, 60ms stagger.
- **Category/ranked bar row**: name+amount header, track+colored fill (width relative to max category)+%, optional trend caption.
- **List row** (merchant/transaction/subscription): avatar + 2-line text + trailing amount + optional badge.
- **Bottom sheet**: ink850(dark)/card(light), radius 28/28/0/0, drag handle 38×4, scrim behind, backdrop blurred/dimmed.
- **Toggle switch**: 38×22 pill; ON=accent+accent-ink thumb right; OFF=ink700+faint thumb left.
- **Segmented control**: ink700 pill container, active segment accent bg + accent-ink text.
- **Primary button**: full pill, accent bg, accent-ink text.
- **Secondary/outline button**: pill, hairline border, transparent bg.
- **Text-action link**: no container, accent-dim (or category color), 600 weight.
- **Linear progress bar**: pill track + colored fill, optional `vsweep` shine while active.
- **Circular progress ring**: conic-gradient vs translucent track, glow shadow, centered readout.
- **Skeleton loader**: `vshimmer` 1.4s linear infinite gradient sweep.
- **Micro badge/tag**: small pill, tint bg + colored mono uppercase text (UNUSUAL, WATCH, GOOD, ANALYSING).
- **Stat tile**: small card, mono micro-label + Space Grotesk value.
- **Monthly mini bar chart**: translucent bars + solid highlighted/current month, mono axis labels.
- **Recurring regularity strip**: 7 rounded segments/months, filled/lighter(skip)/dashed(upcoming).

Icon set: hand-drawn glyphs only (✓ ! › ‹ ▾ ⋯ ✦ ▲ ↓ × search-circle bell checkbox + drag-handle "i") — no icon font/SVG library beyond status-bar icons.

## 5. Navigation flow

```
First run (09) [zero periods] --"Add your first statement"--> file picker --> Uploading (10)
Uploading (10) --success--> Analysing (11)
Uploading (10) --validation failure--> Rejected file (12)
Rejected file (12) --"Choose a different file"--> Uploading (10)
Rejected file (12) --"Open Google Pay"--> external deep link
Analysing (11) [polls jobs/{id}] --on completion--> Overview (01) for the new period (+ push if enabled)

Overview (01) [nav tab] --period pill--> Period switcher (02)
Overview (01) --avatar--> You (08)
Overview (01) --"All 5 →"--> Signals (06)
Overview (01) --category row / "Show 4 more"--> Category drill-down (03)
Overview (01) --signal "See transaction"--> Transaction sheet (05)
Overview (01) --bottom nav--> Signals (06) / Activity (04)

Period switcher (02) --completed period--> switches Overview data, closes sheet
Period switcher (02) --in-progress period--> Analysing (11)
Period switcher (02) --"Add a statement"--> Uploading (10)

Category drill-down (03) --back--> Overview (01)
Activity (04) [nav tab] --transaction row--> Transaction sheet (05)
Transaction sheet (05) --"EDIT" category--> category picker (not mocked)
Transaction sheet (05) --feedback buttons--> POST /v1/feedback

Signals (06) [nav tab] --card "Open"--> Transaction sheet (05)
Signals (06) --RECURRING card--> Recurring (07)
Recurring (07) --back--> Signals (06)

You (08) --"Manage periods"--> period management list (not mocked)
You (08) --"Export my data"--> export flow (not mocked)
You (08) --"Sign out"--> auth flow
You (08) --"Delete account..."--> destructive confirm flow
```

## 6. Backend endpoint mapping

- `statements/{id}/analytics` → Overview hero/flow bar/category breakdown
- `statements/{id}/insights` → Signals screen + Overview "Signals" preview
- `statements/{id}/transactions` → Activity list + Category drill-down merchant list
- `jobs/{id}` → Uploading/Analysing progress polling
- `/v1/feedback` → Transaction sheet "Looks right"/"Wrong category"

(Note: the mock copy references `statements/{id}/analytics` etc. directly, but per API_REFERENCE.md the actual paths are `/statements/{id}/analytics` — no discrepancy, just path-root notation.)

## 7. Explicitly excluded (do not build)

No statement-card shelf on Home. No desktop drag-and-drop upload sheet. No decorative donut/pie chart anywhere. No 4-tab bottom nav (strictly 3: Overview/Signals/Activity). No data-table screen as a peer of Home. Profile/Settings is avatar-accessed, not tab-accessed.
