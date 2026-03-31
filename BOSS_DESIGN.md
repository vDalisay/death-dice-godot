# Death Dice — Boss Design Document

## Overview

**Boss encounters** appear in the final (7th) stage of each loop, replacing the standard stage target. Bosses use tavern props around the dice tray to create dynamic, interactive hazards that interfere with the player's dice rolling and scoring mechanics.

Bosses are **not enemies in the traditional sense**—they don't have health bars. Instead, they are **environmental challenges** where the player must hit a final score target while the boss actively manipulates the field with prop mechanics. Victory against a boss grants a large gold bonus and progression to the next loop.

---

## Boss Design Template

Each boss entry follows this structure:
- **Boss Name** — The tavern character/prop personified
- **Theme** — Narrative context (who is this? why are they here?)
- **Core Mechanic(s)** — The prop-based interactions and hazards
- **Implementation Notes** — How to integrate with existing dice/scoring systems
- **Balance Hints** — Difficulty tuning and counterplay
- **Loop Unlock** — Which loops introduce this boss (Loop 1, 2, 3+)

---

## Boss Roster

### 1. The Chain Smoker (Cigarette Boss)
**Loop Unlock:** Loop 1, Stage 7

**Theme:**  
A grizzled tavern regular nursing an endless cigarette. As the player rolls, the smoker rhythmically taps ash from the cigarette onto the dice tray.

**Core Mechanic: Ash Cloud**
- **Before each reroll opportunity**, the boss "taps out" ash randomly onto N squares of the dice tray (e.g., 3–5 squares depending on loop).
- Any die currently occupying an ash square has its face hidden/obscured for the **next roll turn only**.
- The hidden die rolls normally but the player **cannot see what it landed on**; instead a "???" placeholder is shown.
- The ash clears after one full roll cycle (all rerolls complete or bank).
- **Counterplay**: Strategic rerolls to move dice away from ash zones before they get hidden.

**Implementation Notes:**
- Extend `DiceTray` to track ash zones (array of grid positions).
- Modify `DieButton` rendering to show obscured face placeholder when in ash zone.
- Ash zones persist only until the next bank/bust event.
- Visual: gray/smoke particle effect over affected dice.

**Balance Hints:**
- Loop 1: 3 ash zones, appear after turn 2 onwards.
- Loop 2: 4–5 ash zones, appear every turn.
- Loop 3+: 5–6 zones, can stack between turns.
- Counterplay: Rerolling to empty zones is always an option; encourages tactical positioning.

---

### 2. The Bartender (Beer Glass Boss)
**Loop Unlock:** Loop 1, Stage 7 (alternate to Chain Smoker in some encounters)

**Theme:**  
The tavern bartender, steadying themselves and accidentally sloshing beer across the table. Dice land in sticky patches and refuse to move until picked up.

**Core Mechanic: Sticky Beer Patches**
- **When the boss "spills"** (every turn or on a reroll trigger), 2–4 patches of sticky beer are placed on random grid squares.
- Any die that lands on a sticky patch is **stuck in place** and **cannot be selected for reroll**.
- Stuck dice remain frozen on their current face until the player banks or busts.
- **Counterplay**: Accept the stuck die's value, or deliberately keep other dice and reroll around it.

**Implementation Notes:**
- Extend `DiceTray` to track sticky patches (grid positions + duration).
- Modify `DieButton` to become non-interactive when in a sticky zone.
- Visual: wet/glossy amber overlay on affected squares.
- Patches persist for the entire turn (reset on new turn/bank/bust).

**Balance Hints:**
- Loop 1: 2 patches per spill, 1 spill per turn (during reroll phase).
- Loop 2: 3 patches per spill, 2 spills per turn (before and during rerolls).
- Loop 3+: 4 patches, can chain across multiple rerolls.
- Counterplay: Stuck dice still count toward scoring; high-value faces are less penalizing. Encourages adaptation.

---

### 3. The Card Sharp (Deck of Cards Boss)
**Loop Unlock:** Loop 2, Stage 7

**Theme:**  
A mysterious gambler with a marked deck of cards, shuffling and dealing bets. As the player rolls, cards are dealt onto the tray, covering and "cursing" dice.

**Core Mechanic: Card Curse Stack**
- **Before each roll**, 1–3 "curse cards" are dealt onto random dice.
- A cursed die **cannot score** on its current face; it contributes 0 value (but still counts as rolled).
- Curse cards are **sticky**—they persist across rerolls unless that die is explicitly rerolled (picked up/discarded).
- Once a die is rerolled, old curses are cleared; new curses can be applied to it.
- **Counterplay**: Reroll cursed dice to shed curses, or restructure scoring around non-cursed dice.

**Implementation Notes:**
- Track curse state per die (boolean or curse counter).
- Modify scoring logic to skip cursed dice when summing turn score.
- Visual: playing card overlay (red/black suit symbol) on affected dice.
- Curses reset on new turn/bank/bust.

**Balance Hints:**
- Loop 2: 1–2 curses per turn, only on dice with value ≥ 4.
- Loop 3+: 2–3 curses, applied to any die regardless of value.
- Counterplay: Multi-reroll strategies; building up smaller, non-cursed dice into a high score.

---

### 4. The Smoke Rings (Cigarette + Distortion Boss)
**Loop Unlock:** Loop 2, Stage 7 (variant/combination)

**Theme:**  
An experienced smoker blowing perfect rings across the tavern. Each ring distorts the dice tray's gravity, causing rolls to drift and scatter unpredictably.

**Core Mechanic: Gravity Drift**
- **On turns where the boss "exhales"** (every other turn or on a timer), the dice tray experiences a directional "drift" vector.
- When a die is rerolled, it drifts in the direction of the drift vector (e.g., up-left, down-right) by 1–2 grid squares.
- The drift direction changes each exhale cycle.
- Dice can drift off-limits or into hazards (ash, beer patches from a previous boss_phase).
- **Counterplay**: Account for drift when selecting reroll targets; use drift to your advantage.

**Implementation Notes:**
- Add drift vector to `DiceTray`.
- Modify reroll logic to apply drift offset after a die is placed.
- Clamp drifted positions to tray bounds or apply wrap-around.
- Visual: swirling smoke particles in the drift direction.

**Balance Hints:**
- Loop 2: Drift every other turn, magnitude 1–2 squares.
- Loop 3+: Drift every turn, magnitude 2–3 squares; direction is random instead of cyclical.
- Counterplay: Planning rerolls around predictable drift; higher variance rewards risk-taking.

---

### 5. The Bottle Spinner (Glass Bottle Roulette Boss)
**Loop Unlock:** Loop 2, Stage 7 (rare alternate)

**Theme:**  
Tavern games gone wrong. A spinning bottle on the table, pointing to random dice and "choosing" which ones the player must reroll.

**Core Mechanic: Forced Rerolls**
- **Every turn (or every other turn)**, the boss spins a bottle and it lands pointing at 1–3 random dice.
- Those dice **must be rerolled**—the player cannot keep them.
- This triggers a forced reroll action, draining a "second chance token" or applying a penalty.
- **Counterplay**: Minimize the loss by having weak dice in the chosen spots, or accept the forced reroll and fish for better results.

**Implementation Notes:**
- Extend `RollPhase` state machine to support forced-reroll states.
- Highlight forced-reroll dice visually (e.g., red glow, "MUST REROLL" label).
- Apply game state penalty (e.g., reduce gold on bank, increase bust risk) if forced rerolls are triggered.

**Balance Hints:**
- Loop 2: 1 forced reroll per turn, 1 die affected.
- Loop 3+: 1–2 forced rerolls per turn, 2–3 dice affected; risk of triggering multiple times.
- Counterplay: Early-stage dice management to ensure weak dice are placed in vulnerable spots.

---

### 6. The Broken Lamp (Darkness Creeper Boss)
**Loop Unlock:** Loop 3+, Stage 7

**Theme:**  
A sputtering tavern lamp flickering above the table. As it dims, the dice tray falls into shadow, and the player's view becomes obscured.

**Core Mechanic: Vision Loss**
- **As the turn progresses** (cumulative effect), the lamp flickers and dims the view of the dice tray.
- By mid-turn, **several dice rolls are hidden from view** (player sees dice but not their final faces—similar to the "Ash Cloud" boss, but involuntary).
- Full view is restored after each bank/bust event.
- **Counterplay**: Trust your memory, use context clues (which dice were rerolled?), or bank early before vision is too bad.

**Implementation Notes:**
- Extend `DiceTray` visual rendering to fade out die labels as turn progresses.
- Track turn progress (number of rerolls or elapsed time) and apply opacity/blur effects.
- Reset vision at start of new turn.

**Balance Hints:**
- Loop 3: Vision loss starts after turn 2; by turn 4, 50% of dice are obscured.
- Loop 4+: Vision loss starts after turn 1; rapid darkening.
- Counterplay: Short, decisive play (fewer rerolls); memory and risk management.

---

### 7. The Spilled Perfume (Scent Trails Boss)
**Loop Unlock:** Loop 3+, Stage 7

**Theme:**  
A turned-over perfume bottle. The scent trails guide or mislead the dice as they roll, creating invisible "scent lanes" that push dice toward or away from intended destinations.

**Core Mechanic: Invisible Lanes**
- **Hidden from the player**, 2–3 "scent lanes" are established on the tray (diagonal or straight paths).
- When a die is rerolled and passes through or ends in a lane, it is **nudged in the lane direction** by 1–3 squares.
- The lane positions are **revealed only after a reroll is complete**, showing the player where they were pushed.
- This creates a risk/reward: lanes can be beneficial (pushing dice toward high-value positions) or detrimental.
- **Counterplay**: Learn the lane patterns; use them strategically in later rerolls.

**Implementation Notes:**
- Pre-generate lane paths at turn start (weighted random selection).
- Apply nudge vectors during reroll placement if die path intersects a lane.
- Reveal lanes visually after reroll (e.g., glowing path effect, particle trail).

**Balance Hints:**
- Loop 3: 2 lanes, static for the turn; nudge magnitude 1–2 squares.
- Loop 4+: 3 lanes, dynamic (change every reroll); nudge magnitude 2–3 squares.
- Counterplay: Pattern recognition; building prediction skills; higher risk variance.

---

## Boss Selection and Progression

### Loop 1, Stage 7
- **Available:** Chain Smoker, Bartender (randomly selected or alternating)
- **Target Score:** Base target × 1.5 (e.g., 150 for a 100-base loop)
- **Gold Bonus:** +50 (flat) + 20 per loop for clearing a boss

### Loop 2, Stage 7
- **Available:** Card Sharp, Smoke Rings, Bottle Spinner (random pool)
- **Target Score:** Base target × 2.0
- **Gold Bonus:** +75 + 30 per loop

### Loop 3+, Stage 7
- **Available:** Broken Lamp, Spilled Perfume, + all previous bosses (random pool)
- **Target Score:** Base target × 2.5 (and scales by loop multiplier)
- **Gold Bonus:** +100 + 40 per loop

---

## Implementation Roadmap

### Phase 1: Foundation
1. Create `BossData.gd` resource class (name, mechanic type, spawn rules).
2. Extend `RollPhase.gd` to detect stage 7 and instantiate a boss controller.
3. Add boss visual container to `DiceArena.tscn` (prop positioning).

### Phase 2: Core Mechanics
1. Implement Chain Smoker (ash zones, face hiding).
2. Implement Bartender (sticky patches, frozen dice).
3. Test with existing dice and scoring logic.

### Phase 3: Advanced Bosses
1. Implement Card Sharp (curse stack).
2. Implement Smoke Rings (gravity drift).
3. Implement Bottle Spinner (forced rerolls).

### Phase 4: Hard Mode
1. Implement Broken Lamp (vision loss).
2. Implement Spilled Perfume (hidden lanes).
3. Tune difficulty across loops.

### Phase 5: Polish
1. Boss animations (props moving, effects triggering).
2. Boss dialogue/flavor text (sound cues, tooltips).
3. Victory fanfare and run-end stats.

---

## Balance Philosophy

- **Bosses are not "unbeatable"**—they are **skill checks** that reward thoughtful play and adaptation.
- Mechanics should be **telegraphed**: the player always knows (or can infer) what the boss will do next.
- **Counterplay must exist**: no mechanic should be pure RNG punishment; there is always a strategic response.
- **Feedback is clear**: visual cues show hazards, frozen dice, curses, etc. in real-time.
- **Scaling with loops**: boss difficulty increases by adding more hazards, faster cycles, and higher intersection with other mechanics.

---

## Future Expansion Ideas

- **Boss Combinations:** Later loops (5+) could have two mini-bosses or a "meta-boss" combining multiple mechanics.
- **Player Choices:** Between stages, allow the player to "fight" or "bribe" a boss to modify its difficulty (e.g., fewer ash clouds for 10 gold).
- **Mod Interactions:** Player modifiers could counter boss mechanics (e.g., "Umbrella" modifier blocks ash; "Non-Stick Coating" prevents beer sticking).
- **Dynamic Difficulty:** Boss difficulty adjusts based on player performance (if player is winning, increase hazard frequency; if losing, reduce).
