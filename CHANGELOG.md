# Changelog

## 0.8.0

- **Favourites**: star up to four buttons in the Buttons tab and they show beside the launcher,
  out of the menu, like satellites around it: on the minimap's ring above and below the minimap
  button or the compass arrow, in an arc around the circle and square (an orbit when docked),
  along the side bar. Always, or only while you hover the launcher ("Favorites" on the Launcher
  tab); with the menu always open, they come first in it. They show their own alert dot, and
  hide while you drag the launcher.
- **Boss mods without the dot**: BigWigs (with LittleWigs and TinyWigs) and DBM change their
  icon all the time, so their alert dot starts off. Turn it on in the Buttons tab.
- **A calmer logo**: its buttons orbit more slowly while you hover it.

## 0.7.0

- **WoW Forever**: Satellite runs there too. The symbol settings offer only what the game has
  (no hero talents in Forever).
- The test code is no longer in the download.

## 0.6.0

- **Rename buttons**: right-click a name in the Buttons tab. The menu's names get as much room as
  the longest needs, so "Plumber (Expansion Summary)" isn't cut off any more.
- **Settings for one character**, or shared by all your characters (Behavior tab; switching
  reloads the interface), and **Reset all settings**.
- **The images come alive**: your class, spec or hero talent image glows (or turns a little)
  while you hover the launcher ("Image animation").
- **Pictures in the symbol dropdown**, showing the logo and your own images.
- **The menu closes after a right-click** on a button too, unless the addon opened a dropdown
  there.
- **Dragging the launcher**: the settings stay where they are and the menu closes until you let
  go; smoother, as only the launcher moves while you drag.
- **Blizzard's expansion button in combat** opens its page once combat ends, instead of an
  "Interface action failed" error.
- Settings Satellite no longer uses are removed from your saved settings.

## 0.5.0

- **Satellite's logo** on the launcher at first: its three buttons orbit while you hover it. Or
  show your **class, spec or hero talent image** instead, in its own colours, grey, or tinted
  gold, silver or bronze. The coloured discs are gone.
- **The menu closes when you click elsewhere**, or instead a moment after the mouse leaves it
  ("Closes" in the Behavior tab).
- **Circle, square and side bar share one place**: switch between them and the launcher stays
  where it is.
- **Docking is more precise**: the circle and square dock only once you push them against an
  edge, and slide along it right into the corners.
- **Dragging is smoother**: the menu closes while you drag, and the minimap button no longer
  jumps to the cursor when you grab it.
- **The launcher stays behind your bags** and action bars; its open menu goes over them.
- **Fewer false alerts**: icons that change as you zone in or out (BigWigs) don't show the dot,
  and you can turn the dot off for any button in the Buttons tab.
- **Plumber**: its Expansion Summary stays on the minimap at first, and its buttons have clearer
  names.
- Buttons per column is a dropdown, so the menu doesn't jump while you choose; more room between
  the Launcher tab's settings; the tooltip keeps clear of the launcher; circle buttons' icons are
  a pixel bigger.
- Fixed: the orbit animation flickered.

## 0.4.0

- **Hand-made minimap buttons**: buttons that addons make themselves, without LibDBIcon (e.g.
  Battle Pet Statistics), move into the menu too. They keep their own clicks, tooltip and
  menus, and go back to their place on the minimap when you untick them in the Buttons tab or
  turn off "Collect hand-made minimap buttons" (on at first).
- Buttons of addons that also have a LibDBIcon button (like Plumber's) start unticked, so they
  don't show twice.
- The minimap is looked at for new buttons after login and whenever an addon loads.
- Less work when addons change their buttons often.

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
