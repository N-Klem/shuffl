# Handover: 14 September 2026

A point-in-time summary of one working session, written for whoever picks this up
next. **It is not a source of truth and it is not binding.** `DESIGN.md` governs
anything visual, `CLAUDE.md` describes how the app is built. Where this file and
those disagree, they win. Delete this once you have read it: a third document
that nobody maintains is precisely the problem this session spent its time
undoing.

---

## Read these first, in this order

1. **`DESIGN.md`**: every statement in it is marked **binding**, **open**, or a
   **known violation**, so you can tell which parts are decided. Read "How to read
   this document" and "Which wins, the document or the code?" before changing
   anything visual.
2. **`CLAUDE.md`**: stack, schema, routes, what exists.
3. `Claude outputs/shuffl-critique.html`: the UX/UI critique this session worked
   from. Gitignored, so it is on Noah's machine only. Roughly half its findings
   are now fixed; the rest are listed under *Outstanding* below.

## Before you commit anything

There is a **pre-commit hook** that will block you.

```
bin/design-check          # what the hook runs
bin/design-check --baseline   # re-record the ceiling after cleaning some up
```

It fails on two things: retired colour and font values reappearing anywhere, and
raw hex or hardcoded font families **growing** in any stylesheet beyond the count
recorded in `.design-baseline.yml`. Existing violations are tracked debt that may
shrink and never grow. It is plain Ruby and deliberately does not boot Rails, so
it runs anywhere.

If it blocks you, the fix is a token from `application.css`'s `:root`, not
`--no-verify`.

---

## The through-line of this session

The app had three near-identical burgundies, a typeface that was specified but
never licensed or shipped, and two design documents describing an app from many
commits earlier. The root cause was not carelessness: it was that **the
documents described something the code had never implemented**, so anyone reading
them invented something to bridge the gap.

So: the documents were corrected to match reality, the values were unified onto
tokens, and the two rules that kept breaking were made machine-checkable. The
ordering rule now is **document first, then code**: never the reverse.

One exception was applied once and is spent: where the docs and code disagreed as
of this date, the code won and the docs were corrected. That was a one-time
reconciliation, it says so in both files, and it does not apply going forward.

---

## What changed

### Type system
- **Geist** is the typeface, loaded from Google Fonts, reached through
  `--font-sans`. It replaced Helvetica Now Display, which was specced but never
  licensed, so every page had silently been falling back to Helvetica Neue.
- Seven stylesheets had hardcoded their own font stack. They all read the token now.
- The `shuffl.` wordmark is a partial, `shared/_wordmark.html.erb`. **Never
  hand-write the mark.** Its full stop is a drawn circle, not a typed period:
  Geist's period is square and sits inside the `l`'s optical space, making the
  pair read as a capital `L`.
- Two reading sizes, both tokens: `--text-body` (18px) for prose, `--text-dense`
  (16px) for listing chrome (browse, results, wallet). They previously ran at 15,
  16 and 14px.

### Colour
- **`#601020` is the burgundy.** Four near-identical values were in use
  (`#7B1622`, `#681522`, `#651321`, `#601020`); all four collapsed onto one token
  and the retired three are banned by `design-check`.
- Added `--hairline-strong` (`#CCCCCC`), `--pine`, `--pine-pence`,
  `--hairline-soft`, `--brick` (`#A12A36`, money out: amber was specced for two
  years and never used).
- Neutral greys normalised onto existing tokens (`#777`/`#666`/`#888` → `--muted`,
  `#111` → `--ink`).
- Raw hex across all stylesheets: **413 → 274.** Much of what remains is card
  gradients and shadow `rgba()`, which are legitimately literal.

### Dark mode
- Now **follows the OS** when the visitor has not chosen. Done in the inline boot
  script, not a `prefers-color-scheme` media query: every dark rule is
  `html[data-theme="dark"]`, so a media query would mean duplicating all of
  `theme.css`. An explicit choice still wins.
- Role tokens added: `--surface-raised` (dialogs, menus, trays), `--surface-field`
  (inputs), `--focus-ring`. Dark overrides for `--hairline-strong`, `--pine`,
  `--brick`.
- **Dark mode redefines tokens; it does not restyle components.** Build on
  `var(--token)` and a component themes itself.
- `--burgundy` is deliberately identical in both themes.
- Keyboard focus was invisible in dark mode: nine focus rings used
  `var(--burgundy)` against `#191619`. All twelve now use `--focus-ring`.

### Quiz: the biggest functional change
- **Cut from 16 questions to 10** before results. `Card::CORE_QUESTIONS` runs the
  quiz; `Card::REFINE_QUESTIONS` holds the six removed ones for a refine flow that
  **is not built yet**.
- Questions were chosen for a future catalogue of ~300 real cards with APR, FX
  fees and issuer rules: not against the current 54-card filler. The test used:
  do answers vary between people, and do they change the ranking?
- `biggest_expense` + `second_expense` merged into one **ranked** question
  (`spending_priorities`), weighted 3/2/1 by position. Click order is the answer,
  carried in a hidden field because checkbox submission follows DOM order.
- `rewards_type` is **conditional** on `top_priority` being "Earning rewards".
  The progress count follows only visible questions: it reads 9 of 9 until that
  answer, then becomes 10 of 10.
- Added `pays_in_full`. Someone carrying a balance pays more interest than any
  rewards rate returns. There is **no APR field on Card yet**; the scorer marks
  exactly where real interest data plugs in.
- **Save and finish later**: stores answers as a draft `QuizResponse`
  (`completed_at: nil`). Anonymous drafts ride in the session until sign-in claims
  them via the existing `claim_quiz_response` hook. Resuming derives position from
  the answers, not a stored step, so it survives a conditional question appearing
  or disappearing.
- Footer removed from the quiz page (`content_for :hide_footer`); the assistant
  stays. Progress bubbles kept: nine read fine where sixteen did not.

### Cleanup
- **Three design mockups were live on the production domain**: `login-mockup.html`,
  `results-mockup.html`, `mobile-preview-local.html` all returned 200 from
  `public/`. Deleted. **They are still live on Heroku until master is deployed.**
- Dead code removed: the superseded `.ai-bubble` assistant, `dialog_controller.js`,
  and ~20 unreferenced classes. Dead class count 23 → 1 (`.flash-alert`, a false
  positive: it is built at runtime as `flash-<%= type %>`).
- `browse.css`, `results.css` and `wallet.css` were **minified**: one line of
  7,308 characters in browse. That is why they drifted: a diff on that line is
  unreviewable. They are formatted now; do not re-minify them.
- **Restored a lost feature.** Finn Somerville's signed-in continuity prompt
  (commit `a425275`, 13 Sep) was silently removed the next morning by `47cb95e`,
  a large multi-feature commit whose message never mentioned it. Its CSS survived,
  which is why it showed up as "dead". Restored in `18b44ac`.

---

## Traps: things that nearly broke, and will again

- **`#777` is both muted text and the chip outline on card artwork.** `#fff` is
  both a background and white text on burgundy/graphite card finishes. Colour
  migrations must be **property-aware**; a blanket find-and-replace turns that card
  text into `var(--surface)`, which flips to `#191619` in dark mode and disappears.
- **Never rewrite a custom-property *definition*.** `--ink:#f2eeee` in `theme.css`
  must stay literal or it becomes self-referential.
- **A draft `QuizResponse` has `completed_at: nil`, and NULL sorts last on
  Postgres.** `latest_quiz_response` is scoped to `.completed` for exactly this
  reason: without it, an unfinished quiz becomes the home page's "View your
  results" link.
- The card detail page counts `Card::CORE_QUESTIONS.size`. It used to count
  `QUIZ_QUESTIONS`, which is now 16 and would advertise a sixteen-question quiz.
- Large multi-feature commits are how Finn's work vanished. Prefer small commits;
  `CLAUDE.md` asks for a branch per feature and this session did not always honour
  that.

---

## State right now

- **4 commits are unpushed.** `git push origin master && git push heroku master`.
- **The test suite has not been run.** `test/integration/quiz_flow_test.rb` was
  rewritten and `card_detail_test.rb` amended: both previously posted by index
  across all 16 questions, which no longer describes the flow. They walk the quiz
  dynamically now. Syntax checks pass; **nothing has executed them.** Run
  `bin/rails test` before trusting any of it.
- No migrations, gem changes or route changes are pending beyond what is committed.

---

## Outstanding

**Next task, already scoped.** The refine flow: a "refine my choices" control on
the results page that serves `Card::REFINE_QUESTIONS`. The groundwork is in: draft
completion, resume, and the `save_progress` action all exist. It needs
`:edit`/`:update` on `quiz_responses` so refining updates the same record rather
than creating a second one.

**The one open design decision.** The heading scale for Geist: Display, Hero
figure, Title, Section head, Subhead, and their tracking. It is open because the
code has no answer to defer to: every heading `clamp()` in the project appears
exactly once. The values in `DESIGN.md`'s typography table were tuned for
Helvetica Now and appear in no stylesheet. Until it is settled, **match the file
you are working in and do not invent values.** Owner: Noah.

**Still open from the critique**, roughly in priority order:
- The homepage assumes visitors already know what Shuffl is: no explanation of
  stacks, no preview of what the quiz produces.
- The hero card carousel has no transition animation at all, on a product named
  after shuffling.
- The compare tray is undiscoverable: a small grey checkbox for the most valuable
  feature on the browse page.
- Card detail leads with an oversized annual fee before any benefit.
- Issuer/network/category metadata on card detail is styled like links but is not.
- Card detail's two-column layout runs out of content in the left column.
- Footer links are all "coming soon" `aria-disabled` spans; those pages have never
  existed on any branch.
- Pundit is still not added; user-owned resources rely on `current_user` scoping.
- The six page-scoped stylesheets still carry their own resets: see *Known
  violations* in `DESIGN.md`.
- A local branch `repo-cleanup` (`5ab3687`, "Rotate master key and re-encrypt
  credentials") is unmerged and untracked to origin. Unrelated to this work, but a
  stranded credentials rotation is worth a look.

**Coming, and it shapes decisions.** Noah is loading ~300 real cards with real
APR, FX fees, bonus values and issuer eligibility rules. The current 54-card
catalogue is filler. Do not optimise anything against it. The placeholder card
artwork (`--finish-*` gradients) is temporary and will be replaced by real card
images: do not build on it.
