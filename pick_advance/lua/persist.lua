-- << pick_advance_persist

pickadvance = {}
local pickadvance = pickadvance
local print_as_json = print_as_json
local string = string
local wesnoth = wesnoth

local scenario = string.gsub(wesnoth.game_config.mp_settings.mp_scenario
	.. wesnoth.game_config.mp_settings.mp_scenario_name,
	"[^a-zA-Z_]", "")

local function get_global(var_name)
	wesnoth.wml_actions.get_global_variable {
		namespace = "pickadvance",
		from_global = var_name,
		to_local = "pickadvance_local",
		side = "global",
	}
	return wesnoth.get_variable("pickadvance_local")
end

function pickadvance.get_map_override(unit_clean_type)
	return get_global("pickadvance_override_" .. scenario .. unit_clean_type)
end


local function set_global(var_name, value)
	wesnoth.set_variable("pickadvance_local", value)
	wesnoth.wml_actions.set_global_variable {
		namespace = "pickadvance",
		from_local = "pickadvance_local",
		to_global = var_name,
		side = "global",
		immediate = true,
	}
end

function pickadvance.set_map_override(unit_clean_type, string_override)
	print_as_json("setting map override with", "pickadvance_override_" .. scenario .. unit_clean_type, string_override)
	return set_global("pickadvance_override_" .. scenario .. unit_clean_type, string_override)
end


-- >>
