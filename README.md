![bongbong](https://i.imgur.com/FN9fjwi.gif)
# namjeShipwright
> This framework requires [OpenStarbound](https://github.com/OpenStarbound/OpenStarbound)

> [!WARNING]
> namjeShipwright is still in development and shouldn't be used in an actual playthrough. **Please report any bugs**

> [!WARNING]
> Don't use it on a pre-existing character.

A ship overhaul framework that adds a modern BYOS implementation, the ability to store and move between multiple ships, a new ship upgrading implementation, and the ability to create and use ship templates.

Steam Link (TBA)

## For Modders
Contributions to the framework are welcome!

Refer to [this guide](https://github.com/namje0/namje_shipwright/blob/main/namje_ships/making_ships.md) for making ship templates.

## Features
### Build Your Own Ship (BYOS)
This framework removes racial ships and replaces them with ships made out of blocks, letting you edit and shape them as needed.
- Your starter ship is replaced with a non-racial generic ship.
- BYOS cannot be turned off, it is an integral part of this framework.
### Ship templates
This framework allows you to create and use ship templates.
- Automatic ship license generation for `.namjeship` files.
- Choose to either use a dungeon file for templates, or save your current in-game ship's design as a template.
    - `.dungeon` files take up less space.
### Owning multiple ships
Multiple ships can be owned by a player in this framework, and players can freely swap between them.
- Due to a **Starbound limitation**, any wiring will be disconnected when swapping back to a ship. This may be fixed in an future update. Don't count on it though
- This framework allows you to increase ship slots up to a set maximum limit. You can use this to create rewards for quests, craftables, and more.
### New Upgrade System
Individual ship stats can be upgraded at a ship service technician. This framework implements one at the outpost.
- Max fuel, fuel efficiency, ship speed, crew size, and cargo hold capacity can be upgraded.
- Ship icon and name can also be changed at a ship service technician.
### Cargo Hold
Ships come with a cargo hold, which is a storage container linked to the ship.
- When you overwrite a ship, its cargo is automatically moved to the new one.
### Ship Modules
TBA
### FrackinUniverse Compatiblity
Currently incompatible.

## Upcoming Features
- "Save as template" option on SAIL
- Make crew members and animals per-ship
- Customizable SAIL pet
- Slotable ship modules that allow for stuff like stratagems
- Save ship celestial opsition

## Bugs
- Lounging crew members may not get teleported on a ship swap.
- Items may be duplicated if overwriting a ship that has items in storage containers that aren't the cargo hold