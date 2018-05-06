-- << pick_advance/main.lua

local pickadvance = pickadvance
local assert = assert
local print_as_json = print_as_json
local string = string
local table = table
local wesnoth = wesnoth
local wml = wml
local T = wesnoth.require("lua/helper.lua").set_wml_tag_metatable {}

wesnoth.wml_actions.event {
	first_time_only = false,
	name = "recruit",
	T.lua { code = "pickadvance.reconfigure_unit_x1y1()" }
}
wesnoth.wml_actions.event {
	first_time_only = false,
	name = "post advance",
	T.lua { code = "pickadvance.reconfigure_unit_x1y1()" }
}
wesnoth.wml_actions.set_menu_item {
	id="pickadvance",
	description="Pick Advance",
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


local function assert_correct_override(unit, override)
	local type_advances = table.concat(wesnoth.unit_types[unit.type].advances_to, ",")
	assert(string.find(type_advances, override),
		"Chosen advancement not found for unit type. Please report if you see this. "
			.. "Type advances: " .. type_advances
			.. ", user override: " .. override)
end


local function get_advance_info(unit)
	local clean_type = clean_type_func(unit.type)
	local type_advances = wesnoth.unit_types[unit.type].advances_to
	local game_override_key = "pickadvance_override_side" .. unit.side .. "_" .. clean_type
	local game_override = wesnoth.get_variable(game_override_key)
	local map_override = wesnoth.synchronize_choice(function()
		return { value = pickadvance.get_map_override(clean_type) }
	end).value
	local function correct(override)
		return override and #override > 0 and #override < #type_advances and override or nil
	end
	return {
		type_advances = type_advances,
		unit_override = correct(unit.advances_to),
		game_override = correct(split_comma_units(game_override)),
		map_override = correct(split_comma_units(map_override)),
	}
end


function pickadvance.menu_available(unit)
	return unit.x == wesnoth.get_variable("x1")
		and unit.y == wesnoth.get_variable("y1")
		and unit.side == wesnoth.current.side
		and #unit.advances_to > 0
		and #wesnoth.unit_types[unit.type].advances_to > 1
end


function pickadvance.reconfigure_unit_x1y1()
	local unit = wesnoth.get_unit(wml.variables.x1, wml.variables.y1)
	local advance_info = get_advance_info(unit)
	local desired = advance_info.game_override
		or advance_info.map_override
		or unit.advances_to
	assert_correct_override(unit, table.concat(desired, ","))
	unit.advances_to = desired
	print_as_json("reconfigured", unit.id, unit.advances_to)
end


function pickadvance.pick_advance()
	local x1 = wesnoth.get_variable("x1")
	local y1 = wesnoth.get_variable("y1")
	local unit = wesnoth.get_unit(x1, y1)
	local clean_type = clean_type_func(unit.type)
	local dialog_result = wesnoth.synchronize_choice(function()
		local dialog_result = pickadvance.show_dialog_unsynchronized(unit, get_advance_info(unit) )
		print_as_json("locally chosen advance for unit", unit.id, dialog_result)
		if dialog_result.is_map_override then
			pickadvance.set_map_override(clean_type, dialog_result.map_override)
		end
		return dialog_result
	end)
	assert_correct_override(unit, dialog_result.unit_override or "")
	assert_correct_override(unit, dialog_result.game_override or "")
	assert_correct_override(unit, dialog_result.map_override or "")
	if dialog_result.is_unit_override then
		unit.advances_to = split_comma_units(dialog_result.unit_override)
	end
	if dialog_result.is_game_override then
		wesnoth.set_variable("pickadvance_override_side" .. unit.side .. "_" .. clean_type,
			dialog_result.game_override)
	end
end


-- >>
