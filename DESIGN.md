---
name: Kaban
description: A quiet, ledger-calm privacy-first finance tracker for Philippine wallets.
colors:
  verdant-ledger: "#1B7F5F"
  ledger-paper: "#F1F5F4"
  warn-amber: "#D97706"
  overdraft-red: "#DC2626"
typography:
  display:
    fontFamily: "system-ui, sans-serif"
    fontSize: "32px"
    fontWeight: 800
    lineHeight: 1
    letterSpacing: "-0.5px"
  headline:
    fontFamily: "system-ui, sans-serif"
    fontSize: "28px"
    fontWeight: 800
    letterSpacing: "-0.6px"
  title:
    fontFamily: "system-ui, sans-serif"
    fontSize: "16px"
    fontWeight: 600
  body:
    fontFamily: "system-ui, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.4
  label:
    fontFamily: "system-ui, sans-serif"
    fontSize: "12px"
    fontWeight: 600
    letterSpacing: "0.4px"
rounded:
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  pill: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
components:
  button-primary:
    backgroundColor: "{colors.verdant-ledger}"
    textColor: "#FFFFFF"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    padding: "14px 20px"
  button-outlined:
    backgroundColor: "transparent"
    textColor: "{colors.verdant-ledger}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    padding: "12px 16px"
  card-surface:
    backgroundColor: "{colors.ledger-paper}"
    rounded: "{rounded.lg}"
    padding: "16px"
---

# Design System: Kaban

## Overview

**Creative North Star: "The Quiet Ledger"**

Kaban looks the way a well-kept ledger feels: calm, precise, and honest. The interface is a Material 3 surface system seeded from one deep green — a quiet signal that money is being handled carefully, not a marketing color. Nothing shouts; hierarchy comes from weight, size, and spacing, and color appears only where it means something: income, overspend, warnings, brand.

The system is tonal, not outlined. Surfaces are distinguished by subtle lightness steps, and borders appear only when they carry meaning — a selected state, a warning, a wallet's brand color. Depth is flat by design: no shadows, no elevation theater; the screen reads as a single calm document.

The personality is restrained and quiet. Buttons are confident but unadorned. Typography leads — tight, bold numbers for balances, small-caps labels for structure, and generous whitespace between groups. The result should feel like a well-maintained record book, not a banking app's dashboard.

**Key Characteristics:**
- One accent color, used sparingly; everything else is tonal gray-green
- Flat, borderless surfaces; borders are semantic, not decorative
- Numbers carry the page — big, bold, tabular, peso-formatted
- Quiet motion: 150-280ms ease-out transitions, never attention-seeking
- Material 3 components, but tamed: no shadows, no gradients, no glass

## Colors

A single-seed green and its tonal family; all other colors earn their place semantically.

### Primary
- **Verdant Ledger** (#1B7F5F): The one brand color. Seed of the whole Material scheme. Used for primary buttons, active nav indicators, income, positive progress, and focus states. On the dashboard it marks money flowing in and debt being paid down.

### Secondary
- **Warn Amber** (#D97706): Overspend and warning severity only. Appears in the insight banner and warning icons. Never decorative.

### Tertiary
- **Overdraft Red** (#DC2626): Expenses, overspend alerts, negative balances, destructive actions. Paired with Verdant Ledger in the income/expense summary bar.

### Neutral
- **Ledger Paper** (#F1F5F4): The soft off-white that tints cards, chips, and input fills. The paper of the record book.
- **Surface Tints** (Material `surfaceContainerLow/High/Highest`): The full tonal ramp derived from the seed. Cards use `surfaceContainerLow`; input fills and chips use `surfaceContainerHighest` at 40-50% alpha.
- **Outline Variant** (Material): Borders and dividers, always at 30-40% alpha when used as a hairline.

### Named Rules
**The One Green Rule.** Verdant Ledger is the only accent color on any screen. Amber and red appear only when the data demands them. If a screen has three accent colors, something is wrong.

**The Meaningful Border Rule.** A border only exists to carry meaning — selection, warning, or a wallet's brand color. Never draw a border as decoration around a resting card.

## Typography

**Display Font:** System UI (Roboto on Android, platform default elsewhere)
**Body Font:** System UI
**Label/Mono Font:** System UI (numerals always via tabular figures where data is aligned)

**Character:** Type does the talking. Numbers are big, bold, and tightly tracked; labels are small, uppercase, and widely tracked. The pairing of huge numerals with tiny structural labels is the system's signature move.

### Hierarchy
- **Display** (800, 28-32px, tracking -0.5 to -0.6): Net worth and dashboard headline numbers only. The hero of the ledger page.
- **Headline** (800, 22-24px, -0.4): Section-level money figures — total debt, subscription totals, onboarding headers.
- **Title** (700, 15-16px, -0.2): Card titles, sheet titles, list item names.
- **Body** (400-600, 14px, 1.4): Paragraph text, descriptions, chat messages. Body labels on data rows are 12px at weight 600.
- **Label** (600-700, 12px, +0.4, uppercase): Structural labels — "NET WORTH", "ARCHIVED", card kickers. Uppercase only for data labels, never for prose.

### Named Rules
**The Number-First Rule.** When a screen shows a money figure, the number is the largest thing on it. Labels explain the number; they never compete with it.

## Layout

The app is a single-column mobile layout with a 16px page gutter and a 12px spacing rhythm. Cards are full-width and stack vertically with 10-12px gaps; related content inside a card is separated by 4-6px. Groups are separated generously — 14-20px between sections, more space above a heading than below it.

The bottom navigation bar (5 tabs) is the app's spine; everything else opens as a full-screen route or a bottom sheet. Bottom sheets are scroll-controlled, respect the keyboard inset, and cap at 75% of screen height when content is tall.

Charts sit inside standard cards and share their padding: the pie is 140px with a legend beside it; the bar chart is 150px tall with a 24px month-axis reserve.

## Elevation & Depth

Flat by design. The system uses no shadows anywhere — no card elevation, no floating action button shadow. Depth is conveyed by tonal layering alone: content sits on `surface`, cards on `surfaceContainerLow`, inputs and chips on `surfaceContainerHighest`.

**The Flat-By-Default Rule.** Surfaces are flat at rest. If a future component needs a shadow, it must earn it by being genuinely floating (a menu, a tooltip) — and even then it should be a soft offset blur, never a hard halo.

## Shapes

The form language is gently rounded rectangles. Cards use 16px corners (the default container); buttons and inputs 12px; small tiles and chips 8-14px; pills (999px) are reserved for small non-interactive tags like frequency badges and option counts. Chart bars and progress indicators use 4-6px end radii. Corners are consistent within a component class — a card is always 16, a button always 12.

## Components

### Buttons
- **Shape:** 12px radius, 12-14px vertical padding.
- **Primary:** Filled, Verdant Ledger background, white text, weight 600. Used for the single main action on a sheet or screen.
- **Secondary:** Outlined, transparent fill, Verdant Ledger text. Used for cancel, back, and secondary actions. On destructive flows the outline and text are Overdraft Red.
- **Hover / Focus:** No hover state (mobile); pressed state is the default Material ripple. No elevation change.

### Chips
- **Style:** `surfaceContainerHighest` at ~60% alpha fill, 999px pill radius, 12px label.
- **State:** Selected chips take the Verdant Ledger tinted container with the green text; unselected are neutral tonal. Chips are for suggestions and tags, never primary actions.

### Cards / Containers
- **Corner Style:** 16px (the default), 12px for inline status cards, 14px for tiles inside lists.
- **Background:** `surfaceContainerLow`, occasionally tinted 55% primary container for emphasis (net worth, headers).
- **Shadow Strategy:** None — see Elevation & Depth.
- **Border:** None at rest. Selected/warning cards add a 1-1.5px semantic border.
- **Internal Padding:** 16px standard, 12px compact.

### Inputs / Fields
- **Style:** Filled — `surfaceContainerHighest` at 30-40% alpha, 12px radius, no border. Prefix/suffix icons are 18px and muted.
- **Focus:** Default Material focus ring in Verdant Ledger. No glow, no fill change.
- **Error / Disabled:** Disabled inputs dim via opacity; errors use the standard Material error color on the label only.

### Navigation
- **Style:** Material 3 NavigationBar with `surface` background, Verdant Ledger tinted indicator, 12px weight-500 labels. Five destinations: Home, Wallets, Activity, Debts, Coach.
- **State:** Selected tab shows a filled rounded indicator; unselected are outline icons at rest.

### Action Cards (coach)
- **Style:** Inline cards under assistant messages: `surfaceContainerHighest` at 50% alpha, 12px radius, 1px outline-variant border.
- **Content:** Icon + uppercase label row, bold summary line, optional wallet dropdown, then No/Add buttons (outlined + filled primary).
- **Behavior:** Dismissible; confirm triggers a snackbar. The card is a suggestion, never an auto-action.

### Status / Insight Banner
- **Style:** 12px radius, 8% tinted background of the severity color, 25% alpha border of the same color, 14px padding.
- **Severity colors:** info = Verdant Ledger, warn = Warn Amber, alert = Overdraft Red. Icon 20px, title 13px bold, detail 12px.

## Do's and Don'ts

### Do:
- **Do** lead every data screen with its number, biggest and boldest.
- **Do** use 12-16px radii, 16px card padding, and the 12px spacing rhythm — never invent new sizes for the same component class.
- **Do** put the one primary action in a filled Verdant Ledger button and everything else outlined.
- **Do** keep motion to 150-280ms ease-out transitions on state changes only.
- **Do** use the official bank/e-wallet SVG logos wherever a wallet appears (picker, card, dropdown).

### Don't:
- **Don't** add shadows, gradients, glass, or decorative borders — depth is tonal layering, nothing else.
- **Don't** use accent colors for decoration; Verdant Ledger is for money-in and action, Overdraft Red for money-out and danger, Warn Amber for warnings only.
- **Don't** stack cards inside cards — one container per surface level.
- **Don't** place text over a bank logo; logos sit on neutral surfaces with padding.
- **Don't** invent kickers above headings — the heading carries its own weight; uppercase labels are for data, not titles.
