## Plan: Dark Stage Selection Redesign

Replace the current clean-but-generic branching map with a darker, more tactile stage-selection screen that keeps the existing underlying node logic but presents it with stronger atmosphere, better route readability, and a more intentional sense of journey. The target is a hybrid of Inscryption's ritual, tabletop path-picking, Slice & Dice's compact route clarity, and a darker Cloverpit-adjacent mood: grim, worn, low-light, and mechanically readable.

**What works in reference games**
1. Inscryption works because route choice feels physical and diegetic. The map is not a UI spreadsheet; it feels like tokens laid out on a table under candlelight. The key takeaway is not complexity, but staging: limited options, tangible pieces, strong contrast, and mood doing real work.
2. Slice & Dice works because route selection is compact, legible, and fast. You can parse the path structure at a glance. Icons are simple, options are few, and the screen is about momentum, not explanation overload.
3. FTL works because node color and structure imply route planning, but its best lesson is cautionary: abstract color coding alone is not enough. Players need meaningful previews, not just category colors.
4. Slay the Spire style maps work when they make the path network itself the star: clean route lines, obvious future branching, and immediate understanding of risk/reward structure.
5. Peglin-style progression works when the player always understands both current location and near-term next choices without opening another panel.

**What does not work**
1. Flat full-screen overlays with isolated floating buttons and no environmental frame feel placeholder, even if technically functional.
2. Tiny equal-weight nodes with weak silhouettes make every location feel the same.
3. Emoji or raw symbol-first presentation can work for prototyping, but it undercuts tone when the rest of the game is moving darker and grittier.
4. Large amounts of text directly on the map reduce scan speed and kill atmosphere.
5. Perfectly even spacing and sterile geometry make the screen feel like a flowchart rather than a journey.
6. Dim-only inactive states are too weak. Locked, future, visited, current, and reroute-enabled should each read instantly.

**Current implementation constraints**
1. Preserve the existing map logic from `C:/Users/Home/Documents/death-dice/Scripts/StageMapPanel.gd`, `C:/Users/Home/Documents/death-dice/Scripts/StageMapData.gd`, `C:/Users/Home/Documents/death-dice/Scripts/StageMapGenerator.gd`, and `C:/Users/Home/Documents/death-dice/Scripts/MapNodeData.gd`.
2. Keep the branching structure and node types intact unless visual changes reveal a specific UX problem that requires minor data-layer support.
3. Update tests currently tied to the old structure in `C:/Users/Home/Documents/death-dice/test/unit/StageMapPanelTest.gd` if the scene tree or visual states change.

**Target visual direction**
1. Move away from “full-screen overlay with centered buttons” and toward a framed route board.
2. Present the map as a dark tabletop, pinned dossier, scorched parchment, or chalk-marked board suspended over a gritty background.
3. Use a restrained palette: charcoal, dirty brass, dried bone, oxidized teal, soot gray, ember orange, muted blood red.
4. Keep active path highlights readable with a cold accent, but let the environment stay dark and worn.
5. Use texture, vignette, falloff lighting, and subtle grime to carry tone, not noisy ornament.
6. Node icons should look like carved sigils, stamped seals, hazard markers, or brass tokens rather than clean UI glyphs.

**Proposed layout**
1. Keep a full-screen panel, but divide it into three layers:
A. Background atmosphere layer: low-light environment, vignette, subtle moving fog or dust, maybe a desk or wall silhouette.
B. Map board layer: a centered, framed route surface where the path nodes live.
C. Context HUD layer: title, loop/stage context, selected-node panel, and continue/back hints.
2. Replace the current simple title and hint stack in `C:/Users/Home/Documents/death-dice/Scenes/StageMap.tscn` with a more deliberate composition:
A. Top-left or top-center: run context, loop number, zone title.
B. Center: map board with nodes and route lines.
C. Bottom or side panel: selected node preview, reward/risk summary, and input hint.
3. Avoid scroll and pan if the map remains small. The map should fit comfortably in one framed composition and feel curated.

**Node presentation**
1. Increase node visual hierarchy. Not every node should be the same size and visual weight.
2. Normal fights can remain medium weight.
3. Shop, Forge, Event, Rest, and Special nodes should each have distinct silhouettes and not rely purely on color.
4. Replace the current below-node text labels with a lighter-touch approach:
A. Keep names hidden until hover/focus, or
B. Use ultra-short stamped labels only for the currently reachable row.
5. Use icon medallions or plaques for nodes. A node should feel like an object on a board, not a button with text.
6. Current node states should be unmistakable:
A. Current reachable nodes: lit edge, animated pulse, high contrast.
B. Visited nodes: stamped out, ashen, or crossed through.
C. Future nodes: barely lit silhouettes.
D. Unreachable nodes in current row: visible but obviously cut off.
E. Reroute-accessible nodes: amber warning edge, different from default active glow.

**Connection lines**
1. The current `Line2D` route lines in `C:/Users/Home/Documents/death-dice/Scripts/StageMapPanel.gd` should become more expressive.
2. Replace thin abstract lines with route strokes that look etched, stitched, inked, or wired into the board.
3. The active route should not just be brighter; it should feel alive or recently traced.
4. Use softer inactive paths and emphasize only the immediate next branch strongly.
5. Avoid overly tangled geometry. If generation plus layout creates visual mess, adjust spacing or mild per-row staggering so lines are readable first and realistic second.

**Information architecture**
1. Keep the map itself low-text and high-scan.
2. Put the real explanation in a selected-node panel instead of attaching labels under every node.
3. The selected-node panel should show:
A. Node title
B. Type icon
C. Short flavor line
D. Mechanical summary, such as “Shop: buy dice, modifiers, bets” or “Forge: upgrade and tune a die”
E. Any special rule preview for special stages
4. This solves the FTL problem where color exists but players still do not actually know the consequences.

**Tone direction: Inscryption x Slice & Dice x Cloverpit-adjacent**
1. From Inscryption, borrow ritual and physicality: the map should feel like a thing in the world.
2. From Slice & Dice, borrow compact route readability and fast scan speed.
3. From Cloverpit-style mood, borrow oppressive darkness, dirty surfaces, restrained highlights, and a sense of risk-heavy pressure.
4. Do not go full horror clutter. The screen still has to communicate choices instantly.
5. The correct target is “grim but readable,” not “dark enough that the UI disappears.”

**Concrete scene direction**
1. In `C:/Users/Home/Documents/death-dice/Scenes/StageMap.tscn`, replace the bare `MarginContainer/VBoxContainer` framing with a dedicated board container and a separate info panel.
2. Add a map frame or panel treatment that feels aged or industrial, using the visual language already being established in the rest of the UI.
3. Keep `MapArea` as the dynamic drawing area, but make it live inside a stylized board rather than raw full-screen negative space.
4. Add a selected-node inspector panel instead of relying on `HintLabel` alone.
5. Convert `HintLabel` into either a route instruction label or the footer of the selected-node panel.

**Concrete script direction**
1. In `C:/Users/Home/Documents/death-dice/Scripts/StageMapPanel.gd`, preserve `open()`, node selection, and data usage, but add selected-node tracking and richer hover/focus binding.
2. Replace hardcoded “tiny button plus child label” rendering with a node component or a richer button composition.
3. Consider a dedicated reusable scene for one stage-map node if the visual treatment becomes more elaborate.
4. Extend `MapNodeData.get_hover_description()` usage so the selected-node panel can show better summaries.
5. If needed, add short flavor text or preview metadata to node types without changing routing behavior.

**Suggested examples to combine**
1. Inscryption: framed board, low-light ritual atmosphere, route choice feels tactile.
2. Slice & Dice: minimal branch count, route clarity, node types instantly legible.
3. Slay the Spire: path network is easy to read and plan around.
4. FTL: map should imply strategic planning, but improve on FTL by making node meaning clearer before selection.
5. Darkest Dungeon estate or travel screens as a mood reference: distressed textures, heavy shadows, restrained color.

**What the redesigned screen should feel like**
1. You are not clicking abstract circles on a debug overlay.
2. You are choosing where to drag your run next on a grim route board.
3. The map should feel dangerous and deliberate, but still fast to parse in two seconds.
4. The player should see the route, feel the mood, and understand the consequences.

**Implementation priorities**
1. First, fix composition: board + inspector + mood background.
2. Second, redesign node silhouettes and route lines.
3. Third, move detailed text off-map and into selection context.
4. Fourth, refine active, visited, future, and reroute states.
5. Fifth, tune textures, colors, and subtle animation for atmosphere.

**Relevant files**
- `C:/Users/Home/Documents/death-dice/Scenes/StageMap.tscn`
- `C:/Users/Home/Documents/death-dice/Scripts/StageMapPanel.gd`
- `C:/Users/Home/Documents/death-dice/Scripts/MapNodeData.gd`
- `C:/Users/Home/Documents/death-dice/Scripts/StageMapGenerator.gd`
- `C:/Users/Home/Documents/death-dice/test/unit/StageMapPanelTest.gd`

**Verification**
1. The map should remain readable from a normal desktop distance.
2. The currently reachable row should be instantly identifiable without reading text.
3. Hover or focus should explain a node without cluttering the whole board.
4. The screen should feel materially darker and more intentional than the current overlay.
5. Existing route logic and node selection behavior should remain intact unless explicitly redesigned.
