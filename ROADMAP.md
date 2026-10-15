# Roadmap

Planned features, ideas and open questions for Satellite. Move an entry to
[CHANGELOG.md](CHANGELOG.md) when it ships, and delete it here.

Satellite gathers other addons' minimap buttons into one launcher. The launcher comes in several
styles; the default is a round button with Satellite's logo on the minimap's ring that slides
out a menu.

## Check in game

Shipped, but so far only checked in code and with simulations outside the game:

- **Symbols**: the class, spec and hero talent images, their size inside the border and the trim
  of their rims (`EMBLEM_IMAGE`, `SPEC_IMAGE` in `Launcher/IconStack.lua`), the image colours
  (`IMAGE_TINTS`), and the logo's orbit (no flicker).
- **Alerts**: BigWigs, LittleWigs and TinyWigs zoning in and out without the dot (`ZONE_DELAY`
  in `Launcher/Alert.lua`), and the dot's toggle in the Buttons list.
- **Placing**: docking the circle and square on all four edges and into the corners, the shared
  place with the side bar, the launcher behind the bags with its menu over them, the tooltip's
  place, and closing on a click elsewhere or when the mouse leaves.
- **Hand-made buttons**: Battle Pet Statistics and the test buttons (`/satellite test buttons`),
  with their tooltips, right-click menus and icon changes; Plumber's buttons and names
  (`STAY_ON_MINIMAP` in `Collectors/Handmade.lua`, `OUT_OF_MENU` in `Buttons.lua`). Check the
  HereBeDragons pin table (`minimapPins`) against the real library with TomTom or HandyNotes.
- **Combat**: the menu, the settings and dragging in combat, and the expansion button's page
  opening once combat ends (`Blizzard.Click` in `Collectors/Blizzard.lua`).
- **Favourites** (`Launcher/Favorites.lua`, each style's `PlaceFavorites`): on the minimap's ring
  beside the minimap button (are Blizzard's buttons, calendar or mail, in the way?) and above and
  below the compass arrow, clear of the open menu; the arc round the circle and square, near the
  screen's edges too; the orbit when docked (the menu opening past it), the row in corners; the
  side bar's row beside the tab (the menu opening past it); hidden while dragging.
  Showing on mouseover (they fly out, and back after `LEAVE_DELAY`), their tooltips and clicks,
  hand-made buttons as favourites, their own alert dot, the star in the Buttons list (Blizzard's
  `auctionhouse-icon-favorite` atlas; in WoW Forever too?), and boss mods' dot off by default.
- **Compass arrow**: its measures (`COMPASS_TIP_SHARE`, `COMPASS_HALF_HEIGHT_SHARE` in
  `Launcher/Styles/Arrow.lua`) come from one screenshot; check them at other minimap sizes, and
  `EAST_NUDGE` on the east side, in place of the east arrow and beside it.

## WoW Forever

Satellite runs in WoW Forever's beta too (interface 16001, already in the TOC). What a client can
do is in `Compat.lua` (`ns.Client`), found by looking for its functions; the rest asks it for
features, never for a version.

- Check in Forever: which image symbols it offers (no hero talents; specs?), the compass arrow on
  its minimap art (`COMPASS_TIP_SHARE`, `COMPASS_HALF_HEIGHT_SHARE`), the settings panel and the
  Buttons list, and the addons there.
- Then release with 16001 in the TOC, so CurseForge lists Satellite for Forever.

## Buttons

- Blizzard's expansion button: while its original is hidden, its pulse and alerts (renown, new
  content) can't be seen. Show a glow on the menu's copy.
- A key binding to open and close the menu (`Bindings.xml`).

## Launcher

- Ideas: the side bar's notches from Blizzard's side panels; art matching the minimap's metal
  border.

## Before release on more sites

- Screenshots for CurseForge: the minimap button with its menu open, the compass arrow, the side
  bar, the settings panel, and the image symbols.
- Native speakers to check the translations.
- Wago and WoWInterface.
