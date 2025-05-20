require "/scripts/messageutil.lua"

local ai_config = nil
local tabs = {
    {"main.missions", "main.missions.mission_select.mission_list", "main.missions.mission_info"},
    {"main.home"},
    {"main.crew", "main.crew.crew_select.crew_list", "main.crew.crew_info"}
}
local current_tab = nil
local player_save = nil

local crew = nil
local promise = nil

local sail_canvas = nil
local racial_sail = nil
local speaker_img = nil
local speaker_state = "idle"
local scanline_timer = 0
local speaker_timer = 0
local static_timer = 0
local static_frame = 0
local scan_frame = 0
local speaker_frame = 0

function init()
    promise = PromiseKeeper.new()
    player_save = player.save()

    init_sail()

    swap_tabs("show_home")
    refresh_crew()
end

function update(dt)
    promise:update()

    if sail_canvas then
        if speaker_timer < world.time() then
            speaker_timer = world.time() + (ai_config.aiAnimations[speaker_state].animationCycle or 0.5)
            speaker_frame = (speaker_frame + 1) % ai_config.aiAnimations[speaker_state].frameNumber
        end
        
        if scanline_timer < world.time() then
            scanline_timer = world.time() + 0.05
            scan_frame = (scan_frame + 1) % 14
        end

        if static_timer < world.time() then
            static_timer = world.time() + 0.1
            static_frame = (static_frame + 1) % 4
        end
        draw()
    end
end

function draw()
    local static_opacity = ai_config.staticOpacity
    local scan_opacity = ai_config.scanlineOpacity

	sail_canvas:clear()
    sail_canvas:drawImage(string.gsub(speaker_img, "<index>", speaker_frame), {0,0})
    sail_canvas:drawImage("/ai/" .. racial_sail.staticFrames .. ":" .. static_frame, {0,0}, nil, "#FFFFFF" .. a_to_hex(static_opacity), false)
    sail_canvas:drawImage("/ai/scanlines.png" .. ":" .. scan_frame, {0,0}, nil, "#FFFFFF" .. a_to_hex(scan_opacity), false)
end

function change_speaker_state(new_state)
    speaker_state = new_state
    speaker_img = string.gsub("/ai/" .. ai_config.aiAnimations[speaker_state].frames, "<image>", racial_sail.aiFrames)
end

function init_sail()
    ai_config = root.assetJson("/ai/ai.config")
    racial_sail = ai_config.species[player.species()] or ai_config.species["human"]
    sail_canvas = widget.bindCanvas("sail_portrait")
    static_timer = world.time()

    change_speaker_state("unique")
end

function refresh_crew()
    crew = nil
    promise:add(world.sendEntityMessage(player.id(), "namje_return_crew"), 
        function(result) 
            crew = result 
        end, 
        function(err) 
            sb.logInfo("namje // crew promise error: ".. err) 
        end
    )
end

function swap_tabs(tab)
    if tab == "show_missions" then
        if swap_to_tab("main.missions") then
            mission_tab()
        end
    elseif tab == "show_crew" then
        if swap_to_tab("main.crew") then
            crew_tab()
        end
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

function crew_tab()
    local crew_info = tabs[3][3]
    local crew_list = tabs[3][2]

    widget.clearListItems(crew_list)
    widget.setButtonEnabled(crew_info .. ".dismiss_crew", false)
    widget.setText(crew_info .. ".description", "^gray;> Crew member information will be displayed here.")

    update_directory({"crew"})

    if #crew <= 0 then
        return
    end

    for i = 1, #crew do
        local member = crew[i]

         local list_item = crew_list .. "."..widget.addListItem(crew_list)
        widget.setText(list_item..".item_name", member.name)
        
        local canvas = widget.bindCanvas(list_item..".portrait")
        for _, portrait in ipairs(member.portrait) do
            canvas:drawImage(portrait.image, {-15.5, -19.5})
        end

        widget.setData(list_item, { i })
    end
end

function select_crew()
    local crew_info = tabs[3][3]
    local crew_list = tabs[3][2]
    local selected_member = widget.getListSelected(crew_list)

    if not selected_member then
        return
    end

    local member_index = widget.getData(crew_list .. "." .. selected_member)[1]

    if not member_index then
        return
    end

    local member_data = crew[member_index]

    update_directory({"crew", string.lower(member_data.name) .. ".profile"})

    widget.setText(crew_info..".description", member_data.description)
    widget.setButtonEnabled(crew_info .. ".dismiss_crew", true)
end

function dismiss_crew()
    local crew_list = tabs[3][2]
    local selected_member = widget.getListSelected(crew_list)

    if not selected_member then
        return
    end

    local member_index = widget.getData(crew_list .. "." .. selected_member)[1]

    if not member_index then
        return
    end

    local member_data = crew[member_index]

    --TODO: confirmation for dismissal
    world.sendEntityMessage(player.id(), "namje_dismiss_crew", member_data.podUuid)
    --refresh_crew() --doesn't update the crew for some reason here? likely cant grab the updated crew size until widget is reopened
    table.remove(crew, member_index)
    --refresh tab
    crew_tab()
end

function mission_tab()
    local mission_info = tabs[1][3]
    local mission_list = tabs[1][2]

    update_directory({"missions"})

    widget.clearListItems(mission_list)
    widget.setButtonEnabled(mission_info .. ".start_mission", false)
    widget.setText(mission_info .. ".description", "^gray;> Mission information will be displayed here.")

    local ai_state = player_save.aiState
    local available_missions = ai_state.availableMissions
    local completed_missions = ai_state.completedMissions

    if #available_missions > 0 then
        for i = 1, #available_missions do
            local mission_info = root.assetJson("/ai/"..available_missions[i]..".aimission")

            local list_item = mission_list .. "."..widget.addListItem(mission_list)
            widget.setText(list_item..".item_name", mission_info.speciesText.default.buttonText)
            widget.setImage(list_item..".item_icon", "/ai/" .. mission_info.icon or "/ai/missionhuman1icon.png")
            widget.setData(list_item, { mission_info, false })
            widget.setVisible(list_item..".header_back", false)
        end
    end
    
    if #completed_missions > 0 then
        --replay header to separate mission type
        local list_header = mission_list .. "." ..widget.addListItem(mission_list)
        widget.setText(list_header..".item_name", "^white;Replays^reset;")
        widget.removeChild(list_header, "item_icon")
        widget.removeChild(list_header, "background")
        --widget.setImage(list_header..".background", "/interface/namje_sail/replayheader.png")

        for i = 1, #completed_missions do
            local mission_info = root.assetJson("/ai/"..completed_missions[i]..".aimission")

            local list_item = mission_list .. "."..widget.addListItem(mission_list)
            widget.setText(list_item..".item_name", mission_info.speciesText.default.repeatButtonText)
            widget.setImage(list_item..".item_icon", "/ai/" .. mission_info.icon or "/ai/missionhuman1icon.png")
            widget.setData(list_item, { mission_info, true })
            widget.setVisible(list_item..".header_back", false)
        end
    end
end

function select_mission()
    local mission_info = tabs[1][3]
    local mission_list = tabs[1][2]
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
    local mission_list = tabs[1][2]
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

function a_to_hex(a)
    local alpha_255 = math.floor(math.max(0, math.min(255, a * 255)))
    local a_hex = string.format("%02x", alpha_255)
    return string.upper(a_hex)
end