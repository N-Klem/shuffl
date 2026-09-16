# US demo catalogue

The demo uses 30 US / USD cards. Noah accepted the existing research for demo use on 16 September 2026. UK cards are outside scope. This acceptance does not claim that every term or application requirement has been verified.

## One shared live catalogue

`catalogue.json` is the portable snapshot of the US research candidates, including the saved local research corrections. `CardCandidate` holds editable research. Published `Card` records supply browsing, details, quiz results and wallet payloads; those features no longer read the fictional `data/cards.json`.

Live cards have a stable `source_key`, market, publication status, decimal annual fee and structured `catalogue_terms`. The terms retain reward units and conditions, fee treatment, welcome-offer requirements, benefits, eligibility notes, research limitations and source dates. Null remains unknown. A missing foreign fee is not treated as no fee, and points/miles are not converted into dollars.

`legacy` records are visible until the demo cutover; `draft` records are hidden; `published` records are discoverable; `retired` records remain accessible through historical links and saved data.

## Import and publication

```sh
bundle exec rails db:migrate
bundle exec rails cards:catalogue:import
bundle exec rails cards:catalogue:stage
bundle exec rails cards:catalogue:publish_demo
```

- `import` inserts missing candidates and preserves existing research corrections and review decisions. Updating the JSON does not overwrite an existing candidate.
- `stage` copies non-rejected US candidates into cards by `source_key`. New cards are drafts. Existing cards retain their status and ID; their facts are updated from candidate research.
- `publish_demo` imports the candidates transactionally, publishes the non-rejected US set and retires fictional cards and previously published cards outside that set. It does not delete wallet items, quiz results, stack memberships or card records.
- `db:seed` imports the portable candidates and runs the same demo publication. It is safe to repeat without duplicating cards or restoring fictional cards.

Publication does not mark candidate research as reviewed. Rejected candidates are not published. An invalid candidate rolls the card import back.

## Current display policy

Show recorded rates with their units and conditions, welcome offers with captured requirements, and sources with check dates. Dollar reward estimates and automatic spending allocations are unavailable until calculation rules support caps, conditional rates and redemption values. Missing benefits are not evidence of no benefits.

Old wallet entries and quiz results retain their original card IDs. Retired cards cannot be newly added or offered as swaps. Pre-made stacks containing retired cards are hidden from discovery and the home carousel; rebuilding those stacks is the next separate step. Historical stack links remain available.

The quiz evaluates complementary combinations of published cards, respecting the maximum card count and combined annual-fee budget. Automatic recommendations and results swaps now require matching recorded credit-profile guidance. Unknown card guidance, an unknown user credit range, and unsupported profiles produce no automatic match. New-to-credit guidance is not treated as support for damaged credit. Explicit student requirements and named programme preferences also apply; suitability tags alone are not eligibility requirements. Prime Visa requires an explicit Amazon with Prime answer as well as supported credit guidance. These are conservative editorial filters, not issuer approval guarantees. All published cards remain available in Browse for deliberate selection; historical recommendations retain their saved IDs. A no-match result explains the limitation without presenting an empty stack as a recommendation.

Every current question now feeds eligibility, coverage, management effort, fees or conditional benefits. See `docs/quiz-matching.md` for the complete question-to-decision mapping and editorial scoring policy. Unknown terms are not invented, temporary promotions are excluded from ongoing fit, and dollar reward/bonus-feasibility calculations remain deferred.

## Maintaining research

Edit the candidate identified by `source_key`, preserving URLs, check dates, rates, units and conditions. Re-run `stage` or `publish_demo` to update its live card. To move local research to a fresh installation, update the portable JSON snapshot too; database edits do not write back automatically.

```sh
bundle exec rails cards:catalogue:export
```

This refreshes `review/cards.csv` and `review/cards.md` from the research database. The `review/unknowns` files are the original research checklist, not a current audit of the richer snapshot.

```sh
bundle exec rails test test/models/card_candidate_test.rb test/models/live_catalogue_test.rb
```

## Curated demo stacks

After publishing the US catalogue, run `bundle exec rails stacks:seed_demo`.
`db:seed` also runs this step. The five approved lineups live in `stacks.json`;
card references use stable source keys. Descriptions, roles and usage notes are
editorial guidance, separate from the issuer facts in `catalogue.json`.

The import is transactional and repeatable. It requires available cards, preserves
stack IDs, and leaves historical fictional stacks intact. Starter has two cards;
the other four have three. Fees are summed from the live card records, before
introductory waivers or conditional credits. Saving adds missing cards to Planned
without changing existing owned or planned wallet entries.
