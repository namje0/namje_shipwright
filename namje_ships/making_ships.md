# Making your own ship template

## Ship building guide

- Ships need to be within `{500, 500}` and `{1500, 1500}` of the shipworld. If you are even halfway close to reaching these borders, your ship is too big which will cause issues.
- Vanilla ship teleporters are not supported as they do not set the new ship spawn. Please use the ones supplied in this framework, or make your own derived off of them. If you are making your ship for Frackin Universe, you can use their BYOS teleporters.
- If you want to support Frackin Universe, add the `FTL Panel` to anywhere in your ship. It will be automatically patched to function as a Small FTL Drive, which is required to travel in FU.
- Ships should have a pilot chair, a sail and a fuel hatch (obviously)
- If you plan on using the Cargo Hold feature supplied in this framework, include one of the cargo hold accesses. Please note that if you don't plan on including the Cargo Hold, other ships probably will, reducing the effectiveness of your ship.
- If you are making your ship **from table**, it will not support wiring. Any wired objects will be reset.
- If you intend on making a regular ship template, items and objects on your ship template should be balanced. Giving the player a fully upgraded crafting area and a bunch of pixels is probably unbalanced. Giving the player a minifridge and microwave with their ship is balanced enough. Ships are intended to be mostly canvases to put stuff in.

## Ship format

There are two methods for building the actual ship:

### From Dungeon

namjeShipwright templates support using dungeons. **This is the recommended ship format and has no limitations.**

If you don't know how to make a dungeon in Starbound, [refer to this article](https://starbounder.org/Modding:Tiled)

### From Table (WIP)

This framework comes with the ability to serialize your in-game ship into a table, which can be further turned into a string that can be used in place of a dungeon id. namjeShipwright will build the ship from the table.

Temporarily, the item `namje_saveshiptemplate` can be used to save your ship to `starbound.config`. Copy the ship template from there and use it as the `ship` in your .namjeship file.

Limitations:
- Wiring is not supported. This is a Starbound limitation.

## Ship folder structure

Copy one of the [existing ship folders in the framework](https://github.com/namje0/namje_shipwright/tree/main/namje_ships/ships/namje_startership) and replace it with your own dungeon and information. For best practices, the name of the template folder, dungeon, and json file should be consistent with the id set in your **ship.namjeship** file.

Ship folders should have a **ship_preview.png** that is 1210 x 432 in size (or the same aspect ratio) for best results. 

![Ship preview example](https://github.com/namje0/namje_shipwright/blob/main/namje_ships/ships/namje_startership/ship_preview.png)

The most important part of a ship template is the **ship.namjeship** file. Refer to the [template](https://github.com/namje0/namje_shipwright/blob/main/namje_ships/ships/template.config) for how to customize the ship's stats and information.

## Ship licenses

The primary method of obtaining and changing to a new ship in this framework is through ship license items.    
namjeShipwright will automatically generate ship licenses for any mod that **is loaded before this mod.** (unless you've disabled it for the ship)

This framework provides functionality for changing ships without licenses, so it is not required. You can also opt for making your own ship license instead of having it be generated.

The option to sell the ship license at penguin bay is provided for generated licenses. Other than that, you will have to implement your own method of acquiring them, either through a vendor or something else.