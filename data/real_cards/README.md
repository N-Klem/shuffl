# Real credit-card research catalogue

Initial research: 15 September 2026. 50 candidates: 30 US / USD, 20 UK / GBP (ISO country code GB).

## What is built

`catalogue.json` is a portable initial research import. `CardCandidate` stores it in PostgreSQL's `card_candidates` table. These are **review candidates**, not published `Card` records. No migration or task deletes fictional cards, replaces wallet items, changes old quiz results, or mixes countries in the live catalogue.

```sh
bundle exec rails db:migrate
bundle exec rails cards:catalogue:import
bundle exec rails cards:catalogue:export
```

Exports live at `data/real_cards/review/cards.csv` and `cards.md`. The Markdown version has clickable sources. CSV can be opened in a spreadsheet; edits to the export do not automatically update the database.

## How to review

Open each source and check the exact card, country, new-applicant availability, ongoing fee, first-year fee, foreign purchase fee, reward categories/caps, bonus requirements and eligibility. Send corrections using the stable `source_key`, or edit the candidate in Rails console. Mark a record `reviewed` or `rejected` only with `reviewed_by` and `reviewed_at`. `reviewed` records still do not publish to the app.

Example after completing a manual check (replace values with real findings):

```ruby
candidate = CardCandidate.find_by!(source_key: "us-chase-sapphire-preferred")
research = candidate.research.deep_dup
# Correct research fields and source details here using the issuer page.
candidate.update!(research: research, review_notes: "Describe exactly what was checked")
# When finished, separately record the actual reviewer and time:
# candidate.update!(review_status: "reviewed", reviewed_by: "Your name", reviewed_at: Time.current)
```

Repeat imports intentionally preserve existing records, including pending records with manual edits. Updating the JSON does not overwrite database research. Importing a malformed batch rolls back new inserts. There is no automatic promotion or weekly scraping yet.

## Meaning of the fields

- `source_key`: stable country-specific identity, independent of renames.
- `fees`: decimal strings in the card's currency; annual and monthly billing stay separate. Introductory waivers are described explicitly. A monthly fee is not a billed annual fee.
- `rewards`: numeric rate strings with explicit units and conditions. A multiplier is not cash value. Shared caps, portal requirements and introductory periods must remain attached to their rates. Schedules are partial and marked `rewards_complete: false` until reviewed.
- `welcome_offer`: observed offer text, not a guaranteed offer for every applicant. Null means not captured, not no bonus. Referrals and incidental account credits are not ordinary spending bonuses.
- `eligibility`, `network`, `credit_score_min`: unknown unless supported. No invented numerical approval scores. Issuer display names may still need legal-entity verification.
- `sources`: official URLs, access date, evidence type. `official_page` means page text was retrieved; `official_search_extract` means information came from an issuer search result and may lag the live page. Neither means human approval. Source dates are not guaranteed offer effective dates. Sources support the record collectively, not a field-by-field audit trail.
- `quiz_tags` / `recommendation_conditions`: Shuffl's editorial mapping, not issuer facts. These do not change current quiz scoring.
- `availability`: product listed is not verified application availability. M&S Shopping Plus needs exact-variant confirmation.
- `review_flags`: unresolved research questions. `perks` is initially empty: benefits are not fully extracted. Null, empty reward lists and empty perks lists are not proof that a card lacks them.

## Important findings

- Wells Fargo Active Cash currently shows USD 100 on the retrieved channel, while an older terms result shows USD 200. Preserve channel and recheck.
- Some issuer pages omit dynamic welcome/pricing numbers. These remain unknown rather than being reconstructed from memory.
- John Lewis publishes a future rewards change for 25 September 2026. Preserve the effective date when reviewing.
- Hyatt and United headline multipliers include loyalty-program earnings. The research uses card-only rates where supported.
- Lloyds Ultra and Amazon Barclaycard have first-year rates that differ from ongoing rates.
- Discover sources now link into Capital One; legal issuer and application details need verification.
- Some sources still use the legal names Platinum Cashback / Platinum Cashback Everyday while marketing uses Cashback / Cashback Everyday.

## Remaining product work

After human review: migrate approved facts into a country-aware live catalogue, replace the fictional source consumed by `BrowseCatalogue`, add country selection/localised quiz wording and conditional brand/eligibility checks, and update reward scoring. The current app still reads `data/cards.json` and the existing `cards` table. This step builds the research database and review package only.

Tests:

```sh
RAILS_ENV=test bundle exec rails db:migrate
bundle exec rails test test/models/card_candidate_test.rb
```
