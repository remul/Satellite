# Roadmap

Planned features, ideas and open questions for Satellite. Move an entry to
[CHANGELOG.md](CHANGELOG.md) when it ships, and delete it here.

Satellite gathers other addons' minimap buttons into one launcher. The launcher comes in several
styles; the default is a round button with three discs on the minimap's ring that slides out a
menu.

## Collecting buttons

LibDataBroker objects, the addon compartment and Blizzard's expansion button are collected (see
`Collectors/`); each entry has a stable key, so order and settings survive reloads. Still to do:

- **Hand-made minimap buttons** (`frame:<name>`): the scan finds them, but only on demand
  (`/satellite list`, `/satellite scan`), and they're only listed. Bring them into the menu with
  the player's OK: reparent, and hook `SetPoint`/`SetParent` only on collected frames. Never move
  protected frames, and nothing in combat (wait for `PLAYER_REGEN_ENABLED`). Check the
  HereBeDragons pin table (`minimapPins`) against the real library with TomTom or HandyNotes.
- **Compartment duplicates**: an addon whose compartment title and LibDataBroker name differ
  shows twice when addons without a minimap button are shown too.
- **Saved keys of removed addons** stay in `buttonOrder` and `hiddenButtons`; prune them after a
  while.

## Buttons

- Rename single buttons.
- Button shapes: circle, square, diamond; more with our own mask textures.
- Blizzard's expansion button: while its original is hidden, its pulse and alerts (renown, new
  content) can't be seen. Show a glow on the menu's copy.

## Launcher

- The compass arrow's measures (`COMPASS_TIP_SHARE`, `COMPASS_HALF_HEIGHT_SHARE` in
  `Launcher/Styles/Arrow.lua`) come from one screenshot; check them at other minimap sizes.
- Ideas: the side bar's notches from Blizzard's side panels; art matching the minimap's metal
  border.

## Before release

- Screenshots for CurseForge.
