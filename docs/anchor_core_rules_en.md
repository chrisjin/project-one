# Anchor Board Tactics: Core Rules (Current Version)

> This document contains only the current core rules and the extension interfaces that have already been decided.  
> New BoardPiece types, effect cards, random draws, PvE systems, and experimental maps belong in the separate Expansion Design document.
>
> To keep the rules independent from the final game setting, the term **Anchor** is used throughout.
>
> **Canonical implementation terminology:** `BoardPiece` is the code-facing term for all movable/scoring combat pieces. In prose, **Piece** may be used as shorthand. **Anchors are not BoardPieces.**

---

# 1. Game Overview

- Two players: Black and White.
- Black moves first; players then alternate turns.
- The standard board is **7×7**.
- Players deploy Anchors and BoardPieces and fight through:
  - line attacks;
  - Main Anchor connections;
  - Secondary Anchor protection;
  - liberties and encirclement;
  - supply-line cuts;
  - spatial control.
- At game end:
  - each surviving positive-HP BoardPiece scores 1 point;
  - each legally surviving 0-HP BoardPiece also scores 1 point;
  - Anchors do not score.
- Higher BoardPiece count wins.
- Equal BoardPiece counts are a draw.
- There is currently no komi.

---

# 2. Board, Maps, and Range

## 2.1 Standard Board

The standard competitive board is:

```text
7 × 7
```

Columns:

```text
A B C D E F G
```

Rows:

```text
1 2 3 4 5 6 7
```

Each cell may contain at most one board entity.

---

## 2.2 Anchor Area on the Standard Board

On the standard 7×7 board, Anchors may only occupy the inner 5×5 area:

```text
B2–F6
```

Therefore:

- Anchors may not occupy columns A/G;
- Anchors may not occupy rows 1/7;
- after moving, an Anchor must still remain inside `B2–F6`.

BoardPieces may occupy any cell on the 7×7 board.

---

## 2.3 Larger and Irregular Maps

Future maps may be:

- 9×9;
- 11×11;
- 13×13;
- 19×19;
- irregularly shaped;
- partially impassable;
- equipped with map-specific Anchor-valid cells.

On non-standard maps:

> **The map data defines which cells may contain Anchors.**

`B2–F6` is only the rule for the standard 7×7 map.

---

## 2.4 Base Ray BoardPieces Have Range 6

Base O / D BoardPieces have a maximum attack range of:

```text
6 grid steps
```

This value does not automatically increase on larger maps.

Therefore, on a 7×7 board:

> Range 6 is effectively equivalent to the old “continue to the board edge” rule.

On larger maps:

> O / D BoardPieces no longer have board-wide range.

This naturally creates:

- front lines;
- rear areas;
- safe zones outside enemy range;
- local battlefields;
- strategic depth.

---

# 3. BoardPiece Types and Base Stats

Current base BoardPiece / Anchor types:

1. Anchor
2. Orthogonal BoardPiece O
3. Diagonal BoardPiece D

Suggested notation:

| Symbol | Meaning |
|---|---|
| `BA` | Black Anchor |
| `WA` | White Anchor |
| `BO` | Black Orthogonal BoardPiece |
| `BD` | Black Diagonal BoardPiece |
| `WO` | White Orthogonal BoardPiece |
| `WD` | White Diagonal BoardPiece |
| `BO0 / BD0` | Black 0-HP BoardPiece |
| `WO0 / WD0` | White 0-HP BoardPiece |

---

## 3.1 Anchor

Each physical Anchor:

- HP: **3**
- has no normal attack;
- moves 1 orthogonal cell;
- may bind up to **3 currently surviving BoardPieces**;
- each player may deploy at most **12 physical Anchors total per game**;
- destroyed Anchors do not refund the deployment limit;
- may be orthogonally adjacent to friendly Anchors;
- may form an Anchor Cluster.

---

## 3.2 Orthogonal BoardPiece O

- HP: **2**
- Attack: **2**
- Move: 1 orthogonal cell
- Attack directions:
  - up
  - down
  - left
  - right
- Maximum range: **6 grid steps**

---

## 3.3 Diagonal BoardPiece D

- HP: **2**
- Attack: **2**
- Move: 1 orthogonal cell
- Attack directions:
  - up-left
  - up-right
  - down-left
  - down-right
- Maximum range: **6 grid steps**

> O and D differ only in attack geometry. Their movement is identical.

---

# 4. Anchor System

This chapter defines:

- Main Anchors;
- binding capacity;
- Anchor activation;
- Anchor Clusters;
- Main Anchor supply connection;
- Main Anchor unit-chain damage reduction;
- Secondary Anchor Clusters;
- 0-HP survival;
- Main Anchor death cascades.

---

## 4.1 Every BoardPiece Binds to One Physical Main Anchor

When deployed, a BoardPiece must choose one surviving friendly physical Anchor with an available binding slot as its:

> **Main Anchor**

The binding:

- can never be changed;
- is not changed when the Main Anchor moves;
- is not changed when the Main Anchor joins or leaves a Cluster;
- always points to the specific physical Anchor, not the Cluster.

---

## 4.2 Each Physical Anchor Binds at Most 3 Surviving BoardPieces

Example:

```text
A1
├─ O1
├─ D1
└─ O2
```

A1 is full.

When a bound BoardPiece truly dies:

> that binding slot becomes available again.

---

## 4.3 Main Anchor Death

If a BoardPiece's physical Main Anchor is destroyed:

> **the BoardPiece dies immediately.**

This is true regardless of:

- remaining HP;
- other connected Anchors;
- Secondary Anchor protection;
- 0-HP immortal status.

---

# 5. Anchor Activation and Anchor Clusters

## 5.1 New Anchors Enter Inactive

An Anchor deployed this turn is:

> inactive by default.

It still immediately:

- occupies its cell;
- blocks rays;
- participates in friendly orthogonal connectivity;
- participates in Anchor Cluster geometry;
- participates in liberty calculations.

However, an inactive Anchor:

> **cannot serve as a valid Secondary Anchor protection source.**

Normally it activates:

> at the start of its controller's next turn.

---

## 5.2 Friendly Anchors May Be Orthogonally Adjacent

For example:

```text
A—A
```

or:

```text
A—A—A
```

are legal.

---

## 5.3 Orthogonally Connected Friendly Anchors Form One Anchor Cluster

All friendly Anchors connected by orthogonal adjacency form:

> one **Anchor Cluster**.

Example:

```text
A—A—A
```

contains 3 physical Anchors but counts as:

```text
1 Anchor Cluster
```

for protection-source purposes.

---

## 5.4 Cluster Capacity Still Adds Physical Anchors

Each physical Anchor still provides:

```text
3 BoardPiece binding slots
```

So:

| Physical Anchors | Total Binding Capacity | Protection Sources |
|---:|---:|---:|
| 1 | 3 | 1 |
| 2 | 6 | 1 |
| 3 | 9 | 1 |
| n | 3n | 1 |

---

## 5.5 Clusters Merge and Split Dynamically

After Anchor movement:

- orthogonally adjacent friendly Anchors merge immediately into one Cluster;
- broken Anchor adjacency may split one Cluster into several.

Cluster changes immediately affect:

- Secondary Anchor protection;
- 0-HP survival;
- immortal status.

---

# 6. Two Types of Main Anchor Connection

The rules distinguish:

1. **Supply Connection**
2. **Unit-Chain Connection**

They serve different purposes.

---

## 6.1 Supply Connection: Determines Whether a BoardPiece Can Exist

For BoardPiece M, treat these cells as traversable:

- passable empty cells;
- friendly BoardPieces;
- friendly Anchors.

Treat these as blocked:

- enemy units;
- impassable terrain;
- off-board space.

If M can reach its specific Main Anchor through an **orthogonally connected path** of traversable cells:

> M has Main Anchor supply connection.

---

## 6.2 If Supply Is Cut, the BoardPiece Dies Immediately

After any action resolves, if a BoardPiece can no longer reach its specific Main Anchor through friendly units plus passable empty terrain:

> **the BoardPiece dies immediately.**

There is no grace turn.

This is recalculated after:

- placement;
- movement;
- attacks;
- effect cards;
- terrain changes;
- unit deaths.

---

## 6.3 Invading a Fully Enclosed Enemy Area

If an enemy completely encloses an area and a BoardPiece's Main Anchor is outside that enclosure:

> a normally deployed BoardPiece inside the enclosure immediately dies for lack of supply.

Therefore a normal invasion of a fully sealed region generally requires:

> **deploying a new Anchor inside the region first.**

This is a natural consequence of the supply rule, not a separate placement restriction.

---

## 6.4 Unit-Chain Connection: Grants 1 Damage Reduction

If BoardPiece M can connect to its specific Main Anchor through:

> a continuous orthogonal chain of friendly units,

then M gains:

```text
1 damage reduction
```

Friendly BoardPieces and friendly Anchors may carry the chain.

**Empty cells do not carry damage-reduction connection.**

---

## 6.5 Supply Connection Is Not Damage Reduction

Example:

```text
Main Anchor . . . BoardPiece
```

The BoardPiece:

- has supply;
- survives;
- does not have a continuous unit chain;
- therefore has **no damage reduction**.

---

# 7. Secondary Anchors and 0-HP Survival

## 7.1 Main Anchor Cluster

The Cluster currently containing the BoardPiece's physical Main Anchor is:

> that BoardPiece's **Main Anchor Cluster**.

---

## 7.2 Secondary Anchor Cluster

A BoardPiece may use another friendly Anchor Cluster as a Secondary Anchor Cluster if:

- it connects to that Cluster through an orthogonal network of friendly units;
- that Cluster is different from its Main Anchor Cluster;
- that Cluster contains at least one active Anchor.

---

## 7.3 Secondary Anchors Do Not Grant Damage Reduction

Connection only to a Secondary Anchor:

> does not grant the Main Anchor's 1-point damage reduction.

Damage reduction comes only from:

> a continuous friendly-unit chain to the BoardPiece's own physical Main Anchor.

---

## 7.4 Conditions for 0-HP Survival

A BoardPiece reduced to 0 HP remains on the board only if all are true:

1. the BoardPiece is mature;
2. its physical Main Anchor is still alive;
3. it still has Main Anchor supply connection;
4. it connects through friendly units to at least one valid Secondary Anchor Cluster;
5. the Secondary Anchor Cluster is distinct from the Main Anchor Cluster;
6. the Secondary Anchor Cluster is active.

If all are true:

> the BoardPiece remains as a 0-HP BoardPiece.

---

## 7.5 0-HP BoardPiece State

A legal 0-HP BoardPiece:

- continues occupying its cell;
- still scores 1 point;
- still participates in friendly orthogonal connectivity;
- blocks both players' rays;
- cannot move;
- cannot attack.

---

## 7.6 Losing Protection

A 0-HP BoardPiece dies immediately if:

- its Main Anchor dies;
- Main Anchor supply is cut;
- its Secondary Anchor is destroyed;
- its Secondary Anchor connection is cut;
- the Main and Secondary Clusters merge into one Cluster.

A removed 0-HP BoardPiece does not revive later.

---

# 8. Liberties and No-Liberty States

## 8.1 Friendly Orthogonal Group

Friendly board entities connected by orthogonal adjacency form one friendly group.

A group may contain:

- positive-HP BoardPieces;
- legal 0-HP BoardPieces;
- Anchors;
- immature BoardPieces;
- inactive Anchors.

---

## 8.2 Liberties

A friendly group's liberties are:

> all distinct orthogonally adjacent passable empty cells.

Impassable terrain and off-board space are not liberties.

---

## 8.3 The Supply Rule Always Resolves Before the No-Liberty Rule

Whenever an action, attack, movement, placement, or death changes board topology:

> **Resolve Main Anchor Supply first, then resolve No-Liberty.**

The order is:

1. Recalculate every BoardPiece's supply connection to its specific Main Anchor.
2. Every BoardPiece that has lost supply **dies immediately and is removed**.
3. Recalculate Anchor Clusters, friendly groups, and liberties after those deaths.
4. Only then perform No-Liberty resolution.
5. If No-Liberty causes further deaths, recalculate supply and liberties again.
6. Repeat until the board is stable.

Therefore:

> **A BoardPiece that has already lost Main Anchor supply cannot be “saved” by a later No-Liberty outcome.**

---

## 8.4 No-Liberty Rule

After the Supply Rule has fully resolved, check every remaining friendly group.

If a group has:

```text
liberties = 0
```

perform one No-Liberty judgment on the **entire current zero-liberty group**.

The key rule is:

> **Within the same No-Liberty judgment, ordinary BoardPieces may not be removed first and then have the newly empty cells retroactively save Anchors that belonged to that same zero-liberty group.**

No-Liberty is therefore a group-level judgment on the current topology, not a sequential “remove one piece, recalculate, save the rest” process.

### BoardPieces

A BoardPiece in a zero-liberty group:

- survives if it has valid dual-Anchor protection;
- otherwise dies from No-Liberty.

Valid dual-Anchor protection still requires:

1. the BoardPiece is mature;
2. its physical Main Anchor is alive;
3. Main Anchor Supply still exists;
4. it connects through friendly units to at least one valid Secondary Anchor Cluster;
5. the Secondary Cluster is different from the Main Anchor Cluster;
6. the Secondary Cluster is active.

### Anchors

An Anchor has no independent immunity to No-Liberty. However, Anchor survival is checked **at the level of the entire friendly orthogonally connected group after the Supply Rule has fully resolved**.

Use the following order:

1. Resolve the Supply Rule first and remove every BoardPiece that has lost supply to its Main Anchor.
2. Recalculate the remaining friendly orthogonal groups.
3. For an Anchor, if its entire friendly connected group still contains at least one:
   > **legal dual-Anchor-protected BoardPiece**

   and that Anchor remains orthogonally connected to those protected BoardPieces,
   the Anchor remains as part of that zero-liberty surviving structure.
4. Only if the Anchor's entire friendly connected group:
   > **contains no legal zero-liberty immortal BoardPiece**

   do we perform the pure-Anchor / Anchor-Cluster zero-liberty check.
5. If that remaining pure Anchor / Anchor Cluster still has:
   ```text
   liberties = 0
   ```
   it dies from No-Liberty.
6. If the Supply Rule removed surrounding BoardPieces first and thereby opened passable empty cells around the Anchor, the Anchor now has liberties and never reaches the pure-Anchor zero-liberty death check.

Therefore:

> **An Anchor survives at zero liberties whenever, after Supply resolution, it is still orthogonally connected within the same friendly group to at least one legal dual-Anchor-protected BoardPiece.**

And:

> **The pure Anchor / Anchor Cluster no-liberty death check is performed only after the entire friendly connected group no longer contains any legal zero-liberty immortal BoardPiece.**

This naturally separates one-eye and two-eye structures:

- one Anchor Cluster with no valid dual-Anchor-protected BoardPiece → the zero-liberty group dies;
- valid dual-Anchor-protected BoardPieces still orthogonally connected to the relevant Anchors → the protected zero-liberty structure survives.

---

## 8.5 Example A: One Internal Anchor, All Internal BoardPieces Bound to It — Entire Group Dies

```text
XXXXXXX
X PPP X
X P A X
X PPP X
XXXXXXX
```

where:

- `X` = enemy board entity;
- `P` = friendly BoardPiece;
- `A` = the only friendly Anchor;
- every `P` is bound to internal `A` as its Main Anchor.

### Step 1: Supply Rule

Every `P` can still reach `A` through internal friendly units and/or passable cells.

Therefore:

> no BoardPiece dies from Supply.

### Step 2: No-Liberty Rule

The entire:

```text
P + A
```

structure is one friendly group with:

```text
liberties = 0
```

There is only one Anchor Cluster.

Therefore none of the `P` pieces can have a valid Secondary Anchor Cluster, so none has valid dual-Anchor protection.

Result:

> **the entire zero-liberty group dies, including every P and A.**

You may not first remove the `P` pieces and then claim that their cells became empty and gave `A` new liberties.

Those `P` pieces died as part of the same No-Liberty judgment, and that result cannot retroactively change that same judgment.

This is the current rule's:

> **one-Anchor / one-eye dead structure.**

---

## 8.6 Example B: Internal A Is Only a Secondary Anchor; the P Pieces' Main Anchor Is Outside — P Dies from Supply, A Survives

Use the same geometry:

```text
XXXXXXX
X PPP X
X P A X
X PPP X
XXXXXXX
```

but now:

- `A` is not the Main Anchor of the `P` pieces;
- every `P` is bound to a physical Main Anchor outside the enclosure;
- internal `A` was only serving as a Secondary Anchor.

When the enemy completes the enclosure:

### Step 1: Supply Rule

Every `P` loses all supply paths to its external Main Anchor.

Therefore:

> **all P pieces die immediately from loss of Supply.**

This happens before No-Liberty resolution.

The board first becomes:

```text
XXXXXXX
X ... X
X . A X
X ... X
XXXXXXX
```

### Step 2: Recalculate Liberties

`A` now has passable empty cells around it.

Therefore:

> `A` is no longer a zero-liberty group.

No No-Liberty death occurs.

Final result:

> **all P pieces die, but the internal Secondary Anchor A survives.**

This demonstrates that:

> the ordering of Supply Rule before No-Liberty can materially change the result.

---

## 8.7 Example C: Bare Anchor Completely Surrounded

```text
XXX
XAX
XXX
```

There are no BoardPieces to remove during Supply resolution.

`A` itself forms a pure Anchor group with:

```text
liberties = 0
```

Therefore:

> **A dies directly from No-Liberty.**

---

## 8.8 Example D: Two Independent Anchor Clusters + Valid Dual-Anchor Protection — Zero-Liberty Structure Survives

```text
XXXXXXXXX
X A-P-P X
X P-P-P X
X P-P-A X
XXXXXXXXX
```

Assume:

- the two `A` cells are not orthogonally adjacent and therefore form two distinct Anchor Clusters;
- every relevant `P` still has a living physical Main Anchor;
- Main Anchor Supply remains valid;
- each protected `P` connects through friendly units to another active Anchor Cluster;
- therefore those `P` pieces have valid dual-Anchor protection.

Even if the entire structure has:

```text
liberties = 0
```

the protected `P` pieces survive.

Because the protected BoardPiece structure remains legally alive, and both Anchors are still orthogonally connected to those protected BoardPieces after Supply resolution:

> both Anchor Clusters belong to a friendly connected group that still contains legal zero-liberty immortal BoardPieces, so both remain as part of that surviving structure.

This is the current ruleset's closest analogue to:

> **a living two-eye group in Go.**

The important point is:

> The No-Liberty rule no longer directly says “count two Anchor Clusters and survive.”  
> It asks whether the BoardPieces already have valid protection under the Main / Secondary Anchor rules.


## 8.9 Current Rule Is Fixed for Implementation, but May Change Later

For the current implementation, use this standard resolution order:

```text
1. Main Anchor Supply
2. Main Anchor death cascade
3. Recalculate topology
4. No-Liberty
5. Recalculate until stable
```

This removes the previous ambiguity about pure Anchors at zero liberties:

> **Resolve immediate Supply deaths first and recalculate. Then perform a group-level No-Liberty judgment on the remaining zero-liberty groups. BoardPieces that die in that same No-Liberty judgment cannot retroactively create liberties that save Anchors from that judgment.**

This is now the rule to implement and test.

However:

> **The rule may still be revised later if playtesting shows undesirable behavior for invasions, life-and-death structures, or encirclement.**


# 9. Turn Structure

Each player turn consists of:

1. start-of-turn processing;
2. up to two different action categories, with automatic turn end after the second;
3. immediate full resolution after each action.

---

## 9.1 Start of Turn: BoardPiece Maturation

BoardPieces deployed on that player's previous turn become mature.

Mature BoardPieces:

- may attack;
- may qualify for 0-HP survival.

---

## 9.2 Start of Turn: Anchor Activation

Anchors deployed on that player's previous turn activate automatically if still inactive.

---

## 9.3 Start of Turn: Stabilization

Recalculate until stable:

- Main Anchor existence;
- Main Anchor supply;
- Main Anchor unit-chain connection;
- Anchor Clusters;
- Secondary Anchors;
- 0-HP BoardPieces;
- liberties;
- death cascades.

---

# 10. Three Action Categories: Choose Two

The three action categories are:

1. **Placement**
2. **Movement**
3. **Action**

A player may use at most:

> two different categories per turn.

Using the second category automatically ends the turn after that action fully resolves.

---

## 10.1 Placement

One Placement may be:

- deploy an Anchor;
- deploy base O;
- deploy base D;
- if special BoardPiece cards are enabled, play one special BoardPiece card and deploy that BoardPiece;
- use another future effect explicitly classified as Placement.

A player may not use Placement twice in the same turn.

---

## 10.2 Movement

One Movement may be:

- make one normal movement with one movable friendly unit;
- if movement-effect cards are enabled, play one Movement-class effect card.

Therefore:

```text
normal move + movement card
```

is illegal in the same turn because both consume Movement.

---

## 10.3 Action

One Action may be:

- make one normal attack;
- play one Action-class / attack-class effect card;
- use another future effect explicitly classified as Action.

The current:

> **Rapid Activation**

effect may be classified as an Action.

Therefore:

```text
deploy Anchor + Rapid Activation
```

is legal, but no normal attack may also be made that turn.

---

## 10.4 Legal Category Pairs

```text
Placement + Movement
Placement + Action
Movement + Action
```

---

## 10.5 Illegal Repeats

```text
Placement + Placement
Movement + Movement
Action + Action
```

---

## 10.6 Order Is Free

For example:

```text
Movement → Attack
```

or:

```text
Attack → Placement
```

are both legal.

However:

> after each individual action, the entire board must fully resolve before the second action is taken.

---

# 11. Placement Rules

## 11.1 Deploying a BoardPiece

A BoardPiece may be deployed onto any legal, passable, empty cell.

A valid Main Anchor must be chosen.

Immediately after deployment:

> Main Anchor supply connection is checked.

If no valid supply path exists:

> the BoardPiece dies immediately.

---

## 11.2 New BoardPieces

A newly deployed BoardPiece:

- immediately occupies its cell;
- immediately participates in connectivity and blocking;
- may use the turn's remaining Movement category;
- may not make a normal attack on the deployment turn;
- matures at the start of its controller's next turn;
- cannot survive at 0 HP while immature.

---

## 11.3 Deploying an Anchor

On the standard 7×7 board:

> Anchors may only be deployed in `B2–F6`.

On expansion maps:

> the cell must be marked Anchor-valid by the map.

A new Anchor begins inactive.

---

# 12. Current Fixed Effect: Rapid Activation

Current test effect:

> **Rapid Activation**

Effect:

> Choose an Anchor deployed this turn; it activates immediately.

It is classified as:

```text
Action
```

Therefore:

```text
Placement: Anchor
Action: Rapid Activation
```

uses both categories for that turn.

---

# 13. Movement Rules

## 13.1 BoardPieces

A positive-HP BoardPiece:

```text
moves 1 orthogonal cell
```

The destination must be:

- passable;
- empty.

A 0-HP BoardPiece cannot move.

---

## 13.2 Anchors

An Anchor:

```text
moves 1 orthogonal cell
```

and must remain on an Anchor-valid cell for that map.

After moving an Anchor, immediately recalculate:

- Anchor Clusters;
- Main Anchor supply;
- Main Anchor damage-reduction connection;
- Secondary Anchors;
- 0-HP survival;
- liberties.

Moving one Anchor may therefore cause many bound BoardPieces to:

> die immediately because their supply path is cut.

---

# 14. Attack Rays and Blocking

## 14.1 O

O attacks along:

```text
↑ ↓ ← →
```

up to:

```text
6 grid steps
```

---

## 14.2 D

D attacks along:

```text
↖ ↗ ↙ ↘
```

up to:

```text
6 grid steps
```

---

## 14.3 Friendly Positive-HP BoardPieces Are Transparent

Friendly positive-HP BoardPieces:

> do not block friendly normal attack rays.

---

## 14.4 Friendly 0-HP BoardPieces Block

Friendly 0-HP BoardPieces:

> block friendly rays.

---

## 14.5 Friendly Anchors Block

Friendly Anchors:

> always block friendly normal attack rays.

This is true regardless of:

- HP;
- activation state.

---

## 14.6 The First Enemy Board Entity Is the Target

When a ray reaches the first enemy unit:

- the ray stops;
- that unit becomes the target.

Enemy:

- positive-HP BoardPieces;
- 0-HP BoardPieces;
- Anchors;

all follow this rule.

---

## 14.7 Terrain

The standard empty 7×7 map has no additional terrain.

Future maps may define terrain that is:

- impassable and ray-blocking;
- impassable but ray-transparent;
- otherwise special.

Those details belong to map extensions.

---

# 15. Damage

Base BoardPiece attack:

```text
2
```

---

## 15.1 Anchors

Anchors have no ordinary damage reduction:

```text
3 → 1 → destroyed
```

---

## 15.2 BoardPiece Damage Reduction from Main Anchor Unit Chain

If a BoardPiece has a continuous friendly-unit chain to its own physical Main Anchor:

```text
2 incoming damage → 1 actual damage
```

Otherwise it takes the full:

```text
2 damage
```

If HP reaches 0:

- it remains only if Section 7 is satisfied;
- otherwise it dies.

---

# 16. Main Anchor Death Cascade

When a physical Main Anchor is destroyed:

1. remove that Anchor;
2. immediately kill every BoardPiece bound to it;
3. recalculate Anchor Clusters;
4. recalculate Main Anchor supply;
5. recalculate damage-reduction connections;
6. recalculate Secondary Anchors;
7. recalculate 0-HP BoardPieces;
8. recalculate liberties;
9. continue cascading until stable.

One attack never continues through a destroyed first target to hit a second target in the same attack.

Any newly opened ray matters only for a later action.

---

# 17. Stabilization Order After Every Action

Recommended implementation order:

1. execute the action;
2. if it is an attack, resolve direct damage;
3. remove units that are definitely dead;
4. resolve Main Anchor death cascades;
5. recalculate Anchor Clusters;
6. check every BoardPiece's Main Anchor supply connection;
7. remove BoardPieces whose supply has been cut;
8. recalculate Main Anchor unit-chain damage reduction;
9. recalculate Secondary Anchors;
10. remove 0-HP BoardPieces that lost protection;
11. recalculate liberties;
12. resolve no-liberty BoardPieces;
13. if deaths changed topology again, repeat from step 4;
14. continue until stable;
15. only then allow the turn's second category.

Anchor no-liberty behavior follows the fixed Section 8 sequence: resolve Supply first, then No-Liberty, and repeat until stable.

---

# 18. Total Anchor Deployment Limit

Each player may deploy at most:

```text
12 physical Anchors per game
```

Destroyed Anchors do not refund this number.

Current observation:

> On the standard 7×7 board, players often do not need all 12 Anchors.

The limit currently mainly prevents:

> endlessly deploying Anchors as cheap shields.

On larger maps, the same 12-Anchor limit may naturally become:

> a cap on strategic bases / forward footholds.

---

# 19. Repeated Positions Are Forbidden

The exact same complete game state may not occur again.

The complete state should include at least:

- unit positions;
- unit types;
- HP;
- maturation states;
- Anchor activation states;
- every BoardPiece's physical Main Anchor;
- Anchor Cluster partition;
- total Anchors deployed by each player;
- hand / extension state if enabled;
- side to move;
- categories already used this turn.

If an action would recreate a previously seen complete state:

> that action is illegal.

---

# 20. Pass, End of Game, and Scoring

## 20.1 Pass

A player may take no actions for the turn.

---

## 20.2 End of Game

The game ends after:

```text
Pass → Pass
```

by the two players consecutively.

---

## 20.3 Scoring

Every legally surviving BoardPiece scores:

```text
1 point
```

including:

- positive-HP BoardPieces;
- legal 0-HP BoardPieces.

Anchors score:

```text
0
```

Higher score wins; equal score is a draw.

---

# 21. Core Rules Quick Reference

1. Standard board: 7×7; Black moves first.
2. Each turn choose at most two different categories from **Placement / Movement / Action**.
3. Anchor: 3 HP. Base BoardPiece: 2 HP / 2 attack.
4. O attacks orthogonally; D attacks on 45° diagonals.
5. O / D base maximum range is **6 grid steps**.
6. On 7×7, range 6 is effectively board-wide; larger maps still keep range 6.
7. Every BoardPiece permanently binds to one physical Main Anchor.
8. Each physical Anchor binds at most 3 surviving BoardPieces.
9. Each player may deploy at most 12 Anchors total.
10. A new Anchor is inactive this turn and normally activates next own turn.
11. Orthogonally adjacent friendly Anchors form one Anchor Cluster.
12. A Cluster counts as one protection source regardless of its number of physical Anchors.
13. Every BoardPiece must maintain an orthogonal supply path through friendly units and passable empty cells to its physical Main Anchor.
14. If Main Anchor supply is cut, the BoardPiece **dies immediately**.
15. Only a continuous friendly-unit chain to the Main Anchor grants 1 damage reduction; empty-space supply does not.
16. A valid Secondary Anchor Cluster must be a different active Cluster.
17. Secondary Anchors provide 0-HP survival, not damage reduction.
18. A legal 0-HP BoardPiece still occupies space, scores, connects, and blocks rays, but cannot move or attack.
19. After Supply resolves, an Anchor that remains orthogonally connected to a legal dual-Anchor-protected BoardPiece survives with that zero-liberty structure; only when the entire friendly connected group contains no such BoardPiece do we check pure Anchor / Anchor Cluster zero-liberty death.
20. Friendly positive-HP BoardPieces are transparent to friendly normal rays.
21. Friendly 0-HP BoardPieces and friendly Anchors block friendly normal rays.
22. The first enemy unit blocks the ray and becomes the target.
23. Destroying a Main Anchor immediately kills all BoardPieces bound to it.
24. A normal BoardPiece cannot successfully invade a fully sealed area if its Main Anchor remains outside; a new internal Anchor is normally required.
25. Future special-BoardPiece cards still consume Placement; movement-effect cards consume Movement; attack/skill-effect cards consume Action.
26. Future maps may be larger, irregular, and terrain-based, but base range 6 does not automatically scale with map size.
27. Consecutive Passes end the game; surviving BoardPiece count determines the winner.

---

# 22. Confirmed Extension Interfaces

## 22.1 Special BoardPiece Cards

Future special BoardPieces:

> are deployed through the Placement category.

O / D may remain permanently available base BoardPieces.

---

## 22.2 Movement Effect Cards

Examples:

- swap two BoardPieces;
- formation push;
- clone rotation;
- shockwave displacement.

These consume:

> **Movement**

rather than granting an extra action.

---

## 22.3 Action Effect Cards

Examples:

- Rapid Activation;
- attack-mode conversion;
- armor piercing;
- Anchor Cluster shutdown;
- off-board ray effects.

These consume:

> **Action**

and therefore compete with a normal attack.

---

## 22.4 Arbitrary-Angle Effect Rays

A limited number of future effects may use:

> arbitrary-angle continuous rays with a Supercover grid-traversal rule.

This is an extension mechanic.

Base O / D BoardPieces keep their clear discrete directions and range 6.

---

# 23. Core Details Still Under Test

The following are not fully locked:

2. Whether standard PvP remains permanently 7×7 or adds 9×9 / 11×11 competitive maps.
3. How larger maps define Anchor-valid cells.
4. Whether the 12-Anchor cap remains unchanged on very large maps.
5. Whether long-term first/second-player compensation or komi is needed.

These should be tested through local hot-seat play and AI self-play.
