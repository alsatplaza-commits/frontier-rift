extends Node

var factions := {}
var levels: Array = []
var trivia := {}
var profile := {}
var last_result := {}
var click_player: AudioStreamPlayer


func _ready() -> void:
	DisplayServer.window_set_title("Frontier Rift")
	factions = FactionDB.load_all()
	levels = ContentDB.load_levels()
	trivia = ContentDB.load_trivia()
	profile = ProfileStore.load_profile()
	Quality.apply(str(profile.get("settings", {}).get("quality", "medium")))
	Quality.apply_volume(float(profile.get("settings", {}).get("volume", 0.8)))
	click_player = AudioStreamPlayer.new()
	click_player.stream = _make_click()
	add_child(click_player)


func play_click() -> void:
	if click_player:
		click_player.play()


func save() -> void:
	ProfileStore.save_profile(profile)


func faction_id() -> String:
	var id := str(profile.get("selected_faction", "demir_pence"))
	if not factions.has(id):
		id = "demir_pence"
		profile["selected_faction"] = id
	return id


func level_def(id: int) -> Dictionary:
	return ContentDB.level_by_id(levels, id)


func next_level_id() -> int:
	var cleared := int(profile.get("cleared", 0))
	return clampi(cleared + 1, 1, 3)


func is_unlocked(level_id: int) -> bool:
	return level_id <= int(profile.get("cleared", 0)) + 1 and level_id >= 1 and level_id <= 3


func on_match_end(won: bool, level_id: int) -> void:
	var lvl := level_def(level_id)
	var gained := 0
	var unlocked := false
	if won:
		gained = int(lvl.get("xp_reward", 0))
		profile["xp"] = int(profile.get("xp", 0)) + gained
		if int(profile.get("cleared", 0)) < level_id:
			profile["cleared"] = level_id
			unlocked = level_id < 3
	profile["match"] = null
	save()
	var trivia_id := str(lvl.get("trivia_id", ""))
	last_result = {
		"won": won,
		"gained": gained,
		"unlocked": unlocked,
		"trivia": trivia.get(trivia_id, {"title": "Bilgi", "body": ""}),
		"level_id": level_id,
		"xp": int(profile.get("xp", 0)),
	}


func _make_click() -> AudioStreamWAV:
	var rate := 22050
	var n := 1600
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var env := exp(-t * 30.0)
		var sample := int(sin(t * TAU * 740.0) * env * 7000.0)
		data[i * 2] = sample & 255
		data[i * 2 + 1] = (sample >> 8) & 255
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
