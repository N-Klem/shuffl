# Shuffl

Credit card aggregator for Gen Z. Helps users find optimal credit card combinations ("stacks") based on their spending habits, lifestyle, and rewards preferences.

## What the app does

- **Pre-made stacks**: Curated groups of 3–5 credit cards optimized for a lifestyle (e.g. Traveler, Student, Foodie). Users browse stacks and view which cards are in each.
- **Personalized quiz**: 12-question questionnaire about spending habits, travel, dining, subscriptions, etc. Uses weighted scoring to produce a ranked list of top 5 cards.
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
resources :wallet_items, only: [:index, :create, :destroy]
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

- Questions defined in `Card::QUIZ_QUESTIONS` constant (12 questions, mix of single-select and one multi-select capped at 3 picks)
- Session-based flow: `session[:quiz_step]` (integer index into `QUIZ_QUESTIONS`) tracks progress, `session[:quiz_answers]` (hash) accumulates answers across requests
- `QuizResponsesController#new` renders the current question with a "Question X of 12" progress line; `#create` stores the submitted answer and either redirects to the next question or, on the last one, scores and redirects straight to results
- On the last question, `Card.ranked_for(session[:quiz_answers])` sorts all cards by `#quiz_score`, top 5 are saved as `QuizResponse#top_card_ids` (JSON), session state is cleared
- Scoring weights (all in `Card`'s private methods): top priority (+3), secondary priorities (+1 each, up to 3), frequency-based bonuses for dining/travel/driving/streaming (matched against `best_for`), fee fit (+2/-2 vs `annual_fee`), credit score fit (+2/-3 vs `credit_score_min`), international travel fit (vs `foreign_transaction_fee`), cashback-vs-points preference (vs `best_for` containing "Cashback"), welcome bonus importance (vs `welcome_bonus` presence), student status (+3 vs `best_for` containing "Student")

### Controllers

| Controller | Actions | Status |
|------------|---------|--------|
| `PagesController` | `home` | Working — placeholder view |
| `CardsController` | `index`, `show` | Working |
| `StacksController` | `index`, `show` | Working |
| `WalletItemsController` | `index`, `create`, `destroy` | Working |
| `QuizResponsesController` | `new`, `create`, `show` | Working |

### Views

All views exist under `app/views/`:
- `pages/home.html.erb` — placeholder (needs design)
- `cards/index.html.erb`, `cards/show.html.erb`
- `stacks/index.html.erb`, `stacks/show.html.erb`
- `wallet_items/index.html.erb`
- `quiz_responses/new.html.erb`, `quiz_responses/show.html.erb`
- `shared/_navbar.html.erb`

### What's next

- **Frontend/CSS polish** — Bootstrap is loaded but no view uses its classes yet; current custom CSS is still minimal (~22 lines). Need actual styling: responsive layout, card components, color scheme, typography
- **Home page design** — currently just `<h1>Shuffl</h1>`, tagline, and browse/sign-in links
- **Pundit authorization** — not yet added; policies for user-owned resources (wallet items, quiz responses) still just rely on `current_user` scoping in controllers
- **Quiz UX** — no per-question "required" validation (skipping a question just scores 0 for it) and no way to go back a step

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
- `app/assets/stylesheets/application.css` — minimal starter (~22 lines, needs work)
- `app/javascript/application.js` — minimal by design (2 lines); do not add ad-hoc JS here, use Stimulus controllers

## Repo hygiene

- `config/master.key` and `.kamal/secrets` are untracked from git (secrets shouldn't live in version control); `.kamal/secrets` itself only contains the default Kamal template (`RAILS_MASTER_KEY=$(cat config/master.key)`), no literal secret values
- `.gitignore` covers `graphify-out/`, `.codex/`, `Claude outputs/`, `*.bak`, `.kamal/secrets`, and `/config/*.key` — local tooling output and secrets that shouldn't be committed
- Legacy prototype artifacts removed: a ~1,600-line vibe-coded `application.js` (client-side quiz/wallet/explore/chat/animations that didn't match any real route), the unused `hello_controller.js` scaffold, the `messages` table/model, and `cards.image_url`

## GitHub & Deployment

- **Repo**: N-Klem/shuffl (branch: `master`)
- **Heroku**: shuffl-c0a9cbc48e06.herokuapp.com — deployed via `git push heroku master`; migrations/seeds must be run manually after a push that changes the schema (`heroku run rails db:migrate`, `heroku run rails db:seed` — seeding is safe to re-run, it's idempotent)

## Design System

**Read `DESIGN.md` before touching any view, partial, stylesheet, or Stimulus controller.**

Shuffl follows the "Quiet Interface" design language. The three non-negotiable rules:

1. **One family** — every character is set in the same tight grotesque (Helvetica Now Display / Inter Tight fallback). No second typeface.
2. **One burgundy** (`#7B1622`) — exactly one filled burgundy button per screen, always the primary CTA. Nothing else uses that colour except tertiary text links on hover.
3. **Nothing at rest** — secondary controls (compare, share, explore links) are hidden by default and revealed only on hover/focus with a 160ms opacity transition. Only show buttons that are 100% necessary.

Key implementation details:
- All design tokens (colours, spacing, radii, typography) are defined as CSS custom properties in `application.css` — use `var(--token-name)`, never raw hex values
- No shadows anywhere in the UI
- Dividers over boxes — don't wrap content in a card just to group it
- Pence portions of monetary figures drop to `muted` colour — this is a signature detail
- Hover-revealed controls must be keyboard-accessible (`visibility: hidden` + `opacity: 0`, never `display: none`)
- Use Bootstrap grid, utilities, and responsive breakpoints as normal — but override Bootstrap's default colours, shadows, and radii with the Shuffl tokens (see DESIGN.md for the full CSS variable block)
- Don't use Bootstrap colour classes (`.text-primary`, `.bg-info`) with their defaults — they pull in Bootstrap blue/green instead of the Shuffl palette
- Inter Tight is loaded from Google Fonts as the web fallback font
