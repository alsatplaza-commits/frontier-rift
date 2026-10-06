extends Control

var _flash: Label
var _time := 0.0


func _ready() -> void:
	UiKit.fill(self, Color("12161C"))
	var result: Dictionary = AppState.last_result
	var box := UiKit.column(self)
	var won := bool(result.get("won", false))
	box.add_child(UiKit.label("Kazandın" if won else "Kaybettin", 48))
	var gained := int(result.get("gained", 0))
	if gained > 0:
		box.add_child(UiKit.label("+%d deneyim" % gained, 22))
	var bar_info := ProfileStore.bar_values(int(result.get("xp", 0)))
	var bar := ProgressBar.new()
	bar.min_value = float(bar_info.prev)
	bar.max_value = float(bar_info.next)
	bar.value = float(bar_info.value)
	bar.custom_minimum_size = Vector2(480, 28)
	bar.show_percentage = false
	box.add_child(bar)
	box.add_child(UiKit.label("Deneyim %d / %d" % [int(result.get("xp", 0)), int(bar_info.next)], 16))
	if bool(result.get("unlocked", false)):
		_flash = UiKit.label("Yeni seviye açıldı!", 28)
		_flash.add_theme_color_override("font_color", Color("F2C14E"))
		box.add_child(_flash)
	var trivia: Dictionary = result.get("trivia", {})
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1C2430")
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(560, 120)
	var inner := VBoxContainer.new()
	card.add_child(inner)
	inner.add_child(UiKit.label("Bilgi kartı", 16))
	inner.add_child(UiKit.label(str(trivia.get("title", "")), 24))
	var body := UiKit.label(str(trivia.get("body", "")), 18)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(520, 60)
	inner.add_child(body)
	box.add_child(card)
	if won:
		var next := UiKit.button("Devam")
		next.pressed.connect(func() -> void:
			var nxt := int(result.get("level_id", 1)) + 1
			if nxt <= 3 and AppState.is_unlocked(nxt):
				AppState.profile["match"] = {"fresh": true, "level_id": nxt, "faction": AppState.faction_id()}
				AppState.save()
				get_tree().change_scene_to_file("res://scenes/match.tscn")
			else:
				get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		)
		box.add_child(next)
	else:
		var retry := UiKit.button("Tekrar dene")
		retry.pressed.connect(func() -> void:
			AppState.profile["match"] = {"fresh": true, "level_id": int(result.get("level_id", 1)), "faction": AppState.faction_id()}
			AppState.save()
			get_tree().change_scene_to_file("res://scenes/match.tscn")
		)
		box.add_child(retry)
	var menu := UiKit.button("Ana menü")
	menu.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	box.add_child(menu)


func _process(delta: float) -> void:
	if _flash == null:
		return
	_time += delta
	_flash.modulate.a = 0.35 + 0.65 * absf(sin(_time * 6.0))
