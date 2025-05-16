
function init()

end

function button_press(type)
    if type == "show_missions" then
        widget.clearListItems("main.mission_list")

        local save = player.save()
        local ai_state = save.aiState
        local available_missions = ai_state.availableMissions
        local completed_missions = ai_state.completedMissions

        if #available_missions > 0 then
            for i = 1, #available_missions do
                local mission_info = root.assetJson("/ai/"..available_missions[i]..".aimission")

                local list_item = "main.mission_list."..widget.addListItem("main.mission_list")
                widget.setText(list_item..".itemName", mission_info.speciesText.default.buttonText)
                widget.setImage(list_item..".itemIcon", "/ai/" .. mission_info.icon or "/ai/missionhuman1icon.png")
                widget.setData(list_item, { index = i, })
            end
        end
        
        --replay header to separate mission type
        local list_header = "main.mission_list."..widget.addListItem("main.mission_list")
        widget.setText(list_header..".itemName", "^orange;Replays^reset;")
        widget.removeChild(list_header, "itemIcon")
        widget.removeChild(list_header, "background")

        if #completed_missions > 0 then
            for i = 1, #completed_missions do
                local mission_info = root.assetJson("/ai/"..completed_missions[i]..".aimission")

                local list_item = "main.mission_list."..widget.addListItem("main.mission_list")
                widget.setText(list_item..".itemName", mission_info.speciesText.default.repeatButtonText)
                widget.setImage(list_item..".itemIcon", "/ai/" .. mission_info.icon or "/ai/missionhuman1icon.png")
                widget.setData(list_item, { index = i, })
            end
        end
    elseif type == "show_crew" then

    elseif type == "show_ship_info" then

    elseif type == "show_settings" then

    end
end

function update_directory()

end