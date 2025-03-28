function build(directory, config, parameters, level, seed)
    config.tooltipFields = config.tooltipFields or {}

    config.tooltipFields.shipImage = config.shipImage
    config.tooltipFields.crewLabel = config.recCrewSize and "^orange;Recommended Crew Size:^reset; " .. config.recCrewSize or "^orange;Recommended Crew Size:^reset; 0"
    config.tooltipFields.cargoLabel = config.cargoHoldSize and "^orange;Ship Cargo Hold Size:^reset; " .. config.cargoHoldSize or "^orange;Ship Cargo Hold Size:^reset; ^red;N/A^reset;"

    return config, parameters
end