extends Control


func _ready() -> void:
	UiKit.fill(self, Color("12161C"))
	var strip := ColorRect.new()
	strip.color = FactionDB.color_of(AppState.factions[AppState.faction_id()])
	strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	strip.offset_bottom = 8
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	var box := UiKit.column(self)
	box.add_child(UiKit.label("Frontier Rift", 54))
	var sub := UiKit.label("Rift Engine", 18)
	sub.add_theme_color_override("font_color", Color("A8B0BD"))
	box.add_child(sub)
	box.add_child(UiKit.label("Bölge: yaklaşık 2 km", 16))
	var play := UiKit.button("Oyna")
	play.pressed.connect(func() -> void:
		_start(AppState.next_level_id())
	)
	box.add_child(play)
	var levels := UiKit.button("Seviyeler")
	levels.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/level_select.tscn")
	)
	box.add_child(levels)
	var saved = AppState.profile.get("match")
	if typeof(saved) == TYPE_DICTIONARY and saved.get("sim") != null:
		var cont := UiKit.button("Devam et")
		cont.pressed.connect(func() -> void:
			get_tree().change_scene_to_file("res://scenes/match.tscn")
		)
		box.add_child(cont)
	var settings := UiKit.button("Ayarlar")
	settings.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/settings.tscn")
	)
	box.add_child(settings)
	var quit := UiKit.button("Çıkış")
	quit.pressed.connect(func() -> void:
		get_tree().quit()
	)
	box.add_child(quit)


func _start(level_id: int) -> void:
	AppState.profile["match"] = {"fresh": true, "level_id": level_id, "faction": AppState.faction_id()}
	AppState.save()
	get_tree().change_scene_to_file("res://scenes/match.tscn")
