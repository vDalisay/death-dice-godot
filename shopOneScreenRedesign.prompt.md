## Plan: One-Screen Shop Redesign

Replace the current stacked, text-heavy shop modal with a desktop-first one-screen shop table inspired by what works in Balatro, Slice & Dice, and Peglin: a single offer field with strong visual hierarchy, visible prices, icon-first cards, and a persistent details pane for the currently focused item. Keep the existing economy and purchase logic, but restructure the UI so players can scan offers instantly and only read full text when they want depth.

**Steps**
1. Define the target interaction model before touching scenes: one offer grid, one persistent details panel, one compact top economy bar, one bottom action row. Preserve existing shop item generation, costs, and purchase rules from `ShopPanel.open()`, `_generate_items()`, and `_on_buy_pressed()` in `C:/Users/Home/Documents/death-dice/Scripts/ShopPanel.gd`.
2. Reframe the layout in `C:/Users/Home/Documents/death-dice/Scenes/ShopPanel.tscn`: remove the scroll-first vertical stack and replace it with a full-width modal/table layout. Recommended desktop composition: left/middle = visual offer grid, right = selected-item inspector, top = gold + reroll/refresh context, bottom = continue button and compact run-state summary. This blocks later scene-path and test updates.
3. Replace the current text card template in `C:/Users/Home/Documents/death-dice/Scenes/ShopItemCard.tscn` with a visual card component that prioritizes silhouette and price over prose. Include: item art/icon area, rarity/accent frame, compact type badge, price chip, buy/play CTA, locked/blocked affordance, and a short keyword strip. Move the long description off the card.
4. Add focus/selection state to `C:/Users/Home/Documents/death-dice/Scripts/ShopPanel.gd`: track the currently highlighted item, update a persistent details pane, and support hover/focus/click selection. The details pane should show the item name, full rules text, dice faces or modifier effect summary, and any warnings or eligibility notes. This is the main replacement for the current `DescLabel` wall of text.
5. Convert item metadata into visual tokens in `C:/Users/Home/Documents/death-dice/Scripts/ShopPanel.gd` and `C:/Users/Home/Documents/death-dice/Scripts/ShopItemData.gd`: map each item type to icon, accent color, category glyph, and compact keyword tags. Reuse existing glyphs and art loaders from `C:/Users/Home/Documents/death-dice/Scripts/UITheme.gd`, especially `GLYPH_*`, `get_icon()`, and `get_die_sprite()` where assets exist.
6. Unify the offer field instead of hard-separating DICE and MODIFIERS with big headers. Keep category cues, but present all purchasable offers in a single coherent marketplace with subtle grouping or tabs rather than vertical barriers. Recommended compromise: one grid with small section chips or filter tabs for `Dice`, `Mods`, and `Bets`, while still allowing a shared visual language. This depends on step 2.
7. Treat bet/overlay actions as first-class shop offers visually, but not structurally separate. Cards for `Double Down`, `Insurance Bet`, `Heat Bet`, and `Even/Odd Bet` in `C:/Users/Home/Documents/death-dice/Scripts/ShopPanel.gd` should look like playable stall items with distinctive orange risk framing. Keep their current overlay resolution flow, but surface the risk/reward summary in the details pane before activation.
8. Reduce always-visible text to what materially affects decisions. Keep on-card text to: name, price, 1-line keyword summary, and maybe 3-6 compact face icons or effect chips. Push everything else into the selected-item details pane or hover tooltip. This addresses the current failure mode from `_item_description()` and `_get_upgrade_preview()` in `C:/Users/Home/Documents/death-dice/Scripts/ShopPanel.gd`.
9. Rework affordance and state cues in `C:/Users/Home/Documents/death-dice/Scripts/ShopPanel.gd`: blocked cards should not just dim. Use stronger game-UI states such as muted art, lock/cross badge, red price state for unaffordable, and “owned/full/unavailable” badges for modifier constraints. Reuse the compact icon treatment from `C:/Users/Home/Documents/death-dice/Scripts/ModifierBadge.gd` as the reference pattern.
10. Preserve good genre patterns and explicitly avoid the bad ones:
A. Keep from Balatro: fixed on-screen shopping context, visible reroll economy, limited offers, strong price readability, persistent item selection.
B. Keep from Slice & Dice: compact icon-first readability and fast scan of mechanical identity.
C. Keep from Peglin: simple card readability and obvious purchase action.
D. Avoid: long paragraph cards, scroll-heavy shop browsing, giant category dividers, forcing the player to open submenus just to compare prices, and hiding critical buy constraints in prose.
11. Update tests to match the new structure. `C:/Users/Home/Documents/death-dice/test/unit/ShopPanelLayoutTest.gd` should validate the new one-screen layout nodes and selected-item inspector instead of the current scroll container paths. `C:/Users/Home/Documents/death-dice/test/unit/ShopItemCardSceneTest.gd` should validate the revised card anatomy and touch-target requirements. Add or update interaction coverage for selection/focus behavior, details-pane updates, blocked state badges, and consistent CTA behavior for buy vs play offers.
12. Validate visually and behaviorally: the redesign is only successful if all offers are scannable on one desktop screen, the selected-item pane explains the current offer without cluttering every card, and buy/refresh/continue actions remain legible during fast shop decisions.

**Relevant files**
- `C:/Users/Home/Documents/death-dice/Scenes/ShopPanel.tscn` — Replace the scroll-first modal hierarchy with a one-screen shop table layout.
- `C:/Users/Home/Documents/death-dice/Scripts/ShopPanel.gd` — Preserve economy logic, add selection state, details-pane binding, visual token mapping, and stronger blocked-state handling.
- `C:/Users/Home/Documents/death-dice/Scenes/ShopItemCard.tscn` — Redesign card anatomy around image/icon, price chip, type badge, and short keyword strip.
- `C:/Users/Home/Documents/death-dice/Scripts/ShopItemData.gd` — Extend item metadata support for icon/category/short-summary mapping if the current fields are insufficient.
- `C:/Users/Home/Documents/death-dice/Scripts/UITheme.gd` — Reuse glyphs, colors, fonts, spacing, and icon/sprite loaders; add any missing tokens only if needed.
- `C:/Users/Home/Documents/death-dice/Scripts/ModifierBadge.gd` — Reuse as the pattern for compact icon-first status badges and hover help.
- `C:/Users/Home/Documents/death-dice/test/unit/ShopPanelLayoutTest.gd` — Update layout-path assertions for the new scene structure.
- `C:/Users/Home/Documents/death-dice/test/unit/ShopItemCardSceneTest.gd` — Update card-structure assertions to match the redesigned component.

**Verification**
1. Open the shop in-game at a normal desktop resolution and confirm all offers, economy controls, and continue action fit on one screen with no scrolling.
2. Verify the selected-item panel updates on hover/focus/click and exposes the full mechanics text that was removed from the cards.
3. Confirm buy-state clarity for all blocked cases: insufficient gold, modifier cap reached, modifier already owned, and unavailable bet conditions.
4. Run the affected gdUnit tests for shop layout and card structure, then run the full regression suite required by the repo workflow.
5. Launch the project through the normal Godot validation flow and confirm there are no layout/runtime errors in debug output.

**Decisions**
- Direction: Hybrid of Balatro structure with cleaner readability and stronger iconography.
- Layout priority: Desktop-first one-screen composition, not small-window-first.
- In scope: Shop visual structure, card anatomy, selection/details behavior, affordance clarity, and test updates.
- Out of scope: Economy rebalance, new shop item mechanics, replacing the existing bet overlay minigames, or designing brand-new art assets beyond reusable icons/glyphs/placeholders.

**Further Considerations**
1. If the existing art/icon library is too thin, implement the layout with glyphs, dice-face miniatures, and badge frames first rather than blocking on bespoke illustrations.
2. If a single mixed grid feels noisy in playtests, fall back to subtle category tabs or segmented lanes, but keep the persistent details pane and one-screen composition.
3. If desktop-first density causes controller or keyboard friction, add explicit focus order and selection states rather than reintroducing verbose cards.
