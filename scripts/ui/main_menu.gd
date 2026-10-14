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
	box.add_child(UiKit.label("Üçüncü şahıs açık arazi", 16))
	if _has_resume():
		var cont := UiKit.button("Devam et")
		cont.pressed.connect(func() -> void:
			get_tree().change_scene_to_file("res://scenes/roam.tscn")
		)
		box.add_child(cont)
		var fresh := UiKit.button("Yeni gezinti")
		fresh.pressed.connect(func() -> void:
			_begin(11011, "İlk Kamp")
		)
		box.add_child(fresh)
	else:
		var play := UiKit.button("Oyna")
		play.pressed.connect(func() -> void:
			_begin(11011, "İlk Kamp")
		)
		box.add_child(play)
	var levels := UiKit.button("Bölgeler")
	levels.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/level_select.tscn")
	)
	box.add_child(levels)
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


func _has_resume() -> bool:
	var roam = AppState.profile.get("roam")
	return typeof(roam) == TYPE_DICTIONARY and roam.has("x") and not bool(roam.get("fresh", false))


func _begin(seed: int, region: String) -> void:
	AppState.profile["roam"] = {"fresh": true, "seed": seed, "region": region}
	AppState.save()
	get_tree().change_scene_to_file("res://scenes/roam.tscn")
