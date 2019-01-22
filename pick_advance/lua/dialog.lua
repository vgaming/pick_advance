-- << pickadvance_dialog

pickadvance = {}
local pickadvance = pickadvance
local wesnoth = wesnoth
local ipairs = ipairs
local string = string
local table = table
local T = wesnoth.require("lua/helper.lua").set_wml_tag_metatable {}
local translate = wesnoth.textdomain "wesnoth"

local function filter_false(arr)
	local result = {}
	for _, v in ipairs(arr) do
		if v ~= false then
			result[#result + 1] = v
		end
	end
	return result
end


function pickadvance.show_dialog_unsynchronized(advance_info, unit)
	local spacer = "\n"
	local label = "Plan advance:"

	local unit_type_options = advance_info.type_advances
	--print_as_json("advances for", unit.type, unit_type_options)
	local options = {}
	for _, ut in ipairs(unit_type_options) do
		options[#options + 1] = wesnoth.unit_types[ut]
	end
	local show_images = true

	local unit_override_one = (advance_info.unit_override or {})[2] == nil
		and (advance_info.unit_override or {})[1] or nil
	local game_override_one = (advance_info.game_override or {})[2] == nil
		and (advance_info.game_override or {})[1] or nil

	local description_row = T.row {
		T.column { T.label { use_markup = true, label = label } },
	}

	local list_sub_row
	if show_images then
		list_sub_row = T.row {
			T.column { T.image { id = "the_icon" } },
			T.column { grow_factor = 0, T.label { use_markup = true, id = "the_label" } },
			T.column { grow_factor = 1, T.spacer {} },
		}
	else
		list_sub_row = T.row {
			T.column { horizontal_alignment = "left", T.label { use_markup = true, id = "the_label" } }
		}
	end

	local toggle_panel = T.toggle_panel { return_value = -1, T.grid { list_sub_row } }

	local list_definition = T.list_definition { T.row { T.column { horizontal_grow = true, toggle_panel } } }

	local listbox = T.listbox { id = "the_list", list_definition, has_minimum = true }

	local reset_button = T.button {
		return_value = -3,
		label = "\n" .. translate("Reset") .. "\n"
	}
	local reset_column = (unit_override_one or game_override_one)
		and T.column { horizontal_grow = true, reset_button }
		or false

	local help_button = T.button {
		return_value = -4,
		label = "\n" .. translate("Help") .. "\n"
	}

	local reset_help_buttons = T.grid {
		T.row(filter_false {
			reset_column,
			T.column { horizontal_grow = true, help_button }
		})
	}
	local unit_button_label = unit.canrecruit and "\nSave\n" or "\nSave for unit\n"
	local unit_button = T.button { return_value = -1, label = unit_button_label }
	local recruits_subbutton = T.button { return_value = 1, label = "\nSave for this unit and new\n" }
	local recruits_button = not unit.canrecruit
		and T.row { T.column { horizontal_grow = true, recruits_subbutton } }

	local dialog = {
		T.tooltip { id = "tooltip_large" },
		T.helptip { id = "tooltip_large" },
		T.grid(filter_false {
			T.row { T.column { T.spacer { width = 250 } } },
			description_row,
			T.row { T.column { horizontal_grow = true, listbox } },
			T.row { T.column { horizontal_grow = true, unit_button } },
			recruits_button,
			T.row { T.column { horizontal_grow = true, reset_help_buttons } },
		})
	}

	local function preshow()
		for i, advance_type in ipairs(options) do
			local text = spacer .. advance_type.name
			if advance_type.id == unit_override_one then
				text = text .. " &lt;-unit"
			end
			if advance_type.id == game_override_one then
				text = text .. " &lt;-recruits"
			end
			text = text .. "  " .. spacer
			wesnoth.set_dialog_value(text, "the_list", i, "the_label")
			local img = advance_type.__cfg.image
			wesnoth.set_dialog_value(img or "misc/blank-hex.png", "the_list", i, "the_icon")
		end

		wesnoth.set_dialog_focus("the_list")

		local function select()
			local i = wesnoth.get_dialog_value "the_list"
			if i > 0 then
				local img = options[i].__cfg.image
				wesnoth.set_dialog_value(img or "misc/blank-hex.png", "the_list", i, "the_icon")
			end
		end
		wesnoth.set_dialog_callback(select, "the_list")
	end

	local item_result
	local function postshow()
		item_result = wesnoth.get_dialog_value("the_list")
	end

	local dialog_exit_code = wesnoth.show_dialog(dialog, preshow, postshow)
	local is_help = dialog_exit_code == -4
	local is_reset = dialog_exit_code == -3
	--local is_cancel = dialog_exit_code == -2
	if is_help then
		wesnoth.wml_actions.message {
			speaker = "narrator",
			message = "<b>Save for unit</b> will make your unit always advance to said type. "
				.. "Even if it's leveled during enemy-s turn."
				.. "\n\n"
				.. "<b>Save for game</b> applies to all new recruits of same type in game."
				.. "\n\n"
				.. wesnoth.get_variable("pickadvance_contacts"),
			image = "misc/qmark.png~SCALE(200,200)"
		}
	end
	local is_ok = dialog_exit_code > -2 and item_result >= 1
	print(string.format("Button %s pressed (%s). Item %s selected: %s",
		dialog_exit_code, is_ok and "ok" or "not ok", item_result, options[item_result].id))
	local game_scope = dialog_exit_code == 1
	return {
		is_unit_override = is_reset or is_ok,
		unit_override = is_ok and options[item_result].id
			or is_reset and table.concat(unit_type_options, ","),
		is_game_override = is_reset or game_scope,
		game_override = game_scope and options[item_result].id or nil,
	}
end

-- >>
