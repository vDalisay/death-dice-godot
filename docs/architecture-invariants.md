# Death Dice Architecture Invariants

This document defines boundaries that should stay true during architecture refactors.

## State Ownership

- `GameManager` owns mutable run state (`score`, `gold`, `lives`, stage and loop progression, event flags, shop spend tracking).
- Non-manager scene scripts should not directly mutate global state fields when an equivalent manager method exists.
- Signals that announce state changes should be emitted by the state owner (`GameManager`) so signal behavior remains consistent.

## Scene Responsibilities

- `RollPhase` coordinates run-phase flow, but logic should be decomposed into focused collaborators as complexity grows.
- `RollPhase` should remain a coordinator and delegate probability, bust-resolution routing, and score math to helper services.
- Mode/archetype selection UI should live in a dedicated picker scene (`ArchetypePicker`) rather than procedural construction inside `RollPhase`.
- UI panels and overlays (`ShopPanel`, `CareerPanel`, `StageEventOverlay`, etc.) should be presentation-first and avoid owning run-wide state.
- Scene communication should use typed signals rather than direct sibling/parent reach-ins.

## Data Boundaries

- Resource classes (`DiceData`, `DiceFaceData`, `StageMapData`, modifiers, save data) should primarily represent data.
- Heavy orchestration logic should move to dedicated helpers/services when it reduces coupling and improves testability.
- Keep static typing on arrays, dictionaries, parameters, and returns.

## Test Guardrails

- Keep guardrail coverage for bank and bust outcomes, shop enter/exit side effects, stage-map progression state changes, and event effect side effects.
- Add tests before major refactors, then keep those tests green as behavior contracts.
- Run targeted tests for touched areas first, then full regression before phase completion.
