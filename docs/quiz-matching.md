# Quiz matching rules

The quiz has exactly ten questions. Eight are shared; the highest-ranked goal selects two follow-ups. Matching uses the current published Card records and their captured terms. This is an editorial fit model, not a reward-value calculator or an issuer approval model.

## What every question changes

| Question | Decision |
| --- | --- |
| Ranked goals | Goal weights of 5, 3 and 1; repeated goal coverage across cards counts once. |
| Current card count | Management cost for automatic sizing; first-card vs next-card follow-up wording. It never overrides an explicit maximum. |
| Credit profile | Hard suitability filter using recorded guidance. Missing/unknown guidance cannot establish a match; new credit is distinct from damaged credit. |
| Maximum stack size | Hard ceiling of 1–5. Default minimum is two when a suitable pair fits the combined fee budget. Explicitly choosing 1 still returns at most one. Beyond two, extra coverage must justify another card. |
| Ranked spending | Coverage weights of 4, 2.5 and 1.5 and selection of the relevant spending follow-up. |
| Monthly card spending | Relative weight of ongoing fees: lower spending increases the penalty. No dollar payoff or welcome-offer feasibility is inferred. |
| Annual-fee budget | Hard combined ongoing fee ceiling, with cents preserved. Credits and introductory waivers never increase it. |
| College student status | Eligibility for explicitly student-only products. Employment/income is no longer collected or inferred. The existing `employment_status` storage key is retained. |
| Named programmes | Airline/hotel automatic recommendations require a named preference as well as credit suitability. |
| International travel / foreign purchases | Increasing value for known fee-free foreign spending coverage. Unknown fees earn no credit. |
| Category management | Consistent-reward answers penalise activation/choice products; willingness adds a flexible-category benefit once. No assumed quarterly category calendar. |
| First-card / next-card management | Everyday earning, no fee, focused coverage, or avoiding category management. |
| Useful benefits, ranked | Rank-weighted recorded benefits; identical benefits count once across the stack. Airline/hotel benefits lead to the named-programme question. |
| Grocery retailers | Supermarket, superstore, wholesale and online grocery coverage remain distinct. Unconfirmed bonus coverage falls back to recorded everyday purchase rewards. |
| Online shopping | If no Amazon-specific card can qualify for this profile, ask foreign-currency use instead. When a supported Prime Visa can qualify, generic online retail and Amazon-specific earning remain distinct. Prime requires explicit membership and supported credit guidance. |
| Dining channel | Delivery bonus coverage requires explicit captured delivery terms. Restaurant earning alone does not establish it. |
| Travel booking | Portal rewards count only with explicit willingness. No preference does not assume portal use. |
| Transport | Gas, EV charging and transit are separate coverage channels. |
| Entertainment | Streaming and general entertainment are separate; a proprietary ticket portal is not treated as all events. |
| Bills | Rent has no supported earning coverage. Utilities use ordinary eligible-purchase coverage; phone bills may have a recorded bonus. No card acceptance or payment-processing fee assumptions. |
| Dining providers | Only captured, named credits count. Current Gold terms support Uber Cash; they do not establish a Grubhub credit. No/other providers earn no assumed credit. |
| Credit providers | Captured subscription credits require matching existing usage. Retail purchases and “neither” do not imply subscription use. |

Not every answer must produce different cards: identical recommendations can be correct when the catalogue has only one suitable option. The decision inputs, exclusions and explanations must still be meaningful.

## Selection

`QuizCardFit` produces answer-specific coverage features and fee/management penalties. Reward coverage uses bounded editorial tiers relative to each card's own base earning, never a points-to-cash conversion. Temporary offers are ignored. Captured caps/selected-provider conditions reduce bonus coverage and remain in result explanations; this is not a cap utilisation calculation.

`QuizRecommendation` evaluates every combination up to the explicit maximum (or five in automatic mode), discarding stacks above the budget. Each coverage feature contributes only its strongest value across the stack. Card count, fees and management effort are costs. Ties favour fewer cards, then lower fees and stable catalogue order. The selected cards are ordered by additional contribution.

Consequently, a cheaper pair can beat the individually highest-scoring card, two duplicate roles do not pad a stack, and every extra card must improve the combined score. Experience changes the automatic complexity penalty, not the set of goals offered.

Welcome bonuses do not influence selection. We show captured offer text without assuming the user can earn several bonuses with the same spending.

## Results and wallet

Saved result IDs remain unchanged. Eligible alternatives use the same answer-specific scoring. “Why this card?” shows the user's relevant answers alongside recorded categories/conditions or benefits. These are individual match explanations; manual swaps are user choices and may reduce complementarity or exceed the automatic budget. Saved client selections use card IDs rather than unstable catalogue positions.

A no-match result is a catalogue limitation, not a credit rejection. Saving selected cards adds them to Planned and preserves existing wallet items. Browse remains available for deliberate manual selection.

## Verification

- `test/models/quiz_recommendation_test.rb`: channel exclusions, management, benefits, goal/spending order, fees, combined optimisation, no padding and explanations.
- `test/models/quiz_eligibility_test.rb`: strict suitability and explicit conditions.
- `test/models/quiz_paths_test.rb`: all goal/spending/benefit branches have ten unique questions.
- `test/integration/quiz_flow_test.rb`: completion, branching/backtracking, budgets, no match and saving real cards to Planned.


### Minimum shortlist size

New quizzes prefer at least two cards, including “Recommend for me”, so users can
compare and swap options. Existing card ownership does not imply wanting only one
additional card; the explicit maximum controls this. Credit suitability and combined
ongoing annual fees remain hard constraints: when no suitable pair can fit, return
the feasible singleton (or no result), never an unsuitable filler or an over-budget
pair. Stored completed results are not rewritten. The complexity penalty selects
between feasible stacks at or above the minimum, rather than shrinking a feasible
pair to a singleton.
