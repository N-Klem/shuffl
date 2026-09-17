# Handover: 16 and 17 September 2026, demo readiness

A point-in-time summary of one long working session (Finn, with Claude), written
for whoever picks this up next, including Noah's own Claude session. **It is not a
source of truth and it is not binding.** `DESIGN.md` governs anything visual,
`CLAUDE.md` describes how the app is built, and `docs/card-assistant.md` describes
the assistant. Where this file and those disagree, they win. Delete this once the
branch is merged and read.

The demo is on Friday 18 September 2026.

---

## Where the work is

- Branch `assistant-polish`, PR #16 on N-Klem/shuffl, stacked on branch
  `openai-key-credentials`, PR #15. **Merge #15 first, then #16.** Both are open
  and mergeable. #16 carries 38 commits beyond #15.
- Nothing is deployed to Heroku. That decision is Noah's.
- No migrations, no new gems. The only config changes are
  `config/application.rb` (`config.exceptions_app = routes`) and `config/routes.rb`
  (`/404`, `/500`, a catch-all `*unmatched` that excludes `/rails/` and `/assets/`).
- Verify with the locale set, or the design check misreads the files:

```
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 bin/rails test          # 165 runs, all green
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 bin/rails design:check   # OK, ceiling 227
git config core.hooksPath .githooks                           # once per clone
```

## Rules that still apply, plus two new ones

- `DESIGN.md` is binding: one typeface, one burgundy, tokens only, the six
  breakpoints (480 / 640 / 767 / 850 / 1000, plus 1600). Change `DESIGN.md` first,
  in its own commit, then the code. This session did that for the ranking
  question (commit e925a35) and for the dark-mode correction (a2a7c4f).
- Never commit on master. Branch, then PR.
- **New: no em dashes anywhere in site copy** (Finn's rule; they read as
  machine-written). Use a comma, a full stop, or the site's middot separator.
  Chip is instructed the same way and the panel replaces any that slip through
  with a comma at render time. Three em dashes remain in the code on purpose: a
  CSS comment, an ERB comment, and the `IMPLICIT_SCORING` compatibility key in
  `card.rb` that matches old stored quiz answers and is never displayed.
- The design hook flags Geist as an "overused font" in `public/404.html` and
  `public/500.html`. That is intentional (it is the site's typeface). To silence it:
  `.claude/skills/impeccable/scripts/impeccable hooks ignore-value overused-font "geist" --reason "site typeface"`.

---

## What changed, by area

### chip, the assistant

Files: `app/models/card_assistant.rb`, `app/models/assistant/openai_client.rb`,
`app/controllers/assistant_chats_controller.rb`, `app/views/shared/_assistant.html.erb`,
`app/assets/stylesheets/assistant.css`, `app/javascript/controllers/assistant_controller.js`,
`docs/card-assistant.md`.

- **Name.** `CardAssistant::NAME = "chip"`. Change it there only. The panel greets
  with "hi, i'm chip." and offers three starter pills; the opening screen is
  deliberately short.
- **Key.** `Assistant::OpenaiClient.api_key` reads `ENV["OPENAI_API_KEY"]` and falls
  back to `Rails.application.credentials.dig(:openai, :api_key)`. The key is in
  `config/credentials.yml.enc` (PR #15), so Heroku only needs `RAILS_MASTER_KEY`.
- **Models.** gpt-4.1-mini for screening and answers (`OPENAI_ASSISTANT_MODEL`),
  gpt-4.1 for the single web-search research call (`OPENAI_RESEARCH_MODEL`),
  because mini rejects the web-search domain `filters`. Research is capped at
  2000 output tokens with a 250-word brief; a lower cap came back `incomplete`.
- **Answer quality.** At most three paragraphs of under 60 words, at most five card
  names then "and N more match". One rewrite if a paragraph runs past 70 words.
  Recommendations get `eligible_recommendations` (id and name) plus a
  `meets_user_constraints` flag on each card's evidence; a reply that recommends
  outside that list gets one corrected retry, then fails closed. Verification in
  `verified_reply` is unchanged in spirit: every factual paragraph cites evidence
  that exists, or the reply is rejected.
- **Streaming progress.** `POST /assistant_chat` is now `ActionController::Live` and
  answers as newline-delimited JSON (`application/x-ndjson`): a
  `{"progress": "..."}` line as each stage starts, then one final line with
  `reply` and `remaining`, or `error`. Failures before the first line keep their
  HTTP status (401, 422, 429, 503); after it the status is already 200 and the
  outcome travels in the final line. `CardAssistant.new(..., progress:)` takes a
  callable; the notes are "Reading your question", "Read N cards and M stacks" (or
  "N cards match" when a constraint was extracted, or "No exact matches"),
  "Checking issuer sites", "Checked chase.com" (issuer domains, subdomains
  collapsed), "Nothing found on issuer sites", "Writing", "Shortening", and
  "Correcting". The client (`fetchStream`) renders them as a trail in the pending
  row. A client that disconnects mid-way marks the message `failed` so the
  two-minute in-flight limit does not hold. A failed provider call logs
  `Assistant chat failed: <class> <message>` where the message is metadata only
  ("http 429", "status incomplete max_output_tokens"); prompts and bodies are
  never logged.
- **Follow-up pills.** `followups(reply, question)` in the controller builds up to
  two pills from the cards and stacks a reply named: compare the first two cards,
  who a stack is for, a card's welcome offer, its foreign transaction fees, its
  perks, who it is for. A template is skipped when the question or the reply
  already covered it. Only the latest reply carries pills; they clear on the next
  send. A "which stacks include this card" template was tried and dropped: the
  honest answer is often "none", which is weak on stage and a fail-closed risk.
- **Save to wallet from a reply.** Works for cards and stacks, says "Saved to
  Planned in My Wallet." with a link, and dispatches `assistant:wallet-updated`
  with the fresh wallet payload so the wallet page re-renders in place.
- **Ask chip from elsewhere.** Any element with `data-assistant-ask="<question>"`
  opens the panel and asks. Used on card pages, stack pages, and the wallet
  coverage map.
- **Panel behaviour.** Stays open across page loads (sessionStorage), the orb parks
  bottom-right by default and follows window resizes, arrow keys nudge it, and
  the textarea has no focus ring (page sheets set blanket rings that load later,
  so `assistant.css` overrides with a more specific rule).
- **Quotas, unchanged.** `ASSISTANT_USER_DAILY_LIMIT` default 20 (clamped to 100),
  `ASSISTANT_GLOBAL_DAILY_LIMIT` 200, six per minute per account, reset at
  midnight UTC. For the demo start with `ASSISTANT_USER_DAILY_LIMIT=100`.
- **Tests.** `test/models/card_assistant_test.rb` (the FakeClient repeats its last
  reply on a correction; a progress-order test), `test/integration/assistant_chat_test.rb`
  (a `streamed` helper parses the NDJSON; a test for progress lines and an
  in-stream error), `test/models/assistant_openai_client_test.rb` (now requires
  `net/http` itself so it passes in any order).

### quiz

Files: `app/models/card.rb`, `app/models/quiz_recommendation.rb`,
`app/controllers/quiz_responses_controller.rb`, `app/views/quiz_responses/new.html.erb`,
`app/helpers/quiz_responses_helper.rb`, `app/javascript/controllers/quiz_controller.js`,
`app/assets/stylesheets/quiz.css`.

- **Ranked questions.** This session shipped tap-in-order pills with a numbered
  badge. Noah then replaced that in PR #17 (merged 17 September): tapping a choice
  moves its pill into a "Your priorities" area above the remaining options, a drag
  handle (or the handle's arrow keys) reorders the selection, and tapping a selected
  pill removes it. Up to three. `DESIGN.md` ("Seamless ranked quiz") describes the
  current control; follow it, not the pill description in this session's commits.
  The form still posts `answer[]` plus a hidden `ordered` field joined by U+001F,
  and the status line stays empty until the first tap.
- **"I don't know" for credit score reaches the results.** `Card#recommendable_for?`
  skips the band filter for that answer and the results footnote says so.
- **The quiz never ends on nothing.** `QuizRecommendation#closest` relaxes in order:
  strict, then lenient credit, then the cheapest fee tier, then both, and returns
  `[stack, relaxed]`. The controller derives `@relaxed` (`credit` and `budget`)
  from the saved stack and shows a footnote for each.
- A bookmarked result that no longer exists redirects to the quiz with an alert
  instead of a 500.
- Guidance text is grey; only `.is-error` takes the accent.
- Quiz option strings changed while removing dashes: "Yes, I'm loyal to one brand"
  and "Neither, I wouldn’t spend just to use a credit" (the scoring comparison
  and the test were updated to match).

### results

Files: `app/models/quiz_card_fit.rb`, `app/models/results_stack.rb`,
`app/views/quiz_responses/show.html.erb`, `app/javascript/controllers/results_controller.js`,
`app/assets/stylesheets/results.css`.

- **Why this card, in the person's own words.** `QuizCardFit#preferences_met`
  returns short fragments for the preferences a card meets, strongest first
  (cashback, travel rewards, no annual fee, help building credit only for
  builder-tagged cards, simple everyday rewards, categories you can activate, no
  foreign transaction fee, a named programme, a named benefit). `ResultsStack`
  adds `matches` per card and a top-level `spending` (the ranked categories).
  The page composes one sentence per card from the role it was given plus those
  fragments: "You put groceries first and wanted cashback and no annual fee. This
  card covers all three." A second card meeting the same preferences says "and
  it ticks the same boxes" instead of reciting them. The old disclosure remains
  beneath as "More on this card" with the terms and qualifiers. On phones the
  bottom row stacks.
- **Swap stays alive on relaxed results.** When the strict ranking is empty and the
  saved stack fails the strict credit check, the swap pool is the lenient
  ranking. A strict stack keeps the filtered catalogue (the eligibility test
  guards this).
- The footnote's "My Wallet" is a link.
- Spend categories are matched through the same channel logic as the results
  "Use for" block (`QuizCardFit#recommended_uses`). Cashback and points are never
  compared against each other anywhere in the app.

### wallet

Files: `app/models/wallet_dashboard.rb`, `app/javascript/controllers/wallet_controller.js`,
`app/assets/stylesheets/wallet.css`.

- **Coverage map** at the top of My Wallet: six everyday categories (groceries,
  dining out, travel, gas and transport, online shopping, entertainment and
  subscriptions), each listing the wallet cards that earn extra there with the
  rate in the card's own unit. Payload key `coverage`, built by
  `WalletDashboard#coverage` from `QuizCardFit#recommended_uses` with empty
  answers, for owned and planned cards alike. Legacy and retired cards have no
  recorded rules and never appear. A category with nothing earning extra offers
  "Ask chip" (`data-assistant-ask`), and chip's save button brings the card
  straight back into the map. Cards are marked "· planned" only when the wallet
  mixes owned and planned. Six columns above 1000px, three to 640, two to 480,
  then one. Test in `test/models/live_catalogue_test.rb`.
- The bonus line reads "$400 of $3,000" or "$400 so far". An unset statement
  balance shows a bare dash on purpose: that is an empty-value marker, not prose.

### browse

- The filter panel is pinned with the toolbar (`.controls` is sticky; 84px from
  the top on mobile) instead of opening off-screen. The fee column lines up
  (`.metrics` is a two-column grid).

### site-wide

- **Error pages in every environment.** `ErrorsController` with `not_found` and
  `internal_error`, views under `app/views/errors/`, and
  `ApplicationController` rescues `ActiveRecord::RecordNotFound` (HTML and Turbo
  get the branded 404 page, other formats get `head :not_found`).
  `public/404.html` and `public/500.html` are rewritten to the brand for the
  cases Rails cannot reach. Test: `test/integration/error_pages_test.rb`.
- One focus ring for the whole site (`:where(:focus-visible)` in
  `application.css`), buttons settle on press (`spinning_buttons.css`), a burgundy
  Turbo progress bar, clean card-image edges, the homepage and footer boxed to
  the navbar's 1320px width at 1600px and above, honest sign-in panel copy when a
  visitor has no picks yet, dead controllers removed (`hero_carousel`, `share`),
  redundant dark-mode token re-pins removed from `theme.css`, and the hex ceiling
  in `.design-baseline.yml` lowered to 227.
- **Dark mode already followed the system preference** (the inline script in the
  layout head reads `prefers-color-scheme` before first paint when no choice is
  stored; `theme_controller.js` tracks later OS changes). `DESIGN.md` and
  `CLAUDE.md` said otherwise and were corrected. The remaining dark-mode known
  violation is real: `browse.css` and `results.css` hardcode `#fff` backgrounds.
- Page titles use the middot separator everywhere ("Sign in · Shuffl").

---

## Catalogue gaps worth fixing before the demo (data, not code)

- 10 of the 30 published cards have no `editorial_credit_guidance.band`, so they
  never match a stated credit score.
- No card accepts "Building (300–579)", and only Chase Freedom Rise accepts "No
  credit history" or "Fair (580–669)". Anyone picking those gets the "closest
  fits" footnote. A couple of secured or credit-builder cards would fix it. "Good"
  and "Excellent" each get 14 or 15 cards and produce clean results.
- Chase Sapphire Preferred is in none of the five available stacks.

## Deploy checklist

1. Merge PR #15, then PR #16.
2. `git push heroku master`. No migration. Seeds are unchanged and idempotent.
3. Heroku already holds `RAILS_MASTER_KEY`, which is all the OpenAI key needs.
   Optionally `heroku config:set ASSISTANT_USER_DAILY_LIMIT=100` for the demo.
4. Streaming works through Heroku's router; the request deadline is still 24
   seconds, which stays under the router's 30.

## Test data

Finn's own account holds quiz result 25 (a "Building credit" run, hence its
footnote) and today's chat test questions in its history. The anonymous demo quiz
result and the temporary wallet items used to design the coverage map were
deleted; nothing from this session is left in the development database.
