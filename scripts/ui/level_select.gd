extends Control


func _ready() -> void:
	UiKit.fill(self, Color("12161C"))
	var box := UiKit.column(self)
	box.add_child(UiKit.label("Bölge seç", 40))
	box.add_child(UiKit.label("Serbest gezinti. Konumun kendi kayıt dosyana yazılır.", 16))
	box.add_child(UiKit.label("Kıyafet", 18))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	for id in ["demir_pence", "ruzgar", "kok"]:
		var fac: Dictionary = AppState.factions[id]
		var b := UiKit.button(str(fac["name"]), 200)
		b.add_theme_color_override("font_color", FactionDB.color_of(fac))
		if id == AppState.faction_id():
			b.text = "● " + b.text
		b.pressed.connect(_pick_faction.bind(id))
		row.add_child(b)
	for level in AppState.levels:
		var id := int(level["id"])
		var b := UiKit.button(str(level["name"]), 420)
		b.pressed.connect(_start_region.bind(id))
		box.add_child(b)
	var back := UiKit.button("Geri")
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	box.add_child(back)


func _pick_faction(id: String) -> void:
	AppState.profile["selected_faction"] = id
	AppState.save()
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")


func _start_region(id: int) -> void:
	var level := AppState.level_def(id)
	AppState.profile["roam"] = {
		"fresh": true,
		"seed": int(level.get("seed", 11011)),
		"region": str(level.get("name", "Vadi")),
	}
	AppState.save()
	get_tree().change_scene_to_file("res://scenes/roam.tscn")
