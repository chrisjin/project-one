# Anchor Board Tactics — Expansion Design Reference

> Implementation-oriented reference for future Codex development.
>
> This document describes extension systems that are **not all part of the locked core rules yet**.
> The authoritative base rules remain in:
>
> - `anchor_core_rules_en.md`
>
> Canonical implementation terminology:
>
> - `BoardPiece` = all movable/scoring combat pieces.
> - `Anchor` = non-BoardPiece structural entity.
> - `AnchorCluster` = one or more orthogonally connected friendly Anchors.
> - In prose, `Piece` may be used as shorthand for `BoardPiece`.
> - **Anchors are not BoardPieces.**
>
> Design priority:
>
> > Expand geometry, connectivity, spatial control, and action efficiency before expanding raw stats.

---

# 1. Expansion Goals

Future systems should preserve the game's current identity:

- orthogonal connectivity;
- Main Anchor binding;
- Supply connection;
- Main Anchor unit-chain damage reduction;
- Secondary Anchor protection;
- 0-HP immortal structures;
- liberties and No-Liberty;
- line attacks;
- blocking;
- spatial cuts;
- local tactical geometry.

New mechanics should generally avoid becoming:

```text
more HP
more damage
larger numbers
```

Prefer mechanics that change:

```text
where a Piece can act
how a path is blocked
how a connection is cut
how a formation moves
which geometry an attack uses
how an Anchor network is supported
```

---

# 2. Core Action Framework for Extensions

The core turn framework is:

```text
Placement
Movement
Action
```

Each turn:

> choose at most two different categories.

The same category cannot be used twice in one turn.

Legal pairs:

```text
Placement + Movement
Placement + Action
Movement + Action
```

Illegal examples:

```text
Placement + Placement
Movement + Movement
Action + Action
```

All future cards and special abilities should explicitly declare which category they consume.

---

# 3. Placement Extensions

Placement currently includes:

- Anchor placement;
- base O placement;
- base D placement;
- future Special BoardPiece cards;
- future effects explicitly tagged `Placement`.

A future implementation should preferably model this as a shared action type:

```rust
enum PlacementAction {
    Anchor { cell: CellId },
    BasePiece { piece_type: BasePieceType, cell: CellId, main_anchor: AnchorId },
    SpecialPieceCard { card_id: CardId, cell: CellId, main_anchor: AnchorId },
}
```

The exact API language is illustrative; the rule distinction is authoritative.

---

# 4. Movement Extensions

Movement includes:

- normal movement;
- Movement-class effect cards.

A Movement effect:

> replaces the normal Movement category for that turn.

Therefore:

```text
normal move + Swap card
```

is illegal because both consume `Movement`.

Candidate Movement effects are listed later.

---

# 5. Action Extensions

Action includes:

- normal attack;
- attack modification;
- connection disruption;
- Anchor interaction effects;
- arbitrary-angle effect rays;
- Rapid Activation;
- other future skill cards.

An Action-class card:

> competes directly with a normal attack.

Example:

```text
Placement Anchor
+
Rapid Activation
```

is legal.

But:

```text
Rapid Activation
+
normal attack
```

is illegal.

---

# 6. Special BoardPiece Card System

Recommended initial structure:

> O and D remain permanently available base BoardPieces.

Special BoardPieces are accessed through a separate random card hand.

This preserves the deterministic base game while introducing run-to-run or match-to-match variation.

---

## 6.1 Recommended Hand Model

Initial candidate:

```text
Special BoardPiece hand size = 3
```

At the start of the player's turn:

> if the hand contains fewer than 3 Special BoardPiece cards, draw until it contains 3.

A played Special BoardPiece card:

- consumes `Placement`;
- creates the specified BoardPiece;
- enters the discard pile after successful use.

---

## 6.2 Draw / Discard / Reshuffle

Recommended lifecycle:

```text
Draw Pile
→ Hand
→ Discard Pile
→ Reshuffle when Draw Pile is empty
```

A used card should **not** immediately return to the draw pile.

This prevents short-period repetition.

---

## 6.3 Duplicate Copies

Decklists may contain multiple copies:

```text
Knight ×3
Clone ×2
Chaos ×2
Disruptor ×1
Refractor ×1
```

Copy count is itself a balance tool.

---

## 6.4 Optional Cycling

Candidate rule:

> Once per own turn, discard one card and draw one replacement.

The discarded card goes to the discard pile.

It does not immediately return to the current draw pile.

This is intended to reduce dead-hand frustration.

---

# 7. Effect Card System

Recommended first implementation:

> Special BoardPiece cards and Effect cards use separate decks and separate hands.

Reason:

- easier balance;
- avoids one card category diluting the other;
- easier debugging;
- easier AI evaluation.

A later merged-deck experiment can still be tested.

---

## 7.1 Effect Card Lifecycle

Default:

```text
Draw Pile
→ Hand
→ Use
→ Discard Pile
→ Reshuffle
```

Very strong cards may use:

```text
Exhaust
```

Meaning:

> remove the card from the match / run after use.

---

## 7.2 Fixed Compensation Effects

`Rapid Activation` should preferably remain:

> a fixed compensation tool rather than a normal random card.

For example, if White continues to receive one Rapid Activation as compensation:

- it should be one-use;
- it should not cycle through a normal deck;
- it should consume `Action`.

---

# 8. Strong-Card Gating

Avoid solving early high-roll problems only through rarity.

A rare card can still create unhealthy early games if it is drawable from turn 1.

Recommended tools:

1. staged draw pools;
2. low copy count;
3. Exhaust;
4. stronger action-category cost;
5. telegraphed setup;
6. weak fallback mode.

---

## 8.1 Staged Draw Pools

Example:

```text
Tier 1:
available from match start

Tier 2:
joins draw pool after enough Anchors have been deployed

Tier 3:
joins draw pool after first Anchor death or first legal 0-HP Piece
```

Important:

> Tier gating should usually control when a card enters the draw pool, not whether a card already in hand is playable.

This prevents dead hands.

---

## 8.2 Unlock Insertion

When a higher-tier group becomes available:

> shuffle newly unlocked cards into the current remaining draw pile.

Do not necessarily wait until the next full reshuffle cycle.

This gives the new tier a chance to appear without guaranteeing immediate access.

---

# 9. Candidate Special BoardPieces

---

# 9.1 N — Knight BoardPiece

Purpose:

> attack important connection nodes using non-O/D geometry.

Candidate rules:

- HP: 2
- Attack: 2
- Normal movement: orthogonal 1
- Attack pattern: Chinese-chess knight
- Uses horse-leg blocking
- Cannot attack Anchors
- May attack BoardPieces only

Horse-leg blocking:

> if the intermediate leg cell contains any board entity, that knight attack direction is blocked.

Any of the following should block the horse leg:

- friendly positive-HP BoardPiece;
- friendly 0-HP BoardPiece;
- enemy BoardPiece;
- friendly Anchor;
- enemy Anchor;
- other blocking entity.

Primary role:

- cut Main Anchor unit-chain damage-reduction paths;
- attack Secondary Anchor connection nodes;
- remove supply-supporting bridge Pieces;
- attack important blockers.

N should not bypass the core "Anchor behaves like an eye" principle by directly attacking Anchors.

---

# 9.2 S — Clone / Two-Cell BoardPiece

Purpose:

> trade score density for spatial control.

Candidate representation:

```text
S s
```

One BoardPiece occupies two orthogonally adjacent cells.

Candidate rules:

- shared HP pool: 2;
- one `BoardPieceId`;
- one Main Anchor binding slot;
- scores only 1 point;
- occupies 2 cells;
- both cells block enemy rays;
- both cells consume spatial area and liberties;
- only main cell `S` propagates friendly connection in the first version;
- only main cell `S` is an attack origin in the first version;
- at legal 0 HP, both cells remain;
- movement should use hinge / inchworm geometry rather than free translation;
- optional random secondary-cell deployment direction.

Important balance note:

> The Main Anchor Supply rule makes S significantly stronger because two occupied cells can seal supply corridors.

Therefore S must be tested specifically on:

- choke points;
- irregular maps;
- narrow corridors;
- large-map front lines.

---

# 9.3 X — Chaos BoardPiece

Candidate rules:

- HP: 2
- Attack: 2
- Movement: orthogonal 1

At the start of its controller's turn:

```text
randomly becomes O-mode or D-mode
```

for that turn.

The result is revealed:

> before the player chooses actions.

This is preferred randomness because it is:

> input randomness, not output randomness.

Avoid:

- random hit chance;
- random damage;
- random critical hits.

---

# 9.4 K — Disruptor BoardPiece

Purpose:

> attack topology rather than HP.

Candidate effect:

- targets BoardPieces only;
- does not directly target Anchors;
- temporarily prevents the target BoardPiece from propagating friendly orthogonal connectivity.

Possible consequences:

- remove Main Anchor unit-chain damage reduction;
- break Secondary Anchor connection;
- break dual-Anchor immortal structures;
- weaken supply-supporting formations.

Because this creates temporary topology state:

> K should be a second-phase feature, not an early prototype feature.

---

# 9.5 R — Refractor BoardPiece

Purpose:

> turn friendly Anchors into directional ray-control infrastructure.

Candidate rule:

When R's attack ray first reaches a friendly active Anchor:

```text
choose 90° left
or
choose 90° right
```

The ray then continues.

Maximum:

```text
one reflection per attack
```

This mechanic is relatively complex and should be tested later.

---

# 10. Candidate Movement Effect Cards

These cards consume:

```text
Movement
```

---

## 10.1 Swap

Choose two orthogonally adjacent friendly positive-HP BoardPieces.

Exchange their positions.

Recommended restrictions:

- no Anchors;
- no 0-HP BoardPieces.

Strategic use:

- change O/D attack geometry;
- repair a connection role;
- expose or hide a blocker;
- alter horse-leg geometry;
- change which Piece is on a supply corridor.

---

## 10.2 Formation Push

Candidate:

Move a small connected local formation by one cell.

Example:

```text
A B .
```

becomes:

```text
. A B
```

Requirements:

- all destination cells legal;
- no overlap;
- topology recalculates after movement.

---

## 10.3 Clone Rotation

Specific to S.

Rotate or hinge the secondary cell around the main S cell.

Consumes:

```text
Movement
```

---

## 10.4 Shockwave

Candidate:

Fire an off-board ray.

The first enemy positive-HP BoardPiece hit:

> is pushed one cell in the ray's incoming direction.

Restrictions:

- cannot push Anchors;
- cannot push 0-HP BoardPieces;
- if the destination is illegal or occupied, the displacement fails;
- the card is still consumed.

The exact mapping from continuous ray direction to grid push direction must be defined before implementation.

---

## 10.5 Teleport / Blink

Free unrestricted teleportation is not recommended.

Problem:

```text
teleport ranged Piece
+
attack in same turn
```

can bypass:

- front lines;
- supply geometry;
- terrain;
- blocking;
- local positioning.

If a limited teleport is eventually added:

> the teleported BoardPiece should not be allowed to attack that turn.

Alternative:

> teleport consumes both Movement and Action.

---

# 11. Candidate Action Effect Cards

These consume:

```text
Action
```

---

## 11.1 Rapid Activation

Target:

> an Anchor deployed this turn.

Effect:

> activate it immediately.

This remains a candidate fixed compensation effect.

---

## 11.2 Trajectory Shift

Choose a mature O or D.

For this one attack:

```text
O attacks using D geometry
D attacks using O geometry
```

Range remains:

```text
6 grid steps
```

unless explicitly changed by the card.

---

## 11.3 Armor-Piercing Shot

Make one attack.

For that attack:

> ignore the target BoardPiece's 1-point Main Anchor unit-chain damage reduction.

This does **not** disable:

- Main Anchor Supply;
- Secondary Anchor protection;
- legal 0-HP survival.

---

## 11.4 Friendly-0HP Wall-Piercing Shot

Make one attack.

For this attack only:

> the first friendly 0-HP BoardPiece may be treated as transparent.

Friendly Anchors still block.

Enemy board entities still block normally.

---

## 11.5 Connection Disruption Ray

Fire an off-board ray.

The first enemy BoardPiece hit:

> temporarily stops propagating friendly orthogonal connection.

No direct damage.

Potential impact:

- Main Anchor unit-chain reduction;
- Secondary Anchor structure;
- protected 0-HP structures;
- supply-supporting formations.

Exact duration should be explicit, for example:

> until the target's controller begins their next turn.

---

## 11.6 AnchorCluster Shutdown

Must not directly select any enemy Anchor anywhere on the board.

Candidate geometry:

> fire an off-board ray.

Resolution:

- enemy BoardPieces block the ray;
- if the first relevant target is an enemy Anchor, affect that Anchor's entire AnchorCluster.

Candidate effect:

> that AnchorCluster temporarily cannot count as a Secondary AnchorCluster.

Recommended duration:

> until that AnchorCluster owner's next turn begins.

It still:

- exists;
- blocks rays;
- may remain a Main Anchor;
- may still provide Main Anchor unit-chain damage reduction if the physical Main Anchor connection remains valid.

---

# 12. Anchor Interaction Principle

Future mechanics must preserve the structural role of Anchors.

Core design rule:

> **A special ability should not freely bypass the board and directly dismantle an Anchor.**

If an effect can directly affect an Anchor or AnchorCluster:

> there should normally be a geometric path that enemy BoardPieces can block.

Avoid:

```text
select any enemy Anchor
disable it
```

Prefer:

```text
ray
path
first blocker
Anchor only if actually reached
```

This preserves the idea that Anchors behave more like:

> protected eyes / structural cores

than like globally targetable RTS buildings.

---

# 13. Arbitrary-Angle Effect Rays

Some advanced effect cards may use arbitrary-angle rays.

These should be separate from base O / D attacks.

Base attacks remain:

```text
O = orthogonal
D = 45° diagonal
range = 6
```

Advanced effect rays may use:

> continuous geometry from a board-edge entry point.

---

## 13.1 Grid Traversal

Recommended implementation:

> Supercover grid traversal.

Every grid cell touched or crossed by the continuous ray belongs to the ray path.

Do not use a traversal rule that can visually pass through a cell corner while skipping the cell.

---

## 13.2 Corner Cases

If a ray exactly passes through a grid vertex and touches multiple cells at the same distance:

> all touched cells count as part of the path.

If multiple blockers are reached at the same ray distance:

> they jointly block the ray.

Do not allow floating-point precision exploits to "thread the corner."

Prefer deterministic rational / integer-friendly traversal if practical.

---

# 14. Map Expansion

The standard map remains:

```text
7×7
```

Base O / D range:

```text
6
```

This means the 7×7 game behaves almost exactly like the original full-line-range design.

Larger maps may be:

```text
9×9
11×11
13×13
19×19
```

while base range remains:

```text
6
```

This creates a natural scale transition.

---

## 14.1 Expected Scale Behavior

### 7×7

```text
range 6 ≈ board-wide
```

Gameplay:

- dense;
- tactical;
- limited invasion space;
- almost no true rear area.

### 9×9 / 11×11

Gameplay begins to create:

- safe rear cells;
- local attack zones;
- limited flanking.

### 13×13

Gameplay can support:

- left / center / right sectors;
- true supply corridors;
- forward Anchors.

### 19×19

Gameplay may support:

- strategic fronts;
- multiple local battles;
- large invasion regions;
- real territorial separation.

---

# 15. Irregular Maps and Terrain

Recommended map representation:

> rectangular storage + playable-cell mask + terrain metadata.

Example conceptual mask:

```text
# # . . . # #
# . . . . . #
. . . # . . .
. . . # . . .
# . . . . . #
# # . . . # #
```

Possible terrain classes:

1. normal passable terrain;
2. impassable + ray-blocking;
3. impassable + ray-transparent;
4. future special terrain.

Important:

> off-board and impassable cells are not liberties.

Map data should also define:

> Anchor-valid cells.

The standard 7×7 `B2–F6` rule should not be hard-coded into generic map logic.

---

# 16. Supply Cuts on Large / Irregular Maps

The Main Anchor Supply rule becomes significantly more important on irregular maps.

Recall:

> a BoardPiece must be orthogonally connected to its physical Main Anchor through friendly units and passable empty cells.

Enemy board entities and impassable terrain block Supply.

Therefore:

- bridges;
- gates;
- narrow corridors;
- tunnels;
- islands;
- mountain passes;

become real strategic chokepoints.

A BoardPiece whose supply is cut:

> dies immediately.

No grace turn.

This can create large cascades and should be considered when designing maps.

---

# 17. No-Liberty Interaction with Expansion Systems

The authoritative ordering remains:

```text
1. resolve Main Anchor Supply
2. remove supply-disconnected BoardPieces
3. recalculate topology
4. resolve No-Liberty
5. repeat until stable
```

Important implementation rule:

> Deaths caused by Supply happen before No-Liberty and may open liberties.

But:

> BoardPieces that die as part of the same No-Liberty judgment cannot retroactively create liberties that save Anchors from that same judgment.

Anchor survival at zero liberties:

- if, after Supply resolution, an Anchor remains orthogonally connected in the same friendly group to at least one legal dual-Anchor-protected BoardPiece, it survives with that protected zero-liberty structure;
- only when the entire friendly connected group contains no such protected BoardPiece do we check pure Anchor / AnchorCluster zero-liberty death.

This rule should remain centralized inside the rules engine.

Do not reimplement it separately in card logic.

---

# 18. PvE Enemy Architecture

PvE should not force every enemy to use exactly the player's Anchor rules.

Recommended enemy ecosystems:

1. Mirror Anchor Faction
2. Anchorless Wild BoardPieces
3. Nests
4. Boss Cores
5. Parasites
6. Neutral hazards

---

# 19. Mirror Anchor Faction

Uses almost the full player rules:

- Main Anchor binding;
- Supply;
- Main Anchor unit-chain reduction;
- Secondary Anchor protection;
- legal 0-HP Pieces;
- cards;
- special BoardPieces.

Best for:

- elite encounters;
- rival factions;
- advanced AI;
- PvP-like bosses.

Purpose:

> test understanding of the full core rules.

---

# 20. Anchorless Wild BoardPieces

These behave more like traditional tactical enemies.

Candidate simplification:

- no Main Anchor;
- no Supply;
- no Main Anchor damage reduction;
- no Secondary Anchor protection;
- HP reaches 0 → death.

They can still:

- occupy cells;
- block rays;
- affect liberties;
- cut player supply routes.

Use cases:

- swarm encounters;
- tower-defense-style PvE;
- early campaign teaching.

---

# 21. Nests

A Nest is a stationary spawning structure.

Candidate behavior:

```text
every N turns:
spawn one wild BoardPiece
```

A Nest is not necessarily an Anchor.

It may:

- have HP;
- be immobile;
- be ray-blocking;
- spawn based on local empty cells.

The player must decide whether to:

- fight spawned enemies;
- advance toward the Nest;
- cut its surrounding defenders.

---

# 22. Boss Cores

Boss Cores may behave differently from normal Anchors.

Candidate systems:

- summon waves;
- open / close terrain;
- generate temporary walls;
- fire special rays;
- spawn sub-cores;
- transform map geometry.

Still preserve:

> protected-core geometry.

Avoid:

> arbitrary direct-target damage that ignores defenders.

---

# 23. Parasite Enemies

Late-game experimental enemy type.

Concept:

> an enemy that benefits from the player's Anchor network.

Possible mechanics:

- gains reduction when connected to player structure;
- gains a special survival mode if touching two player Anchor regions;
- forces player to cut their own connectivity.

Purpose:

> make a large, highly connected Anchor network occasionally dangerous.

---

# 24. PvE Run / Campaign Deck Growth

Recommended structure:

> cards are gradually acquired during a run.

Do not start a run with the full card catalog.

---

## 24.1 Post-Battle Reward

Recommended:

```text
show 3 cards
choose 1
or Skip
```

Skip is important.

The player should not be forced to dilute the deck.

---

## 24.2 Reward Category Choice

Possible post-battle structure:

```text
choose:
Special BoardPiece reward
or
Effect reward
```

Then show three candidates from that category.

This gives the player some deck-direction control.

---

## 24.3 Upgrades

Instead of always adding more cards:

> upgrade existing cards.

Examples:

- Swap gains slightly more flexibility;
- Knight gains deployment maturation;
- a ray gains a second mode;
- a weak card gains a fallback mode.

Avoid turning upgrades into large raw-number inflation.

---

## 24.4 Card Removal

Camps, shops, or events may allow:

> remove one card from the run deck.

This is essential for deck refinement.

---

## 24.5 Active Deck + Reserve

Recommended late-run structure:

```text
Collected Pool
→ Active Deck
+ Reserve
```

Example target sizes:

```text
Special BoardPiece Active Deck: ~8–10 cards
Effect Active Deck: ~8–10 cards
```

The player may own more cards overall, but only the Active Deck participates in battle draws.

Reserve swapping should happen only at controlled locations:

- camp;
- shop;
- boss checkpoint;
- explicit preparation node.

Avoid unlimited free sideboarding before every fight.

---

# 25. PvE Stage Progression

One possible structure:

### Act 1

Focus:

- base O / D;
- Supply;
- liberties;
- simple wild enemies;
- simple maps.

### Act 2

Add:

- N;
- S;
- Nests;
- choke-point maps;
- movement cards.

### Act 3

Add:

- Mirror Anchor factions;
- K;
- AnchorCluster shutdown;
- stronger map topology.

### Late Game

Add:

- R;
- arbitrary-angle rays;
- 13×13 / 19×19 maps;
- Boss Cores;
- Parasites;
- advanced dual-Anchor structures.

---

# 26. Randomness Philosophy

Preferred:

> randomness generates the situation; player decisions resolve it deterministically.

Good randomness:

- random card hand;
- random Special BoardPiece draw;
- Chaos Piece mode revealed before acting;
- random Clone secondary-cell direction;
- random artillery angle revealed before use.

Avoid:

- hit chance;
- critical hit chance;
- random damage;
- random miss;
- hidden randomness deciding the result after the player commits.

---

# 27. Local Testing Architecture

Before strong AI:

> build local Human vs Human hot-seat.

Recommended separation:

```text
GameState
RulesEngine
LegalActionGenerator
ActionResolver
PlayerController
UI
```

---

## 27.1 RulesEngine Responsibilities

The rules engine should be authoritative for:

- board occupancy;
- Main Anchor binding;
- Anchor capacity;
- Anchor activation;
- AnchorCluster construction;
- Supply;
- Main Anchor unit-chain connection;
- damage reduction;
- Secondary Anchor protection;
- legal 0-HP state;
- liberties;
- No-Liberty;
- ray tracing;
- action categories;
- repetition rule;
- scoring.

Card code should call into this logic, not duplicate it.

---

## 27.2 Recommended Pure Functions

Useful conceptual APIs:

```text
get_legal_actions(state)
apply_action(state, action) -> new_state
stabilize(state) -> new_state
trace_ray(state, ray_spec)
compute_supply(state, piece_id)
compute_anchor_clusters(state, player)
compute_friendly_groups(state, player)
compute_liberties(state, group_id)
```

Implementation language may differ.

---

# 28. Debug UI

For each BoardPiece, expose:

- PieceId;
- type;
- HP;
- maturity;
- MainAnchorId;
- Main Anchor alive?;
- Supply valid?;
- unit-chain connected to Main Anchor?;
- damage reduction active?;
- Secondary AnchorCluster IDs;
- legal 0-HP protection?;
- friendly group ID;
- liberty count.

For each Anchor, expose:

- AnchorId;
- HP;
- activation state;
- AnchorClusterId;
- bound BoardPiece count;
- deployment index;
- zero-liberty status;
- protected-group membership.

This debug information is extremely valuable for rule validation.

---

# 29. Required Replay / Logging Support

The local test build should support:

- complete action log;
- replay;
- undo in debug mode;
- exportable game record;
- deterministic random seed;
- state hash.

Goal:

> if turn 31 is reported illegal or inconsistent, the exact state must be reproducible.

---

# 30. Automated Rule Tests

At minimum, build fixed-position tests for:

### Anchor

- physical Main Anchor death cascade;
- binding capacity;
- AnchorCluster merge;
- AnchorCluster split;
- activation timing;
- inactive Secondary Anchor rejection.

### Supply

- open empty-space supply;
- supply through friendly BoardPieces;
- enemy wall cuts supply;
- impassable terrain cuts supply;
- moving Main Anchor cuts supply;
- mass immediate death after supply cut.

### Damage Reduction

- unit-chain Main Anchor connection;
- empty-space-only supply gives no reduction;
- Secondary-only connection gives no reduction.

### 0-HP

- valid Secondary Anchor protection;
- invalid same-Cluster protection;
- inactive Secondary rejection;
- loss of Secondary connection;
- Main Anchor death;
- Supply cut.

### No-Liberty

- one-Anchor zero-liberty group dies;
- external-Main-Anchor Pieces die by Supply before No-Liberty;
- Secondary Anchor may gain liberties after Supply deaths;
- bare Anchor at zero liberties dies;
- dual-Anchor protected zero-liberty structure survives;
- same-No-Liberty deaths cannot retroactively save Anchor.

### Rays

- friendly positive-HP BoardPiece transparent;
- friendly 0-HP BoardPiece blocks;
- friendly Anchor blocks;
- first enemy entity is target;
- kill does not continue through target;
- range exactly 6;
- range 7 illegal on larger board.

### Special Geometry

- Knight horse-leg;
- Clone occupancy;
- arbitrary-angle Supercover corner cases.

---

# 31. AI Development Order

Recommended progression:

```text
Random Legal AI
→ Heuristic AI
→ MCTS
```

---

## 31.1 Random Legal AI

Purpose:

- find illegal-state bugs;
- discover crash positions;
- stress test stabilization;
- run large numbers of games.

Do not use Random AI to judge balance quality.

---

## 31.2 Heuristic AI

Possible evaluation features:

- surviving BoardPiece count;
- positive-HP count;
- protected 0-HP count;
- Anchor count;
- deployed Anchor quota;
- exposed 1-HP Anchors;
- Main Anchor loading risk;
- number of threatened Main Anchors;
- supply vulnerability;
- number of liberties;
- protected dual-Anchor structures;
- card hand value;
- current attack threats.

---

## 31.3 MCTS

Likely useful once:

- special card draws;
- large branching;
- uncertain future hands;
- movement effects;

become important.

Prefer:

> complete turn as one search edge

rather than one atomic category action per edge if branching becomes too large.

---

# 32. AI-vs-AI Metrics

Track:

- Black win rate;
- White win rate;
- draw rate;
- average turns;
- median turns;
- terminal BoardPiece count;
- terminal Anchor count;
- legal 0-HP count;
- supply-cut deaths;
- No-Liberty deaths;
- Main Anchor cascade deaths;
- O usage;
- D usage;
- N usage;
- S usage;
- X usage;
- card play frequency;
- card draw frequency;
- win rate conditional on drawing / playing each card.

For large maps also track:

- average combat distance;
- average number of active fronts;
- average number of supply cuts;
- Anchor usage by map sector.

---

# 33. Recommended Development Sequence

Do not implement every extension at once.

Recommended sequence:

```text
Phase 1
Core rules
O / D
7×7
local hot-seat
```

Then:

```text
Phase 2
Supply cuts
No-Liberty finalization
range = 6
9×9 / 11×11 map support
```

Then:

```text
Phase 3
N
S
Special BoardPiece hand
draw / discard / reshuffle
```

Then:

```text
Phase 4
Swap
Formation Push
Rapid Activation
AnchorCluster Shutdown
```

Then:

```text
Phase 5
X
arbitrary-angle effect rays
Supercover traversal
```

Then:

```text
Phase 6
K
R
PvE wild enemies
Nests
Boss Cores
large irregular maps
```

---

# 34. Current Extension Priorities

Highest-value near-term extensions:

1. rule-engine stabilization;
2. Supply / No-Liberty automated tests;
3. configurable map masks;
4. fixed O/D range 6;
5. 9×9 / 11×11 experiments;
6. N;
7. S;
8. Special BoardPiece hand;
9. Swap;
10. PvE wild enemy prototype.

Lower-priority experimental systems:

- K;
- R;
- unrestricted large-map PvP;
- Parasites;
- complex terrain;
- large deckbuilding meta systems.

---

# 35. Design Constraints to Preserve

Future development should preserve these principles unless deliberately changed:

1. Anchors are structural cores, not generic BoardPieces.
2. BoardPieces bind to physical Main Anchors.
3. Supply is distinct from damage-reduction connection.
4. Supply can pass through empty terrain.
5. Main Anchor unit-chain reduction cannot pass through empty terrain.
6. Supply loss kills immediately.
7. Secondary Anchors do not replace Main Anchor Supply.
8. Same AnchorCluster cannot count as both Main and Secondary protection.
9. Protected 0-HP BoardPieces remain positional objects.
10. Friendly positive-HP BoardPieces are transparent to friendly normal rays.
11. Friendly 0-HP BoardPieces and friendly Anchors block friendly normal rays.
12. Base O / D range is 6 on every map size.
13. Special Anchor-affecting abilities should normally require blockable geometry.
14. Input randomness is preferred over output randomness.
15. Placement / Movement / Action remains the core action economy.
16. No-Liberty must be resolved at group level after Supply resolution.
17. Same-No-Liberty deaths cannot retroactively save Anchors.
18. Anchors survive a zero-liberty structure when still orthogonally connected to legal dual-Anchor-protected BoardPieces.
19. Pure Anchor / AnchorCluster zero-liberty death is checked only after the connected group contains no legal protected BoardPiece.

---

# 36. Open Questions for Future Playtesting

Still experimental:

- exact S movement geometry;
- whether S's secondary cell should propagate connection;
- whether N should keep attack 2;
- whether K disruption duration is too strong;
- whether AnchorCluster Shutdown duration is too strong;
- whether effect-card hand size should be 2 or 3;
- whether free once-per-turn cycling is needed;
- whether larger maps need more than 12 Anchors;
- whether 19×19 is strategically rich or too slow;
- whether some large-map terrain should modify range;
- whether large-map PvP should remain symmetric;
- whether PvE Mirror Anchor factions should obey every player rule;
- whether Active Deck / Reserve should be used immediately or only after the card pool grows.

These should remain data-driven and should not be hard-coded prematurely.

---

# 37. Summary for Codex

When implementing future expansion systems:

> Treat the core rules engine as authoritative and extensions as declarative modifiers.

Prefer:

```text
Card says what category it consumes
Card says what temporary modifier it creates
RulesEngine resolves topology
RulesEngine resolves Supply
RulesEngine resolves No-Liberty
RulesEngine resolves final legal state
```

Avoid:

```text
Card code manually kills pieces
Card code manually recomputes clusters
UI decides legality
Special unit script duplicates core connection rules
```

The intended architecture is:

```text
extension input
→ core rule resolution
→ stable GameState
```

This separation is the most important requirement for keeping future BoardPieces, cards, maps, PvE enemies, and large-board variants maintainable.
