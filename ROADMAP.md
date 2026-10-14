# Roadmap

Planned features, ideas and open questions for Satellite. Move an entry to
[CHANGELOG.md](CHANGELOG.md) when it ships, and delete it here.

Satellite gathers other addons' minimap buttons into one launcher. The launcher comes in several
styles; the first is a gold arrow next to the minimap that slides out a menu.

## Collecting buttons

All three sources are found (see `Collectors/`); each entry has a stable key so order and settings
survive reloads. Still to do:

- **LibDataBroker** (`ldb:<name>`): most addons. Read the data objects
  (`DataObjectIterator`, `LibDataBroker_DataObjectCreated`) and build our own buttons from `icon`,
  `iconCoords`, `label`, `text`, `OnClick`, `OnTooltipShow`. Hide LibDBIcon's own button
  (`LibDBIcon10_<name>`, `LibDBIcon_IconCreated`). Only `type == "launcher"` by default; data
  sources (live text, e.g. coordinates) as an option.
- **Minimap scan** (`frame:<name>`): ask the user before collecting what the scan finds. Reparent,
  and hook `SetPoint`/`SetParent` only on collected frames. Check the HereBeDragons pin table
  (`minimapPins`) against the real library once TomTom or HandyNotes is installed.
- Never move protected frames, and nothing in combat (wait for `PLAYER_REGEN_ENABLED`).

## Buttons

- Sort by hand (drag) or by name; hide single buttons; rename them.
- Icons only, icons with names, or names only.
- Button shapes: circle, square, diamond; more with our own mask textures.

## Launcher

- **Arrow and menu** (first version done). Next: labels (icons with names), drag to sort, hide
  or rename single buttons; square minimaps (`GetMinimapShape`); the scanned hand-made buttons
  (with the player's OK). The minimap's measures (`COMPASS_TIP_SHARE`,
  `COMPASS_HALF_HEIGHT_SHARE` in `Launcher/Launcher.lua`) come from one screenshot; check them at
  other minimap sizes.
- Styles done: compass arrow, circle, square, triangle, side bar, always open. Ideas: the side
  bar's notches from Blizzard's side panels; a size setting for the shapes.
- Animations with AnimationGroups: arrow flip, buttons popping in one after another, hover glow.
- Art matching the minimap's metal border and gold arrows: TGAs in `Media/`.

## Before release

- Screenshots.
- Check the name once more on CurseForge, Wago and WoWInterface.
