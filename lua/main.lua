-- << pick_advancement_vasya_main.lua

local pickadvance = pickadvance
local assert = assert
local ipairs = ipairs
local print_as_json = print_as_json
local string = string
local table = table
local wesnoth = wesnoth
local T = wesnoth.require("lua/helper.lua").set_wml_tag_metatable {}


wesnoth.wml_actions.event {
	id = "pickadvance_side_turn_end",
	first_time_only = false,
	name = "side turn end",
	T.lua { code = "pickadvance.side_turn_end()" }
}
wesnoth.wml_actions.set_menu_item {
	id="pickadvance",
	description="Pick Advancement",
	T.show_if {
		T.have_unit {
			lua_function = "pickadvance_advancement_menu_available"
		}
	},
	T.command {
		T.lua {
			code = "pickadvance.pick_advance()"
		}
	}
}


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

function pickadvance.advance_array(unit_type)
	--print_as_json("__cfg.advances_to", wesnoth.unit_types[unit_type].__cfg.advances_to)
	return split_comma_units(wesnoth.unit_types[unit_type].__cfg.advances_to)
end


local function parse_advances_config_local_function(unit)
	local unit_override = unit.variables.pickadvance_override
	--print_as_json("parsing unit override", unit_override)
	if unit_override then
		return { unit_override }
	end

	local clean_type = string.gsub(unit.type, "[^a-zA-Z_]", "")

	local game_override = wesnoth.get_variable("pickadvance_override_" .. clean_type)
	if game_override then
		return split_comma_units(game_override)
	end

	return pickadvance.advance_array(unit.type)
end


local function save_user_preferences(unit, dialog_result)
	unit.variables.pickadvance_override = dialog_result.type
	if dialog_result.game_scope then
		local clean_type = string.gsub(unit.type, "[^a-zA-Z0-9_]*", "")
		wesnoth.set_variable("pickadvance_override_" .. clean_type, dialog_result.type)
	end
end


local function apply_advances_config(unit, force)
	assert(unit.side == wesnoth.current.side)
	if force or (not unit.variables.pickadvance_handled) then
		local user_advances = wesnoth.synchronize_choice(function()
			local parsed = parse_advances_config_local_function(unit)
			return { value = table.concat(parsed, ",") }
		end).value
		assert(string.find(table.concat(pickadvance.advance_array(unit.type), ","), user_advances),
			"Chosen advancement not found for unit type. Please report if you see this.")
		user_advances = split_comma_units(user_advances)
		unit.advances_to = user_advances
		unit.variables.pickadvance_handled = true
		print_as_json("applied advance for", unit.type, "x", unit.x, "y", unit.y, "advance_array", unit.advances_to, user_advances)
	end
end


function pickadvance_advancement_menu_available(unit)
	return unit.x == wesnoth.get_variable("x1")
		and unit.y == wesnoth.get_variable("y1")
		and unit.side == wesnoth.current.side
		and #pickadvance.advance_array(unit.type) > 1
end


function pickadvance.side_turn_end()
	print_as_json("Handling side turn end", wesnoth.current.side)
	for _, unit in ipairs(wesnoth.get_units { side = wesnoth.current.side }) do
		apply_advances_config(unit, false)
	end
end


function pickadvance.pick_advance()
	local x1 = wesnoth.get_variable("x1")
	local y1 = wesnoth.get_variable("y1")
	local unit = wesnoth.get_unit(x1, y1)
	wesnoth.synchronize_choice(function()
		local dialog_result = pickadvance.show_dialog_unsynchronized(unit)
		print_as_json("locally chosen advance for unit", unit.type, unit.x, unit.y, dialog_result)
		if dialog_result.is_ok then
			save_user_preferences(unit, dialog_result)
		end
		return {}
	end)
	apply_advances_config(unit, true)
end


-- >>
