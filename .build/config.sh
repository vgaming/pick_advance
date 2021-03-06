not_pushed_ignore=true

upload_to_wesnoth_versions=(1.14 1.15)

icon() {
	mkdir -p src/target
	hex="misc/blank-hex.png"
	question="misc/qmark.png~SCALE(36,36)"
	arrow="lobby/status-lobby-s.png~SCALE(36,36)"
	marksman="units/elves-wood/marksman.png~CROP(16,12,47,47)~SCALE(36,36)"
	avenger="units/elves-wood/avenger.png~CROP(20,12,47,47)~SCALE(36,36)"
	echo "$hex~BLIT($arrow,0,36)~BLIT($avenger,36,0)~BLIT($marksman,36,36)" | tee src/target/icon.txt
}
addon_manager_args=("--pbl-key" "icon" "$(icon)")
