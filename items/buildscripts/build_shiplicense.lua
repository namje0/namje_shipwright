function build(directory, config, parameters, level, seed)
    config.tooltipFields = config.tooltipFields or {}

    config.tooltipFields.shipImage = config.shipImage
    config.tooltipFields.crewLabel = config.recCrewSize and "^orange;Recommended Crew Size:^reset; " .. config.recCrewSize or "^orange;Recommended Crew Size:^reset; 0"

    return config, parameters
end