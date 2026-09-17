# Shuffl Design Language: "The Quiet Interface"

This document is the single source of truth for Shuffl's visual design. `CLAUDE.md` describes how
the app is built; anything visual is decided here and nowhere else.

## How to read this document

Every statement here is one of exactly three things, and it says which:

- **Binding.** A settled answer. Implement it as written. Do not substitute a near-miss value
  because it looks similar, and do not introduce a new value for a job a token already covers.
  If you believe a binding answer is wrong, change it here first, in its own commit, and say why.
- **Open.** A decision nobody has made yet, listed under *Open decisions* at the end. Until it is
  settled, do not invent an answer: reuse whatever the surrounding code already does and leave
  it alone. Every drift problem this codebase has had started as an open question answered quietly.
- **Known violation.** Something binding that the code does not yet do, listed under
  *Known violations*. These are debt, not precedent. Never cite one to justify another.

Two rules are machine-checked by `rake design:check` (see *Enforcement*). The rest are on you.

## Which wins, the document or the code?

**The document does: from now on.** To change a binding answer you edit this file first, in its
own commit, with the reason. Then you change the code. Never the reverse: a value typed into a
stylesheet does not amend this document, it just makes the document wrong, and a wrong document
is what produced three burgundies and a typeface nobody had licensed.

There was exactly one exception, applied once. Where this document and the code disagreed as of
September 2026, **the code won and this document was corrected to match it**: shadows, radius,
content width, breakpoints, the dark palette and the money-out colour were all settled that way.
That was a one-time reconciliation to stop the two drifting further apart, not a standing rule,
and it is now spent. The ordering above applies to everything after it.

One question could not be settled that way: the type scale. Deferring to the code requires the
code to contain an answer, and it contains no scale at all: every heading in the project uses a
`clamp()` that appears exactly once. It stays open below.

---

## The Three Rules

*Binding.*

1. **One family.** Every character: wordmark, 100px display headline, 12px disclosure: is set in
   the same tight grotesque. No second typeface, no monospace for numbers.
2. **One burgundy.** Exactly one filled burgundy control per screen, and it is always the thing the
   user came here to do. Nothing else on the page may use the colour. Burgundy is a verb.
3. **Nothing at rest.** A control that is not the next step is not visible at rest. It appears on
   hover/focus and disappears again.

---

## Design Tokens

### Colour

*Binding.* These are the CSS custom property names exactly as they are defined in
`application.css`'s `:root`. Reference them as `var(--token)`. A raw hex in any stylesheet is a
defect: see *Enforcement*.

| Token              | Hex / Value           | Use                                                              |
|--------------------|-----------------------|------------------------------------------------------------------|
| `--ink`            | `#0A0A0A`             | All primary text, wordmark, selection outlines, 1px structural rules |
| `--body-color`     | `#4A4A4A`             | Body copy, descriptive paragraphs                                |
| `--muted`          | `#6B6B6B`             | Captions, labels, disclosures, pence portions of figures         |
| `--hairline`       | `#E5E5E5`             | Card borders, section dividers                                   |
| `--hairline-soft`  | `#F0F0F0`             | Row separators inside a panel                                    |
| `--surface`        | `#FFFFFF`             | The only background. White is the loudest colour in the system.  |
| `--burgundy`       | `#601020`             | The single primary action per screen. Nothing else.              |
| `--burgundy-hover` | `#4C0D1A`             | Hover and active state of the primary button only                |
| `--pine`           | `#16624B`             | Money in: rewards, cashback, positive deltas                    |
| `--pine-pence`     | `#3F7A65`             | Pence portion of a pine figure (4.6:1 on white)                  |
| `--brick`          | `#A12A36`             | Money out: fees, interest, negative flags                       |
| `--overlay-from`   | `rgba(10,10,10,0)`    | Top stop of the hover-reveal scrim over card artwork             |
| `--overlay-to`     | `rgba(10,10,10,0.74)` | Bottom stop of that scrim                                        |

The card finishes (`--finish-bone`, `--finish-burgundy`, `--finish-graphite`, `--finish-steel`,
`--finish-silver`) are gradients for placeholder card artwork. They are temporary and will be
replaced by real card images: do not build anything else on them.

**The burgundy is `#601020` and only `#601020`.** The app previously carried three near-identical
burgundies (`#7B1622`, `#681522`, `#601020`) across different stylesheets because each was typed
by hand instead of referenced. All three are now `var(--burgundy)`. The two retired values are
banned outright by `rake design:check`.

**Colour budget:** burgundy must occupy under 3% of any screen's pixels. On a 1440×900 viewport
that is one button plus the wordmark rule. Pine appears only on figures, never on chrome.

**Never coloured:** headings, selected states, links at rest, tags, icons.

**Money out is `--brick`, not amber.** This document specified amber `#A85410` for two years and
no stylesheet ever used it; `browse.css` and `wallet.css` both used `#A12A36`. The code's answer
won. Amber is gone: do not reintroduce it. There is no `--brick-pence` yet: pine has one because
pine figures carry pence, and no money-out figure in the app currently does. Add it when one does,
and give it a contrast ratio above 4.5:1 on white, as `--pine-pence` has.

### Typography

**Font stack:** `--font-sans` → `"Geist", "Helvetica Neue", Helvetica, Arial, sans-serif`

Geist (Google Fonts) is the face. It is loaded in the layout and exposed as the `--font-sans`
token. Never name a font family directly in a stylesheet: that is how six sheets ended up
pinned to Helvetica and silently missed the last face change. Always reference the token.

The font stack above is **binding**, and so are the two reading sizes below. The heading
scale is still **open**: see *Open decisions*.

**Two reading sizes, both tokens.** `--text-body` (18px) is prose: the home page, detail pages,
the quiz, auth. `--text-dense` (16px) is listing chrome: browse, results and wallet, where the
page is a table of records rather than something you read top to bottom. Nothing else is a base
size, and neither number appears as a literal anywhere.

Those three pages previously ran at 15px, 16px and 14px: three arbitrary answers to a question
nobody had asked. Moving them onto one number turned out to be almost invisible: row height on
browse is set by the fixed card artwork, and everything with visual weight (card name 23px,
reward 22px, fee 22px, issuer 11px) carries an explicit size. The base only governs secondary
chrome: the search placeholder, the result count, the compare labels: which is exactly why
18px looked wrong there: it let supporting text compete with the data.

Two separate things are wrong with it. No stylesheet implements a single one of these steps:
`clamp(40px, 8.4vw, 104px)` does not appear anywhere in the codebase, and neither does any other
row. And the tracking values were tuned for Helvetica Now Display, which was never licensed and
never shipped; Geist sets appreciably tighter, so applying them as written runs the type too
close. That is the same fault that made the wordmark read as a capital L.

Until the scale is settled, **match the surrounding file rather than importing a row from this
table.** Treat it as a record of intent, not as values to paste.

| Step          | Size                       | Weight | Tracking   | Line-height | Use                            |
|---------------|----------------------------|--------|------------|-------------|--------------------------------|
| Display       | `clamp(40px, 8.4vw, 104px)` | 700    | −0.045em   | 0.95        | Page headline                  |
| Hero figure   | `clamp(44px, 6vw, 76px)`    | 700    | −0.04em    | 1.0         | The one number a page is about |
| Title         | 32px                       | 700    | −0.035em   | 1.1         | Card names in detail contexts  |
| Section head  | `clamp(26px, 3.6vw, 46px)` | 700    | −0.04em    | 1.1         | Numbered section headings      |
| Subhead       | 19–20px                    | 600    | −0.03em    | 1.3         | Card names in lists, sub-titles |
| Body          | 18px                       | 400    | 0          | 1.55        | The only reading size          |
| UI            | 15–17px                    | 400/600 | −0.015em  | 1.4         | Rows, buttons, controls        |
| Caption       | 14px                       | 400    | 0          | 1.6         | Supporting notes               |
| Disclosure    | 13px                       | 400    | 0          | 1.5         | Regulatory / illustrative copy |
| Eyebrow       | 12–13px                    | 400    | 0.08em     | 1           | Panel labels (uppercase)       |

**Rule:** tracking closes up as size grows. Nothing above 40px is looser than −0.04em; nothing
at or below 18px is tracked at all.

### Wordmark

The full stop in `shuffl.` is a **drawn circle, not a typed period**. Geist's period is square,
and its default sidebearing puts it inside the `l`'s optical space, so at display sizes the pair
closes up and reads as a capital `L`. Drawing it as a span fixes the shape and the spacing at once.

Never hand-write the mark. Render the partial:

```erb
<%= render "shared/wordmark" %>                           <%# links home %>
<%= render "shared/wordmark", class: "footer-wordmark" %> <%# sized by context %>
<%= render "shared/wordmark", link: false %>              <%# plain span, no link %>
```

`.wordmark` owns shape only: family, tracking (−0.054em) and the dot geometry. Weight, colour
and size belong to the context that uses it, so the mark can sit at 12px inside running text
without turning bold and black. The dot is `currentColor`, so dark mode needs no extra rule.

### Numerics

- Every figure: `font-variant-numeric: tabular-nums lining-nums` so columns align.
- **Pence drop to `muted`.** Split the string: `£412` in the figure's ink colour, `.00` in muted.
  For pine figures use `--pine-pence`, so the semantic colour survives while staying above 4.5:1
  contrast. This is a signature detail: do not skip it. The money-out equivalent waits on
  *Open decisions*.
- Deltas always carry a sign and a colour: `+£137` in `--pine`, `−£3.72` in the money-out colour.
- Currency symbol and unit never separate from the number across a line break.

### Spacing

8-point scale: `8 / 12 / 16 / 24 / 40 / 64 / 96`.

- Section padding: `clamp(40px, 5vw, 68px)` vertically
- Page gutter: `clamp(16px, 3.5vw, 56px)`: this one is real, it is the `--page-gutter` token
- Content max-width: **`1440px`**, centred

The 8-point scale above is aspirational: the code is full of off-scale values (`25px`, `27px`,
`38px`) and no token enforces it. The content width is the code's own majority answer: `1440px`
appears three times, against `1320px`, `1450px` and `1500px` elsewhere. Both are recorded under
*Known violations*.

### Radius & Elevation

Two radius tokens exist, and these are the values in `application.css`:

- `--radius-button`: `6px`
- `--radius-card`: `14px`

There is no row/panel radius token. Page-scoped sheets use `5px`, `8px`, `9px` and `12px` by hand;
that is recorded under *Known violations*.

**Shadows are used, deliberately, on floating surfaces only.** This document previously said "no
shadows anywhere", which was never true: there are 27 `box-shadow` declarations and the best
component in the app, the frosted navbar, is built out of a layered one. The rule was wrong, so
the rule changed.

A shadow is permitted when the element genuinely floats above the page:

- the navbar, the account menu, the mobile navigation menu
- the assistant orb and its panel
- dialogs, the compare tray, toasts, and the browse toolbar when it pins
- card artwork, which carries its own contact shadow

A shadow is **not** permitted to separate one block of static content from another. That is what
the hairline dividers are for, and "dividers over boxes" still holds. If you are reaching for a
shadow on something that does not float, you want a rule instead.

### Breakpoints

*Binding.* Five tiers, plus one large-desktop floor. Use these and only these:

| Tier          | Query                     | What changes                                  |
|---------------|---------------------------|-----------------------------------------------|
| Small phone   | `max-width: 480px`        | Footer collapses to two columns; tightest gutters |
| Phone         | `max-width: 640px`        | Multi-column grids go to one column           |
| Mobile        | `max-width: 767px`        | The main mobile breakpoint: nav collapses, layouts stack |
| Small tablet  | `max-width: 850px`        | Side panels drop below their content          |
| Laptop        | `max-width: 1000px`       | Two-column page layouts become one            |
| Large desktop | `min-width: 1600px`       | Wider hero and card-fan treatment             |

These were read off the code, not designed: `767px` was already the dominant mobile value at eight
uses, and where two near-identical values tied, the one used by a shared stylesheet won. That is
why the tiers are not round numbers and do not match Bootstrap's.

The project currently also contains `760px`, `860px`, `650px`, `1050px` and `520px`: near-misses
of the tiers above, each invented by whichever stylesheet needed one. They are recorded under
*Known violations* and should converge on this table. **Do not add a twelfth breakpoint.** If a
layout needs to change at a width that is not in this table, that is a signal the layout is wrong,
not that the table is missing a row.

### Dark mode

*Binding.* Dark mode is driven by `data-theme="dark"` on `<html>`, set by the navbar toggle and
persisted in `localStorage` under `shuffl-theme`. `theme.css` implements it.

The mechanism is correct and should be followed: **dark mode redefines the tokens, it does not
restyle components.** Inside `html[data-theme="dark"]`, `theme.css` overrides the core token set,
and anything built on `var(--token)` inverts for free:

| Token            | Light     | Dark      |
|------------------|-----------|-----------|
| `--ink`          | `#0A0A0A` | `#F2EEEE` |
| `--body-color`   | `#4A4A4A` | `#D2CBCD` |
| `--muted`        | `#6B6B6B` | `#AFA5A8` |
| `--hairline`     | `#E5E5E5` | `#443B3F` |
| `--surface`      | `#FFFFFF` | `#191619` |

`--burgundy` does **not** change between themes. The brand colour is the brand colour.

Component-specific dark values (`#211C20` for raised panels, `#38232D`, `#574A51`, `#E5A6B1` for
links on dark, and others) are currently written as literals inside `theme.css` rather than as
tokens. That is the single largest concentration of raw hex in the project and is recorded under
*Known violations*. When you touch one, promote it to a token rather than adding another literal.

The system preference is followed: with no stored choice, the inline script in the layout head
reads `prefers-color-scheme` before first paint and `theme_controller.js` tracks later OS changes.
An explicit toggle always wins. One thing is still missing and is *not* an open question, just
unbuilt: `browse.css` and `results.css` hardcode `#fff` backgrounds, so they ignore the theme
entirely. It is recorded under *Known violations*.

### Structure

- `1px solid #0A0A0A`: opens a major section or closes the page. Used sparingly.
- `1px solid #E5E5E5`: everything else structural.
- Dividers are preferred over boxes. Do not wrap content in a card just to group it.

---

## Components

### Navbar

Present on every page. Format from the prototype:
- Left: the **shuffl.** wordmark: render `shared/_wordmark.html.erb`, never hand-write it (see Wordmark above)
- Right: `Home | Quiz | My Wallet | Browse Cards` as text links
- Active page has an underline
- Clean white background with a `1px solid #E5E5E5` bottom border
- No icons, no hamburger on desktop. On mobile: wordmark + bottom bar (4 items)
- Padding: 16px vertical, page gutter horizontal

### Primary Button (burgundy)

Background `burgundy`, text `#FFFFFF`, no border, radius `6px`, padding `15px 22px`,
font-size `17px`, weight `400`, sentence case.

- Hover: background `burgundy-hover`, transition `120ms`
- Focus: `2px ink` ring, `2px` offset
- Never carries an icon alone
- **Maximum one per screen.** If a screen seems to need two, one of them is a secondary: or
  the screen is really two screens.

### Secondary Button

White background, `1px solid #0A0A0A`, ink text, radius `6px`, same padding.
Use only when a real alternative action must be permanently visible.

### Tertiary / Text Action

An underlined phrase inside a sentence: ink text, `1px solid #C9C9C9` bottom border, `2px`
padding below. Hover turns text and border `burgundy` (120ms): this is the *only* place
burgundy appears outside the primary button. No box, no background.

### Destructive Actions

Never burgundy. Ink text button plus a confirm step. Burgundy always moves forward.

### Selection (Radio Row)

Full-width row, `1px solid #0A0A0A` when selected / `#E5E5E5` when not, radius `8px`,
padding `14px 18px`. 18px circular indicator, ink fill. Supporting figure right-aligned in
muted. Selection is **black, never burgundy.**

### Tag

13px, `body` text, `1px solid #E5E5E5`, radius `99px`, padding `5px 12px`. No fill, no colour.

### Card Tile (Browse Grid)

- Artwork: aspect-ratio `1.58`, radius `10px`, `1px solid #E5E5E5`, real card photography
- Wordmark "shuffl" 12px/600/−0.03em, top-right, in the card's contrasting ink
- Masked number `•••• 4417` 12px bottom-left at 0.7 opacity
- Below artwork: name (17px/600/−0.02em) left, APR (15px muted) right, estimated value
  (14px pine) on the next line
- **No visible link at rest.** No "Explore this card" text.

---

## Interaction Patterns

### The Golden Rule: Hide Controls, Reveal on Hover

Links and secondary actions should be **hidden by default** and revealed only on hover/focus.
Only show buttons that are 100% necessary on the page itself: everything else hides behind
cards, rows, or panels and is revealed with hover animations.

### Hover Reveal (Signature Interaction)

On hover, a card tile's artwork gets a full-bleed `overlay` scrim; the resting masked-number
fades to 0; two actions fade in bottom-left:
- "Explore this card →" (16px, `#FFFFFF`, white underline)
- "Add to compare" (14px, `#FFFFFF`, full opacity)

**Timing:** `opacity` only, `160ms ease`. No scale, no lift, no shadow. The page should feel
like it is *answering*, not animating.

The overlay sits *on* the artwork so the grid never reflows and row heights never jump.

**Touch:** no hover exists: drop the overlay entirely and make the whole tile the link. One
tap, no visible control, same outcome.

**Keyboard:** focus shows the identical overlay plus a 2px ink focus ring. Hidden must never
mean unreachable: this is a hard accessibility requirement.

**Reduced motion:** `prefers-reduced-motion` → show the overlay instantly with no transition.

### Where the Buttons Went

Deleting a control is only safe if something absorbs its job:

1. **The row is the button.** A card + name + figure in a row is already a target. Clicking
   anywhere opens it: no "View details" link.
2. **Hover reveals.** Compare, save, share live on the artwork overlay. Secondary by definition.
3. **Selection commits.** Quiz answers advance on tap. No Next button under a single-choice
   question; keep one only where multi-select needs a definite end.
4. **Text, not chrome.** Anything a sentence can say: "change your spending", "how we rank":
   is an underlined phrase inside the sentence, not a bordered button beside it.
5. **Menus die.** Push the one useful item into hover-reveal and delete the rest.

**Target counts:** Browse ≤ 2 visible controls; Results = 1 (the primary CTA).

### Other Transitions

- Primary button hover: background `var(--burgundy)` → `var(--burgundy-hover)`, `120ms`
- Text action hover: colour and border-colour → burgundy, `120ms`
- Row hover (runners-up, selection rows): background → `#FAFAFA`, no border change
- Focus visible everywhere: 2px ink ring, 2px offset
- **No page-level entrance animation, no parallax, no scroll-triggered reveals.**

---

## Page Architecture

Every page follows this vertical structure:

```
Navbar
─── 1px ink rule ───
Display headline
Deck line (subtitle)
─── 1px ink rule ───
Content area
─── 1px ink rule ───
Disclosure text
Footer
```

Every page must have a bottom; none may end in empty white.

### Home

- Fourth-panel refinement: use lighter Shuffl card faces, with a burgundy tertiary
  link directly over them and the shared moving underline. No box behind the link.
- Card benefits and annual fees now live on the reverse of the active hero card,
  revealed by expanding the stack through hover, tap or keyboard. Keep the vertical
  wheel. Annual rewards must say “Depends on spending” until a spending basis exists.
  Remove the separate sample comparison section; retain only the stack explanation.
- The fourth hero panel has four translucent decorative card silhouettes behind
  an “Explore more stacks” link. Keep the link fully opaque and readable.
- Keep the stack explanation brief; the following catalogue example is a visual
  strip of card benefits and fees, not another two-column essay. The continuity
  partial is retained for reuse but is not rendered on the homepage (Noah's choice).
- The hero showcases one featured stack at a time using the existing fan-to-vertical
  wheel interaction. A clickable four-position rail selects three stacks and a final
  “Explore more stacks” panel. Its active quarter is burgundy, an explicit exception
  to the action-only colour rule requested by Noah. No automatic horizontal carousel.
- Show the stack explanation below the hero, then the sample benefits/fees preview.
  The featured stacks live in the hero rather than a repeated row further down.
- Explain the product before asking visitors to commit: define a stack as a group of
  cards for different spending needs, and state the quiz's maximum question count
  from `Card::CORE_QUESTIONS`. Results require no account; saving a wallet does.
- Below the hero, use a short editorial explanation and a clearly labelled sample
  stack from the catalogue to preview card benefits and annual fees. This is not a
  personalised recommendation. Disclose the sample catalogue; do not invent savings,
  testimonials or live offers. Use existing heading treatments and shared colour tokens.
- Display headline: "find the perfect credit cards for you"
- Two CTAs: "Take the quiz" (burgundy primary), "Browse stacks" (secondary)
- Below: three card-stack fan images for Student / Traveller / Foodie categories
- Bottom: "Explore by what matters to you." text with "Explore more stacks →" tertiary link
- "Ask shuffl" AI assistant bubble (bottom-right corner)

### Quiz

- One question per page, display-size headline
- "Why do we ask this?" as tertiary text link
- Radio row selection cards (2×2 grid or single column on mobile)
- "Continue" burgundy button (only visible when an answer is selected)
- "Back" as tertiary text link (bottom-left)
- Selection state: black border + filled circle (never burgundy)

### Results

*Binding, simplified at Noah’s request.*
- Show only the recommended cards and the actions to keep, swap and save them.
- Present recommendations as compact horizontal rows separated by hairlines, with
  small card artwork, a role headline, earning details and an aligned fee. Keep
  Keep, Swap and the expandable explanation together; avoid large boxed panels.
- Each card explains “Use for” a concrete qualifying purchase category and highlights
  the captured cashback percentage or points/miles per dollar, with material conditions.
- Keep the card artwork, name and ongoing annual fee visible. Supporting match reasons
  and benefits can sit behind “Why this card?”. Empty reward and offer rows are omitted.
- Lead each card with a prominent role hook tied to its suggested use (for example,
  “Your online shopper”). Highlight earning rates in pine, positive ongoing fees in
  brick, and zero-fee labels in neutral ink. Keep conditions beside the earning rate.
  Credit-building cards get an honest credit-builder hook, never a rewards claim.
- No spending slider, budget inputs, programme selectors, annual earnings estimates,
  separate usage planner, summary sidebar or application timeline on Results.
- Spending planning belongs in My Wallet. Its calculations require confirmed spending,
  preserve original reward currencies and count each purchase once.
- Historical cards and saved recommendations remain intact. Known facts take the place
  of missing metrics; never invent rewards for cards that do not earn them.

### My Wallet

- Display headline: "My Wallet"
- Subtitle: "Your cards, in one place."
- Left: stacked card fan image of user's saved cards
- Right: selected card detail with rewards list
- "Browse more cards" as secondary button

### Browse Cards / Stacks

- Display headline: "Browse stacks" or "Browse cards"
- Tab switcher: Cards | Stacks (underline active)
- Filter row: dropdowns + search (all as text/select controls, not button bars)
- Grid: `repeat(auto-fit, minmax(220px, 1fr))`, gap `clamp(16px, 2vw, 28px)`
- Card tiles with hover reveal as specified above

---

## Mobile Adaptations

- Display drops to `40px` but keeps `−0.045em` tracking
- Multi-column grids become a horizontal snap rail, never a vertical dump
- Quiz option grids become one column with `56px` rows
- Nav collapses to wordmark + four-item bottom bar
- Minimum touch target: `44px`
- No hover reveals on touch: whole tile becomes the tap target

---

## Card Artwork Mapping

Six card finishes, each bound to a category so imagery carries information:

| Finish    | Colour     | Category   |
|-----------|------------|------------|
| Bone      | Off-white  | Everyday   |
| Burgundy  | `--finish-burgundy` | Travel |
| Graphite  | Dark grey  | Dining     |
| Steel     | Silver     | Student    |
| Silver    | Light grey | Cashback   |
| Onyx      | Black      | Essentials |

- Flat front-on for a single card in a decision context
- Four-card fan only for a stack
- Three-quarter hero shot: once per page at most

---

## Accessibility Requirements

- Body and UI text meets 4.5:1 on white (this is why pence tints are `#3F7A65` / `#8A6234`)
- Hover-revealed actions must be reachable by keyboard focus and exposed to screen readers at
  all times (`visibility: hidden` + `opacity: 0`, never `display: none`)
- Colour is never the only signal: pine/brick figures always carry `+` or `−` sign
- Focus ring on every interactive element: `2px solid #0A0A0A`, `2px` offset

---

## CSS Implementation Notes

This is a Rails app with Propshaft and Bootstrap 5. **Use Bootstrap** for layout and structure:
`.container`, `.row`, `.col-*`, utility classes (`.d-flex`, `.gap-*`, `.text-center`, etc.),
and responsive breakpoints all work as you'd expect from Le Wagon. The design language layers
on top of Bootstrap by overriding its theme variables so the rendered result matches Shuffl's
look instead of Bootstrap's defaults.

The authoritative token list is the `:root` block of `app/assets/stylesheets/application.css`.
It is deliberately **not** reproduced here: this document previously carried its own copy, the two
drifted, and the copy is what people implemented. Read the file for the values; read the *Colour*
and *Typography* tables above for what each token is *for*.

Bootstrap's own variables are remapped onto those tokens in the same block, so
`--bs-primary`, `--bs-body-font-family` and friends resolve to Shuffl values rather than
Bootstrap defaults.

**Using Bootstrap with the Shuffl design language:**

- **DO use** Bootstrap grid (`.container`, `.row`, `.col-*`), spacing utilities (`.mb-3`,
  `.p-4`, `.gap-*`), flexbox/display utilities (`.d-flex`, `.justify-content-between`),
  and responsive breakpoints: this is the Le Wagon way and it works here.
- **DO use** `.btn` as a base: style `.btn-primary` to match the burgundy spec and
  `.btn-outline-dark` for secondary buttons. Override Bootstrap's button padding, radius,
  and colours in your CSS to match the tokens above.
- **DO override** Bootstrap's defaults where they clash: remove `box-shadow` from `.btn`,
  `.card`, `.form-control` (no shadows in the design). Set `--bs-border-radius` to match
  the radius tokens.
- **DON'T use** Bootstrap colour classes like `.text-primary`, `.bg-info`, `.badge-success`
  with their default Bootstrap meanings: they'll pull in Bootstrap blue/green/cyan instead
  of the Shuffl palette. Either override them in CSS or use Shuffl token classes instead.

Load Geist from Google Fonts (in the `application.html.erb` layout):
```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Geist:wght@400;500;600;700&display=swap"
      rel="stylesheet">
```

---

## Enforcement

Two of the binding rules are machine-checked, because prose alone demonstrably did not hold them:
the app carried three burgundies and six stylesheets pinned to a font nobody had licensed, all
while this document said otherwise.

```
rake design:check      # what the pre-commit hook runs
rake design:baseline   # re-record the ceiling after cleaning some up
```

`design:check` enforces two things:

1. **Banned values fail outright.** The retired burgundies (`#7B1622`, `#681522`, `#63111B`) and
   the retired font names (`Helvetica Now`, `Inter Tight`) may not reappear anywhere, in any count.
2. **Debt may shrink, never grow.** Raw hex literals and hardcoded font families are counted per
   file and compared against `.design-baseline.yml`. Adding one to a file fails the check. Removing
   some and running `rake design:baseline` locks in the lower number permanently.

The ratchet exists because failing on all 361 existing violations at once would only teach everyone
to pass `--no-verify`. You cannot make the mess worse; you can only make it better.

Enable the hook once per clone:

```
git config core.hooksPath .githooks
```

Do not hand-edit `.design-baseline.yml`. If a violation is genuinely unavoidable, say so in the
pull request and run `rake design:baseline` deliberately, so the exception is visible in the diff.

---

## Known violations

Binding rules the code does not yet follow. These are debt, not precedent: never cite one to
justify another.

**Six stylesheets are self-contained design systems.** `browse.css`, `wallet.css`, `login.css`,
`results.css`, `home.css` and `quiz.css` each carry their own CSS reset and their own colour
literals rather than building fully on `application.css`. The base font sizes are no longer part
of this: all three now use `--text-dense`. This is the root cause of
almost everything else in this list, and unpicking it is the single highest-value piece of frontend
work outstanding. `results.css` still aliases `--wine` to the burgundy token rather than using it
directly.

**361 raw hex literals remain**, concentrated in the files above:

| File                   | Raw hex |
|------------------------|---------|
| `browse.css`           | 60      |
| `wallet.css`           | 55      |
| `theme.css`            | 53      |
| `login.css`            | 44      |
| `application.css`      | 40      |
| `results.css`          | 33      |
| `home.css`             | 26      |
| everything else        | 50      |

Most are an ad-hoc grey ramp: `#777` appears 29 times, then `#ccc`, `#666`, `#ddd`, `#888`,
`#555`, `#111`: sitting alongside the `--muted` and `--hairline` tokens that already exist for
exactly that job.

**The type scale is not implemented.** No stylesheet uses any row of it. Each page sized its
headings independently. This is bound up with the open question below.

**Eleven breakpoints exist where there should be six.** Alongside the tiers in *Breakpoints*,
the code contains `760px` (`application.css`, `login.css`, `results.css`), `860px` (`detail.css`),
`650px` (`browse.css`), `1050px` (`home.css`, `results.css`) and `520px` (`detail.css`). Each is
within ten pixels of a real tier. This is the burgundy problem in a different dimension, and it is
why a layout can break at a slightly different width depending which page you are on.

**Four content widths exist where there should be one.** `1440px` is canonical;
`detail.css` uses `1320px`, `footer.css` and `browse.css` use `1450px`, `wallet.css` uses `1500px`.

**Radius is set by hand outside the two tokens.** Page-scoped sheets use `5px`, `8px`, `9px` and
`12px` directly rather than `--radius-button` / `--radius-card`.

**The spacing scale is not enforced.** `25px`, `27px`, `38px` and other off-scale values appear
throughout. Nothing checks it and no token expresses the scale.

**The dark palette is mostly literals.** `theme.css` correctly overrides the core tokens, but
carries roughly a dozen component-specific colours as raw hex. It is the third-largest hex count
in the project at 53.

**`.ai-bubble` is dead.** A full component's worth of rules across `application.css`, `home.css`
and `theme.css` that no view references. Safe to delete.

---

## Open decisions

Nobody has decided these. Until one is settled, **do not invent an answer**: match whatever the
surrounding file already does. Settle one by editing this document in its own commit.

**1. The heading scale for Geist.** The base reading sizes are now settled (`--text-body` and
`--text-dense`, above). What remains open is everything above them: Display, Hero figure, Title,
Section head, Subhead: their sizes and especially their tracking.

This is the one question that could not be settled by deferring to the code, because the code has
no answer to defer to. Every heading in the project uses a `clamp()` that appears exactly once;
there is no scale, just twenty-odd independent decisions. The table under *Typography* is not it
either: those values were tuned for Helvetica Now Display and appear in no stylesheet, and Geist
sets tighter, so applying them as written runs the type too close. That is the same fault that
made the wordmark read as a capital L.

Settling it means choosing tracking and size relationships for Geist at each step, then migrating
the pages onto them. The wordmark and the base sizes were both settled by looking at the real
thing at real sizes rather than reasoning about numbers, and the heading scale deserves the same.
Until then, match the file you are working in. *Owner: Noah.*

---

### Wallet organization and interaction: September 2026

*Binding, requested by Noah.* Keeps the wallet fan layout above.
- Owned-card payments appear first, ordered by due date with undated cards last.
- Compact Owned and Planned card fans select one card; Overview, Payments and Bonus
  tabs keep the selected owned card's tracking details separate.
- Both timelines run horizontally in a single scrollable row to minimize page height.
- The bonus deadline is plain status text, with no border.
- Planned application dates have their own timeline below the collection.
- Both card states offer a neutral Remove this card action with confirmation.
- Wallet action buttons use the shared circling-border light. Text links and
  text buttons use only the moving underline: no glow, shadow or lift.
- Date-setting and payment actions remain visible so tracking is discoverable.

## Implementation notes (non-binding)

Everything below this line is a record of how particular surfaces were built. It is context, not
specification: where it disagrees with anything above, the rule above wins.

### Home reference refinement (September 2026)

The supplied `home.png` is the authority for the home surface. Scoped rules live in
`home.css`: an inset outlined navigation bar, oversized two-line grotesque headline,
right-aligned burgundy and outline actions, three divided card fans, and bone,
burgundy, graphite and silver brushed-metal finishes with engraved silver chips.
Card materials intentionally use burgundy and contact shadows beyond the general
UI colour/elevation rules above. Other surfaces retain the existing system.

Each home fan uses the Stimulus `stack` controller. Fine-pointer hover previews the
stack; its category button or artwork toggles a pinned expansion. Cards turn through
360 degrees into four separated vertical rectangles, revealing the existing sample
names and benefits. Escape closes it. Transform transitions are interruptible,
staggered by 40ms, and removed for reduced-motion preferences. Mobile uses a horizontal
snap rail and button activation. The assistant remains a visual placeholder until
its backend is implemented.

### Quiz reference implementation (September 2026)

`quiz.css` scopes the supplied quiz reference to `.quiz-page`: the home navigation
frame, large black question heading, thin divider, two-column outlined answers on
desktop and one column on mobile. Burgundy marks the selected native radio or
checkbox and completed progress. No decorative icons or emoji appear in the quiz.

The current 10 questions and their scoring are sourced from `quiz-questions-redesign`.
The progress track measures answered questions and labels the current question out
of the total. Selecting an answer advances after 250ms of visible feedback; Back
restores saved selections, including the ability to choose the same answer again.
The final answer submits results. The server validates options and question index
and rejects stale submissions. The shared renderer also supports future bounded
multiple-choice questions. Without JavaScript, a submit fallback remains available.

Verify the server flow with `RAILS_ENV=test bundle exec ruby test/integration/quiz_flow_test.rb`.

Quiz sizing refinement: headings cap at 58px on desktop and 34px on phones; answer text uses 17–23px on desktop and 16px on phones. Compact spacing keeps all 10 questions within a 375×667 viewport. Seven-answer questions use two columns on short phones, with 58px minimum answer targets. Content remains scrollable for accessibility zoom and unusually small viewports.

Navigation update: the shared navbar is borderless and sticky at the viewport top, with an opaque white background and elevation above page content. This supersedes the outlined navigation frame in the earlier reference notes.

Navigation glass refinement: the sticky navbar floats 12px below the viewport top (8px on mobile), with a translucent neutral surface, 24px backdrop blur, a fine light rim, rounded corners, and a soft shadow. This supersedes the previous opaque borderless treatment. Reduced-transparency preferences and browsers without backdrop blur receive a solid light surface.

Quiz presentation update: content is centred within 880px. Key phrases in each question use burgundy, with a soft burgundy selected-answer tint. Ten progress bubbles replace the line: solid bubbles mark completed questions, a double ring marks the current question, and outlined bubbles mark upcoming questions. Progress retains an accessible label and numeric value.

### Results integration (September 2026)

The approved results mockup is integrated into quiz responses. The page uses the
shared sticky navbar, a 1440px content width, a left value/spending/timeline panel,
and recommended card boxes on the right. Card artwork flips over 1.15 seconds;
reduced motion removes the transition. Decimal figures use separate, looser tracking.
Keep and Swap remain visible; “Why this card?” expands below the artwork.
The burgundy Save this stack action adds every displayed card to My Wallet.

Results styles are scoped to .results-page. The Stimulus results controller loads
quiz recommendations and six category sliders from ResultsStack. Category spending
is assigned once to the highest-rate selected card (ties follow recommendation order).
Sample-catalogue estimates assume 1 cent per point and exclude welcome bonuses,
conditional perks and caps. The illustrative signup timeline is retained for now.
Selections and spending survive sign-in in session storage; authenticated saving is
atomic and avoids duplicate wallet cards. The original standalone mockup remains
available for reference.

### Heading keyword emphasis: September 2026

User-approved exception to “One burgundy”: primary editorial headings may highlight
one or two meaningful words in the signature burgundy (home: cards / wallet;
browse and results: rewarding; wallet: wallet; authentication: stack / yours).
Quiz question emphasis uses the same colour treatment. Keep body copy, navigation,
product names and financial figures neutral; do not automatically colour every
occurrence of a keyword. This extends the existing quiz-heading exception.
Use `.keyword-emphasis` and `var(--burgundy)` in light mode. In dark mode,
`--keyword-ink` mixes 40% burgundy with white for readable text; button colour stays
unchanged. The older strict colour budget yields to this limited heading treatment.

### Seamless ranked quiz: September 2026

The quiz is one ten-question journey, with a fixed ten-step progress indicator
from the first screen. Visitors rank up to three goals first; every goal is
available regardless of card ownership. The first goal selects two later
questions, without introducing stages or announcing routing. All three ranked
goals contribute to scoring at descending weights. Every path asks about
repayment, spending, fees and credit context. First-card repayment wording is
prospective. Loyalty and wallet-gap claims are absent from the new flow.

Goals and spending share one ranking control: tapping a choice moves its pill
into a separate ordered selection area above the remaining options. Up to three
choices can be selected. Drag a selected pill by its handle to reorder it on
mouse or touch; keyboard users can use the handle's arrow keys. Tapping a selected
pill removes it. Selection stays neutral, and Continue submits the final order.
There is no automatic advancement. Without JavaScript the checkboxes remain
available and submit in option order.

Back preserves answers. Only answers incompatible with a changed path are
removed on submission; saved drafts retain the ranking. Per-form tokens reject
stale submissions. Short inline explanations replace the unavailable quiz-help
link. Existing completed quizzes retain their previous scoring interpretation.
