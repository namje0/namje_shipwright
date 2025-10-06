# Making your own ship template

## Ship building guide
The primary intention of ship templates is for them to be a "canvas" for the player to build off of. Leaving empty space for the player is recommended
- Ships should not be excessively large (exceeding 1000 blocks in either direction) or loading problems may occur.
- All ships must include a pilot chair, a SAIL interface, and a fuel hatch.
- Vanilla ship teleporters are not supported. Please use the ones supplied in this framework.
- Ships come with a cargo hold feature. If you would like your ship to make use of it, please include any variation of the **Cargo Hold Access** in your ship.

## Ship format

There are two methods for building the actual ship:

### From Dungeon

namjeShipwright templates support the `.dungeons` format. **This is the recommended ship format and has no limitations.**

If you don't know how to make a dungeon in Starbound, [refer to this article](https://starbounder.org/Modding:Tiled)

### From Ship Code

You are able to save your existing ship as a Base64 ship code. If you put the code as the `ship` argument in a `.namjeship` file, it will build the ship properly.
-Please note that these codes can get extremely long depending on ship size.

## Ship folder structure

The ship folder is pretty simple, review one of the [existing ships in the framework](https://github.com/namje0/namje_shipwright/tree/main/namje_ships/ships/namje_startership).

The `ship.namjeship` file is required to create the ship template. Refer to the [template](https://github.com/namje0/namje_shipwright/blob/main/namje_ships/ships/template.md) for how to customize the ship's stats and information.

Ship folders should have a `ship_preview.png` that is 1210 x 432 in size (or the same aspect ratio) for best results. 

![Ship preview example](https://github.com/namje0/namje_shipwright/blob/main/namje_ships/ships/namje_startership/ship_preview.png)

## Ship licenses

The primary method of obtaining ships in this framework is through ship license items.    
namjeShipwright will automatically generate ship licenses for any mod that **is loaded before this mod**, unless `auto_create_license` is false.

The ship license appearance can be changed with `license_icon`. Remove it to use the default ship license appearance.

This framework also provides functionality for registering ships without licenses.

Penguin Bay at the outpost is automatically patched to sell any licenses for ships that have `add_to_penguin_bay` set to true.