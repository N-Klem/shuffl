# Shuffl Design Language — "The Quiet Interface"

This document is the single source of truth for Shuffl's visual design. Every frontend view,
component, and stylesheet must follow this spec. When an implementation decision is ambiguous,
resolve it with the three rules below.

---

## The Three Rules

1. **One family.** Every character — wordmark, 100px display headline, 12px disclosure — is set in
   the same tight grotesque. No second typeface, no monospace for numbers.
2. **One burgundy.** Exactly one filled burgundy control per screen, and it is always the thing the
   user came here to do. Nothing else on the page may use the colour. Burgundy is a verb.
3. **Nothing at rest.** A control that is not the next step is not visible at rest. It appears on
   hover/focus and disappears again.

---

## Design Tokens

### Colour

| Token             | Hex / Value           | Use                                                              |
|-------------------|-----------------------|------------------------------------------------------------------|
| `ink`             | `#0A0A0A`             | All primary text, wordmark, selection outlines, 1px structural rules |
| `body`            | `#4A4A4A`             | Body copy, descriptive paragraphs                                |
| `muted`           | `#6B6B6B`             | Captions, labels, disclosures, pence portions of figures         |
| `hairline`        | `#E5E5E5`             | Card borders, section dividers                                   |
| `hairline-soft`   | `#F0F0F0`             | Row separators inside a panel                                    |
| `surface`         | `#FFFFFF`             | The only background. White is the loudest colour in the system.  |
| `burgundy`        | `#7B1622`             | The single primary action per screen. Nothing else.              |
| `burgundy-hover`  | `#63111B`             | Hover state of the primary button only                           |
| `pine`            | `#16624B`             | Money in — rewards, cashback, positive deltas                    |
| `pine-pence`      | `#3F7A65`             | Pence portion of a pine figure (4.6:1 on white)                  |
| `amber`           | `#A85410`             | Money out — fees, interest, negative flags                       |
| `amber-pence`     | `#8A6234`             | Pence portion of an amber figure (4.9:1 on white)                |
| `overlay`         | `rgba(10,10,10,0.74)` | Hover-reveal scrim over card artwork                             |

**Colour budget:** burgundy must occupy under 3% of any screen's pixels. On a 1440×900 viewport
that is one button plus the wordmark rule. Pine and amber appear only on figures, never on chrome.

**Never coloured:** headings, selected states, links at rest, tags, icons.

### Typography

**Font stack:** `"Helvetica Now Display", "Helvetica Neue", Helvetica, "Inter Tight", Arial, sans-serif`

Helvetica Now Display is the intended face. Inter Tight (Google Fonts) is the web fallback for
non-Apple platforms — closest freely-licensed match for the tight, closed-aperture grotesque.

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

### Numerics

- Every figure: `font-variant-numeric: tabular-nums lining-nums` so columns align.
- **Pence drop to `muted`.** Split the string: `£412` in the figure's ink colour, `.00` in muted.
  For pine/amber figures, use `pine-pence` / `amber-pence` so the semantic colour survives while
  staying above 4.5:1 contrast. This is a signature detail — do not skip it.
- Deltas always carry a sign and a colour: `+£137` pine, `−£3.72` amber.
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
- Left: **shuffl** wordmark (bold, tight tracking −0.045em)
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

- Primary button hover: background `#7B1622` → `#63111B`, `120ms`
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
| Burgundy  | `#7B1622`  | Travel     |
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

In `app/assets/stylesheets/application.css`, override Bootstrap's theme and add Shuffl tokens:

```css
:root {
  /* Override Bootstrap theme colours */
  --bs-primary: #7B1622;
  --bs-body-color: #4A4A4A;
  --bs-body-bg: #FFFFFF;
  --bs-border-color: #E5E5E5;
  --bs-link-color: #0A0A0A;
  --bs-link-hover-color: #7B1622;
  --bs-body-font-family: "Helvetica Now Display", "Helvetica Neue", Helvetica,
    "Inter Tight", Arial, sans-serif;

  /* Shuffl colour tokens */
  --ink: #0A0A0A;
  --body: #4A4A4A;
  --muted: #6B6B6B;
  --hairline: #E5E5E5;
  --hairline-soft: #F0F0F0;
  --surface: #FFFFFF;
  --burgundy: #7B1622;
  --burgundy-hover: #63111B;
  --pine: #16624B;
  --pine-pence: #3F7A65;
  --amber: #A85410;
  --amber-pence: #8A6234;
  --overlay: rgba(10, 10, 10, 0.74);

  /* Spacing */
  --section-padding: clamp(40px, 5vw, 68px);
  --page-gutter: clamp(16px, 3.5vw, 56px);
  --content-max-width: 1320px;

  /* Radius */
  --radius-button: 6px;
  --radius-row: 8px;
  --radius-card: 10px;
}
```

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

Load Inter Tight from Google Fonts as the web fallback (add to `application.html.erb` layout):
```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter+Tight:wght@400;600;700&display=swap"
      rel="stylesheet">
```
