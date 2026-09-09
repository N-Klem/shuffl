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
- Bootstrap for CSS framework (planned — CSS is still minimal)
- No React, no external JS frameworks — everything is server-rendered ERB

## Le Wagon conventions

This is a Le Wagon bootcamp project (9-week course: HTML/CSS/JS → Ruby on Rails). Follow these rules:

- **CRUD-first architecture**: Routes → Controller actions → Views. Every feature is a standard Rails CRUD flow.
- **Feature branching**: Never code on master. One branch per feature, named descriptively (e.g. `cards-index`, `quiz-flow`, `wallet-crud`). Merge via PR after review.
- **Vertical slices**: Each feature goes route → controller → view with CSS. Don't batch "all controllers" or "all views" separately.
- **Keep it realistic**: Code should look like it was written by someone who completed a 9-week bootcamp. No metaprogramming, no complex service objects, no over-engineering. Simple, readable, conventional Rails.
- **RESTful resources**: Use `resources` in routes. Standard controller patterns (`index`, `show`, `new`, `create`, `edit`, `update`, `destroy`).
- **Pundit for authorization**: Will be added for policies (users can only manage their own wallet items, quiz responses, etc.).

## Current state of the codebase

### Database (7 tables)

| Table | Purpose |
|-------|---------|
| `users` | Devise auth + first_name |
| `cards` | Credit card data — name, issuer, network, card_type, annual_fee, reward_rate, welcome_bonus, perks, best_for, description, image_url, credit_score_min, foreign_transaction_fee |
| `wallet_items` | User ↔ Card join (unique index on user_id + card_id) |
| `quiz_responses` | Quiz answers (JSON text), top_card_ids (JSON text), completed_at |
| `messages` | Chat messages with role and optional card reference (not yet wired up) |
| `stacks` | Pre-made card groupings — name, category, description |
| `stack_cards` | Stack ↔ Card join with unique index on stack_id + card_id |

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

- **Auth**: User sign-up / sign-in / sign-out via Devise
- **Cards**: Browse all cards (`/cards`), view card details (`/cards/:id`)
- **Stacks**: Browse pre-made stacks (`/stacks`), view stack with ordered card list (`/stacks/:id`)
- **Wallet**: Add/remove cards to personal wallet, view wallet (`/wallet_items`)
- **Quiz**: Full 12-question multi-step flow (`/quiz_responses/new`), results page (`/quiz_responses/:id`)
- **Navigation**: Shared navbar partial
- **Seeds**: `db/seeds.rb` populates cards from `data/cards.json` and creates pre-made stacks (Traveler, Foodie, Student, etc.)

### Quiz implementation

The quiz uses a **weighted scoring** approach — each card is scored independently against the user's answers, avoiding nested if-statements:

- Questions defined in `Card::QUIZ_QUESTIONS` constant (12 questions, mix of single-select and multi-select)
- Session-based multi-step flow: `session[:quiz_step]` tracks progress, `session[:quiz_answers]` accumulates answers
- `QuizResponsesController#new` renders current question, `#create` saves answer and advances or finishes
- `Card.ranked_for(answers)` sorts all cards by `quiz_score` — top 5 are saved to the QuizResponse
- Scoring weights: top priority (+3), secondary priorities (+1 each), frequency-based bonuses for dining/travel/driving/streaming, fee fit (+2 or -2), credit score fit (+2 or -3), international travel fit, rewards type preference, welcome bonus importance, student status (+3)

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

- **Frontend/CSS polish** — current CSS is minimal (~22 lines). Need Bootstrap integration, responsive design, card components, color scheme, typography
- **Home page design** — currently just `<h1>Shuffl</h1>` with a tagline
- **Pundit authorization** — policies for user-owned resources
- **Messages/chat feature** — model exists but not wired up
- **Production deployment** — Heroku app exists, needs PostgreSQL addon + migrate + seed

## Data

- `data/cards.json` — 54 fictional credit cards with rewards, perks, sign-up bonuses, categories
- Card categories in `best_for`: Travel, Dining, Groceries, Gas, Streaming, Cashback, Student, Business, Luxury, etc.

## Key files

- `app/models/card.rb` — Card model with `QUIZ_QUESTIONS`, `ranked_for`, and `quiz_score` methods
- `app/models/stack.rb` — Stack model with category field
- `app/models/stack_card.rb` — Join model with uniqueness validation
- `app/controllers/quiz_responses_controller.rb` — Full session-based quiz flow
- `db/schema.rb` — current DB structure (7 tables)
- `db/seeds.rb` — card seeder (reads cards.json) + stack seeder
- `config/routes.rb` — all resource routes wired up
- `app/views/shared/_navbar.html.erb` — site navigation
- `app/assets/stylesheets/application.css` — minimal starter (needs work)

## GitHub & Deployment

- **Repo**: N-Klem/shuffl
- **Heroku**: shuffl-c0a9cbc48e06.herokuapp.com
