# Changelog

## 0.1.0

- Addon scaffold: settings in Blizzard's Options (AddOns tab), `/satellite` command and an entry
  in the addon compartment.
- Finds the buttons of addons that use LibDataBroker, and the entries of Blizzard's addon
  compartment, and hand-made minimap buttons (map pins and Blizzard's own frames are left out);
  `/satellite list` shows them. An addon with both shows once.
- Blizzard's expansion button (the landing page: order hall, covenant sanctum, Omnium Folio...)
  can join the menu too (a setting, off at first), with its own art, tooltip and click; its
  minimap button is then hidden like the addons' (and comes back if you take it out of the menu).
- **The launcher**: a round button on the minimap's ring, where Blizzard puts its own buttons,
  with a stack of three coloured discs (a dragon, a potion and a sword) and a gold chevron
  pointing the way the menu opens. Click it to slide out a menu with your addons' buttons beside
  it, away from the minimap; click it again to close it. Hover a button for its tooltip; clicks go
  to the addon as on its own button. The menu can show the addons' names beside their buttons.
- **Launcher styles**: the minimap button; the minimap's north compass arrow, turned west, in the
  place of the west arrow (or beside it), with a + to show it opens; a circle or square like the
  minimap button, you can put anywhere (the menu opens toward the middle of the screen; dragged
  against an edge of the screen, it docks there, partly past the edge); a side bar like Blizzard's
  side panels, on any edge of the screen (left, right, top or bottom); or no launcher, with the
  menu always open.
- **Settings beside the menu**: right-click the launcher for the look (style, size, colours,
  symbols), the menu (button size, buttons per column, names, direction), the place (locked, or
  drag to move; Shift-drag while locked) and, on the Buttons tab, which buttons the menu shows and
  their order. The menu stays open, so changes show at once. Also from Blizzard's Options.
  `/satellite reset` puts the launcher back in its place.
- The menu shows every addon with a minimap button, and hides those minimap buttons (a setting
  keeps them). Addons without one (only in the addon compartment, or only for broker displays) can
  be shown too.
- The launcher stays behind Blizzard's expansion button on the minimap (e.g. the Omnium Folio).
- `/satellite test` for development: test launchers, data sources, addon compartment entries,
  hand-made minimap buttons and up to thousands of map pins.
- Icon and logo.
- Languages: English, German, French, Italian, Russian, Spanish, Portuguese, Simplified and
  Traditional Chinese, and Korean.
