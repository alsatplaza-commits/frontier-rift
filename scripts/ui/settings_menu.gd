extends Control

var _status: Label
var _downloader: PackDownload
var _confirm: ConfirmationDialog
var _alert: AcceptDialog
var _licenses: Window


func _ready() -> void:
	UiKit.fill(self, Color("12161C"))
	var box := UiKit.column(self)
	box.add_child(UiKit.label("Ayarlar", 40))
	var settings: Dictionary = AppState.profile.get("settings", {})
	var auto := " Grafik bu cihaza göre seçildi." if bool(settings.get("quality_auto", false)) else ""
	box.add_child(UiKit.label("Grafik kalitesi." + auto, 18))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	for q in [["low", "Düşük"], ["medium", "Orta"], ["high", "Yüksek"]]:
		var key := str(q[0])
		var b := UiKit.button(str(q[1]), 160)
		if str(settings.get("quality", "")) == key:
			b.text = "● " + b.text
		b.pressed.connect(_set_quality.bind(key))
		row.add_child(b)
	box.add_child(UiKit.label("Ses", 18))
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.05
	slider.value = float(settings.get("volume", 0.8))
	slider.custom_minimum_size = Vector2(420, 48)
	slider.value_changed.connect(func(v: float) -> void:
		AppState.profile["settings"]["volume"] = v
		Quality.apply_volume(v)
		AppState.save()
	)
	box.add_child(slider)
	var pack := UiKit.button("Test paketini indir", 420)
	pack.pressed.connect(_on_pack)
	box.add_child(pack)
	_status = UiKit.label("Çekirdek oyun paket olmadan da çalışır.", 16)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(480, 48)
	box.add_child(_status)
	var uninstall := UiKit.button("Oyunu kaldır", 420)
	uninstall.pressed.connect(_on_uninstall)
	box.add_child(uninstall)
	var licenses := UiKit.button("Lisanslar", 420)
	licenses.pressed.connect(_on_licenses)
	box.add_child(licenses)
	var back := UiKit.button("Geri")
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	box.add_child(back)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Kaldır"
	_confirm.dialog_text = "Frontier Rift kaldırılsın mı?"
	_confirm.ok_button_text = "Kaldır"
	_confirm.cancel_button_text = "Vazgeç"
	_confirm.confirmed.connect(_on_confirm_uninstall)
	add_child(_confirm)
	_alert = AcceptDialog.new()
	_alert.title = "Kaldırma"
	_alert.ok_button_text = "Tamam"
	add_child(_alert)
	_licenses = Window.new()
	_licenses.title = "Lisanslar"
	_licenses.size = Vector2i(840, 600)
	_licenses.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	_licenses.close_requested.connect(func() -> void:
		_licenses.hide()
	)
	var license_text := TextEdit.new()
	license_text.name = "LicenseText"
	license_text.editable = false
	license_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	license_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_licenses.add_child(license_text)
	add_child(_licenses)


func _set_quality(key: String) -> void:
	AppState.profile["settings"]["quality"] = key
	AppState.profile["settings"]["quality_auto"] = false
	Quality.apply(key)
	AppState.save()
	get_tree().change_scene_to_file("res://scenes/settings.tscn")


func _on_pack() -> void:
	if _downloader != null:
		return
	_status.text = "İndiriliyor..."
	_downloader = PackDownload.new()
	add_child(_downloader)
	_downloader.finished.connect(func(ok: bool, message: String) -> void:
		_status.text = message
		_downloader = null
	)
	_downloader.start()


func _on_licenses() -> void:
	var view := _licenses.get_node("LicenseText") as TextEdit
	if FileAccess.file_exists("res://THIRD_PARTY_LICENSES.txt"):
		view.text = FileAccess.get_file_as_string("res://THIRD_PARTY_LICENSES.txt")
	else:
		view.text = "Lisans metni bulunamadı."
	_licenses.popup_centered()


func _on_uninstall() -> void:
	_confirm.popup_centered()


func _on_confirm_uninstall() -> void:
	var message := UninstallRouter.request(get_tree())
	if message != "":
		_alert.dialog_text = message
		_alert.popup_centered()
