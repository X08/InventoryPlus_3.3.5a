# InventoryPlus by X08 | Dreamwind (Chromiecraft-EU)
Category tabs on the side of your bags (WotLK 3.3.5a). Each tab is a set of item types that belongs in that bag.

## Features
- **Magnet tabs** fade in on the side of every default bag frame; the small **+** tab adds a new one.
- **Exclusive** option per tab: only its types may live in that bag; strangers move to your other bags (filled first) and only stay when nothing else is free.
- **Drag a tab onto another bag**: the tab moves, its items follow, and items that do not belong are swapped out.
- **Hover a tab**: items of that type glow, everything else dims (across all open bags and the bank).
- **Click a tab**: gathers matching items into that bag and sorts it. Shift-click sorts only. Right-click edits.
- **Auto-routing**: looted, bought or withdrawn items move into the bag whose tab holds their type (full bag = item stays).
- **Warehouse**: remembers the bags and bank of every character (worn items are left out). Tooltips show who has an item. The Warehouse page lists items per character, the current one first, with an auction-house style category tree and search on the left. Click a character's name to minimise it; with a category picked, a yellow number next to the name says how many of those items the character has. Hover an icon to see where it is and who else has it. A character showing "nothing recorded yet" has not been scanned successfully: log in on it once and it fills in (the bank part fills in when you visit the bank).
- **Ignore list**: Alt-click an item in your bags (or drop it on the Ignore page) and it is never moved, routed, sorted around or deleted. Hearthstone, totems...
- **Category in tooltips** (option): shows which InventoryPlus category an item belongs to.
- **Junk deletion** (off by default): looted grey items worth less than a limit (default 1s per item; amount syntax 10g34s10c, per item or per stack) are destroyed. Only fresh loot, never quest items. Last deletions listed on the Junk page.
- **Sub-categories**: tick a whole category on a tab, or expand it (+/-) and pick parts. Gear and Weapons split by quality (white, green, blue, epic or better); Crafting splits into Cloth, Leather, Ore & Stone, Herbs, Enchanting, Jewelcrafting, Engineering, Elemental, Inscription and Other materials. A bag with a specific tab (say Gear: Blue) gets those items even if another bag has a plain Gear tab.
- **Soul Shards** (Warlock only, off by default): shards above a limit (default 20) are destroyed, from the last slots first. Soul Shards count as Reagents.
- Item types: Quest, Junk, Gear, Weapons (incl. shields; both by quality), Consumables (cooked/crafted food), Conjured, Raw Food (raw meat, fish, fruit), Crafting (by profession material), Reagents, Gems, Recipes, Containers, Ammo, Glyphs, Miscellaneous.

## Commands
`/inventoryplus` (`/invplus`, `/ip`) options | Shift-click on the + tab opens them (the last used page, or the Warehouse: your choice) | `debug` print routing decisions | `organize` route everything + sort | `sort` | `wh <item>` search warehouse | `offset <x> <y>` nudge tabs

## Notes
- Default bag frames only. English client for item types.
- Special bags (quiver, herb...) are skipped; bank bags work while the bank is open, the main bank slots are highlight-only.
- Hand-moved items are never re-routed; the queue pauses while you hold something on the cursor.
