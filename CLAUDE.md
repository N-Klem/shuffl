# Shuffl

Credit card aggregator for Gen Z. Helps users find optimal credit card combinations ("stacks") based on their spending habits, lifestyle, and rewards preferences.

## What the app does

- **Pre-made stacks**: Curated groups of 3–5 credit cards optimized for a lifestyle (e.g. Traveler, Student, Foodie). Users browse stacks and view which cards are in each.
- **Personalized quiz**: 16-question questionnaire about spending habits, travel, dining, subscriptions, etc. Uses weighted scoring to produce a ranked list of top 5 cards.
- **Results page**: Shows the user's recommended cards from quiz results with details on each card.
- **My Wallet**: Users save cards they like and manage their collection. Add/remove from any card view.
- **Card browsing**: Browse all 54 cards, view individual card details (annual fee, reward rates, perks, sign-up bonus).
- **Stack browsing**: Browse pre-made stacks by category, view stack details with ordered card lists.

## Tech stack

- Rails 8 with Propshaft, Importmap, Turbo, Stimulus
- PostgreSQL
- Devise (authentication)
- Bootstrap 5.3.3 via CDN (`<link>`/`<script>` in the layout — no Sass build, no Node/npm toolchain; views don't use Bootstrap classes yet, just the framework is loaded)
- No React, no external JS frameworks — everything is server-rendered ERB
- `app/javascript/application.js` is intentionally minimal (just the two default importmap imports) — no custom JS. Add interactivity via Stimulus controllers under `app/javascript/controllers/`, not inline scripts

## Le Wagon conventions

This is a Le Wagon bootcamp project (9-week course: HTML/CSS/JS → Ruby on Rails). Follow these rules:

- **CRUD-first architecture**: Routes → Controller actions → Views. Every feature is a standard Rails CRUD flow.
- **Feature branching**: Never code on master. One branch per feature, named descriptively (e.g. `cards-index`, `quiz-flow`, `wallet-crud`). Merge via PR after review.
- **Vertical slices**: Each feature goes route → controller → view with CSS. Don't batch "all controllers" or "all views" separately.
- **Keep it realistic**: Code should look like it was written by someone who completed a 9-week bootcamp. No metaprogramming, no complex service objects, no over-engineering. Simple, readable, conventional Rails.
- **RESTful resources**: Use `resources` in routes. Standard controller patterns (`index`, `show`, `new`, `create`, `edit`, `update`, `destroy`).
- **Pundit for authorization**: Will be added for policies (users can only manage their own wallet items, quiz responses, etc.).

## Current state of the codebase

### Database (6 tables)

| Table | Purpose |
|-------|---------|
| `users` | Devise auth + first_name |
| `cards` | Credit card data — name, issuer, network, card_type, annual_fee, reward_rate, welcome_bonus, perks, best_for, description, credit_score_min, foreign_transaction_fee |
| `wallet_items` | User ↔ Card join (unique index on user_id + card_id) |
| `quiz_responses` | Quiz answers (JSON text), top_card_ids (JSON text), completed_at |
| `stacks` | Pre-made card groupings — name, category, description |
| `stack_cards` | Stack ↔ Card join with unique index on stack_id + card_id |

The `messages` table/model and `cards.image_url` column were removed as unused legacy-prototype leftovers (migrations `drop_messages` and `remove_image_url_from_cards`).

### Routes

```ruby
devise_for :users
root "pages#home"
resources :stacks, only: [:index, :show]
resources :cards, only: [:index, :show]
resources :wallet_items, only: [:index, :create, :update, :destroy] do
  patch :preferences, on: :collection
  post  :save_browse, on: :collection
  post  :save_stack,  on: :collection
end
resources :quiz_responses, only: [:new, :create, :show]
```

### What's built and working

- **Auth**: User sign-up / sign-in / sign-out via Devise, with a custom `first_name` field added to the sign-up and account-edit forms (`app/views/devise/registrations/{new,edit}.html.erb`) and permitted via `configure_permitted_parameters` in `ApplicationController`
- **Cards**: Browse all cards (`/cards`), view full card details (`/cards/:id`)
- **Stacks**: Browse pre-made stacks (`/stacks`), view stack with ordered card list (`/stacks/:id`); stacks index links to the quiz for users who don't find a fit
- **Wallet**: Add a card from its show page ("Add to Wallet" button, hidden if signed out or already owned), remove from `/wallet_items`, view wallet (`/wallet_items`)
- **Quiz**: One-question-per-page wizard (`/quiz_responses/new` → `/quiz_responses/:id`), auth-gated
- **Navigation**: Shared navbar partial (`shared/_navbar.html.erb`) — Home / Stacks / Cards always, "My Wallet" only when signed in
- **Homepage**: Links to Browse Stacks / Browse Cards, plus Sign in / Sign up when signed out
- **Seeds**: `db/seeds.rb` populates cards from `data/cards.json` (idempotent — `find_or_initialize_by` + always-assign, so re-running backfills existing rows) and creates 5 pre-made stacks (Traveler, Foodie, Student, Cashback King, Luxury), each matched to cards by category via `best_for`

### Quiz implementation

The quiz is a **one-question-per-page wizard** with **weighted scoring** — each card is scored independently against the user's answers, avoiding nested if-statements:

- Questions defined in `Card::QUIZ_QUESTIONS` constant (16 questions, mix of single-select and one multi-select capped at 3 picks)
- Session-based flow: `session[:quiz_step]` (integer index into `QUIZ_QUESTIONS`) tracks progress, `session[:quiz_answers]` (hash) accumulates answers across requests
- `QuizResponsesController#new` renders the current question with a "Question X of 12" progress line; `#create` stores the submitted answer and either redirects to the next question or, on the last one, scores and redirects straight to results
- On the last question, `Card.ranked_for(session[:quiz_answers])` sorts all cards by `#quiz_score`, top 5 are saved as `QuizResponse#top_card_ids` (JSON), session state is cleared
- Scoring weights (all in `Card`'s private methods): top priority (+3), secondary priorities (+1 each, up to 3), frequency-based bonuses for dining/travel/driving/streaming (matched against `best_for`), fee fit (+2/-2 vs `annual_fee`), credit score fit (+2/-3 vs `credit_score_min`), international travel fit (vs `foreign_transaction_fee`), cashback-vs-points preference (vs `best_for` containing "Cashback"), welcome bonus importance (vs `welcome_bonus` presence), student status (+3 vs `best_for` containing "Student")

### Controllers

| Controller | Actions | Status |
|------------|---------|--------|
| `PagesController` | `home` | Working — fully designed |
| `CardsController` | `index`, `show` | Working |
| `StacksController` | `index`, `show` | Working |
| `WalletItemsController` | `index`, `create`, `update`, `destroy`, plus `preferences`, `save_browse`, `save_stack` on the collection | Working |
| `QuizResponsesController` | `new`, `create`, `show` | Working |

### Views

Under `app/views/`. Every surface is designed — none of these are placeholders.

- `pages/home.html.erb`
- `cards/index.html.erb` (client-rendered from `@browse_payload`), `cards/show.html.erb`
- `stacks/index.html.erb`, `stacks/show.html.erb`
- `wallet_items/index.html.erb`
- `quiz_responses/new.html.erb`, `quiz_responses/show.html.erb`
- `shared/` — `_navbar`, `_footer`, `_wordmark`, `_flash`, `_assistant`
- `devise/` — custom `sessions/new`, `registrations/new`, `registrations/edit`, `passwords/*`,
  plus `devise/shared/_auth_tabs`, `_stack_panel`, `_error_messages`

### Front-end assets

Fourteen stylesheets in `app/assets/stylesheets/`:

`application` (tokens + shared chrome), `theme` (dark mode), `footer`, `assistant`, `z_mobile`,
`product_motion`, `spinning_buttons`, `detail`, and six page-scoped sheets: `home`, `quiz`,
`browse`, `results`, `login`, `wallet`.

> The six page-scoped sheets each carry their own CSS reset and colour literals instead of
> building on `application.css`. This is the largest piece of frontend debt in the project and it
> is recorded under *Known violations* in DESIGN.md. Do not add a seventh.

Twelve Stimulus controllers in `app/javascript/controllers/`:

`assistant`, `browse`, `dialog`, `hero_carousel`, `password_visibility`, `quiz`, `quiz_finish`,
`results`, `share`, `stack`, `theme`, `wallet`, plus a shared `motion_helpers.js`.
`app/javascript/application.js` stays minimal — add behaviour as a Stimulus controller, never
as an inline script or ad-hoc JS in that file.

### What's next

- **Unify the six page-scoped stylesheets** onto `application.css`'s tokens — see *Known
  violations* in DESIGN.md. Highest-value frontend work outstanding; dark mode for browse and
  results falls out of it almost free.
- **Settle the two open design decisions** (type scale for Geist, money-out colour) — see
  *Open decisions* in DESIGN.md. Until then, do not invent values for either.
- **Quiz length** — the quiz is 16 questions with no payoff until the end. Planned: cut to 8,
  show results, then a "keep refining" path that reopens the rest. Needs `:edit`/`:update` on
  `quiz_responses`, since the record is currently created once at the end.
- **Dark mode ignores the system preference** — `theme.css` responds only to the navbar toggle;
  there is no `prefers-color-scheme` query.
- **Pundit authorization** — not yet added; user-owned resources still rely on `current_user`
  scoping in the controllers.
- **Quiz UX** — no per-question "required" validation; skipping a question scores 0 for it.

## Data

- `data/cards.json` — 54 fictional credit cards with rewards, perks, sign-up bonuses, categories
- Card categories in `best_for`: Travel, Dining, Groceries, Gas, Streaming, Cashback, Student, Business, Luxury, etc.

## Key files

- `app/models/card.rb` — Card model with `QUIZ_QUESTIONS` constant, `self.ranked_for`, `#quiz_score`, and the private per-dimension scoring helpers
- `app/models/stack.rb` — Stack model, `has_many :cards, through: :stack_cards`
- `app/models/stack_card.rb` — join model, uniqueness of `card_id` scoped to `stack_id`
- `app/models/wallet_item.rb` — join model, uniqueness of `card_id` scoped to `user_id`
- `app/controllers/quiz_responses_controller.rb` — session-based one-question-per-page quiz wizard
- `app/controllers/wallet_items_controller.rb` — auth-gated wallet CRUD (index/create/destroy)
- `app/controllers/application_controller.rb` — Devise `first_name` param permitting
- `db/schema.rb` — current DB structure (6 tables)
- `db/seeds.rb` — idempotent card seeder (reads `cards.json`) + stack seeder
- `config/routes.rb` — all resource routes wired up
- `app/views/shared/_navbar.html.erb` — site navigation
- `app/views/layouts/application.html.erb` — Bootstrap CDN tags + navbar render
- `app/assets/stylesheets/application.css` — the `:root` token block plus shared chrome
  (navbar, buttons, footer, flash). The authoritative source for every design token.
- `app/assets/stylesheets/theme.css` — dark mode, driven by `data-theme` on `<html>`
- `lib/tasks/design.rake` — `design:check` / `design:baseline`, the enforcement described above
- `.design-baseline.yml` — recorded violation ceiling per stylesheet; never hand-edit
- `.githooks/pre-commit` — runs `design:check` when a stylesheet is staged
- `app/javascript/application.js` — minimal by design; do not add ad-hoc JS here, use Stimulus controllers
- `app/views/shared/_wordmark.html.erb` — the `shuffl.` wordmark; render it, never hand-write the mark

## Repo hygiene

- `config/master.key` and `.kamal/secrets` are untracked from git (secrets shouldn't live in version control); `.kamal/secrets` itself only contains the default Kamal template (`RAILS_MASTER_KEY=$(cat config/master.key)`), no literal secret values
- `.gitignore` covers `graphify-out/`, `.codex/`, `Claude outputs/`, `*.bak`, `.kamal/secrets`, and `/config/*.key` — local tooling output and secrets that shouldn't be committed
- Legacy prototype artifacts removed: a ~1,600-line vibe-coded `application.js` (client-side quiz/wallet/explore/chat/animations that didn't match any real route), the unused `hello_controller.js` scaffold, the `messages` table/model, and `cards.image_url`

## GitHub & Deployment

- **Repo**: N-Klem/shuffl (branch: `master`)
- **Heroku**: shuffl-c0a9cbc48e06.herokuapp.com — deployed via `git push heroku master`; migrations/seeds must be run manually after a push that changes the schema (`heroku run rails db:migrate`, `heroku run rails db:seed` — seeding is safe to re-run, it's idempotent)

## Design System

**Read `DESIGN.md` before touching any view, partial, stylesheet, or Stimulus controller.**

**DESIGN.md is the only source of truth for anything visual.** It is deliberately not summarised
here: this file used to restate its rules, the two copies drifted, and the drifted copy is what
people implemented. Three burgundies and an unlicensed typeface came out of that. Read DESIGN.md
itself — it marks every statement as binding, open, or a known violation, so you can tell which
parts are decided.

The short version, so you know what you are walking into:

- One typeface (Geist), one burgundy (`#601020`), nothing visible at rest that is not the next step.
- Never write a raw hex or name a font family in a stylesheet. Use `var(--token)`. The
  authoritative token list is the `:root` block of `application.css`.
- Never hand-write the `shuffl.` wordmark. Render `shared/_wordmark.html.erb` — its full stop is
  a drawn circle, not a typed period, for reasons DESIGN.md explains.
- Two design decisions are explicitly **open** (the type scale, the money-out colour). Do not
  answer them in passing. Match the surrounding file and leave them alone.

### Enforcement

`rake design:check` fails a commit that reintroduces a retired burgundy or font name, or that adds
a raw hex or hardcoded font family to any stylesheet. Existing violations are recorded per file in
`.design-baseline.yml` and may shrink but never grow; run `rake design:baseline` after cleaning
some up to lock in the lower number.

Enable the hook once per clone:

```
git config core.hooksPath .githooks
```
