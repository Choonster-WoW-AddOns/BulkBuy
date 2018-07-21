## 1.07
- Bump TOC Interface version to 8.0
- Add .travis.yml file and TOC properties for the BigWigs packager script
	- https://www.wowinterface.com/forums/showthread.php?t=55801

## 1.06
- Fix bugs related to 7.2 merchant frame changes
- Change how items sold for non-gold currencies are purchased:
	- If an item is sold for a non-gold currency, the AddOn will now buy the largest multiple of the stack size sold by the merchant less than the amount entered in the stack split popup.
	- The previous behaviour introduced in 1.05 was to buy the stack size sold by the merchant multiplied by the amount entered in the stack split popup.
- Bump TOC Interface version to 7.2

## 1.05
- Fix purchasing of items sold for non-gold currencies
	- Thanks to Exhunt for posting this change on [Curse](https://mods.curse.com/addons/wow/bulk-buy?comment=12)
- Bump TOC Interface version to 7.1

## 1.04
- Fix "attempt to compare number with nil"
    - `ITEM_QUALITY` constants were changed to Lua enums (`LE_ITEM_QUALITY`) in 6.0

## 1.03
- Create GitHub repository for AddOn

## 1.02
- Buying items that cost proper currencies like Justice Points should now be fixed. This issue wasn't affecting items bought with other items like Inks from the Ink Trader. 

## 1.01
- Added support for bulk buying items that cost non-gold currencies. 

## 1.00
- AddOn Created!
