# Shuffl Design Language — "The Quiet Interface"

This document is the single source of truth for Shuffl's visual design. `CLAUDE.md` describes how
the app is built; anything visual is decided here and nowhere else.

## How to read this document

Every statement here is one of exactly three things, and it says which:

- **Binding.** A settled answer. Implement it as written. Do not substitute a near-miss value
  because it looks similar, and do not introduce a new value for a job a token already covers.
  If you believe a binding answer is wrong, change it here first, in its own commit, and say why.
- **Open.** A decision nobody has made yet, listed under *Open decisions* at the end. Until it is
  settled, do not invent an answer — reuse whatever the surrounding code already does and leave
  it alone. Every drift problem this codebase has had started as an open question answered quietly.
- **Known violation.** Something binding that the code does not yet do, listed under
  *Known violations*. These are debt, not precedent. Never cite one to justify another.

Two rules are machine-checked by `rake design:check` (see *Enforcement*). The rest are on you.

---

## The Three Rules

*Binding.*

1. **One family.** Every character — wordmark, 100px display headline, 12px disclosure — is set in
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
defect — see *Enforcement*.

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
| `--pine`           | `#16624B`             | Money in — rewards, cashback, positive deltas                    |
| `--pine-pence`     | `#3F7A65`             | Pence portion of a pine figure (4.6:1 on white)                  |
| `--overlay-from`   | `rgba(10,10,10,0)`    | Top stop of the hover-reveal scrim over card artwork             |
| `--overlay-to`     | `rgba(10,10,10,0.74)` | Bottom stop of that scrim                                        |

The card finishes (`--finish-bone`, `--finish-burgundy`, `--finish-graphite`, `--finish-steel`,
`--finish-silver`) are gradients for placeholder card artwork. They are temporary and will be
replaced by real card images — do not build anything else on them.

**The burgundy is `#601020` and only `#601020`.** The app previously carried three near-identical
burgundies (`#7B1622`, `#681522`, `#601020`) across different stylesheets because each was typed
by hand instead of referenced. All three are now `var(--burgundy)`. The two retired values are
banned outright by `rake design:check`.

**Colour budget:** burgundy must occupy under 3% of any screen's pixels. On a 1440×900 viewport
that is one button plus the wordmark rule. Pine appears only on figures, never on chrome.

**Never coloured:** headings, selected states, links at rest, tags, icons.

The colour used for fees and other money-out figures is *open* — see *Open decisions*.

### Typography

**Font stack:** `--font-sans` → `"Geist", "Helvetica Neue", Helvetica, Arial, sans-serif`

Geist (Google Fonts) is the face. It is loaded in the layout and exposed as the `--font-sans`
token. Never name a font family directly in a stylesheet — that is how six sheets ended up
pinned to Helvetica and silently missed the last face change. Always reference the token.

The font stack above is **binding**. The scale below is **open** — see *Open decisions*.

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

`.wordmark` owns shape only — family, tracking (−0.054em) and the dot geometry. Weight, colour
and size belong to the context that uses it, so the mark can sit at 12px inside running text
without turning bold and black. The dot is `currentColor`, so dark mode needs no extra rule.

### Numerics

- Every figure: `font-variant-numeric: tabular-nums lining-nums` so columns align.
- **Pence drop to `muted`.** Split the string: `£412` in the figure's ink colour, `.00` in muted.
  For pine figures use `--pine-pence`, so the semantic colour survives while staying above 4.5:1
  contrast. This is a signature detail — do not skip it. The money-out equivalent waits on
  *Open decisions*.
- Deltas always carry a sign and a colour: `+£137` in `--pine`, `−£3.72` in the money-out colour.
- Currency symbol and unit never separate from the number across a line break.

### Spacing

8-point scale: `8 / 12 / 16 / 24 / 40 / 64 / 96`.

- Section padding: `clamp(40px, 5vw, 68px)` vertically
- Page gutter: `clamp(16px, 3.5vw, 56px)`
- Content max-width: `1320px`, centred

### Radius & Elevation

- `6px` — buttons
- `8px` — rows, selection targets, small panels
- `10px` — cards, card artwork, large panels
- **No shadows anywhere.** Card photography carries its own contact shadow in the image; the
  interface adds none.

### Structure

- `1px solid #0A0A0A` — opens a major section or closes the page. Used sparingly.
- `1px solid #E5E5E5` — everything else structural.
- Dividers are preferred over boxes. Do not wrap content in a card just to group it.

---

## Components

### Navbar

Present on every page. Format from the prototype:
- Left: the **shuffl.** wordmark — render `shared/_wordmark.html.erb`, never hand-write it (see Wordmark above)
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
- **Maximum one per screen.** If a screen seems to need two, one of them is a secondary — or
  the screen is really two screens.

### Secondary Button

White background, `1px solid #0A0A0A`, ink text, radius `6px`, same padding.
Use only when a real alternative action must be permanently visible.

### Tertiary / Text Action

An underlined phrase inside a sentence: ink text, `1px solid #C9C9C9` bottom border, `2px`
padding below. Hover turns text and border `burgundy` (120ms) — this is the *only* place
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
Only show buttons that are 100% necessary on the page itself — everything else hides behind
cards, rows, or panels and is revealed with hover animations.

### Hover Reveal (Signature Interaction)

On hover, a card tile's artwork gets a full-bleed `overlay` scrim; the resting masked-number
fades to 0; two actions fade in bottom-left:
- "Explore this card →" (16px, `#FFFFFF`, white underline)
- "Add to compare" (14px, `#FFFFFF`, full opacity)

**Timing:** `opacity` only, `160ms ease`. No scale, no lift, no shadow. The page should feel
like it is *answering*, not animating.

The overlay sits *on* the artwork so the grid never reflows and row heights never jump.

**Touch:** no hover exists — drop the overlay entirely and make the whole tile the link. One
tap, no visible control, same outcome.

**Keyboard:** focus shows the identical overlay plus a 2px ink focus ring. Hidden must never
mean unreachable — this is a hard accessibility requirement.

**Reduced motion:** `prefers-reduced-motion` → show the overlay instantly with no transition.

### Where the Buttons Went

Deleting a control is only safe if something absorbs its job:

1. **The row is the button.** A card + name + figure in a row is already a target. Clicking
   anywhere opens it — no "View details" link.
2. **Hover reveals.** Compare, save, share live on the artwork overlay. Secondary by definition.
3. **Selection commits.** Quiz answers advance on tap. No Next button under a single-choice
   question; keep one only where multi-select needs a definite end.
4. **Text, not chrome.** Anything a sentence can say — "change your spending", "how we rank" —
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

- Display headline: "Here are the cards we recommend."
- Subtitle: "Your recommended stack"
- Left panel: "Your stack at a glance" summary (annual fees, sign-up bonuses, estimated
  yearly rewards, estimated first-year value)
- Lead card gets the single burgundy "Keep this card" / "Apply for this card" button
- Runner-up cards: compact clickable rows with thumbnail, name, figures — their apply buttons
  live on detail pages
- Disclosure text directly under figures

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
- No hover reveals on touch — whole tile becomes the tap target

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
- Colour is never the only signal: pine/amber figures always carry `+` or `−` sign
- Focus ring on every interactive element: `2px solid #0A0A0A`, `2px` offset

---

## CSS Implementation Notes

This is a Rails app with Propshaft and Bootstrap 5. **Use Bootstrap** for layout and structure —
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
  and responsive breakpoints — this is the Le Wagon way and it works here.
- **DO use** `.btn` as a base — style `.btn-primary` to match the burgundy spec and
  `.btn-outline-dark` for secondary buttons. Override Bootstrap's button padding, radius,
  and colours in your CSS to match the tokens above.
- **DO override** Bootstrap's defaults where they clash: remove `box-shadow` from `.btn`,
  `.card`, `.form-control` (no shadows in the design). Set `--bs-border-radius` to match
  the radius tokens.
- **DON'T use** Bootstrap colour classes like `.text-primary`, `.bg-info`, `.badge-success`
  with their default Bootstrap meanings — they'll pull in Bootstrap blue/green/cyan instead
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

Binding rules the code does not yet follow. These are debt, not precedent — never cite one to
justify another.

**Six stylesheets are self-contained design systems.** `browse.css`, `wallet.css`, `login.css`,
`results.css`, `home.css` and `quiz.css` each carry their own CSS reset, their own base font size
and their own colour literals rather than building on `application.css`. This is the root cause of
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

Most are an ad-hoc grey ramp — `#777` appears 29 times, then `#ccc`, `#666`, `#ddd`, `#888`,
`#555`, `#111` — sitting alongside the `--muted` and `--hairline` tokens that already exist for
exactly that job.

**The type scale is not implemented.** No stylesheet uses any row of it. Each page sized its
headings independently. This is bound up with the open question below.

**`.ai-bubble` is dead.** A full component's worth of rules across `application.css`, `home.css`
and `theme.css` that no view references. Safe to delete.

**Dark mode does not follow the system preference.** `theme.css` responds only to the
`data-theme` attribute set by the navbar toggle. There is no `prefers-color-scheme` query, so a
reader whose OS is in dark mode gets the light theme until they find the control.

---

## Open decisions

Nobody has decided these. Until one is settled, **do not invent an answer** — match whatever the
surrounding file already does. Settle one by editing this document in its own commit.

**1. The type scale for Geist.** The table under *Typography* was tuned for a different face and
is implemented nowhere. Deciding it means picking tracking values for Geist at each step and then
migrating the pages onto them. The wordmark was settled this way — by looking at candidates at the
real sizes rather than reasoning about numbers — and the scale deserves the same treatment.
*Owner: Noah.*

**2. The colour of money-out figures.** This document has always specified amber `#A85410` for
fees, interest and negative flags. No stylesheet has ever used it; `browse.css` and `wallet.css`
use a red, `#a12a36`, instead. Amber reads as caution and pairs with pine; red reads as cost and
is the more conventional choice for a fee. One of them is right and the other should be deleted
from this document. There is deliberately no `--amber` token until this is settled, so that
nothing can quietly start depending on the losing answer. *Owner: Noah.*

---

## Implementation notes (non-binding)

Everything below this line is a record of how particular surfaces were built. It is context, not
specification — where it disagrees with anything above, the rule above wins.

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

The current 16 questions and their scoring are sourced from `quiz-questions-redesign`.
The progress track measures answered questions and labels the current question out
of the total. Selecting an answer advances after 250ms of visible feedback; Back
restores saved selections, including the ability to choose the same answer again.
The final answer submits results. The server validates options and question index
and rejects stale submissions. The shared renderer also supports future bounded
multiple-choice questions. Without JavaScript, a submit fallback remains available.

Verify the server flow with `RAILS_ENV=test bundle exec ruby test/integration/quiz_flow_test.rb`.

Quiz sizing refinement: headings cap at 58px on desktop and 34px on phones; answer text uses 17–23px on desktop and 16px on phones. Compact spacing keeps all 16 questions within a 375×667 viewport. Seven-answer questions use two columns on short phones, with 58px minimum answer targets. Content remains scrollable for accessibility zoom and unusually small viewports.

Navigation update: the shared navbar is borderless and sticky at the viewport top, with an opaque white background and elevation above page content. This supersedes the outlined navigation frame in the earlier reference notes.

Navigation glass refinement: the sticky navbar floats 12px below the viewport top (8px on mobile), with a translucent neutral surface, 24px backdrop blur, a fine light rim, rounded corners, and a soft shadow. This supersedes the previous opaque borderless treatment. Reduced-transparency preferences and browsers without backdrop blur receive a solid light surface.

Quiz presentation update: content is centred within 880px. Key phrases in each question use burgundy, with a soft burgundy selected-answer tint. Sixteen progress bubbles replace the line: solid bubbles mark completed questions, a double ring marks the current question, and outlined bubbles mark upcoming questions. Progress retains an accessible label and numeric value.

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
