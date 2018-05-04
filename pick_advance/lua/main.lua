-- << pick_advance/main.lua

local pickadvance = pickadvance
local assert = assert
local ipairs = ipairs
local print_as_json = print_as_json
local string = string
local table = table
local wesnoth = wesnoth
local wml = wml
local T = wesnoth.require("lua/helper.lua").set_wml_tag_metatable {}


wesnoth.wml_actions.event {
	id = "pickadvance_side_turn_end",
	first_time_only = false,
	name = "side turn end",
	T.lua { code = "pickadvance.side_turn_end()" }
}
wesnoth.wml_actions.event {
	id = "pickadvance_recruit",
	first_time_only = false,
	name = "recruit",
	T.lua { code = "pickadvance.recruit()" }
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


local function calculate_desired_unit_advances(unit)
	local clean_type = clean_type_func(unit.type)
	local game_override = wesnoth.get_variable("pickadvance_override_side" .. unit.side .. "_" .. clean_type)
	if game_override and game_override ~= "" then
		return split_comma_units(game_override)
	end
	local map_override = wesnoth.synchronize_choice(function()
		return { value = pickadvance.get_map_override(clean_type) }
	end).value
	if map_override and map_override ~= "" then
		return split_comma_units(map_override)
	end
	return unit.advances_to
end


local function reconfigure_unit(unit)
	assert(unit.side == wesnoth.current.side)
	local clean_type = clean_type_func(unit.type)
	if unit.variables.pickadvance_type ~= clean_type then
		local desired = calculate_desired_unit_advances(unit)
		assert_correct_override(unit, table.concat(desired, ","))
		unit.advances_to = desired
		unit.variables.pickadvance_type = clean_type
		print_as_json("applied advance for", unit.id, unit.advances_to)
	end
end


function pickadvance.menu_available(unit)
	return unit.x == wesnoth.get_variable("x1")
		and unit.y == wesnoth.get_variable("y1")
		and unit.side == wesnoth.current.side
		and #unit.advances_to > 0
		and #wesnoth.unit_types[unit.type].advances_to > 1
end


function pickadvance.side_turn_end()
	--print_as_json("Handling side turn end", wesnoth.current.side)
	for _, unit in ipairs(wesnoth.get_units { side = wesnoth.current.side }) do
		reconfigure_unit(unit)
	end
end


function pickadvance.recruit()
	local unit = wesnoth.get_unit(wml.variables.x1, wml.variables.y1)
	reconfigure_unit(unit)
end


function pickadvance.pick_advance()
	local x1 = wesnoth.get_variable("x1")
	local y1 = wesnoth.get_variable("y1")
	local unit = wesnoth.get_unit(x1, y1)
	local clean_type = clean_type_func(unit.type)
	local dialog_result = wesnoth.synchronize_choice(function()
		local dialog_result = pickadvance.show_dialog_unsynchronized(unit)
		print_as_json("locally chosen advance for unit", unit.type, unit.id, dialog_result)
		if dialog_result.map_scope then
			pickadvance.set_map_override(clean_type, dialog_result.type)
		end
		return dialog_result
	end)
	assert_correct_override(unit, dialog_result.type)
	unit.advances_to = split_comma_units(dialog_result.type)
	if dialog_result.game_scope then
		wesnoth.set_variable("pickadvance_override_side" .. unit.side .. "_" .. clean_type, dialog_result.type)
	end
	unit.variables.pickadvance_type = clean_type
end


-- >>
