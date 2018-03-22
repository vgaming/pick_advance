-- << pickadv_dialog

local pickadvance = pickadvance
local wesnoth = wesnoth
local ipairs = ipairs
local string = string
local table = table
local T = wesnoth.require("lua/helper.lua").set_wml_tag_metatable {}
local translate = wesnoth.textdomain "wesnoth"

function pickadvance.show_dialog_unsynchronized(unit, current)
	local spacer = "\n"
	local label = string.format("Pick advance (currently %s):", current)
	local unit_type_options = pickadvance.advance_array(unit.type)
	--print_as_json("advances for", unit.type, unit_type_options)
	local options = {}
	for _, ut in ipairs(unit_type_options) do
		options[#options + 1] = wesnoth.unit_types[ut]
	end
	local show_images = true

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

	local help_button = T.button {
		return_value = -4,
		label = "\n" .. translate("Help") .. "\n"
	}

	local reset_help_buttons = T.grid {
		T.row {
			T.column { horizontal_grow = true, reset_button },
			T.column { horizontal_grow = true, help_button }
		}
	}

	local dialog = {
		T.tooltip { id = "tooltip_large" },
		T.helptip { id = "tooltip_large" },
		T.grid {
			T.row { T.column { T.spacer { width = 250 } } },
			description_row,
			T.row { T.column { horizontal_grow = true, listbox } },
			--T.row { T.column { T.label { use_markup = true, label = "Save as default advance for:" } }, },
			T.row { T.column { horizontal_grow = true, T.button { return_value = 2, label = "\nSave for unit\n" } } },
			T.row { T.column { horizontal_grow = true, T.button { return_value = 1, label = "\nSave for game\n" } } },
			T.row { T.column { horizontal_grow = true, T.button { return_value = -1, label = "\nSave for map (default)\n" } } },
			T.row { T.column { horizontal_grow = true, reset_help_buttons } },
		}
	}

	local function preshow()
		for i, advance_type in ipairs(options) do
			wesnoth.set_dialog_value(spacer .. advance_type.name .. spacer, "the_list", i, "the_label")
			local img = advance_type.__cfg.image
			wesnoth.set_dialog_value(img or "misc/blank-hex.png", "the_list", i, "the_icon")
		end

		if wesnoth.compare_versions(wesnoth.game_config.version, ">=", "1.13.10") then
			wesnoth.set_dialog_focus("the_list")
		end

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
	local is_cancel = dialog_exit_code == -2
	local is_ok = dialog_exit_code > -2 and item_result >= 1
	if is_help then
		wesnoth.wml_actions.message {
			speaker = "narrator",
			message = "Picking advance for your unit makes the unit "
				.. "always advance to said type, even in multiplayer game when it's not your turn."
				.. "\n\n"
				.. "<b>Save for game</b> applies to all new units of same type in game."
				.. "\n\n"
				.. "<b>Save for map</b> applies to all new units of same type in all future games on a map. "
				.. "Works while the add-on is enabled."
				.. "\n\n\n" .. wesnoth.get_variable("pickadvance_contacts"),
			image = "misc/qmark.png~SCALE(200,200)"
		}
	end
	print(string.format("Button %s pressed (%s). Item %s selected: %s",
		dialog_exit_code, is_ok and "ok" or "not_ok", item_result, options[item_result].id))
	local do_not_change = is_help or is_cancel
	return {
		type = do_not_change and current
			or is_reset and table.concat(unit_type_options, ",")
			or options[item_result].id,
		game_scope = is_reset or dialog_exit_code == 1 or dialog_exit_code == -1,
		map_scope = is_reset or dialog_exit_code == -1
	}
end

-- >>
