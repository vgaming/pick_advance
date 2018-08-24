-- << pickadvance_advertisement

local wesnoth = wesnoth
local ipairs = ipairs
local tostring = tostring

local script_arguments = ...
local remote_version = tostring(script_arguments.remote_version)
local filename = "~add-ons/pick_advance/target/version.txt"

local side = wesnoth.sides[wesnoth.current.side]
if not side.is_local and side.controller == "human" then
	wesnoth.wml_actions.remove_event { id = "pickadvance_ad" }
	if not wesnoth.have_file(filename) then
		for _, s in ipairs(wesnoth.sides) do
			if s.is_local then
				wesnoth.message("PlanUnitAdvance", "When it's your turn, click on units to select their advances for the future. If you'll like this add-on, feel free to download it.")
				return
			end
		end
	else
		local local_version = wesnoth.read_file(filename)
		if wesnoth.compare_versions(remote_version, ">", local_version) then
			wesnoth.wml_actions.message {
				caption = "PlanUnitAdvance",
				message = "🠉🠉🠉 Please upgrade your PlanUnitAdvance add-on 🠉🠉🠉"
					.. "\n\n"
					.. local_version .. " -> " .. remote_version
					.. "(You can do that after the game)",
				image = "misc/blank-hex.png~BLIT(lobby/status-lobby-s.png~SCALE(36,36),0,36)~BLIT(units/elves-wood/avenger.png~CROP(20,12,47,47)~SCALE(36,36),36,0)~BLIT(units/elves-wood/marksman.png~CROP(16,12,47,47)~SCALE(36,36),36,36)",
			}
		end
	end
end

-- >>
