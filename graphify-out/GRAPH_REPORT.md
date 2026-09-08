# Graph Report - shuffl  (2026-09-08)

## Corpus Check
- 93 files · ~51,049 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 162 nodes · 151 edges · 61 communities (6 shown, 25 thin omitted)
- Extraction: 90% EXTRACTED · 9% INFERRED · 1% AMBIGUOUS · INFERRED: 14 edges (avg confidence: 0.86)
- Token cost: 381,811 input · 0 output

## Community Hubs (Navigation)
- Animation Skill Docs
- Card Interaction JS
- Rails Models
- Rails Controllers
- Apple Design & Motion Skills
- Rails App Config
- Application Job Base
- Deploy & Ops Config
- Devise Users Migration
- Create Cards Migration
- Create Wallet Items Migration
- Create Quiz Responses Migration
- Create Messages Migration
- Wallet Items Unique Index Migration
- Application Helper
- Cards Helper
- Quiz Responses Helper
- Wallet Items Helper
- Stimulus Application Controller
- I18n Locale Files
- App Icon Assets
- Animation Vocabulary Skill
- Agent Cowork Instructions
- Bundler Audit Ignore List
- 400 Error Page
- 404 Error Page
- Unsupported Browser Error Page
- 422 Error Page
- 500 Error Page
- README Overview
- Rubocop Omakase Style

## God Nodes (most connected - your core abstractions)
1. `Building Animations (Skill)` - 11 edges
2. `Emil Kowalski's Animation & Design Philosophy` - 8 edges
3. `renderWallet()` - 7 edges
4. `ApplicationRecord` - 7 edges
5. `Apple Design (Skill)` - 7 edges
6. `Improving Animations (Skill)` - 7 edges
7. `ApplicationController` - 6 edges
8. `moveCard()` - 6 edges
9. `showDetail()` - 6 edges
10. `Design Engineering (Emil Kowalski Skill)` - 6 edges

## Surprising Connections (you probably didn't know these)
- `Write Swift (Skill)` --semantically_similar_to--> `Building Animations (Skill)`  [INFERRED] [semantically similar]
  .agents/skills/write-swift/SKILL.md → .agents/skills/animate/SKILL.md
- `Expo Animation Recipes` --shares_data_with--> `Rubber-Banding Resistance Formula`  [INFERRED]
  .agents/skills/animate-expo/RECIPES.md → .agents/skills/apple-design/SKILL.md
- `"You Don't Need Animations" (Emil Kowalski article)` --conceptually_related_to--> `Emil Kowalski's Animation & Design Philosophy`  [INFERRED]
  .agents/skills/find-animation-opportunities/SKILL.md → .agents/skills/emil-design-eng/SKILL.md
- `Shuffl App Icon (SVG)` --semantically_similar_to--> `Shuffl App Icon`  [INFERRED] [semantically similar]
  public/icon.svg → public/icon.png
- `CardsController` --inherits--> `ApplicationController`  [EXTRACTED]
  app/controllers/cards_controller.rb → app/controllers/application_controller.rb

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Motion Skill Suite Cross-Delegation** — _agents_skills_animate_skill, _agents_skills_animate_expo_skill, _agents_skills_review_animations_skill, _agents_skills_improve_animations_skill, _agents_skills_find_animation_opportunities_skill, _agents_skills_prototype_skill, _agents_skills_pick_ui_library_skill [EXTRACTED 1.00]
- **Shared Emil Kowalski Design Philosophy Foundation** — _agents_skills_emil_design_eng_skill, _agents_skills_emil_design_eng_skill_emil_kowalski_animation_philosophy, _agents_skills_review_animations_standards, _agents_skills_improve_animations_audit, _agents_skills_animate_skill [EXTRACTED 1.00]
- **Shared Easing Curve Token System** — _agents_skills_animate_skill_shared_easing_tokens, _agents_skills_animate_skill, _agents_skills_animate_recipes, _agents_skills_review_animations_standards, _agents_skills_improve_animations_audit [INFERRED 0.90]
- **Rails Default Static Error Pages (shared design system)** — public_400_error_page, public_404_error_page, public_406_unsupported_browser_error_page, public_422_error_page, public_500_error_page [INFERRED 0.95]
- **Shuffl Deployment & Dependency-Security Configuration** — config_database_config, config_deploy_kamal_config, config_bundler_audit_ignore_list [INFERRED 0.70]

## Communities (61 total, 25 thin omitted)

### Community 0 - "Animation Skill Docs"
Cohesion: 0.22
Nodes (22): Animation Recipes (Web), Building Animations (Skill), Shared Easing Curve Tokens (--ease-out / --ease-in-out / --ease-drawer), Rubber-Banding Resistance Formula, Sonner API Reference, Working With Sonner (Skill), Sonner (Toast Library), Design Engineering (Emil Kowalski Skill) (+14 more)

### Community 1 - "Card Interaction JS"
Cohesion: 0.16
Nodes (16): buildCardEl(), cardVisualSelector, deselectCard(), enterPage(), hasOwnAnimation(), moveCard(), pageTransitionedMains, readWallet() (+8 more)

### Community 2 - "Rails Models"
Cohesion: 0.15
Nodes (7): ApplicationRecord, Base, Card, Message, QuizResponse, User, WalletItem

### Community 3 - "Rails Controllers"
Cohesion: 0.17
Nodes (6): ApplicationController, Base, CardsController, PagesController, QuizResponsesController, WalletItemsController

### Community 4 - "Apple Design & Motion Skills"
Cohesion: 0.25
Nodes (9): Expo Animation Recipes, Building Animations in Expo (Skill), React Native Reanimated, Apple Design (Skill), Designing Audio-Haptic Experiences (WWDC), Designing Fluid Interfaces (WWDC 2018), The Details of UI Typography (WWDC 2020), Momentum Projection Formula (+1 more)

### Community 5 - "Rails App Config"
Cohesion: 0.50
Nodes (3): Application, Shuffl, Shuffl::Application

## Ambiguous Edges - Review These
- `Kamal Deploy Configuration` → `robots.txt`  [AMBIGUOUS]
  config/deploy.yml · relation: references

## Knowledge Gaps
- **30 isolated node(s):** `ApplicationHelper`, `CardsHelper`, `QuizResponsesHelper`, `WalletItemsHelper`, `savedTheme` (+25 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 103 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **25 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Kamal Deploy Configuration` and `robots.txt`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **Why does `Building Animations (Skill)` connect `Animation Skill Docs` to `Apple Design & Motion Skills`?**
  _High betweenness centrality (0.011) - this node is a cross-community bridge._
- **Why does `Apple Design (Skill)` connect `Apple Design & Motion Skills` to `Animation Skill Docs`?**
  _High betweenness centrality (0.010) - this node is a cross-community bridge._
- **Why does `Motion / Framer Motion` connect `Animation Skill Docs` to `Apple Design & Motion Skills`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **What connects `ApplicationHelper`, `CardsHelper`, `QuizResponsesHelper` to the rest of the system?**
  _30 weakly-connected nodes found - possible documentation gaps or missing edges._