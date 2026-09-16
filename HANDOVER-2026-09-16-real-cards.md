# Handover: real US cards and adaptive quiz

Date: 16 September 2026. Workspace: `/Users/noah/shuffl`.
Branch at handover: `codex/us-card-catalogue`.

This records this conversation’s decisions and implementation status. Read `AGENTS.md` and `DESIGN.md` before continuing. This file supplements, rather than replaces, the older `HANDOVER.md` from 14 September.

## Objective and next task

Replace fictional cards with real US cards and recommend coordinated stacks that fit each person's goals. The real catalogue is connected locally. **Next: implement coordinated-stack scoring, then rebuild the pre-made stacks.**

The current recommendation algorithm is NOT a coordinated-stack optimiser. `QuizResponsesController#finish_quiz` walks individually ranked cards, accepting cards until it reaches the fee budget or card-count ceiling. Do not mistake that interim implementation for the approved final product.

## Decisions already agreed with Noah

- Start with **30 US cards**, USD. UK cards removed from the research files and local candidate database. Expanding to 50 is a future decision.
- Existing research is sufficient for the demo. More verification is not a prerequisite. Demo acceptance does not mean every term is verified; retain unknowns and provenance.
- Recommend a **coordinated stack of 1–5 cards**. Never pad a stack to five. Each additional card must contribute useful coverage or benefits beyond existing cards, accounting for fees and complexity.
- Optimise credit-card fit for **the user's ranked goals**, not maximum dollar rewards. Never silently override their priorities.
- Annual-fee tolerance means **combined ongoing fees across the whole stack**, a hard ceiling. Estimated perks cannot justify exceeding it.
- Maximum stack size is authoritative when explicitly chosen. “Recommend for me” should choose 1–5 using fit, contribution and complexity; current ownership is context only in that automatic mode.
- Recommend a fresh stack for the demo, regardless of which specific cards someone owns. Users retain agency through Keep/Swap. Building around their actual My Wallet comes later.
- Welcome bonuses are supplementary. They must not displace a better long-term match. Display captured spending requirements and deadlines alongside bonuses.
- Future bonus feasibility must consider **combined qualifying spending**: the same dollars cannot satisfy several cards' targets at once. Do not imply all bonuses are attainable when their combined requirements exceed the user's spending.
- Keep **exactly ten quiz questions**, with adaptive follow-ups based on prior answers. Every question should inform a recommendation decision.
- Replaced the balance-repayment question with maximum stack size. No authorised-user question for now: we lack a useful established scoring interpretation.
- Airline/hotel cards should only enter automatic recommendations with a relevant named programme preference. Keep them available for manual browsing/swaps.
- Noah explicitly chose **show actual terms; defer dollar reward estimates** until calculation rules support caps, conditions and redemption values. Do not restore the old assumption that every point/mile is worth one cent.
- Existing frontend design is broadly accepted. Keep conventional Rails/ERB/Stimulus; no React, elaborate architecture or seventh page stylesheet.

## Implemented: ten-question quiz

Shared questions, in order:

1. Ranked goals (`priorities`).
2. Current card count (`open_credit_cards`).
3. Credit score/history context (`credit_score`), not an approval prediction.
4. Maximum stack size (`stack_size`): 1, 2, 3, 4, 5, Recommend for me.
5. Ranked spending categories (`spending_priorities`).
6. Monthly card spending (`monthly_card_spend`).
7. Exact combined annual-fee ceiling (`annual_fee_budget`). Presets $0/$100/$300 or custom amount; stored as a decimal string.
8. Student/employment status (`employment_status`).

Final two questions:

| Top goal | Question 9 | Question 10 |
|---|---|---|
| Travel rewards | Named airline/hotel programmes, up to three; No preference is exclusive | International travel frequency |
| Cashback | Consistent versus changing/activated categories | Follow-up about highest-ranked spending category |
| Building credit | First-card versus next-card management preference; student-specific first-card wording | Follow-up about highest-ranked spending category |
| Keeping costs down | Foreign-currency purchases online or abroad | Consistent versus changing/activated categories |
| Useful perks | Ranked benefit preferences | International travel, dining providers, credit providers, or spending follow-up depending on first-ranked benefit |

Spending follow-ups cover grocery retailers, online shopping, dining channels, travel booking, transport, entertainment and bills. Backtracking discards incompatible branch answers. Draft resume validates answers against the current path. Custom budget validation and conditional input live in the controller/view/Stimulus controller. Preset single choices advance automatically; custom budget and multiple choices require Continue/Done.

Definitions are in `Card::QUESTION_POOL`, `FOLLOW_UP_QUESTIONS`, merged `QUIZ_QUESTION_POOL`, and `Card.quiz_questions_for`. Some old question definitions and scoring helpers remain for compatibility. **Most newly collected follow-ups are not yet connected to meaningful scoring.**

`Card.stack_size_limit` currently returns the explicit maximum or 5. Automatic sizing and complexity penalties remain unimplemented.

## Implemented: live catalogue

Migration: `db/migrate/20260916140000_add_real_catalogue_to_cards.rb`.

Added stable `source_key` (unique), country, currency, `catalogue_status`, and JSONB `catalogue_terms`. Annual fee is decimal. Unknown foreign-transaction fees can remain null. Structured research retains rates, units, conditions, benefits, fee treatment, welcome-offer text, eligibility, other research fields, and sources. Unknown network/reward rate is allowed for real cards.

Publication states:

- `legacy`: original records visible before cutover.
- `draft`: imported, hidden from discovery.
- `published`: visible live cards.
- `retired`: hidden from discovery but retained for history.

`Card.available` returns legacy/published records. Local cutover was performed: **30 published real cards, 54 retired fictional cards**, last verified during this session. The 20 UK candidates were deleted locally earlier in this conversation. Nothing was deployed to Heroku.

Import flow:

```sh
bundle exec rails db:migrate
bundle exec rails cards:catalogue:import
bundle exec rails cards:catalogue:stage
bundle exec rails cards:catalogue:publish_demo
```

- Candidate `import` inserts missing source keys without overwriting existing database corrections/review decisions.
- `stage` calls `Card.import_us_candidates!`: non-rejected US candidates become draft cards if new; existing card facts update by stable key, retaining ID and publication state.
- `publish_demo` imports transactionally, publishes the eligible US candidate set and retires legacy/out-of-set cards. Research is not falsely marked reviewed.
- `db:seed` now imports real candidates and publishes the demo; it no longer seeds fictional cards or old stacks.
- `cards:catalogue:export` refreshes Markdown/CSV review exports.

**Important discovery:** the local candidate database contained richer research from yesterday than the original JSON. We imported those corrections and snapshotted all 30 US records back to `data/real_cards/catalogue.json` so fresh installations get the same research. Keep that richer snapshot. Future changes to existing candidate JSON do not automatically update existing database candidates.

See `data/real_cards/README.md` for the operational workflow. `review/unknowns.*` is the original checklist, not an up-to-date gap audit. `review/cards.*` was refreshed from the richer US database.

## Connected surfaces and historical data

- `BrowseCatalogue` uses `Card.available`; no fictional JSON reads.
- Card detail pages show reward rules, units, conditions, bonus requirements, eligibility notes and dated sources. Unknown fees/networks are explicit.
- `ResultsStack` reads cards from the database, preserving saved recommendation IDs even when retired. Published alternatives remain available for manual swaps.
- `WalletDashboard` preserves retired owned/planned entries while excluding retired cards from the add/swap catalogue.
- Wallet create/swap/save endpoints reject newly adding retired cards.
- `Stack.available` excludes empty stacks and stacks containing unavailable cards. Old stack records and memberships survive for historical URLs.
- The homepage hides old fictional stacks and offers a real-card browsing fallback.
- Browse, results and wallet no longer present numerical dollar reward estimates or inferred best-card spending allocations. Fee totals and manual wallet tracking still work.
- Structured benefit arrays are used directly through `Card#perk_list`; do not split real benefits on commas (that broke amounts such as “35,000 points”).

Basic automatic recommendation guards were added:

- Student-tagged real cards require `employment_status == "Student"`.
- Six airline/hotel source keys map to the named `travel_programs` answers.
- Unknown foreign fees do not score as fee-free.

These are only basic filters, not a complete eligibility model or the new stack algorithm. Browsing/manual swaps remain broader, as requested.

## Main code to inspect next

- `app/models/card.rb`: research import/publication, presentation helpers, adaptive questions, existing scoring, basic filters.
- `app/controllers/quiz_responses_controller.rb`: answer validation/pruning, draft flow, interim budget-constrained selection.
- `app/models/results_stack.rb`: results and swap payload.
- `app/models/browse_catalogue.rb`: browsing payload.
- `app/models/wallet_dashboard.rb`: current and retired wallet entries.
- `app/models/stack.rb`: available-stack scope.
- `app/controllers/wallet_items_controller.rb`: available-card restrictions.
- `app/javascript/controllers/{quiz,browse,results,wallet}_controller.js`: budget input and display changes.
- `app/views/cards/show.html.erb`: full terms and sources.
- `db/seeds.rb`, `lib/tasks/card_catalogue.rake`, `data/real_cards/README.md`.

## Remaining work, in order

1. Define explicit, explainable card features/editorial mappings from the real terms and adaptive answers. Keep facts distinct from editorial suitability. Avoid inferring missing benefits, approval cutoffs or point values.
2. Replace individual ranking plus greedy fee filtering with coordinated-stack selection. Respect ranked goals, combined fee ceiling and maximum size; evaluate marginal contributions and overlap; stop when another card adds little value.
3. Implement automatic stack size for Recommend for me, using experience only as context. Respect explicit maxima without forcing that many cards.
4. Wire all adaptive answers into actual decisions (retailer exclusions, category-management preference, portal preference, useful perks, etc.). Handle explicit conditions such as Prime membership without assuming them.
5. Model bonus requirements/feasibility across a stack while keeping ongoing fit primary. Offer text is preserved; structured spending-window calculations are not implemented yet.
6. Review example quiz personas and resulting stacks with Noah. He wants oversight of product decisions, not repeated approval for routine implementation. The decisions above do not need asking again.
7. Rebuild the pre-made stacks using real cards and clear complementary roles. **They are currently hidden, not rebuilt.**
8. Add cash-value estimates only once the calculation policy and supported terms justify them; Noah has accepted their temporary absence.
9. Review/commit changes on the feature branch and deploy only within the user's requested scope. No commits, PR or deployment were created in this conversation.

Manual swaps can currently choose a more expensive card, reflecting the agreed user agency; the automatic recommendation ceiling is enforced. Old completed quiz results retain their saved IDs rather than being silently regenerated.

## Validation completed during this conversation

Last relevant automated run: **47 tests, 1,276 assertions, no failures/errors**.

```sh
bundle exec rails test \
  test/models/live_catalogue_test.rb \
  test/models/card_candidate_test.rb \
  test/models/quiz_paths_test.rb \
  test/integration/quiz_flow_test.rb \
  test/integration/results_stack_test.rb \
  test/integration/wallet_dashboard_test.rb \
  test/integration/card_detail_test.rb

bundle exec rails design:check
git diff --check
```

Design check passed (231 tracked raw hex vs ceiling 250 at that time). JS syntax checks passed for browse/results/wallet; separate budget interaction checks passed.

Browser checked at `http://127.0.0.1:3000`:

- Browsing shows 30 real cards.
- Modal/detail displays captured rates, conditions, bonus spending target/deadline and source links.
- Completed all ten questions on a sample travel path, including custom $150 combined budget and a maximum of three cards.
- Results rendered real cards, actual fees and unavailable dollar estimates.
- Keep disabled that card’s Swap button; browser console had no errors.
- Basic student/programme filters were added after that initial sample result; covered by subsequent automated tests. The sample anonymous result remains local history and may reflect the pre-filter selection.

A local Rails server was started on port 3000 with PID file `/tmp/shuffl-catalogue-server.pid`. It may or may not still be running; check before starting another. Development/test PostgreSQL access and git branch creation required sandbox escalation in this environment. Prior approvals were granted. No external publication occurred.

## Working-tree caution at handover

Changes from this conversation are **uncommitted** on `codex/us-card-catalogue`. Do not reset or overwrite them. A new status check while writing this handover also showed changes not authored in this conversation:

- `app/assets/stylesheets/application.css`
- untracked `card images/`
- untracked `config/card_images.json`
- untracked `public/card-images/`

These may be concurrent/user work. Inspect and preserve them; do not assume the 47-test result validates later changes. Other files may also have concurrent edits. This handover did not modify those assets.

The repository requires feature branches, simple Rails conventions and `DESIGN.md` before visual changes. Do not invent design tokens or alter the existing frontend direction as part of backend work.
