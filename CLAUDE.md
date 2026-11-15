# CLAUDE.md (root pointer)

All project instructions, design, plan and progress notes live in the Obsidian vault at `docs/`.

**Before doing anything, read `docs/CLAUDE.md`** and follow its session protocol
(start: read `docs/04 - Progress/Status.md` and the latest `docs/04 - Progress/Session Log.md` entry;
end: update Session Log, Status and the active iteration note).

## Paths on this machine
- **Godot project (`res://`)**: this folder — `C:\Users\nikom\OneDrive\Escritorio\DriverProject\new-game-project`
- **Docs vault**: `docs/` (inside this folder)
- **Godot 4.6.1 executable**: `C:\Users\nikom\OneDrive\Escritorio\DriverProject\Godot_v4.6.1-stable_win64.exe`
  (no separate `_console.exe` build is installed; this one does print to stdout when run from the shell)
- **Version control**: this folder **is** a git repository (branch `main`). The vault's older "no git" rule
  is out of date — see `docs/CLAUDE.md` §6.

## Quick verification command
```
"C:\Users\nikom\OneDrive\Escritorio\DriverProject\Godot_v4.6.1-stable_win64.exe" --headless --path "C:\Users\nikom\OneDrive\Escritorio\DriverProject\new-game-project" --import
```
Full list of autotests and screenshot tools: `docs/CLAUDE.md` §5.
