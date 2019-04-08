-- << pick_advance/main.lua

local pickadvance = pickadvance
local ipairs = ipairs
local string = string
local table = table
local wesnoth = wesnoth
local wml = wml
local on_event = wesnoth.require("lua/on_event.lua")
local T = wesnoth.require("lua/helper.lua").set_wml_tag_metatable {}

wesnoth.wml_actions.set_menu_item {
	id = "pickadvance",
	description = "Pick Advance",
	T.show_if {
		T.lua {
			code = "return pickadvance.menu_available()"
		},
	},
	T.command {
		T.lua {
			code = "pickadvance.pick_advance()"
		}
	}
}

local function clean_type_func(unit_type)
	return string.gsub(unit_type, "[^a-zA-Z0-9]", "_")
end

local function split_comma_units(string_to_split)
	local result = {}
	local n = 1
	for s in string.gmatch(string_to_split or "", "[^,]+") do
		if s ~= "" and s ~= "null" and wesnoth.unit_types[s] then
			result[n] = s
			n = n + 1
		end
	end
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
		take_only_once = false,
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


function pickadvance.menu_available()
	local unit = wesnoth.get_unit(wml.variables.x1, wml.variables.y1)
	return unit and
		#unit.advances_to > 0
		and wesnoth.sides[unit.side].is_local and wesnoth.sides[unit.side].controller == "human"
		and (#original_advances(unit) > 1 or #unit.advances_to > 1)
end


local function initialize_unit(unit)
	local clean_type = clean_type_func(unit.type)
	if unit.variables["pickadvance_orig_" .. clean_type] == nil then
		wesnoth.wml_actions.remove_object {
			object_id = "pickadvance",
			id = unit.id
		}
		unit.variables["pickadvance_orig_" .. clean_type] = table.concat(unit.advances_to, ",")
		local advance_info = get_advance_info(unit)
		local desired = advance_info.game_override or unit.advances_to
		desired = filter_overrides(unit, desired)
		set_advances(unit, desired)
		-- print_as_json("initialized unit", unit.id, unit.advances_to)
	end
end


function pickadvance.pick_advance(unit)
	unit = unit or wesnoth.get_unit(wml.variables.x1, wml.variables.y1)
	initialize_unit(unit)
	local _, orig_options_sanitized = original_advances(unit)
	local dialog_result = wesnoth.synchronize_choice(function()
		local local_result = pickadvance.show_dialog_unsynchronized(get_advance_info(unit), unit)
		-- print_as_json("locally chosen advance for unit", unit.id, local_result)
		return local_result
	end, function() return { is_ai = true } end)
	if dialog_result.is_ai then
		return
	end
	-- print_as_json("applying manual choice for", unit.id, dialog_result)
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


local function initialize_unit_x1y1(ctx)
	local unit = wesnoth.get_unit(ctx.x1, ctx.y1)
	if not wesnoth.sides[unit.side].__cfg.allow_player then return end
	initialize_unit(unit)
	if #unit.advances_to > 1 and wml.variables.pickadvance_force_choice and unit.side == wesnoth.current.side then
		pickadvance.pick_advance(unit)
	end
end

on_event("start", -91, function()
	local recruits = false
	for _, side in ipairs(wesnoth.sides) do
		if #side.recruit ~= 0 and side.__cfg.allow_player then
			recruits = true
		end
	end
	wml.variables.pickadvance_force_choice = wml.variables.pickadvance_force_choice
		or not recruits
end)

local fresh_turn = false
on_event("turn refresh", -91, function()
	fresh_turn = true
end)
on_event("moveto", -91, function()
	if fresh_turn then
		fresh_turn = false
		if not wesnoth.sides[wesnoth.current.side].__cfg.allow_player then return end
		for _, unit in ipairs(wesnoth.get_units { side = wesnoth.current.side }) do
			initialize_unit(unit)
			if #unit.advances_to > 1 and wml.variables.pickadvance_force_choice and wesnoth.current.turn > 1 then
				pickadvance.pick_advance(unit)
				if #unit.advances_to > 1 then
					local len = #unit.advances_to
					local rand = wesnoth.random(len)
					unit.advances_to = { unit.advances_to[rand] }
				end
			end
		end
	end
end)

on_event("recruit", -91, initialize_unit_x1y1)
on_event("post advance", -91, initialize_unit_x1y1)


-- >>
