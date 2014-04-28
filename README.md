-----------------------------------------------------------------------------------------------
-- Overview
-----------------------------------------------------------------------------------------------
This addon aim to be an Wildstar equivalent of Bagnon. You can configure this size and basic appearance to have a light replacement of the huge Inventory stock addon.
Currently the addon don't remove the stock Inventory addon to let you access virtual inventory and crafting inventory until this feature is added to SpaceStashInventory. For quick access, you can create a macro to bind the addon to a key on your bar with "/ssi" command.

-----------------------------------------------------------------------------------------------
-- Commands
-----------------------------------------------------------------------------------------------
/ssi : This command toggle the visibility state of the SpaceStashInventory
/ssi help : Show this help
/ssi option RowSize [number] : define the number of item per row you want.
/ssi option IconSize [number] : define size of item icons.
/ssi option currency [ElderGems,Prestige,Renown,CraftingVouchers] : define the currently tracked alternative currency.
/ssi redraw : debuging purpose - redraw the bag window
/ssi info : debuging purpose - send the metatable to GeminiConsole

-----------------------------------------------------------------------------------------------
-- Missing features before 1.0
-----------------------------------------------------------------------------------------------
The addon is in an early stage so some features are missing. Here is a non-exhaustive list :

1	Config : A window to configure the addon without commands
2.	Bags : Add a toggle button to display or not bags item.
3.	Currencies : Add two small button to change the alternative currency displayed and/or a little menu on right clic.
4.	Bank : Change the stock bank addon with SpaceStashBank.
5.	Search box : highlight item in your inventory based on search patterns
6.	Salvaging : Chose between the current ImprovedSalvage or a toggle button highlight salvageable items and to salvage clicked items. 

-----------------------------------------------------------------------------------------------
-- Possible features
-----------------------------------------------------------------------------------------------
This features mostly depend of evolution of addon Libraries like Gemini.

*	Ability to other modder to define the salvaging and previewing method
*	Config profiles
*	Alt bag access to view items in your alt inventory / bank
*	A customizable data display of other addon

-----------------------------------------------------------------------------------------------
-- Known bugs
-----------------------------------------------------------------------------------------------
*	Inventory dont resize with bag changes.
*	The new item sprit dont fade until the item is moved.
*	Impossible to destroy items.

-----------------------------------------------------------------------------------------------
-- Changelog
-----------------------------------------------------------------------------------------------
-- beta2 --
*	Added an icon for item that cannot be used.
*	Removed GeminiConsole dependancy
*	Added a command /ssi redraw for debuging purpose.
*	Added this readme file.
*	Fixed command /ssi option currency.
*	Command /ssi option BoxPerRow and SquarePerRow have been renamed RowSize and IconSize.

-- beta1 --
*	Initial release
