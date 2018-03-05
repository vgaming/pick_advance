-- << pick_advance_persist

pa_vasya = {}
local pa_vasya = pa_vasya
local wesnoth = wesnoth
local string = string

local scenario = string.gsub(wesnoth.game_config.mp_settings.mp_scenario, "[^a-zA-Z_]", "")

local function get_global(var_name)
	wesnoth.wml_actions.get_global_variable {
		namespace = "pa_vasya",
		from_global = var_name,
		to_local = var_name,
		side = "global",
	}
	return wesnoth.get_variable(var_name)
end

function pa_vasya.get_map_override(unit_clean_type)
	return get_global("pa_vasya_override_" .. scenario .. unit_clean_type)
end

function pa_vasya.get_global_override(unit_clean_type)
	return get_global("pa_vasya_override_" .. unit_clean_type)
end


-- >>
