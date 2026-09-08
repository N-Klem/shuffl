# Shuffl

Credit card aggregator for Gen Z. Helps users find optimal credit card combinations ("stacks") based on their spending habits, lifestyle, and rewards preferences.

## What the app does

- **Pre-made stacks**: Curated groups of 3–5 credit cards optimized for a lifestyle (e.g. Traveler, Student, Foodie). Users browse these from the home page and can view which cards are in each stack.
- **Personalized quiz**: ~15-question questionnaire about spending habits, travel frequency, dining, subscriptions, etc. Produces a custom stack of 3–5 cards tailored to the user's answers.
- **Results page**: Shows the recommended stack from quiz results — which cards, why they were chosen, rewards breakdown.
- **My Wallet**: Users save cards they currently hold, track spending, points, and rewards across their cards.
- **Card detail**: Individual card pages showing annual fee, reward rates, perks, sign-up bonus.

## Tech stack

- Rails 8 with Propshaft, Importmap, Turbo, Stimulus
- PostgreSQL
- Devise (authentication)
- Bootstrap for CSS framework
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

### Done
- Rails app created with Devise template, PostgreSQL configured
- All 5 models with associations and validations:
  - `User` (Devise auth, has_many wallet_items/cards/quiz_responses/messages)
  - `Card` (name, issuer, network, card_type, annual_fee, reward_rate, welcome_bonus, perks, best_for, description)
  - `WalletItem` (belongs_to user + card, unique index on user_id + card_id)
  - `QuizResponse` (belongs_to user, stores answers as text, top_card_ids, completed_at)
  - `Message` (belongs_to user + optional card, content, role)
- All migrations run, schema up to date
- `db/seeds.rb` reads from `data/cards.json` (54 fictional credit cards)
- Empty controllers generated: `CardsController`, `WalletItemsController`, `QuizResponsesController`
- `PagesController` with only a `home` action
- Minimal layout, placeholder home view, basic CSS starter
- GitHub repo: N-Klem/shuffl
- Heroku app exists (needs production migrate + seed)

### Not yet built
- Card seed data not yet loaded (run `rails db:seed`)
- No feature routes, controller logic, or views beyond the home placeholder
- Pundit not installed
- No authorization policies
- Production DB not migrated or seeded

## Data

- `data/cards.json` — 54 fictional credit cards with rewards, perks, sign-up bonuses, categories
- Card categories include: travel, dining, groceries, gas, streaming, general, student, business, luxury

## Key files

- `app/models/` — all 5 models
- `db/schema.rb` — current DB structure
- `db/seeds.rb` — card seeder (reads cards.json)
- `config/routes.rb` — currently just Devise + root
- `app/controllers/pages_controller.rb` — home action only
- `app/views/pages/home.html.erb` — placeholder
- `app/assets/stylesheets/application.css` — minimal starter
