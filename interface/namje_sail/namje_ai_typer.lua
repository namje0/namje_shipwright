local queue = {}

local is_typing = false

local current_widget = ""
local current_goal
local current_goal_mods = {}
local current_goal_mod = 0
local current_progress = ""
local current_length = 0
local current_speed = 0
local typing_timer = 0
local current_state = "idle"

namje_ai_typer = {}

function namje_ai_typer.push_request(widget, message, speed_mod, talking_state, sound)
    local clean_msg, mods = extract_and_replace_modifiers(message)
    local request = {
        widget_name = widget,
        speed = speed_mod,
        typing_sound = sound or nil,
        ai_state = talking_state,
        goal = {
            message = speed_mod == -1 and message or clean_msg,
            modifiers = mods
        }
    }
    table.insert(queue, request)
    if not is_typing then
        start_next_request()
    end
end

function namje_ai_typer.pop()
    if #queue > 0 then
        return table.remove(queue, 1)
    else
        return nil
    end
end

function namje_ai_typer.update(dt)
    if is_typing and current_goal then
        if typing_timer < world.time() then
            if current_speed == -1 then
                current_progress = current_goal
                widget.setText(current_widget, current_progress)
                pane.stopAllSounds(current_sound)
                is_typing = false
                start_next_request()
            else
                typing_timer = world.time() + (0.02 / (current_speed or 1))
                if current_length < #current_goal then
                    local next_char = string.sub(current_goal, current_length + 1, current_length + 1)
                    if next_char == "|" then
                        local mod = current_goal_mods[current_goal_mod]
                        current_progress = current_progress .. mod
                        current_goal_mod = current_goal_mod + 1
                        current_length = current_length + 1
                    else
                        current_progress = current_progress .. next_char
                        current_length = current_length + 1
                    end
                    widget.setText(current_widget, current_progress)
                else
                    pane.stopAllSounds(current_sound)
                    is_typing = false
                    start_next_request()
                end
            end
        end
    end
end

function namje_ai_typer.stop_sounds()
    pane.stopAllSounds(current_sound)
end

function namje_ai_typer.clear_queue()
    namje_ai_typer.stop_sounds()
    queue = {}
    current_goal = nil
    current_goal_mods = nil
    current_goal_mod = 0
    current_speed = 0
    current_widget = ""
    current_state = "idle"
    
    current_progress = ""
    current_length = 0

    is_typing = false
end

--[[
function namje_ai_typer.get_typing()
    if is_typing then
        return current_widget, current_progress
    else
        return nil
    end
end
]]

function namje_ai_typer.is_typing()
    return is_typing
end

function namje_ai_typer.get_ai_state()
    return current_state
end

function namje_ai_typer.is_empty()
    return #queue == 0
end

function start_next_request()
    if not namje_ai_typer.is_empty() then
        local request = namje_ai_typer.pop()
        current_goal = request.goal.message
        current_goal_mods = request.goal.modifiers
        current_goal_mod = 1
        current_speed = request.speed
        current_widget = request.widget_name
        current_state = request.ai_state
        
        current_progress = ""
        current_length = 0

        is_typing = true

        if request.typing_sound then
            current_sound = request.typing_sound
            pane.playSound(current_sound, -1 ,1)
        end
    end
end

--helper function for ai typing; extracting color mods and escape sequences from a string and putting them into an array
--this was written by AI... im too lazy to write allat
--this actually isn't needed, but well, im too lazy to change it now
function extract_and_replace_modifiers(text)
    local modifiers = {}
    local replaced_text = ""
    local i = 1
    while i <= #text do
        if string.sub(text, i, i) == "^" then
            local start_index = i
            local end_index = string.find(text, ";", start_index + 1)
            if end_index and end_index > start_index + 1 then
            local modifier = string.sub(text, start_index, end_index)
            table.insert(modifiers, modifier)
            replaced_text = replaced_text .. "|"
            i = end_index + 1
            else
            -- If '^' is found but no matching ';' is found afterwards, treat it as a regular character
            replaced_text = replaced_text .. "^"
            i = i + 1
            end
        elseif string.sub(text, i, i) == "\n" then
            table.insert(modifiers, "\n")
            replaced_text = replaced_text .. "|"
            i = i + 1
        else
            replaced_text = replaced_text .. string.sub(text, i, i)
            i = i + 1
        end
    end
    return replaced_text, modifiers
end