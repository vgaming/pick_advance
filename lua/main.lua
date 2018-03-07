-- << pick_advancement_vasya_main.lua

local pickadvance = pickadvance
local wesnoth = wesnoth
local assert = assert
local ipairs = ipairs
local string = string
local type = type
local table = table
local T = wesnoth.require("lua/helper.lua").set_wml_tag_metatable {}
local translate = wesnoth.textdomain "wesnoth"

wesnoth.dofile("~add-ons/Creep_War_Dev/lua/.vasya_personal_json_format.lua") -- TODO


wesnoth.wml_actions.event {
	id = "pickadvance_unit_placed",
	name = "unit placed",
	T.lua { code = "pickadvance.unit_placed()" } -- 1.13 unit placed
	-- TODO: remove this and use "side turn end" event instead
}
wesnoth.wml_actions.event {
	id = "pickadvance_side_turn",
	name = "side turn",
	T.lua { code = "pickadvance.side_turn()" }
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


wesnoth.wml_actions.set_menu_item {
	id="pickadvance_exp",
	description="Give Experience",
	T.command {
		T.lua {
			code = "pickadvance.give_experience()"
		}
	}
}
wesnoth.wml_actions.set_menu_item {
	id="pickadvance_reload",
	description="PA: reload",
	T.command {
		T.lua {
			code = 'wesnoth.dofile("~add-ons/pick_advance_by_vasya/lua/persist.lua")\n'
			.. 'wesnoth.dofile("~add-ons/pick_advance_by_vasya/lua/dialog.lua")\n'
			.. 'wesnoth.dofile("~add-ons/pick_advance_by_vasya/lua/main.lua")\n'
		}
	}
}
function pickadvance.give_experience()
	local x1 = wesnoth.get_variable("x1") or 0
	local y1 = wesnoth.get_variable("y1") or 0
	local unit = wesnoth.get_unit(x1, y1)
	unit.experience = unit.max_experience - 1
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
	print_as_json("split: acceptable upgrades:", result)
	return result
end


function pickadvance.advance_array(unit_type)
	print_as_json("__cfg.advances_to", wesnoth.unit_types[unit_type].__cfg.advances_to)
	return split_comma_units(wesnoth.unit_types[unit_type].__cfg.advances_to)
end


local function parse_advances_config_local_function(unit)
	local unit_override = unit.variables.pickadvance_override
	print_as_json("parsing unit override", unit_override)
	if unit_override then
		return { unit_override }
	end

	local clean_type = string.gsub(unit.type, "[^a-zA-Z_]", "")

	local game_override = wesnoth.get_variable("pickadvance_override_" .. clean_type)
	if game_override then
		return split_comma_units(game_override)
	end

	--local map_override = pickadvance.get_map_override(clean_type)
	--if map_override then
	--	return split_comma_units(map_override)
	--end

	--local global_override = pickadvance.get_global_override(clean_type)
	--if global_override then
	--	return split_comma_units(global_override)
	--end

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
		local local_advance_array = wesnoth.synchronize_choice(function()
			local parsed = parse_advances_config_local_function(unit)
			return { value = table.concat(parsed, ",") }
		end).value
		local_advance_array = split_comma_units(local_advance_array)
		unit.advances_to = local_advance_array
		unit.variables.pickadvance_handled = true
		print_as_json("advances for", unit.type, "x", unit.x, "y", unit.y, "advance_array", unit.advances_to, local_advance_array)
	end
end


function pickadvance_advancement_menu_available(unit)
	return unit.x == wesnoth.get_variable("x1")
		and unit.y == wesnoth.get_variable("y1")
		and unit.side == wesnoth.current.side
		and #pickadvance.advance_array(unit.type) > 1
end


function pickadvance.unit_placed()
	local x1 = wesnoth.get_variable("x1") or 0
	local y1 = wesnoth.get_variable("y1") or 0
	local unit = wesnoth.get_unit(x1, y1)
	if unit.side == wesnoth.current.side then
		apply_advances_config(unit)
	else
		local side_queue = unit_queue[unit.side]
		side_queue[#side_queue + 1] = unit
	end
end


function pickadvance.side_turn()
	for _, unit in ipairs(unit_queue[wesnoth.current.side]) do
		apply_advances_config(unit)
	end
	unit_queue[wesnoth.current.side] = {}
end


function pickadvance.pick_advance()
	local x1 = wesnoth.get_variable("x1")
	local y1 = wesnoth.get_variable("y1")
	local unit = wesnoth.get_unit(x1, y1)
	wesnoth.synchronize_choice(function()
		local dialog_result = pickadvance.show_dialog_unsynchronized(unit)
		print_as_json("chosen advances for unit", unit.x, unit.y, "is", dialog_result)
		if dialog_result.is_ok then
			save_user_preferences(unit, dialog_result)
		end
		return {}
	end)
	apply_advances_config(unit, true)
end


-- >>
