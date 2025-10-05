![bongbong](https://i.imgur.com/FN9fjwi.gif)
# 🚀 namjeShipwright
> This framework requires [OpenStarbound](https://github.com/OpenStarbound/OpenStarbound)

> [!WARNING]
> namjeShipwright is still in development and shouldn't be used in an actual playthrough. **Please report any bugs**
> This framework has not been tested in multiplayer.
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
- Custom species are automatically patched for BYOS.
### Ship templates
This framework allows you to create and use ship templates.
- Automatic ship license generation for `.namjeship` files.
- Choose to either use a dungeon file for templates, or save your current in-game ship's design as a template.
    - `.dungeon` files take up less space.
### Owning multiple ships
Multiple ships can be owned by a player in this framework, and players can freely swap between them.
- Different ships have their own separate cargo holds.
- Ships retain their celestial position and will appear in that position when swapped to.
    - This will play the warp/fly animation everytime due to limitations. Only slightly immersion breaking.
- This framework allows you to increase ship slots up to a set maximum limit. You can use this to create rewards for quests, craftables, and more.
### New S.A.I.L Interface
A new larger S.A.I.L interface that allows for custom themes via `.namjetheme` files.
- Searches the player's save for current and previous missions instead of doing guesswork.
- Allows for swapping between owned ships and seeing ship information.
- Settings page can be added to by modders. (TBA)
### New Upgrade System
Individual ship stats can be upgraded at a ship service technician. This framework implements one at the outpost.
- Max fuel, fuel efficiency, ship speed, crew size, and cargo hold capacity can be upgraded.
- Up to five module slots can be added to every ship. See the Ship Modules section for more information.
- Ship icon and name can also be changed at a ship service technician.
### Ship Modules
Ship Modules can provide a wide range of benefits to your ships.
- Ships do not come with any modules or module slots by default.
- For modules with scripts, only the active ship's modules are used.
- Module script delta is 60. This may be changed later.
- Module scripts are only initialized for the ship owner clientside when they are on their ship.
    - Use stagehands to create global module effects
### Cargo Hold
Ships come with a cargo hold, which is a storage container linked to the ship.
- When you overwrite a ship, its cargo is automatically moved to the new one.
### FrackinUniverse Compatiblity
Compatible with some caveats. Should be stable, but not fully tested. Use with caution!
- FU BYOS is instantly enabled, and there is no option to choose your starter ship.
- FU's exclusive S.A.I.L. can be accessed via a new button on the S.A.I.L. interface.
- "Crew Capacity" upgrade is no longer available as crew capacity is handled through crew beds.
    - Inactive crew are not handled in the default S.A.I.L. interface and are instead handled in FU's interface.
- "FTL Panel" object is patched to function similarly to a Small FTL Drive. (TBA)
- Ship maximum fuel is multipled by `fu_fuel_modifier` set in the `.namjeship` file.

## Technical Stuff
- This framework caches the position of loaded chunks/sectors around the player that have collisions/background tiles in them to improve saving and loading times. This should cover all regular gameplay cases, though certain cases may result in chunks not being registered:
    - Placing down a large dungeon or build with an external mod (e.g Base In A Box) and swapping ships without exploring the whole thing
    - Placing things down and leaving the 96x96 scan area faster than the region cache update interval (2s)
    - Making your zoom level so small that the game does not load the sectors adjacent to you
- You shouldn't make extremely big ships in base Starbound, and you shouldn't in this framework either. Stored ships are pretty large and can bloat the player file, and larger ships will have longer loading times for serializing. An extremely large ship will take a while to swap to and from.
- Plants will not grow in inactive ships, but their growth stage is saved.

## Incompatabilities
The following list does not include Frackin Universe, as FU compatibility is built into the framework.
- Other BYOS mods
- S.A.I.L mods
- Any mod that calls `player.upgradeShip` may cause issues and/or brick your save

## Upcoming Features
- "Save as template" option on SAIL
- Make crew members per-ship
- Customizable SAIL pet
- Add failsafe for existing characters without the framework enabled

## Bugs
- Lounging crew members may not get teleported on a ship swap.
- Colony deed tenants may be unlinked from the deed and have a new tenant spawn.
- Colony deed tenants on your ship will have their quests failed when swapping ships. This is a limitation from how ships are stored
- Harvestables (e.g mothtrap) are inconsistent on ship swap and may reset.
- Dropped items won't be stored on ship swap.