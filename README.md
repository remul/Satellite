<p align="center"><img src="Media/Logo.png" width="200" alt="Satellite"></p>

# Satellite

Satellite gathers the minimap buttons of your addons, and Blizzard's expansion button (order hall,
Omnium Folio...), into one launcher, so your minimap stays clear. Open the launcher to reach them
all in one place.

Satellite is in early development. It runs in Retail and in WoW Forever. Click the button with
Satellite's logo on your minimap's ring to open its menu; hover it, and the logo's buttons orbit.

## Settings

**Beside the menu**: right-click the launcher, or the menu's background (with the menu always
open). The menu stays open while you change things, so you see them at once.

- **Launcher** tab:
  - The style: a round button on the minimap's ring (drag it around the ring), the
    compass arrow, a circle or square, a side bar on any edge of the screen, or the menu always
    open. Drag the circle or square against an edge of the screen and it docks there, half past
    the edge. On a square minimap (ElvUI, BasicMinimap...), the minimap button follows its
    sides. With the minimap at the screen's left edge, the compass arrow and its menu move to
    the minimap's east side.
  - The launcher's size (50–200%, kept for each style), and for the compass arrow: in place of
    the minimap's west arrow or beside it.
  - The border colour of the launcher and its menu (gold, silver, bronze or a quiet version of
    your class colour), and the launcher's symbol: by default Satellite's logo, whose buttons
    orbit while you hover it, or your class, spec or hero talent image, in its own colours, grey,
    or tinted gold, silver or bronze, glowing or turning a little while you hover it.
  - The menu: button size and shape (circle, minimap button, square or diamond), how many
    buttons go down each column, and what it shows (icons, icons and names, or names only).
- **Buttons** tab: untick buttons to take them out of the menu, drag them or use the arrows to
  change the order, or sort them by name again. Click a button's red dot to turn its alerts off
  (or on again), and right-click its name to rename it. Below the list: hide the addons' own minimap
  buttons (or keep them), collect hand-made minimap buttons too, show addons without a minimap
  button too (only in the addon compartment, or only for broker displays), and include
  Blizzard's expansion button.
- **Behavior** tab:
  - Open the menu on mouseover. It closes when you click anywhere else, or instead a moment
    after the mouse leaves it; and after you click a button (on at first; after a right-click
    only if the addon opened no dropdown). For the circle and square, which way it opens:
    toward the middle of the screen, left, right, up or down.
  - A dot on the launcher when an addon changes its icon to show something new (BugSack's bug
    turns red), until you open the menu; the buttons that changed show it too. Icons that change
    as you zone in or out (BigWigs lights up in an instance) don't count. And a short pulse when
    an addon adds a button while you play.
  - Locked or not: unlocked, drag the launcher to move it; locked, Shift-drag still moves it.
    "Reset position" puts it back.
  - Settings for this character only, or shared by all your characters (switching reloads the
    interface), and "Reset all settings".

**In Blizzard's Options**, on the AddOns tab (or type `/satellite`): the same button options, and
a button that opens the launcher settings.

## Good to know

- The launchers you can put anywhere (circle, square, side bar, the menu always open) are drawn
  above the action bars.
- Hand-made minimap buttons (addons that make their own, without LibDBIcon) are moved into the
  menu as they are: they keep their own clicks, tooltip and menus. Satellite stops the addon
  from moving them back while they're there. Untick one in the Buttons tab, or turn the option
  off, and it goes back to its place on the minimap. Buttons of addons that also have a
  LibDBIcon button start unticked, so they don't show twice. Plumber's Expansion Summary starts
  unticked both ways: it stays on the minimap, like Blizzard's expansion button.
- In combat, `/satellite` opens the launcher settings: Blizzard's Options can't open then.
- Order and hidden buttons are kept while an addon is turned off; after 30 days without it,
  they're forgotten.

## Commands

| Command              | What it does           |
|----------------------|------------------------|
| `/satellite`         | Open the settings      |
| `/satellite list`    | List the buttons found |
| `/satellite reset`   | Put the launcher back  |
| `/satellite debug`   | Toggle debug output    |

## Languages

English, German, French, Italian, Russian, Spanish, Portuguese, Chinese (simplified and
traditional) and Korean.

## License

[MIT](LICENSE)
