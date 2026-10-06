class_name UiKit
extends RefCounted

static func fill(parent: Node, color: Color) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = color
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	return bg


static func button(text: String, wide := 280.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(wide, 68)
	b.add_theme_font_size_override("font_size", 22)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("243041")
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var hover := normal.duplicate()
	hover.bg_color = Color("31425A")
	var pressed := normal.duplicate()
	pressed.bg_color = Color("1A2838")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", normal)
	b.add_theme_color_override("font_color", Color("F4F7FB"))
	b.pressed.connect(func() -> void:
		if Engine.get_main_loop() and Engine.get_main_loop().root.has_node("AppState"):
			Engine.get_main_loop().root.get_node("AppState").play_click()
	)
	return b


static func label(text: String, size := 20) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("F4F7FB"))
	return l


static func column(parent: Node) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 24
	box.offset_top = 24
	box.offset_right = -24
	box.offset_bottom = -24
	parent.add_child(box)
	return box
