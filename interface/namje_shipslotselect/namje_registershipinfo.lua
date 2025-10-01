require "/scripts/namje_byos.lua"

--TODO: grab all icons in path instead of hardcoded presets
local icon_path = "/namje_ships/ship_icons/generic_%s.png"
local icon_index = 1
local icon = "/namje_ships/ship_icons/generic_1.png"
local name_prefixes = {
  "AOM", "UES", "XGS", "CRN", "VRS", "AAS", "FTL", "DMC", "KNS", "OBS", "SRV", "PRT", "USS", "UNSC", "UESC", "HRT",
  "TRN", "DRN", "FRG", "CRB", "SPN", "VGL", "HRM", "MSC", "DSS", "Star", "Void", "Aero", "Nexa", "Chrono", "Phaze", "Crys", "Event", "Battlestar",
  "Aether", "Lum", "Omni", "Zeta", "Nova", "Pulsar", "Nebula", "Comet", "Epoch", "Genesis", "Vortex", "Zenith", "Echo", "The", "Millennium", "Song Of", "Eye Of",
  "Ninomae"
}
local name_affixes = {
  "Aegis", "Orion", "Pegasus", "Seraph", "Valkyrie", "Goliath", "Leviathan", "Chimera", "Phoenix", "Griffin", "Mjolnir", "Excalibur", "Bifrost", "Argus", "Hesperus", "Hyperion", "Icarus", "Janus", "Kid", "Veridian", "Falcon", "Bebop", "Infinity",
  "Kellion", "Solara", "Astra", "Celeste", "Cosmos", "Galaxia", "Orbis", "Stella", "Terra Nova", "Vesper", "Aurora", "Eclipse", "Meteor", "Quasar", "Singularity", "Stardust", "Zenith", "Voyager", "Pioneer", "Argo", "Serenity", "Horizon", "Galactica",
  "Vigilance", "Resilience", "Ascendant", "Dominion", "Prowess", "Resolve", "Vector", "Apex", "Concord", "Destiny", "Endeavor", "Frontier", "Harmony", "Insight", "Journey", "Liberty", "Odyssey", "Sanctuary", "Unity", "Vanguard", "Express",
  "Striker", "Harbinger", "Sentinel", "Drifter", "Nomad", "Ranger", "Seeker", "Wanderer", "Guardian", "Pathfinder", "Explorer", "Interceptor", "Reaver", "Spectre", "Phantom", "Hunter", "Echo", "Relic", "Whisper", "Vagabond", "Marathon", "Dawn", "Benevolence",
  "Eternity", "Soul", "Sword", "Abyss", "Ina'Nis", "Luminesk"
}


spin_count = {}
spin_count.up = function()
  icon_index = icon_index + 1 == 7 and 1 or icon_index + 1
  icon = string.format(icon_path, icon_index)
  widget.setImage("img_icon", icon)
end
spin_count.down = function()
  icon_index = icon_index - 1 == 0 and 6 or icon_index - 1
  icon = string.format(icon_path, icon_index)
  widget.setImage("img_icon", icon)
end

function init()
end

function ok()
  local ship_list = player.getProperty("namje_ships", {})
  local slot_num = config.getParameter("slot")
  local slot = ship_list[slot_num]

  local name = widget.getText("name")
  world.sendEntityMessage(pane.sourceEntity(), "namje_confirmSlot", slot_num, name, icon)
  pane.dismiss()
end

function cancel()
  player.interact("ScriptPane", "/interface/namje_shipslotselect/namje_shipslotselect.config", pane.sourceEntity())
end

function randomize()
  local function get_rand_index(array)
    local random_value = sb.nrand(array / 6)
    local index = math.floor(random_value + (array / 2))
    return math.max(1, math.min(array, index))
  end

  local name_prefix = name_prefixes[get_rand_index(#name_prefixes)]
  local name_affix = name_affixes[get_rand_index(#name_affixes)]
  
  widget.setText("name", string.format("%s %s", name_prefix, name_affix))
end