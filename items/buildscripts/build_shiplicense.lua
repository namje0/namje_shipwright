function build(directory, config, parameters, level, seed)
    local ship_type = config.shipType
    local ship_config = root.assetJson("/namje_ships/ships/".. ship_type .."/ship.config")
    if not ship_config then
        error("namje // ship config not found for " .. ship_type)
    end
    if ship_config.ship ~= ship_type then
        error("namje // ship config does not match ship type " .. ship_type)
    end
    
    config.tooltipFields = config.tooltipFields or {}

    config.tooltipFields.shipImage = "/namje_ships/ships/" .. ship_type .. "/ship_preview.png" or ""
    config.tooltipFields.crewLabel = ship_config.recommended_crew_size and "^orange;Recommended Crew Size:^reset; " .. ship_config.recommended_crew_size or "^orange;Recommended Crew Size:^reset; ^red;N/A^reset;"
    config.tooltipFields.cargoLabel = ship_config.atelier_stats.cargo_hold_size and "^orange;Ship Cargo Hold Size:^reset; " .. ship_config.atelier_stats.cargo_hold_size or "^orange;Ship Cargo Hold Size:^reset; ^red;N/A^reset;"
    config.tooltipFields.speedLabel = ship_config.base_stats.ship_speed and "^orange;Ship Speed:^reset; " .. ship_config.base_stats.ship_speed or "^orange;Ship Speed:^reset; ^red;N/A^reset;"
    config.tooltipFields.fuelLabel = ship_config.base_stats.max_fuel and "^orange;Max Fuel:^reset; " .. ship_config.base_stats.max_fuel or "^orange;Max Fuel:^reset; ^red;N/A^reset;"
    config.tooltipFields.efficiencyLabel = ship_config.base_stats.fuel_efficiency and "^orange;Fuel Efficiency:^reset; " .. (ship_config.base_stats.fuel_efficiency*100) .. "%" or "^orange;Fuel Efficiency:^reset; ^red;N/A^reset;"

    config.tooltipFields.descriptionLabel = ship_config.description or ""
    config.tooltipFields.title = ship_config.name or config.shortdescription

    config.tooltipFields.subTitle = ship_config.manufacturer
    config.tooltipFields.manufacturerImage = ship_config.manufacturer_icon or ""
    return config, parameters
end