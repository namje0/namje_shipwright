# Making your own ship template

Currently, this framework only supports using dungeons for ship templates.    
If you don't know how to make a dungeon in Starbound, [refer to this article](https://starbounder.org/Modding:Tiled)

Copy one of the [existing ship folders in the framework](https://github.com/namje0/namje_shipwright/tree/main/namje_ships/ships/namje_startership) and replace it with your own dungeon and information. For best practices, the name of the template folder, dungeon, and json file should be consistent with the id set in your **ship.namjeship** file.

Ship folders should have a **ship_preview.png** that is 1210 x 432 in size (or the same aspect ratio) for best results.

![Ship preview example](https://github.com/namje0/namje_shipwright/blob/main/namje_ships/ships/namje_startership/ship_preview.png)

The most important part of a ship template is the **ship.namjeship** file. Refer to the [template](https://github.com/namje0/namje_shipwright/blob/main/namje_ships/ships/template.config) for how to customize the ship's stats and information.

## Ship licenses

The primary method of obtaining and changing to a new ship in this framework is through ship license items.    
namjeShipwright will automatically generate ship licenses for any mod that **is loaded before this mod.** (unless you've disabled it for the ship)

This framework provides functionality for changing ships without licenses, so it is not required. You can also opt for making your own ship license instead of having it be generated.

The option to sell the ship license at penguin bay is provided for generated licenses. Other than that, you will have to implement your own method of acquiring them, either through a vendor or something else.
