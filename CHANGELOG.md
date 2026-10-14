# Changelog

## 0.3.2

- Fixed: addons whose minimap button has another name than their broker button (RareScanner)
  weren't put in the menu, and their minimap button stayed.

## 0.3.1

- **Circle** is the menu buttons' shape at first.
- Slightly thinner borders on the circle, square and diamond buttons.

## 0.3.0

- **Button shapes**: the menu's buttons can look like minimap buttons, circles, squares or
  diamonds, with a border in the border colour.
- **The discs orbit** a little while you hover the launcher.
- **A short pulse** on the launcher when an addon adds a button while you play.
- **The compass arrow on the east side**: with the minimap at the screen's left edge, the arrow
  and its menu move to the minimap's other side, in place of the east arrow or beside it.
- **The compass arrow's menu** slides and fades in like the others, without an invisible edge.
- **The settings don't jump** when you switch tabs: the panel keeps one height.
- Fixed: an addon whose compartment entry and broker button have different names showed twice.
- The order and hidden buttons of addons that are gone for 30 days are forgotten.

## 0.2.0

- **Symbols for your class and spec**: each class has its own symbol, and each spec two more, on
  the launcher's three discs (a Frost Death Knight: a skull, a snowflake and a sword). They change
  when you change spec. 35 new symbols.
- **Gold symbols** by default, and softer colours for "Colored".
- **A dot on the launcher** when an addon changes its icon to show something new (BugSack's bug
  turns red), until you open the menu; the buttons that changed show it too. A setting.
- **Names only**: the menu can show icons, icons and names, or only the names, as a list.
- **Behavior tab** in the settings: open the menu on mouseover, close it after clicking a button
  (on at first; never on right-click) or when the mouse leaves, which way it opens, and the
  launcher's position.
- **Each style keeps its own size**: the circle and the square can have different sizes.
- **The menu's border** takes the border colour, for every style.
- **Docking**: the circle and square keep their size and look on an edge of the screen, half of
  them past it.
- **Square minimaps** (ElvUI, BasicMinimap...): the minimap button follows the square's edge.
- **Menus stay on the screen**: at the screen's left edge, the compass arrow's menu opens on the
  minimap's other side, and the always open menu can't be dragged off the screen.
- **Smoother menu**: it slides and fades in, instead of appearing from behind an invisible edge.
- **Above the action bars**: the circle, square, side bar and always open menu.
- **Settings**: clearer wording; all button options on the Buttons tab; right-click the menu's
  background to open them (with the menu always open, there's no launcher to right-click). In
  combat, `/satellite` opens them instead of doing nothing. The cog in the menu is gone.
- Fixed: the compass arrow kept a grey bit of ring when it moved, and only part of it lit up.
- Fixed: other minimap addons' changes to the compass were undone; another button collector could
  show buttons Satellite hides.
- Faster: the minimap scan only runs when asked (`/satellite list`), and only icon changes of
  broker addons are followed.
- `/satellite test alert` and `/satellite test error` for testing (with debug on).

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
- The launcher stays above Blizzard's expansion button on the minimap (e.g. the Omnium Folio).
- `/satellite test` for development: test launchers, data sources, addon compartment entries,
  hand-made minimap buttons and up to thousands of map pins.
- Icon and logo.
- Languages: English, German, French, Italian, Russian, Spanish, Portuguese, Simplified and
  Traditional Chinese, and Korean.
