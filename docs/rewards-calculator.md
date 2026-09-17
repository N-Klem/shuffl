# Cashback calculator: first supported version

## Product presentation

Results, Wallet, Browse and card details use `Card#value_profile` to present known
value even when a dollar calculation is not supported. Credit-building cards lead
with their purpose and annual fee; points/miles retain their earning units and
conditions; cashback cards show an ongoing rate until a confirmed estimate exists.
Temporary/introductory reward rows do not become the ongoing headline rate.
Only an explicit `rewards_status: none` identifies a no-rewards product; an empty
schedule alone never proves that. Empty or explicitly absent welcome offers do
not create placeholder rows. Historical wallet bonus tracking is retained.

Unsupported selections show benefits and match reasons without a spending form.
The calculator still returns null for unknown dollar values. Mixed selections
show the estimated **cashback portion before fees**, with the other card benefits
separately and no implied total net value. Failed requests return to known product
facts and a retry explanation, without preserving a stale dollar estimate.

`RewardsCalculator` calculates an ongoing full-year **scenario**, using published
`Card#catalogue_terms`. It does not change recommendations, historical results or
wallet membership. `POST /reward_estimates` is stateless; Wallet calls the same
model directly. The browser supplies card IDs and spending, never trusted rates.

## Supported schedules

The explicitly reviewed mappings are in `config/cashback_rules.json`:

| Card | Modeled rewards |
| --- | --- |
| Chase Freedom Unlimited | Dining 3%; other eligible purchases 1.5% |
| Chase Freedom Rise | Ongoing eligible purchases 1.5% |
| Amex Blue Cash Preferred | Eligible US supermarkets 6% on $6,000/year then 1%; eligible streaming 6%; eligible US gas 3%; other 1% |
| Amex Blue Cash Everyday | Eligible US supermarkets and gas 3%, with separate $6,000/year caps, then 1%; other 1% |
| Capital One Savor / Savor Student | Eligible dining, supermarkets and streaming 3%; other 1% |
| Capital One Quicksilver | Eligible purchases 1.5% |
| Citi Double Cash | Purchase and repayment combined 2%, conditional on confirmed full, on-time repayment |
| Wells Fargo Active Cash | Eligible purchases 2% |

These are nine cards. Rates are read from the published terms, rather than copied
into calculator code. The configuration binds a category/cap mapping to the entire
reviewed reward schedule from `data/real_cards/catalogue.json`. If the published
schedule changes, estimation becomes unavailable until that mapping is reviewed.
Do not regenerate this configuration automatically during catalogue imports.

Portal bookings, drugstores, transit, entertainment and online-retail bonuses are
not modeled in these six inputs; eligible purchases entered in Other get the
reviewed base rate. This can understate earnings. No temporary/introductory rates,
welcome bonuses, cashback match, membership enhancements or conditional credits
are included. The recurring fee is used even when year one has a waiver.

Rotating categories (including Freedom Flex and Discover), Bank of America's
chosen/shared-cap categories and Prime membership rewards remain unavailable.
Points/miles also remain unavailable: there is no default cents-per-point value.
Future support needs a redemption assumption, dated calendar/activation, or
confirmed eligible usage, as appropriate. Do not count multiple bonuses against
the same budget.

## Spending is explicit

Results starts with six zeros and displays the quiz's range as context only. It
does not infer category amounts from rankings or turn a range midpoint into a
budget. Users enter eligible net purchases and confirm category eligibility and
full, on-time repayment before a dollar estimate appears. Zero is an explicit
no-spending input, distinct from unavailable rewards.

The definitions deliberately narrow the old grocery/gas/streaming inputs:

- Supermarkets exclude superstores, warehouse clubs, convenience stores and meal kits.
- US gas excludes stations attached to supermarkets, superstores and clubs. Transit goes in Other.
- Streaming must be eligible for each selected issuer and billed directly.
- Other includes eligible purchases outside the modeled bonus definitions.
- Fees, interest, cash advances, transfers, gift cards and cash equivalents are excluded entirely.

Merchant coding still controls actual eligibility. The confirmation asks the user
to check each selected card's terms. Definitions were checked against
[Amex rewards information](https://www.americanexpress.com/us/rewards-info/retail.html)
and the [Savor product page](https://www.capitalone.com/credit-cards/savor/)
on 2026-09-16. These checks do not certify the whole catalogue as live offers.

After confirmation the total slider scales a stored copy of that spending mix.
It does not repeatedly round and rescale the previous slider step. Category edits
and card swaps require confirmation again. The scenario survives sign-in in a
new versioned session-storage key; old arbitrary presets are not imported.

Wallet preserves previous preference amounts but does not use them until a new
plan is submitted with confirmation and the current input version. Adding an
owned card invalidates confirmation. Notification changes do not confirm spending.
Only Owned cards participate; Planned cards remain outside the calculation.
Results' exploratory budget is not silently written into Wallet preferences.

## Arithmetic and unavailable states

For each category, annual spending is monthly spending × 12. The calculator sorts
reviewed earning segments by rate, assigns spending once, consumes each independent
annual cap, then routes overflow to the next best supported segment. This is exact
for the supported independent caps; shared/quarterly caps need another allocation
model before they can be supported. Calculations use decimal arithmetic and round
only displayed dollar outputs. Contributions are allocated shares, not standalone
card estimates. Independently rounded contributions can differ from the rounded
total by a cent.

The scenario assumes an entire year of unchanged spending and unused caps. It is
not a forecast of remaining rewards this calendar year or an existing account's
remaining cap. Transaction charges and interest are excluded, not presumed paid.

- **Confirmation required:** product facts remain visible; no estimated dollars or allocation displayed.
- **Available:** all selected reward schedules supported. Subtract the sum of
  ongoing annual fees and separately billed monthly fees × 12. Unknown fees leave
  net value unavailable; zero and negative net values remain visible.
- **Partial:** allocate only among supported cashback cards and explicitly label
  that portion. Show fees for the entire selection if known, but do not report a
  net total or treat excluded cards as earning zero.
- **Unavailable:** no supported schedule, no cards, or historical/unpublished
  records. Preserve card details and matching explanations without inventing dollars.

## Validation

Run `bundle exec rails test test/models/rewards_calculator_test.rb
test/integration/reward_estimates_test.rb test/integration/results_stack_test.rb
test/integration/wallet_dashboard_test.rb` (one shell command), plus
`bundle exec rake design:check`.

Tests cover cap thresholds/overflow, routing to another card, independent caps,
duplicate IDs, unknown fees, decimal amounts, partial and unsupported stacks,
changed terms, explicit confirmation, owned/planned isolation and historical
spending migration without overwriting amounts.


## Category spending plan (September 16, 2026)

Results and Wallet now use `SpendingPlan` for the “Which card, when?” guide and
native rewards totals. The original `RewardsCalculator` response remains compatible
for existing clients; new requests use `plan: true` at the same stateless endpoint.
Neither endpoint updates historical quiz results or wallet entries.

Before confirmation, the guide shows earning rates and qualifying conditions,
without inventing spending or annual earnings. Users enter the six category amounts.
With more than one reward programme, each nonzero category requires an explicit
programme choice. The planner ranks eligible rates **only within that programme**.
It routes cap overflow to the next eligible rate/card in the same programme.
Ties retain stack order. The total slider scales the confirmed mix; changing card
selection clears programme choices and requires renewed spending confirmation.

Native support adds Sapphire Preferred, Amex Gold, Venture, Venture X, Autograph,
and BofA Travel Rewards for Students to the nine cashback profiles. Reviewed rules,
programme identities and official source links are in `config/points_rules.json`.
These six official product pages were checked September 16, 2026. Exact captured
reward schedules must still match; edits fail closed until the profile is reviewed.

Each programme has its own annual total. Points/miles are never assigned a dollar
value, combined across programmes, or reduced by dollar fees. All selected cards’
known ongoing fees appear separately. A cashback-only allocation can show its modeled
cashback less all stack fees, including fees on cards not receiving spending. This is
not a valuation of specialist benefits on the other cards. The UI names modeled scope.
Welcome offers, anniversary bonuses, conditional credits and transfer assumptions
remain excluded. No credit-score tracker or prediction is added.

Broad spending categories deliberately do not imply narrower bonuses: Preferred's
supermarket amount uses the in-store base rate, not its online-grocery multiplier;
Gold's broad direct-travel budget uses base earnings and explicitly explains that
flight bonuses need separate amounts. Portal purchases and merchant-specific
bonuses are outside this plan. These are conservative scoped scenarios, not claims
of exhaustive rewards coverage. Shared-cap and rotating schedules still require
additional modeling and data. Unsupported cards retain known benefits and conditions.

Wallet persists programme choices alongside its existing confirmed budget. Only
Owned cards participate; Planned and historical entries remain intact. Saving a
Results shortlist continues to save cards to Planned without copying over a wallet
budget. Existing saved category amounts are not silently reinterpreted as programme
choices: mixed-programme wallets ask users to choose before showing totals.


## Results simplification (later September 16, 2026)

Noah narrowed Results to recommended cards, their suggested uses and captured earning
rates. Results no longer renders or calls the spending planner, collects amounts,
offers programme choices or shows annual totals. The earlier Results planner
behavior above is superseded. Spending planning remains in Wallet.

`QuizCardFit#recommended_uses` provides purchase descriptions from ongoing captured
rules matched to the quiz's ranked spending categories. Results gives each displayed
card an unused suggested role when possible, in recommendation order; everyday rewards
are the fallback. This is a simple usage suggestion, not a claim of maximum monetary
value. It never compares point currencies, invents category amounts, or predicts
annual rewards. Rate conditions stay visible; narrower source wording is preserved.
Keep/Swap/Save still work. Prior session selections migrate to a cards-only session
key; historical quiz records, previous session budgets and wallet preferences are
not overwritten.
