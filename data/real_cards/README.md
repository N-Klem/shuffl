# Real credit-card research catalogue

Researched 15 September 2026: **50 records, 30 US / USD and 20 UK / GBP**. The source collection covers all 30 US cards and 19 UK cards. M&S Shopping Plus remains on hold because its exact current variant could not be confirmed.

## Sources and scope

- **US:** NerdWallet card reviews are the primary source, with issuer evidence retained where useful.
- **UK:** MoneySavingExpert covers nine shortlisted cards; issuer pages and summary boxes fill other coverage. NerdWallet's UK comparison service closed on 24 March 2026.
- Core rewards, account fees, foreign purchase fees, observed welcome offers, selected perks and available interest/eligibility guidance are captured. Sources include URLs, access dates and evidence labels.
- This is a demo research dataset, not a weekly updater. A source may omit dynamic pricing or personalised bonuses. Those fields stay explicitly unresolved rather than receiving guessed values.

The data lives in `catalogue.json` and the local PostgreSQL `card_candidates` table. **The live app still uses the fictional catalogue. No Heroku data or deployment was changed.** Country selection, live-card import and recommendation integration are separate remaining work.

## Read the data

- `review/cards.md`: readable card-by-card facts and clickable sources.
- `review/cards.csv`: spreadsheet export of the same database records.
- `review/unknowns.md` and `.csv`: regenerated source gaps and caveats, including optional fields. These replace the original blanket manual-lookup checklist.

There are account-fee values for 48 records and foreign-purchase-fee values for 45. The substantive gaps are:

- M&S Shopping Plus: exact offer, fees and rewards unresolved; `demo_inclusion: hold`.
- Halifax Clarity: account fee unresolved.
- Amazon Barclaycard, Barclaycard Avios, Avios Plus and Capital One Classic: exact foreign purchase fee unresolved.
- UK British Airways Amex and Marriott Amex: retrieved pages omit a new-card welcome amount.

Missing networks, additional perks, numerical APRs and general eligibility are also listed where relevant. They do not all block a rewards demo. No universal numerical credit-score approval threshold is invented.

## Import and export

```sh
bundle exec rails db:migrate
bundle exec rails cards:catalogue:import
bundle exec rails cards:catalogue:export
```

Import adds missing candidates and **preserves every existing record**, including manual edits. It is not a refresh command. The research collection in this change was explicitly refreshed into the local database only where pending records still matched the preceding JSON; reviewed or manually changed records would have been preserved.

For an existing database, reconcile JSON changes with the stored research explicitly. Do not delete and reimport to refresh it. Spreadsheet edits do not automatically change the database. Export regenerates both the full catalogue and the gaps from database records.

`review_status` describes human review only. It remains `pending` until someone actually reviews a record; automated research does not impersonate a reviewer. `research_status` separately describes NerdWallet, MSE or issuer coverage. Neither field automatically publishes cards. Human review can be recorded with `reviewed_by` and `reviewed_at`, but this source-gathering task does not require a manual review of every card for the demo.

## Interpret the fields

- **Fees:** decimal strings in the record's currency. Monthly billing is separate from annual billing. Applicability fields explain why an alternative billing field is blank. `annual_conditions` and `foreign_purchase_conditions` must accompany the amount.
- **Rewards:** points, miles and cashback use different units. `rewards_complete` means the captured core earning schedule, not exhaustive benefits or every merchant promotion. Scope and conditions remain attached. No rewards advertised is distinct from confirmed no rewards and from an unresearched schedule.
- **Welcome offers:** status distinguishes observed, personalised, no offer, no offer advertised on the retrieved page and an amount that could not be captured. Never add a referral reward to a new-card bonus.
- **Perks:** selected benefits with relevant caps and spending/enrolment conditions. Not an exhaustive insurance policy. An empty list means no additional perks captured.
- **Eligibility:** partial guidance. `editorial_credit_guidance` is a publisher's recommendation, not an issuer approval requirement; `credit_score_min` remains null.
- **Sources:** `editorial_review` / `editorial_guide`, `official_page` and `official_search_extract` distinguish the evidence. Search extracts can lag. Access dates are not offer effective dates. Sources support the record collectively; this is not a field-level historical audit.
- **Quiz tags and recommendation conditions:** Shuffl's editorial mapping. They do not change current scoring.

## Conditions to preserve during integration

- Freedom Flex's foreign fee changes on 20 September 2026; use the current value until its effective date. Future rotating categories and temporary Lyft earnings must respect their dates.
- United's hotel booking-channel total includes earnings beyond the credit card; `earning_basis` marks this. Do not score it as a pure card multiplier.
- Virgin Reward caps monthly reward-earning spend at the credit limit. Its foreign-fee waiver applies only to specified currencies and locations, not all overseas spending.
- John Lewis pays vouchers, Amazon Barclaycard pays gift cards, and Yonder points have experience-specific redemption values.
- Amex Cashback Everyday UK requires GBP 3,000 annual spending for cashback payment. Lloyds Ultra and Amazon Barclaycard introductory rates differ from ongoing rates.
- Personalised Amex/Yonder offers are not guaranteed amounts. Wells Fargo's selected-channel bonus differs from an older issuer result; Discover Student's NerdWallet offer must not be combined with a different issuer promotion.
- John Lewis has a future terms change on 25 September 2026. A Bank of America student-card source also contains conflicting availability information; retained source caveats explain it.

## Validation

```sh
bundle exec rails test test/models/card_candidate_test.rb
bundle exec rubocop lib/tasks/card_catalogue.rake --cache false
```

The import tests cover all 50 records, market and numeric validation, manual-edit preservation and rollback. Live Cards, wallets, stacks and quiz results remain separate.
