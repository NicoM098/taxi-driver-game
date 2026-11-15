---
tags: [plan, phase]
phase: 10
status: not-started
---
# Phase 10 — Game Flow, UI & Save

**Goal:** a complete game wrapper: main menu → shift → summary → garage → next shift, with pause, settings and save/load.
**Depends on:** [[Phase 09 - Economy, Shop & Upgrades]]

## Tasks
- [ ] `SceneLoader` transitions with fade.
- [ ] Main menu: Continue / New Game / Settings / Quit.
- [ ] **Time of day picked when a game starts** (user, 2026-11-14): day / dusk / night chosen on
  New Game, not only with the F6 debug key. The moods already exist as data (`Lighting`, D-064) and
  `City.set_mood()` applies one live, so this is a menu option writing one value — put it wherever
  the New Game flow lands, and keep F6 for development.
- [ ] Pause menu (Esc): resume, settings, quit to menu; pauses tree, frees mouse.
- [ ] Shift summary screen: rides, decisions made, cash in/out (fares, tips, theft, bounties), heat, items found.
- [ ] Game over (taxi destroyed / driver killed) rules: lose shift earnings? Define with user → [[Decisions Log]].
- [ ] Settings: mouse sensitivity, invert Y, FOV, head-bob intensity, volume buses, resolution/fullscreen, keybinding remap (optional).
- [ ] `SaveManager`: serialize `GameState` (+ settings separately) to `user://`; autosave at garage; versioned save format.
- [ ] HUD polish pass: consistent style, readable at speed.
- [ ] Controller polish pass (controller is supported from Phase 00): button glyphs by device, full focus navigation in every menu, rumble on impacts/shots, stick dead-zone & sensitivity settings.
- [ ] ~~Endless shifts (demo)~~ obsolete since D-051 (no shift clock, open world): replace with open-world run flow / stats when this phase is re-planned.

## Definition of done
- Quit and relaunch → Continue restores cash, weapons, upgrades, perks, inventory, shift number.

## User test checklist
- [ ] Full loop from menu → 2 shifts → quit → continue.

## Notes
