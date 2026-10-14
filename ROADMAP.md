# Roadmap

Planned features, ideas and open questions for Satellite. Move an entry to
[CHANGELOG.md](CHANGELOG.md) when it ships, and delete it here.

Satellite gathers other addons' minimap buttons into one launcher. The launcher comes in several
styles; the default is a round button with three discs on the minimap's ring that slides out a
menu.

## Collecting buttons

LibDataBroker objects, the addon compartment, Blizzard's expansion button and hand-made minimap
buttons are collected (see `Collectors/`); each entry has a stable key, so order and settings
survive reloads. Still to do:

- **Hand-made buttons**: check in game with Battle Pet Statistics and the test buttons
  (`/satellite test buttons`), including their tooltips, right-click menus and icon changes.
  Check the HereBeDragons pin table (`minimapPins`) against the real library with TomTom or
  HandyNotes. Plumber's own button starts unticked, on the minimap (`STAY_ON_MINIMAP` in
  `Collectors/Handmade.lua`); its LibDBIcon button is in the menu.

## Buttons

- Rename single buttons.
- Blizzard's expansion button: while its original is hidden, its pulse and alerts (renown, new
  content) can't be seen. Show a glow on the menu's copy.

## Launcher

- The compass arrow's measures (`COMPASS_TIP_SHARE`, `COMPASS_HALF_HEIGHT_SHARE` in
  `Launcher/Styles/Arrow.lua`) come from one screenshot; check them at other minimap sizes. On
  the east side (minimap at the screen's left edge), `EAST_NUDGE` was set by eye; check it there
  too, in place of the east arrow and beside it.
- Ideas: the side bar's notches from Blizzard's side panels; art matching the minimap's metal
  border.

## Before release

- Screenshots for CurseForge.
