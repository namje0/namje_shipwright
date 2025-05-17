local mission_info = "main.missions.mission_info"
local mission_list = "main.missions.mission_select.mission_list"
local tabs = {
    {"main.missions", "main.missions.mission_select.mission_list"},
    {"main.home"}
}
local current_tab = nil

function init()
    swap_tabs("show_home")
end

function swap_tabs(tab)
    if tab == "show_missions" then
        if swap_to_tab("main.missions") then
            mission_tab()
        end
    elseif tab == "show_crew" then

    elseif tab == "show_ship_info" then

    elseif tab == "show_settings" then

    elseif tab == "show_home" then
        if swap_to_tab("main.home") then
            update_directory({"home"})
            --mission_tab()
        end
    end
end

function swap_to_tab(tab)
    if current_tab == tab and tab ~= nil then
        return false
    end
    for i = 1, #tabs do
        if tabs[i][2] then
            widget.clearListItems(tabs[i][2])
        end
        if tabs[i][1] == tab then
            current_tab = tabs[i][1]
            widget.setVisible(tabs[i][1], true)
        else
            widget.setVisible(tabs[i][1], false)
        end
    end
    if current_tab == tab then
        return true
    end
    if tab ~= nil then
        sb.logInfo("namje // sail tab not found: " .. tab)
    end
    return false
end

function update_directory(directory)
    local result = "root/"
    for i, v in ipairs(directory) do
        result = result .. v
        if i < #directory then
            result = result .. "/"
        end
    end
    widget.setText("directory_text", result)
end

function mission_tab()
    update_directory({"missions"})

    widget.clearListItems(mission_list)
    widget.setButtonEnabled(mission_info .. ".start_mission", false)

    local save = player.save()
    local ai_state = save.aiState
    local available_missions = ai_state.availableMissions
    local completed_missions = ai_state.completedMissions

    if #available_missions > 0 then
        for i = 1, #available_missions do
            local mission_info = root.assetJson("/ai/"..available_missions[i]..".aimission")

            local list_item = mission_list .. "."..widget.addListItem(mission_list)
            widget.setText(list_item..".itemName", mission_info.speciesText.default.buttonText)
            widget.setImage(list_item..".itemIcon", "/ai/" .. mission_info.icon or "/ai/missionhuman1icon.png")
            widget.setData(list_item, { mission_info, false })
        end
    end
    
    if #completed_missions > 0 then
        --replay header to separate mission type
        local list_header = mission_list .. "." ..widget.addListItem(mission_list)
        widget.setText(list_header..".itemName", "^white;Replays^reset;")
        widget.removeChild(list_header, "itemIcon")
        widget.setImage(list_header..".background", "/interface/namje_sail/replayheader.png")

        for i = 1, #completed_missions do
            local mission_info = root.assetJson("/ai/"..completed_missions[i]..".aimission")

            local list_item = mission_list .. "."..widget.addListItem(mission_list)
            widget.setText(list_item..".itemName", mission_info.speciesText.default.repeatButtonText)
            widget.setImage(list_item..".itemIcon", "/ai/" .. mission_info.icon or "/ai/missionhuman1icon.png")
            widget.setData(list_item, { mission_info, true })
        end
    end
end

function select_mission()
    local selected_mission = widget.getListSelected(mission_list)
    if not selected_mission then
        return
    end
    local mission_data = widget.getData(mission_list .. "." .. selected_mission)
    if not mission_data then
        return
    end

    local replay = mission_data[2]

    update_directory({"missions", mission_data[1].missionName .. ".msn"})
    
    widget.setText(mission_info..".description", "^gray;> " .. (replay and "^orange;[Replay] ^gray;" or "") ..  mission_data[1].speciesText.default.selectSpeech.text)
    widget.setButtonEnabled(mission_info .. ".start_mission", true)
end

function start_mission()
    local selected_mission = widget.getListSelected(mission_list)
    if not selected_mission then
        return
    end
    local mission_data = widget.getData(mission_list .. "." .. selected_mission)
    if not mission_data then
        return
    end
    player.warp('instanceworld:' .. mission_data[1].missionWorld, mission_data[1].warpAnimation or 'beam')
    pane.dismiss()
end