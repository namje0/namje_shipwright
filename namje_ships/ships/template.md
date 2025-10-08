
    // The id should be unique and not conflict with any other ship id.
    "id" : "namje_template",

    // The ingame display name for the ship.
    "name" : "AOM Kellion",

    // Flavor text. Currently only used for auto-generated ship licenses
    "description" : "An outdated maintenance shuttle used by the Protectorate. This one was carrying capsules to be sent out into the galaxy. \nIt's seen better days, but it has ^cyan;FTL^reset; capability and a decent cargo hold size.",

    // Flavor text. Currently only used for auto-generated ship licenses
    "manufacturer" : "Terrene Protectorate",
    "manufacturer_icon" : "/namje_ships/manufacturers/protectorate.png",
    
    // Also flavor text that appears on ship licenses. 
    // Shouldn't be higher than the maximum crew size.
    "recommended_crew_size" : "1-2",

    // If you did NOT include this framework as a dependency and have your
    // mod priority lower than it, namjeShipwright will automatically
    // generate a license for your ship with this set to true.
    "auto_create_license" : true,

    // The price of the ship in pixels. 
    // Used for the ship license item and salvage refunds.
    "price" : 10000,

    // If auto_create_license is true, adds it to the Penguin Bay in the outpost.
    "add_to_penguin_bay" : true,

    // The item icon for the ship license. Exclude to use the default icon.
    "license_icon" : "/namje_ships/ships/namje_startership/license_icon.png",

    // Vanilla ship stats. If you are making a normal FTL capable ship, keep
    // the capabilities the same.
    "base_stats" : {
        "capabilities" : ["teleport", "planetTravel", "systemTravel"],
        "fuel_efficiency" : 0,
        "max_fuel" : 5000,
        "ship_speed" : 30,
        "crew_size" : 2
    },

    // namjeShipwright specific stats.
    "namje_stats" : {

        // The size of the ship's cargo hold. The cargo hold is tied the ship
        // and is not a normal container object.
        "cargo_size" : 150,

        // The center position of the ship, used for positioning it 
        // during initial ship creation.
        // Only needed for ships using the .dungeon format.
        "ship_center_pos" : [74, 42]
    },

    // Upgrades are levels from 1 to 5. While they should be balanced, you can
    // do whatever you want with them.
    "stat_upgrades" : {

        // FrackinUniverse introduces scaling fuel costs, so the max_fuel will
        // be multipled by this factor to compensate.
        "fu_fuel_modifier" : 2,

        "max_fuel" : [
            { "stat": 5500, "description": "Increases maximum fuel capacity to 5500." },
            { "stat": 6000, "description": "Increases maximum fuel capacity to 6000." },
            { "stat": 6500, "description": "Increases maximum fuel capacity to 6500." },
            { "stat": 7000, "description": "Increases maximum fuel capacity to 7000." },
            { "stat": 7500, "description": "Increases maximum fuel capacity to 7500." }
        ],
        "fuel_efficiency" : [
            { "stat": 0.1, "description": "Improves fuel costs for FTL travel by 10%" },
            { "stat": 0.2, "description": "Improves fuel costs for FTL travel by 20%" },
            { "stat": 0.3, "description": "Improves fuel costs for FTL travel by 30%" },
            { "stat": 0.4, "description": "Improves fuel costs for FTL travel by 40%" },
            { "stat": 0.5, "description": "Improves fuel costs for FTL travel by 50%" }
        ],
        "ship_speed": [
            { "stat": 45, "description": "Improves travel speed within a system by 50%" },
            { "stat": 60, "description": "Improves travel speed within a system by 100%" },
            { "stat": 75, "description": "Improves travel speed within a system by 150%" },
            { "stat": 90, "description": "Improves travel speed within a system by 200%" },
            { "stat": 105, "description": "Improves travel speed within a system by 250%" }
        ],
        "crew_size": [
            { "stat": 4, "description": "Increases maximum crew capacity to 4." },
            { "stat": 6, "description": "Increases maximum crew capacity to 6." },
            { "stat": 8, "description": "Increases maximum crew capacity to 8." },
            { "stat": 10, "description": "Increases maximum crew capacity to 10." },
            { "stat": 12, "description": "Increases maximum crew capacity to 12." }
        ],
        "cargo_size": [
            { "stat": 200, "description": "Increases cargo hold capacity by 50 units." },
            { "stat": 250, "description": "Increases cargo hold capacity by 100 units." },
            { "stat": 300, "description": "Increases cargo hold capacity by 150 units." },
            { "stat": 350, "description": "Increases cargo hold capacity by 200 units." },
            { "stat": 400, "description": "Increases cargo hold capacity by 250 units."}
        ]
    },

    // The dungeon id for the ship, or the ship code.
    "ship" : "namje_aomkellion"
