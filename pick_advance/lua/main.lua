-- << pick_advance/main.lua

local pickadvance = pickadvance
local print_as_json = print_as_json
local ipairs = ipairs
local string = string
local table = table
local wesnoth = wesnoth
local wml = wml
local T = wesnoth.require("lua/helper.lua").set_wml_tag_metatable {}

wesnoth.wml_actions.event {
	first_time_only = true,
	name = "start",
	T.lua { code = "pickadvance.start_event()" }
}
wesnoth.wml_actions.set_menu_item {
	id = "pickadvance",
	description = "Pick Advance",
	T.show_if {
		T.have_unit {
			lua_function = "pickadvance.menu_available"
		}
	},
	T.command {
		T.lua {
			code = "pickadvance.pick_advance()"
		}
	}
}

local function clean_type_func(unit_type)
	return string.gsub(unit_type, "[^a-zA-Z0-9_]", "")
end

local function split_comma_units(string_to_split)
	local result = {}
	local n = 1
	for s in string.gmatch(string_to_split or "", "[^,]+") do
		--print_as_json("checking advance string", s)
		if s ~= "" and s ~= "null" and wesnoth.unit_types[s] then
			result[n] = s
			n = n + 1
		end
	end
	--print_as_json("split: acceptable upgrades:", result)
	return result
end


local function original_advances(unit)
	local clean_type = clean_type_func(unit.type)
	local variable = unit.variables["pickadvance_orig_" .. clean_type] or ""
	return split_comma_units(variable), clean_type_func(variable)
end

local function set_advances(unit, array)
	wesnoth.add_modification(unit, "object", {
		id = "pickadvance",
		T.effect {
			apply_to = "new_advancement",
			replace = true,
			types = table.concat(array, ",")
		}
	})
end


local function array_to_set(arr)
	local result = {}
	for _, v in ipairs(arr) do
		result[v] = true
	end
	return result
end

local function array_filter(arr, func)
	local result = {}
	for _, v in ipairs(arr) do
		if func(v) then
			result[#result + 1] = v
		end
	end
	return result
end

--- works as anti-cheat and fixes tricky bugs in [male]/[female]/undead variation overrides
local function filter_overrides(unit, overrides)
	local possible_advances_array = original_advances(unit)
	local possible_advances = array_to_set(possible_advances_array)
	local filtered = array_filter(overrides, function(e) return possible_advances[e] end)
	return #filtered > 0 and filtered or possible_advances_array
end


local function get_advance_info(unit)
	local type_advances, orig_options_sanitized = original_advances(unit)
	local game_override_key = "pickadvance_side" .. unit.side .. "_" .. orig_options_sanitized
	local game_override = wesnoth.get_variable(game_override_key)
	local function correct(override)
		return override and #override > 0 and #override < #type_advances and override or nil
	end

	return {
		type_advances = type_advances,
		unit_override = correct(unit.advances_to),
		game_override = correct(split_comma_units(game_override)),
	}
end


function pickadvance.menu_available(unit)
	return unit.x == wml.variables.x1
		and unit.y == wml.variables.y1
		and unit.side == wesnoth.current.side
		and #unit.advances_to > 0
		and #(original_advances(unit) or unit.advances_to) > 1
end


local function initialize_unit(unit)
	local clean_type = clean_type_func(unit.type)
	if unit.variables["pickadvance_orig_" .. clean_type] == nil and #unit.advances_to > 1 then
		unit.variables["pickadvance_orig_" .. clean_type] = table.concat(unit.advances_to, ",")
		local advance_info = get_advance_info(unit)
		local desired = advance_info.game_override or unit.advances_to
		desired = filter_overrides(unit, desired)
		set_advances(unit, desired)
		print_as_json("initialized unit", unit.id, unit.advances_to)
	end
end


function pickadvance.pick_advance(unit)
	unit = unit or wesnoth.get_unit(wml.variables.x1, wml.variables.y1)
	initialize_unit(unit)
	local _, orig_options_sanitized = original_advances(unit)
	local dialog_result = wesnoth.synchronize_choice(function()
		local local_result = pickadvance.show_dialog_unsynchronized(get_advance_info(unit))
		print_as_json("locally chosen advance for unit", unit.id, local_result)
		return local_result
	end, function() return { is_ai = true } end)
	if dialog_result.is_ai then
		return
	end
	print_as_json("applying manual choice for", unit.id, dialog_result)
	dialog_result.unit_override = split_comma_units(dialog_result.unit_override)
	dialog_result.game_override = split_comma_units(dialog_result.game_override)
	dialog_result.unit_override = filter_overrides(unit, dialog_result.unit_override)
	dialog_result.game_override = filter_overrides(unit, dialog_result.game_override)
	if dialog_result.is_unit_override then
		set_advances(unit, dialog_result.unit_override)
	end
	if dialog_result.is_game_override then
		local key = "pickadvance_side" .. unit.side .. "_" .. orig_options_sanitized
		wesnoth.set_variable(key, table.concat(dialog_result.game_override, ","))
	end
end


function pickadvance.initialize_unit_x1y1()
	local unit = wesnoth.get_unit(wml.variables.x1, wml.variables.y1)
	if not wesnoth.sides[unit.side].__cfg.allow_player then return end
	initialize_unit(unit)
	if #unit.advances_to > 1 and wml.variables.pickadvance_force_choice and unit.side == wesnoth.current.side then
		pickadvance.pick_advance(unit)
	end
end

function pickadvance.turn_refresh_event()
	if not wesnoth.sides[wesnoth.current.side].__cfg.allow_player then return end
	for _, unit in ipairs(wesnoth.get_units { side = wesnoth.current.side }) do
		initialize_unit(unit)
		if #unit.advances_to > 1 and wml.variables.pickadvance_force_choice and wesnoth.current.turn > 1 then
			pickadvance.pick_advance(unit)
		end
	end
end

function pickadvance.start_event()
	wml.variables.pickadvance_have_recruits = false
	for _, side in ipairs(wesnoth.sides) do
		if #side.recruit ~= 0 and side.__cfg.allow_player then
			wml.variables.pickadvance_have_recruits = true
		end
	end
	wml.variables.pickadvance_force_choice = wml.variables.pickadvance_force_choice
		or not wml.variables.pickadvance_have_recruits
	wesnoth.wml_actions.event {
		first_time_only = false,
		name = "recruit",
		T.lua { code = "pickadvance.initialize_unit_x1y1()" }
	}
	wesnoth.wml_actions.event {
		first_time_only = false,
		name = "post advance",
		T.lua { code = "pickadvance.initialize_unit_x1y1()" }
	}
	wesnoth.wml_actions.event {
		first_time_only = false,
		name = "turn refresh",
		T.lua { code = "pickadvance.turn_refresh_event()" }
	}
end


-- >>
