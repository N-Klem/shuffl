# Shuffl

**Find the credit cards that fit how you actually spend — then build them into a wallet.**

Shuffl is a credit-card recommendation app for people who find the rewards-card
world opaque. Instead of a wall of comparison tables, it asks about how you live
and spend, then recommends a small *stack* of cards that work well together — and
gives you a place to track the ones you hold.

> Le Wagon bootcamp project. Server-rendered Rails, no front-end framework.
> The card catalogue is illustrative sample data, not live offers.

---

## What it does

- **Take a 16-question quiz** (no account needed) — spending habits, credit
  profile, travel, rewards preferences — and get a ranked stack of the top 5
  cards, scored individually against your answers.
- **Browse the catalogue** — 54 cards and 5 curated stacks (Traveler, Foodie,
  Student, Cashback King, Luxury), searchable and filterable, with a
  compare-up-to-three view.
- **See how any card fits you** — once you've taken the quiz, every card page
  shows where that card ranks *for your answers* and whether it's in your stack.
- **Build your wallet ("Ledger")** — save cards as *owned* or *planned*, track
  sign-up-bonus progress and statement payments, and model your spending to
  estimate annual rewards. Requires an account.

## The journey

```
Home ──► Quiz (16 questions, no login) ──► Results: your top 5 cards
  │                                              │
  └──► Browse cards & stacks ◄───────────────────┘
              │
              ▼
        Card / stack detail ──► "Add to wallet" / "Save this stack"
              │                          │
              │                    (sign in prompted)
              ▼                          ▼
        My Wallet (Ledger): owned vs planned, bonus & payment tracking
```

Signing in **claims** any quiz you took beforehand, so your result follows you
into your account.

## Tech stack

- **Rails 8.1** — server-rendered ERB, Propshaft, Import Maps, Turbo + Stimulus
- **PostgreSQL**
- **Devise** for authentication
- **Bootstrap 5.3** (via CDN) plus a small custom design system — see
  [`DESIGN.md`](DESIGN.md), "The Quiet Interface"
- No React, no build step, no Node toolchain

## Getting started

Requires **Ruby 3.3.5** and **PostgreSQL**.

```bash
bundle install
bin/rails db:prepare   # create, migrate, and seed
bin/dev                # http://localhost:3000
```

Once the database exists, `bin/setup` is a shortcut that reinstalls gems,
clears logs, and starts the server (it does not create or seed the database).

Seeding loads the 54-card catalogue from [`data/cards.json`](data/cards.json)
and builds the 5 stacks. It's idempotent — safe to re-run.

## Tests

```bash
bin/rails test
```

Integration tests cover the quiz flow, card and stack detail pages, browse
catalogue, results, and the wallet.

## Project layout

| Path | What's there |
|------|--------------|
| `app/models/card.rb` | Card model, `QUIZ_QUESTIONS`, and the weighted `quiz_score` / `ranked_for` scoring |
| `app/controllers/` | Cards, Stacks, WalletItems, QuizResponses, Pages |
| `app/javascript/controllers/` | Stimulus: browse, quiz, results, wallet, stack carousel |
| `app/assets/stylesheets/` | `application.css` (tokens + shared) plus one file per page |
| `data/cards.json` | The illustrative 54-card catalogue |
| `db/seeds.rb` | Card + stack seeder |
| `DESIGN.md` | The design language |

## Conventions

This is a bootcamp project and deliberately stays at that altitude: standard
Rails CRUD, RESTful resources, no metaprogramming or service objects. Work on a
feature branch and open a PR — never commit straight to `master`.

## Deployment

Deployed to Heroku. After a push that changes the schema:

```bash
heroku run rails db:migrate
heroku run rails db:seed      # idempotent
```
