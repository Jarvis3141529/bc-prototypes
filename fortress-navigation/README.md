# Fortress Compound — Prototype v2

Prototype for the final approach to Bognor: a 2D scroller through the fortress
compound where the player **chooses spells from their spell book** and casts
them by solving multiplication facts **under time pressure** (fluency = fast
recall — the timer is the mastery test).

## What's here

Two playable perspectives sharing one mechanics core, to compare feel and pick
one (Phase 2 of the design plan):

- **Side-View Scroller** (`lib/sidescroll/`) — storybook cross-section, walk
  left→right: Sealed Gate → Broken Bridge (checkpoint) → Guard Tower →
  Stone Wall → Missile Trap → Magic Ward → Throne Door. Obstacles physically
  block progress; enemy towers volley while you're in their danger zone.
- **Top-Down Compound** (`lib/topdown/`) — overhead fortress grounds, drag to
  roam, route choice through 8 encounters.

**Shared core** (`lib/core/`):
- `spells.dart` — the 7 spells (mirrors the main game's `spell_data.dart`).
- `encounter.dart` — obstacle/enemy archetypes, one+ per spell; the Guard
  Tower accepts Shatter *or* Fog (spell choice is part of the puzzle).
- `casting_panel.dart` — the **ritual casting panel**: sigil + incantation,
  the fact with its orb-array, six options, and the **fluency timer**.
  Wrong/timeout costs a heart (kindly); correct collapses into the world
  effect.
- `cast_flow.dart` — arm spell → tap target → fizzle (wrong spell) or panel
  (right spell). Spells are never auto-selected.
- `session.dart` — hearts, checkpoints, kind retry (progress is kept).

## Run it

```
flutter run -d chrome
```

The menu's fluency-timer slider (0.75×–1.5×) stands in for real per-fact
mastery data during prototyping.

## Design references

- Design plan: `BognorsCurse-flutter` repo → fortress compound plan
  (design doc lands as `docs/GAME_DESIGN_FORTRESS.md` after perspective lock).
- Spell book identity (whether it is Aldric's book) is deliberately
  **lore-agnostic** in all copy here.
- The v1 free-roam mockup is preserved in git history (`main` before this
  branch).
