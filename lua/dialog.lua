-- << pickadv_dialog

local pickadvance = pickadvance
local wesnoth = wesnoth
local ipairs = ipairs
local string = string
local T = wesnoth.require("lua/helper.lua").set_wml_tag_metatable {}
local translate = wesnoth.textdomain "wesnoth"

function pickadvance.show_dialog_unsynchronized(unit)
	local spacer = "\n"
	local label = "Pick advancement for " .. wesnoth.unit_types[unit.type].name
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

	local dialog = {
		T.tooltip { id = "tooltip_large" },
		T.helptip { id = "tooltip_large" },
		T.grid {
			T.row { T.column { T.spacer { width = 250 } } },
			description_row,
			T.row { T.column { horizontal_grow = true, listbox } },
			T.row { T.column { T.label { use_markup = true, label = "Save as default advance for:" } }, },
			T.row { T.column { horizontal_grow = true, T.button { return_value = 0, label = "\nSave for unit\n" } } },
			T.row { T.column { horizontal_grow = true, T.button { return_value = -1, label = "\nSave for game (default)\n" } } },
			--T.row { T.column { horizontal_grow = true, T.button { return_value = -1, label = "\nSave for map (default)\n" } } },
			--T.row { T.column { horizontal_grow = true, T.button { return_value = 2, label = "\nSave globally\n" } } },
			T.row { T.column { horizontal_grow = true, T.button { return_value = -2, label = "\n" .. translate("Cancel") .. "\n" } } },
		}
	}

	local function preshow()
		for i, unit in ipairs(options) do
			wesnoth.set_dialog_value(spacer .. unit.name .. spacer, "the_list", i, "the_label")
			local img = unit.__cfg.image -- TODO: safer way to access __cfg.image
			wesnoth.set_dialog_value(img or "misc/blank-hex.png", "the_list", i, "the_icon")
		end

		if wesnoth.compare_versions(wesnoth.game_config.version, ">=", "1.13.10") then
			wesnoth.set_dialog_focus("the_list")
		end

		local function select()
			local i = wesnoth.get_dialog_value "the_list"
			if i > 0 then
				local img = options[i].__cfg.image -- TODO
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
	local is_ok = dialog_exit_code ~= -2 and item_result >= 1
	print(string.format("Button %s pressed (%s). Item %s selected: %s",
		dialog_exit_code, is_ok and "ok" or "not_ok", item_result, options[item_result].id))
	return {
		is_ok = is_ok,
		type = options[item_result].id,
		game_scope = dialog_exit_code == -1
	}
end

-- >>
