require "/scripts/messageutil.lua"
require "/interface/namje_sail/namje_ai_typer.lua"
require "/scripts/namje_byos.lua"

local tabs = {
    {"main.missions", "main.missions.mission_select.mission_list", "main.missions.mission_info"},
    {"main.home"},
    {"main.crew", "main.crew.crew_select.crew_list", "main.crew.crew_info"},
    {"main.ships", "main.ships.ship_select.ship_list", "main.ships.ship_info"},
    {"main.settings"}
}
local typing_sound = "/sfx/interface/aichatter1_loop.ogg"

local sail_themes = {}
local current_theme, current_tab, player_save, crew, promise, ai_config, sail_canvas, racial_sail, speaker_img, last_selected_widget, localization
local speaker_state = "idle"
local scanline_timer = 0
local speaker_timer = 0
local static_timer = 0
local static_frame = 0
local scan_frame = 0
local speaker_frame = 0

local swap_confirm = false

function init()
    promise = PromiseKeeper.new()
    player_save = player.save()

    localization = root.assetJson("/interface/namje_sail/localization.config")

    init_themes()
    init_sail()

    refresh_crew()
    change_speaker_state("unique")
    init_settings()

    swap_tabs("show_home")
end

function update(dt)
    promise:update()

    namje_ai_typer.update(dt)
    if namje_ai_typer.is_typing() then
        local typing_state = namje_ai_typer.get_ai_state()
        if speaker_state ~= typing_state then
            change_speaker_state(typing_state)
        end
    else
        if speaker_state ~= "idle" then
            change_speaker_state("idle")
        end
    end

    if sail_canvas then
        if speaker_timer < world.time() then
            speaker_timer = world.time() + ((ai_config.aiAnimations[speaker_state].animationCycle or 0.5) / (dt*60))
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

function dismissed()
    namje_ai_typer.stop_sounds()
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
    speaker_frame = 0
    speaker_timer = 0
end

function init_sail()
    ai_config = root.assetJson("/ai/ai.config")
    racial_sail = ai_config.species[player.species()] or ai_config.species["human"]
    sail_canvas = widget.bindCanvas("sail_portrait")
    static_timer = world.time()
end

function init_themes()
    local themes = root.assetsByExtension("namjetheme")
    local player_theme = player.getProperty("namje_sail_theme", "default")

    sail_themes = {}
    for i = 1, #themes do
        local theme = root.assetJson(themes[i])
        sail_themes[theme.id] = theme
    end

    swap_theme(player_theme)
end

function swap_theme(new_theme)
    if not sail_themes[new_theme] then
        sb.logInfo("namje // warning: tried swapping to non existent theme, defaulting to default theme")
        new_theme = "default"
    end

    local default = sail_themes["default"]
    current_theme = sail_themes[new_theme]

    widget.setText("fake_window_subtitle", current_theme.subtitle or default.subtitle)

    widget.setImage("fake_footer", current_theme.footer or default.footer)
    widget.setImage("fake_body", current_theme.body or default.body)
    widget.setImage("fake_header", current_theme.header or default.header)

    widget.setImage("fake_window_icon", current_theme.icon or default.icon)

    widget.setButtonImages("close", current_theme.close_button or default.close_button)
    widget.setButtonImages("show_home", current_theme.home_button or default.home_button)

    widget.setImage("main.missions.mission_info.background", current_theme.list_info_back or default.list_info_back)
    widget.setImage("main.crew.crew_info.background", current_theme.list_info_back or default.list_info_back)

    widget.setButtonImages("main.missions.mission_info.start_mission", current_theme.deploy_button or default.deploy_button)
    widget.setButtonImages("main.crew.crew_info.dismiss_crew", current_theme.dismiss_button or default.dismiss_button)

    widget.setButtonImages("show_missions", current_theme.left_buttons or default.left_buttons)
    widget.setButtonImages("show_crew", current_theme.left_buttons or default.left_buttons)
    widget.setButtonImages("show_ship_info", current_theme.left_buttons or default.left_buttons)
    widget.setButtonImages("show_settings", current_theme.left_buttons or default.left_buttons)

    --update the settings page
    settings_tab()
end

function init_settings()
    --[[local gravity = config.getParameter("gravity", 0)
    widget.setSliderValue("main.settings.settings_area.sld_gravity", gravity)]]
    local player_theme = player.getProperty("namje_sail_theme", "default")
    widget.setText("main.settings.settings_area.button_theme", sail_themes[player_theme].name)
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
        if swap_to_tab("main.ships") then
            ship_tab()
        end
    elseif tab == "show_settings" then
        if swap_to_tab("main.settings") then
            settings_tab()
        end
    elseif tab == "show_home" then
        if swap_to_tab("main.home") then
            home_tab()
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
    widget.setText("directory_text", "^" .. current_theme.directory_text_color .. ";" .. result)
end

function home_tab()
    local upgrades = player.shipUpgrades().capabilities
    local teleport, thrusters, ftl = false

    namje_ai_typer.clear_queue()
    update_directory({})

    for _, v in pairs(upgrades) do
        if v == "teleport" then
            teleport = true
        elseif v == "planetTravel" then
            thrusters = true
        elseif v == "systemTravel" then
            ftl = true
        end
    end

    local formatted_profile = string.format(theme_format(localization.home_flavor_text), string.lower(player.name()), thrusters and "^" .. current_theme.success_text_color.. ";online^reset;" or "^" .. current_theme.error_text_color.. ";offline^reset;", ftl and "^" .. current_theme.success_text_color.. ";online^reset;" or "^" .. current_theme.error_text_color.. ";offline^reset;", teleport and "^" .. current_theme.success_text_color.. ";online^reset;" or "^" .. current_theme.error_text_color.. ";offline^reset;")

    widget.setText("main.home.fetch", "")
    widget.setText("main.home.ascii", "")
    widget.setText("main.home.flavor_text", "")
    widget.setText("main.home.ai_dialog", "")
    local status = (thrusters and ftl and teleport) and theme_format(localization.home_status_repaired) or theme_format(localization.home_status_warning)
    namje_ai_typer.push_request("main.home.fetch", theme_format(localization.home_fetch), 0.5, "unique", nil)
    namje_ai_typer.push_request("main.home.ascii", current_theme.fetch_ascii, -1, "unique", nil)
    namje_ai_typer.push_request("main.home.flavor_text", formatted_profile, 2, "unique", nil)
    namje_ai_typer.push_request("main.home.ai_dialog", status, 1, "idle", nil)
end

function ship_tab()
    local shipslot_info = tabs[4][3]
    local ship_list = tabs[4][2]

    last_selected_widget = nil

    namje_ai_typer.clear_queue()
    update_directory({"ships"})

    widget.setText(shipslot_info .. ".stats_1", "")
    widget.setText(shipslot_info .. ".stats_num_1", "")
    widget.setText(shipslot_info .. ".stats_2", "")
    widget.setText(shipslot_info .. ".stats_num_2", "")
    widget.clearListItems(ship_list)
    widget.setButtonEnabled(shipslot_info .. ".swap_ship", false)
    widget.setButtonEnabled(shipslot_info .. ".salvage_ship", false)
    widget.setButtonEnabled(shipslot_info .. ".favorite_ship", false)
    --widget.setVisible(shipslot_info .. ".swap_ship", false)
    namje_ai_typer.push_request(shipslot_info .. ".description",  theme_format(localization.ship_info), 2, "talk", nil)

    local player_ships = player.getProperty("namje_ships", {})

    for slot, ship in pairs(player_ships) do
        sb.logInfo("namje // ship slot: %s", ship)
        local ship_info = ship.ship_info
        if ship_info then
            local ship_config = namje_byos.get_ship_config(ship_info.ship_id) or nil
            local list_item = ship_list .. "."..widget.addListItem(ship_list)
            widget.setText(list_item..".item_name", "^" .. current_theme.main_text_color .. ";" .. ship_info.name .. (ship_info.favorited and " " or ""))
            widget.setText(list_item..".item_model", "^" .. current_theme.os_text_color .. ";" .. (ship_config and ship_config.name or ""))
            widget.setImage(list_item..".item_icon", ship_info.icon or "/namje_ships/ship_icons/generic_1.png")
            widget.setImage(list_item..".item_background", current_theme.list_item_bg or sail_themes["default"].list_item_bg)
            widget.setData(list_item, { tonumber(string.match(slot, "slot_(%d)")) })
        end
    end
end

function select_ship()
    local shipslot_info = tabs[4][3]
    local ship_list = tabs[4][2]
    local selected_ship = widget.getListSelected(ship_list)

    if not selected_ship then
        return
    end

    local ship_slot = widget.getData(ship_list .. "." .. selected_ship)[1]

    if not ship_slot then
        return
    end

    local player_ships = player.getProperty("namje_ships", {})
    local ship_data = player_ships["slot_" .. ship_slot]

    swap_confirm = false
    widget.setText(shipslot_info .. ".swap_ship", "SWAP")

    if last_selected_widget then
        widget.setImage(ship_list .. "." .. last_selected_widget .. ".item_background", current_theme.list_item_bg or sail_themes["default"].list_item_bg)
    end
    widget.setImage(ship_list .. "." .. selected_ship .. ".item_background", current_theme.list_item_bg_select or sail_themes["default"].list_item_bg_select)
    widget.setVisible(shipslot_info .. ".swap_ship", true)

    namje_ai_typer.clear_queue()
    widget.setText(shipslot_info .. ".description", "")
    widget.setText(shipslot_info .. ".stats_1", "")
    widget.setText(shipslot_info .. ".stats_num_1", "")
    widget.setText(shipslot_info .. ".stats_2", "")
    widget.setText(shipslot_info .. ".stats_num_2", "")

    local ship_info = namje_byos.get_ship_info(ship_slot)
    local ship_stats = namje_byos.get_stats(ship_slot)
    if ship_info and ship_stats then
        local ship_config = namje_byos.get_ship_config(ship_info.ship_id) or nil
        local current_slot = player.getProperty("namje_current_ship", 1)
        local stats_1 = string.format(
            "^os_text_color;%s%%\n%s\n%s\n%s\n%s", 
            math.floor(ship_config.base_stats.fuel_efficiency*10),
            ship_config.base_stats.max_fuel,
            ship_config.base_stats.ship_speed,
            ship_config.base_stats.crew_size, 
            ship_config.atelier_stats.cargo_hold_size
        )
        local stats_2 = string.format(
            "^os_text_color;%s\n%s\n%s\n%s", 
            #ship_stats.cargo_hold,
            ship_stats.fuel_amount,
            ship_stats.crew_amount,
            0 
        )

        update_directory({"ship", string.lower(string.gsub(ship_info.name, " ", "")) .. ".ship"})
        namje_ai_typer.push_request(shipslot_info .. ".stats_1", theme_format(localization.ship_stats_1), 2, "talk", nil)
        namje_ai_typer.push_request(shipslot_info .. ".stats_num_1", theme_format(stats_1), 2, "talk", nil)
        namje_ai_typer.push_request(shipslot_info .. ".stats_2", theme_format(localization.ship_stats_2), 2, "talk", nil)
        namje_ai_typer.push_request(shipslot_info .. ".stats_num_2", theme_format(stats_2), 2, "talk", nil)

        widget.setButtonEnabled(shipslot_info .. ".favorite_ship", true)
        if string.find(ship_slot, tostring(current_slot)) then
            local favorite = not ship_info.favorited
            widget.setButtonEnabled(shipslot_info .. ".swap_ship", false)
            widget.setButtonEnabled(shipslot_info .. ".salvage_ship", favorite)
        else
            widget.setButtonEnabled(shipslot_info .. ".swap_ship", true)
            widget.setButtonEnabled(shipslot_info .. ".salvage_ship", false)
        end
    end
    last_selected_widget = selected_ship
end

function swap_ship()
    local shipslot_info = tabs[4][3]
    local ship_list = tabs[4][2]
    local selected_ship = widget.getListSelected(ship_list)

    if not swap_confirm then
        swap_confirm = true
        widget.setText(shipslot_info .. ".swap_ship", "CONFIRM")
        return
    end

    if not selected_ship then
        return
    end

    local ship_slot = widget.getData(ship_list .. "." .. selected_ship)[1]

    if not ship_slot then
        return
    end

    local player_ships = player.getProperty("namje_ships", {})
    local ship_data = player_ships["slot_" .. ship_slot]

    if not ship_data or not ship_data.ship_info then
        return
    end

    sb.logInfo("namje // swapping ship to slot: %s", ship_slot)
    sb.logInfo("namje // ship data: %s", ship_data)
    namje_byos.swap_ships(ship_slot)
end

function favorite_ship()
    local shipslot_info = tabs[4][3]
    local ship_list = tabs[4][2]
    local selected_ship = widget.getListSelected(ship_list)

    if not selected_ship then
        return
    end

    local ship_slot = widget.getData(ship_list .. "." .. selected_ship)[1]

    if not ship_slot then
        return
    end
    local current_slot = player.getProperty("namje_current_ship", 1)
    local ship_info = namje_byos.get_ship_info(ship_slot)
    if not ship_info then
        return
    end

    ship_info.favorited = not ship_info.favorited
    sb.logInfo("favorite %s", ship_info.favorited)
    namje_byos.set_ship_info(ship_slot, {["favorited"] = ship_info.favorited})
    widget.setText(ship_list .. "." .. selected_ship .. ".item_name", "^" .. current_theme.main_text_color .. ";" .. ship_info.name .. (ship_info.favorited and " " or ""))
    if current_slot == ship_slot then
        widget.setButtonEnabled(shipslot_info .. ".salvage_ship", not ship_info.favorited)
    end
end

function salvage_ship()
    interface.queueMessage("Ship salvaging currently unavailable.")
end

function settings_tab()
    namje_ai_typer.clear_queue()
    update_directory({"settings"})
    widget.setText("main.settings.settings_area.lbl_theme", theme_format(localization.settings_theme_lbl))
end

function change_setting(setting_name)
    if setting_name == "button_theme" then
        local theme, first_theme
        local player_theme = player.getProperty("namje_sail_theme", "default")
        local found_theme = false
        local num = 0
        for k, v in pairs(sail_themes) do
            num = num + 1
            if not first_theme then
                first_theme = k
            end
            if found_theme then
                theme = k
                break
            end
            if k == player_theme then
                found_theme = true
                if num >= #sail_themes then
                    theme = first_theme
                end
            end
        end
        if theme then
            player.setProperty("namje_sail_theme", theme)
            widget.setText("main.settings.settings_area.button_theme", sail_themes[theme].name)
            swap_theme(theme)
        end
    end
end

function crew_tab()
    local crew_info = tabs[3][3]
    local crew_list = tabs[3][2]

    last_selected_widget = nil

    namje_ai_typer.clear_queue()
    update_directory({"crew"})

    widget.clearListItems(crew_list)
    widget.setButtonEnabled(crew_info .. ".dismiss_crew", false)
    namje_ai_typer.push_request(crew_info .. ".description",  theme_format(localization.crew_info), 2, "talk", nil)

    if #crew <= 0 then
        return
    end

    for i = 1, #crew do
        local member = crew[i]

        local list_item = crew_list .. "."..widget.addListItem(crew_list)
        widget.setText(list_item..".item_name", "^" .. current_theme.main_text_color .. ";" .. member.name)
        widget.setImage(list_item..".item_background", current_theme.list_item_bg or sail_themes["default"].list_item_bg)
        
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
    if last_selected_widget then
        widget.setImage(crew_list .. "." .. last_selected_widget .. ".item_background", current_theme.list_item_bg or sail_themes["default"].list_item_bg)
    end
    widget.setImage(crew_list .. "." .. selected_member .. ".item_background", current_theme.list_item_bg_select or sail_themes["default"].list_item_bg_select)

    local member_desc = member_data.description
    member_desc = string.gsub(member_desc, "cyan", current_theme.accent_text_color)

    namje_ai_typer.clear_queue()
    namje_ai_typer.push_request(crew_info..".description", member_desc, 2, "idle", nil)

    widget.setText(crew_info..".description", member_data.description)
    widget.setButtonEnabled(crew_info .. ".dismiss_crew", true)

    last_selected_widget = selected_member
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

    last_selected_widget = nil

    namje_ai_typer.clear_queue()
    update_directory({"missions"})

    widget.clearListItems(mission_list)
    widget.setButtonEnabled(mission_info .. ".start_mission", false)
    namje_ai_typer.push_request(mission_info .. ".description", theme_format(localization.mission_info), 2, "talk", nil)

    local ai_state = player_save.aiState
    local available_missions = ai_state.availableMissions
    local completed_missions = ai_state.completedMissions

    if #available_missions > 0 then
        for i = 1, #available_missions do
            local mission_info = root.assetJson("/ai/"..available_missions[i]..".aimission")

            local list_item = mission_list .. "."..widget.addListItem(mission_list)
            widget.setText(list_item..".item_name", "^" .. current_theme.main_text_color .. ";" .. mission_info.speciesText.default.buttonText)
            widget.setImage(list_item..".item_icon", "/ai/" .. mission_info.icon or "/ai/missionhuman1icon.png")
            widget.setImage(list_item..".item_background", current_theme.list_item_bg or sail_themes["default"].list_item_bg)
            widget.setData(list_item, { mission_info, false })
            widget.setVisible(list_item..".header_back", false)
        end
    end
    
    if #completed_missions > 0 then
        --replay header to separate mission type
        local list_header = mission_list .. "." ..widget.addListItem(mission_list)
        widget.setText(list_header..".item_name", theme_format(localization.mission_replay_header))
        widget.setImage(list_header..".header_back", current_theme.list_header or sail_themes["default"].list_header)
        widget.removeChild(list_header, "item_icon")
        widget.removeChild(list_header, "item_background")
        --widget.setImage(list_header..".background", "/interface/namje_sail/replayheader.png")

        for i = 1, #completed_missions do
            local mission_info = root.assetJson("/ai/"..completed_missions[i]..".aimission")

            local list_item = mission_list .. "."..widget.addListItem(mission_list)
            widget.setText(list_item..".item_name", "^" .. current_theme.main_text_color .. ";" .. mission_info.speciesText.default.repeatButtonText)
            widget.setImage(list_item..".item_icon", "/ai/" .. mission_info.icon or "/ai/missionhuman1icon.png")
            widget.setImage(list_item..".item_background", current_theme.list_item_bg or sail_themes["default"].list_item_bg)
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
    if last_selected_widget then
        widget.setImage(mission_list .. "." .. last_selected_widget .. ".item_background", current_theme.list_item_bg or sail_themes["default"].list_item_bg)
    end
    widget.setImage(mission_list .. "." .. selected_mission .. ".item_background", current_theme.list_item_bg_select or sail_themes["default"].list_item_bg_select)
    
    local info_text = "^" .. current_theme.main_text_color .. ";> " .. (replay and theme_format(localization.mission_replay_desc) .. "^" .. current_theme.main_text_color .. ";" or "") ..  mission_data[1].speciesText.default.selectSpeech.text
    namje_ai_typer.clear_queue()
    namje_ai_typer.push_request(mission_info .. ".description", info_text, 1, "talk", typing_sound)
    
    widget.setButtonEnabled(mission_info .. ".start_mission", true)

    last_selected_widget = selected_mission
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

function theme_format(string)
    local text_colors = {
        "main_text_color",
        "accent_text_color",
        "accent2_text_color",
        "os_text_color",
        "success_text_color",
        "error_text_color",
        "warn_text_color"
    }

    local modified = string
    
    for i = 1, #text_colors do
        modified = string.gsub(modified, text_colors[i], current_theme[text_colors[i]])
    end

    return modified
end

function a_to_hex(a)
    local alpha_255 = math.floor(math.max(0, math.min(255, a * 255)))
    local a_hex = string.format("%02x", alpha_255)
    return string.upper(a_hex)
end