# UI/UX Upgrade Brief

**What this is.** A working method for raising Shuffl's interface to the standard of Stripe,
Mercury and Linear. It is a *method*, not a style guide: `DESIGN.md` remains the only source of
truth for anything visual. Where this file and `DESIGN.md` disagree, **`DESIGN.md` wins**.

Every trap in §5 is something a real session actually hit.

---

## 1. Read first
- **`DESIGN.md`**: statements are marked *binding*, *open*, or *known violation*. The visual law
  lives there; this brief deliberately does not restate it.
- **`CLAUDE.md`**: stack, schema, routes.
- **`application.css` `:root`**: the authoritative token list. **`theme.css`**: how each token
  flips for dark.

---

## 2. Findings before edits
Never open with a change. Produce a ranked table first:

| # | Finding | What it violates | Severity | Proposed fix |

Rank by value-per-risk, then work down. Make findings **measurable** where you can: "the left
column ends 288px short of the right" beats "the layout feels unbalanced".

---

## 3. Constraints
`DESIGN.md` already covers tokens, the one burgundy, the six breakpoints, the 1440 content width,
radius tokens, shadow rules, dark-mode-redefines-tokens, and the wordmark. Follow it; don't
re-derive it. The rules that are *not* in `DESIGN.md` and get missed:

- **No new framework or dependency.** Rails 8 + Propshaft + Importmap + Turbo + Stimulus,
  server-rendered ERB. No Tailwind, no CSS-in-JS, no icon library, no npm step.
- **Behaviour goes in a Stimulus controller** under `app/javascript/controllers/`. Never an inline
  `<script>`, never ad-hoc JS in `application.js`. Extend an existing controller before adding one.
- **Do not add a seventh page-scoped stylesheet.** Work inside the existing sheets; lift genuinely
  shared chrome up into `application.css`.
- **Hierarchy comes from weight, colour and space: not new type sizes.** The Geist heading scale
  is an *open* decision (§7). Use `--ink` / `--body-color` / `--muted`, weight and spacing instead.
- **Figures get `font-variant-numeric: tabular-nums`** and a shared alignment edge: money, dates,
  ranks, rates.
- **Never invent** savings figures, testimonials, live offers or financial data. Keep the
  sample-catalogue disclosure intact wherever figures appear.

---

## 4. Visual references

### >>> UPLOAD INSPIRATION SCREENSHOTS HERE <<<
Paste Mobbin / Stripe / Mercury / Linear screenshots into the conversation, or drop files in
`design/inspiration/` and give the path. For each, say **what you like** and **which surface it
maps to**.

**With no references provided, do not invent a new visual direction.** Work from `DESIGN.md` and
the existing surfaces, and ask.

**Extract:** spatial system (grid, gutters, density, rhythm) · hierarchy (what is loud, what is
deliberately quiet) · surface strategy (elevation, hairlines, grouping) · *relative* typographic
rhythm · motion character · state design.

**Never copy:** their colours, typefaces, logos, illustrations, or a layout one-to-one. Never
reproduce another company's branding or imply affiliation. Translate the spatial logic into our
tokens: the result must still look unmistakably like Shuffl.

---

## 5. Traps
- **Verify computed styles; never assume the cascade.** `theme.css` uses `:is()` selectors whose
  specificity comes from their most specific member, and they routinely out-specify page rules.
- **Colour work is property-aware.** `#777` is muted text *and* the card chip outline. `#fff` is a
  background *and* white text on burgundy/graphite card faces: mapping it to `--surface` breaks it
  in dark. Never blanket find-and-replace.
- **Never rewrite a custom-property definition.** `--ink:#f2eeee` in `theme.css` must stay literal
  or it becomes self-referential. If a page re-pins a token to a light value locally, **delete the
  re-pin** rather than fighting it downstream.
- **Check `overflow` before blaming z-index.** A clipped card corner was misdiagnosed as a
  stacking-order bug and cost a long session. The cause was one `overflow: hidden`.
- **Changing a container width changes measure.** After widening, re-check line length and cap
  prose near 60ch. Widening card detail to the canonical 1440 pushed perk text to ~95ch.
- **Floating overlays cover content.** The assistant bubble overlaps body copy and links at phone
  widths. Check any fixed/floating element against the content beneath it at every tier.
- **Sticky offsets must clear the nav.** `.site-nav` is `position: sticky; top: 12px` and ~89px
  tall, so a sticky rail wants roughly `top: 116px`.

---

## 6. Data states that must not break
Signed-out vs signed-in navbar · empty wallet · card already in wallet · no quiz taken · draft
`QuizResponse` (`completed_at: nil`) · **anonymous results stay viewable: never auth-gate
`quiz_responses#show`** · blank `welcome_bonus` / `credit_score_min` · card with no perks or
`best_for` · stack with no cards · zero search results · `noscript` fallbacks · very long card
names · ≥44px tap targets · `prefers-reduced-motion` · full keyboard path with visible focus ·
existing `aria-pressed` / `aria-expanded` / live regions.

The 54-card catalogue is **filler**; ~300 real cards are landing (`data/real_cards/`,
`CardCandidate`). Do not tune to specific card names, and do not build on the placeholder
`--finish-*` gradients.

---

## 7. Propose, don't decide
Some answers are Noah's. Surface them as a written proposal, never a quiet change:
- The **Geist heading scale** (open in `DESIGN.md`).
- Any **new token**: e.g. a warm surface for the bespoke creams (`#f5f3f0`, `#f6f5f2`, `#faf7f3`)
  that currently cannot theme in dark.
- **Homepage personalisation**: `DESIGN.md` forbids a personalised recommendation there.
- The **wallet layout and interaction rules**.
- **Card artwork conventions**: card faces hand-write the wordmark, which `DESIGN.md` otherwise
  forbids.

To change a binding answer: edit `DESIGN.md` first, in its own commit, with the reason.

---

## 8. Verify and ship
One concern per branch, small commits, a PR per slice. Never commit to `master`.
- Verify at **1440 and a phone width, in light *and* dark**. Click the real `.theme-toggle`:
  setting `data-theme` directly is reverted by the theme controller.
- `bin/rails test`
- `LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 bin/design-check` (it crashes in a non-UTF-8 locale).
  The raw-hex baseline may shrink but never grow; re-record with `--baseline`.

**Done means:** deliberate at 1440 / 1000 / 767 / 480 in both themes · keyboard path complete with
visible focus · reduced motion honoured · no new raw hex or font family · gates green · every state
in §6 still renders · the PR says what got better **and** what you deliberately left alone.

---

## 9. Surface map
Roughly in value order.

- **Results**: `quiz_responses/show.html.erb` · `results.css` · `results_controller.js`
  Our metric dashboard. `.summary` is a hero-metric panel and `#total` is the one number the page
  is about. Group `.breakdown` with hairlines, align values to a shared edge, make `.summary` a
  sticky rail at ≥1000px, and reserve width on live figures so dragging `#spend` never jitters the
  layout.
- **Browse**: `cards/index.html.erb` · `browse.css` · `browse_controller.js`
  Our table. Lock a column grid so `.metrics` align down the page; row hover is a surface shift,
  not a border. **The compare tray is the biggest bottleneck**: a default checkbox guarding the
  most valuable feature on the page; make selection raise a persistent bar. Client-rendered, so add
  skeleton rows matched to the final row height. Arrow-key traversal, Escape closes.
- **Wallet**: `wallet_items/index.html.erb` · `wallet.css` · `wallet_controller.js`
  Tracking dashboard. Noah's rules in `DESIGN.md` are binding; the craft inside them is yours:
  date and money legibility, tabs that read as one control, horizontal timelines that signal
  scrollability, quiet status text over badges.
- **Card detail**: `cards/show.html.erb` · `detail.css`
  Record page. Hero figure, spec rows aligned to a shared edge. The left column runs ~290px short
  of the right; a sticky rail closes it (trial-verified).
- **Quiz**: `quiz_responses/new.html.erb` · `quiz.css` · `quiz_controller.js`
  Binding "seamless ranked quiz": one ten-question journey, no stages. Polish bubble rhythm, ≥44px
  targets, and controls that never move between questions.
- **Navigation**: Shuffl is a **top-nav product. Do not bolt on a global sidebar.** Take the
  principles instead: persistent context, obvious current location, keyboard reachability, Escape
  closes. A persistent rail is only legitimate on the dashboard-shaped Results/Wallet columns.
- **Footer**: every link is an inert `aria-disabled` span. Give them real destinations or stop
  styling them as links.
