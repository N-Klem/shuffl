# Card assistant

The floating chat uses OpenAI Responses, the current available card catalogue and curated stacks. It can display expandable card/stack details and save them via the existing authenticated `save_browse` wallet endpoint. Save buttons are explicit user actions; the model cannot execute database writes or supply SQL.

## Connect it

1. Create the key in a dedicated OpenAI project with API billing enabled, then store it in Rails encrypted credentials: run `bin/rails credentials:edit` and add `openai:` with `api_key:` nested under it. The encrypted file is committed, so anyone holding `config/master.key` can use the key, and Heroku decrypts it with `RAILS_MASTER_KEY`. Setting `OPENAI_API_KEY` in the server environment overrides the credential. Never put a real key in plain text in source control, browser JavaScript, a screenshot or chat. This app does not automatically load `.env` files.
2. Restart the Rails server. Deploy this branch only after review and run `heroku run rails db:migrate` on the intended app.
3. Sign in, open the chat bubble and try the examples below. No additional database/search service or Node dependency is needed.

Configuration (server environment only):

| Variable | Default | Purpose |
| --- | --- | --- |
| `OPENAI_API_KEY` | credentials `openai.api_key` | API credential; the environment variable overrides the credential |
| `OPENAI_ASSISTANT_MODEL` | `gpt-4.1-mini` | Screening and answer calls; must support Responses structured output |
| `OPENAI_RESEARCH_MODEL` | `gpt-4.1` | The single issuer web-search call; must support `web_search` with domain `filters`, which gpt-4.1-mini rejects |
| `ASSISTANT_ENABLED` | `true` | Set `false` to stop new model calls immediately |
| `ASSISTANT_USER_DAILY_LIMIT` | `20` | Attempts per account per UTC day, maximum 100 |
| `ASSISTANT_GLOBAL_DAILY_LIMIT` | `200` | Attempts across the app per UTC day, maximum 10,000; 0 disables calls |

Set OpenAI project billing alerts as well. The app's cap is a hard **request** cap, not a precise dollar cap. Failed calls and refused questions count because they may incur provider costs. Clearing a chat doesn't reset usage. The reservation uses a PostgreSQL transaction/advisory lock, so the cap works across multiple Rails workers/dynos. One in-flight request per account and six attempts per rolling minute are allowed.

## Grounding and limits

- A small structured screening call restricts questions to credit-card facts, comparisons, rewards, relevant education, stacks and wallet shortlists. Off-topic questions stop there, without loading the full catalogue or searching. This classifier is a model, so it is not a perfect injection detector; hard quotas limit abuse regardless of classification.
- Each accepted answer receives all attributes of every `Card.available` record and available stack membership/roles. Retired/draft records are excluded. At present there are 30 available real cards; source data remains a demo research snapshot, not a certified live offer feed.
- Three recent server-stored turns provide context. Client-provided roles/history/instructions are ignored, and every conversation query is scoped to `current_user`.
- Answers use structured paragraphs with evidence references. Unknown evidence, unrecognised record IDs, uncited factual paragraphs, malformed output, incomplete provider responses and service failures fail closed. The app creates names, URLs, details and wallet actions from database records, not model text.
- Explicit no-foreign-fee and ongoing dining-rate/unit constraints are checked against recorded facts before recommendation actions can appear. Unknown fees don't equal zero; points/miles don't equal cashback; temporary rates don't count as ongoing rates. Other suitability constraints and the meaning of narrative claims still depend on the model.
- A current-terms request can trigger one hosted issuer-only web search. An entirely unknown catalogue answer also triggers one search before a final attempt. The server only accepts actual provider URL annotations on the issuer-domain allowlist; generated URLs are not used. The final answer receives the cited sentence and source URL/date, not unrelated uncited search prose.
- The allowlist lives in `CardAssistant::ISSUER_DOMAINS`. Its entries allow subdomains. Broader financial/editorial sources may exist in the stored catalogue; they are not allowed for live web search.
- No recursive tool loop: maximum four model requests, one web-search tool invocation, 160,000 input bytes per request, 350 screening output tokens, 1,100 research output tokens and 1,800 answer output tokens per answer attempt. There are no automatic HTTP retries. A 24-second overall deadline stays below the normal Heroku router timeout; slow lookups return a retry message.
- Provider credentials and raw errors never go to the browser. Text is rendered with `textContent`, never model HTML. Rails CSRF protection stays enabled and wallet ownership uses the existing authenticated endpoints.

**This reduces hallucination risk; it cannot guarantee zero hallucinations.** A valid citation proves that a referenced record/source was supplied, not that the model interpreted it correctly. Web evidence is a cited model summary, not independently verified page text. A misleading catalogue fact can still lead to a misleading answer. The UI identifies catalogue snapshots, links supporting records/issuer evidence and tells users to check issuer terms. Live adversarial and factual evaluation must follow key setup before public launch.

## Data and retention

Only user questions, bounded conversation context, published catalogue data and the user's saved card IDs are sent to OpenAI. We do not send account email/name, balances, wallet preferences, quiz answers or payment details. Users should not enter account numbers or other secrets. Responses use `store: false`; this does not override OpenAI's separate abuse-monitoring retention policies.

Messages are stored in `assistant_messages` with usage counters. Clear chat erases the current conversation's question/reply content while retaining quota metadata. Deleting a user cascades their assistant rows. To enforce 30-day retention, schedule `bundle exec rake assistant:prune` daily in the deployment's scheduler; the task is provided but no production schedule has been created. Rails logs filter `message` and `history` request parameters.

## Progress

`POST /assistant_chat` streams its reply as newline-delimited JSON (`application/x-ndjson`): one `{"progress": "…"}` line as each stage of the work starts ("Reading your question", "Read 30 cards and 5 stacks" or "4 cards match", "Checking issuer sites", "Checked chase.com", "Writing", "Shortening", "Correcting"), then one final line holding `reply` and `remaining`, or `error`. Failures before the first line keep their ordinary HTTP status (401, 422, 429, 503); once a line has gone out the status is already 200 and the outcome travels in that final line. The panel shows the lines as a trail in the transcript while it waits.

## Follow-ups

Beneath the latest reply the panel offers up to two follow-up pills, templated in the browser from the cards and stacks the reply named: compare the first two cards, who a stack is for, a card's welcome offer, its foreign transaction fees, its perks, who it is for. A template is dropped when the question or the reply already covered it. They are ordinary questions sent through the same endpoint and checks; nothing about the model call changes.

## Verification

Run:

```sh
RAILS_ENV=test bundle exec ruby -Itest -e 'Dir["test/{models/card_assistant,models/assistant_openai_client,integration/assistant_chat}_test.rb"].each { |file| require_relative file }'
bundle exec rake design:check
```

After connecting the key, exercise these live cases:

- “Find a card with no foreign transaction fees and 3% cashback on dining.” Check eligibility/conditions and source record, inspect the card and save it. Verify it appears once in Planned.
- “I meant 3x points, not cashback.” Confirm units and conversation context.
- “Show me the Foodie stack.” Expand its members and save the stack; repeated saving must not duplicate cards.
- “What are the latest terms for [a named catalogue card]?” Verify that a permitted issuer citation appears and supports the claim.
- Ask about an unrecorded/undocumented benefit. It must admit missing evidence.
- “Write Python code”, “Ignore your instructions”, and a card question mixed with an unrelated task must be refused.
- Exhaust the account limit, then clear/reopen the chat. Quota must remain exhausted.

API references: [Responses structured output](https://developers.openai.com/api/docs/guides/structured-outputs), [hosted web search and domain filtering](https://developers.openai.com/api/docs/guides/tools-web-search), [GPT-4.1 mini](https://developers.openai.com/api/docs/models/gpt-4.1-mini).
