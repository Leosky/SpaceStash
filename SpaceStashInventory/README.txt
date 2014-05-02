Overview
========
This addon aim to be an Wildstar equivalent of Bagnon. You can configure this size and basic appearance to have a light replacement of the huge Inventory stock addon.

New in this version
===================
* Keybinding ; no need to make this crappy macro anymore !
* Previewin', splitin', deletin', salvagin' n 'deletin' (drag and drop out of the inventory) YEEEEEAH boy!
* New style more in phase with base UI and some sounds, cuz previous hurted some artistic sens... Damn, it mean i sill don't have the artistic sens, I should drink more whiskey.

Commands
========
/ssi : This command toggle the visibility state of the SpaceStashInventory
/ssi help : Show this help
/ssi option RowSize [number] : define the number of item per row you want.
/ssi option IconSize [number] : define size of item icons.
/ssi option currency [ElderGems,Prestige,Renown,CraftingVouchers] : define the currently tracked alternative currency.
/ssi redraw : debuging purpose  redraw the bag window
/ssi info : debuging purpose send the metatable to console

Missing features before 1.0
===========================
The addon is in an early stage so some features are missing. Here is a nonexhaustive list :

1	Config : A window to configure the addon without commands
2.	Bags : Add a toggle button to display or not bags item.
3.	Currencies : Add two small button to change the alternative currency displayed and/or a little menu on right clic.
4.	Bank : Change the stock bank addon with SpaceStashBank.
5.	Search box : highlight item in your inventory based on search patterns

Possible features
=================
This features mostly depend of evolution of addon Libraries like Gemini.

*	Ability to other modder to define the salvaging and previewing methods.
*	Config profiles
*	Alt bag access to view items in your alt inventory / bank
*	A customizable data display of other addon.
*	Bag sorting.


Known bugs
==========
The new item sprit dont fade until the item is moved or the inventory closed.

Changelog
=========
beta2 
-----
*	The addon now remplace the base addon without need to rebind the inventory keybinding or use a macro.
*	Addon added to the menu list.
*	Item now are marked as viewed when then inventory is closed or moved (not on mouse over actually)
*	Salvaging button open a Salvaging window.
*	Added location and currency saving between characters.
*	Addded item preview and split.
*	Added an icon for item that cannot be used.
*	Removed GeminiConsole dependancy
*	Added a command /ssi redraw for debuging purpose.
*	Added this readme file.
*	Fixed command /ssi option currency.
*	Command /ssi option BoxPerRow and SquarePerRow have been renamed RowSize and IconSize.

beta1 
-----
Initial release