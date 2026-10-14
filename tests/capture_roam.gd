extends SceneTree

func _init() -> void:
	call_deferred("_shot")


func _shot() -> void:
	var app = root.get_node("AppState")
	Quality.apply("high")
	app.profile["settings"]["quality"] = "high"
	app.profile["roam"] = {"fresh": true, "seed": 11011, "region": "İlk Kamp"}
	var err := change_scene_to_file("res://scenes/roam.tscn")
	if err != OK:
		print("CAPTURE_FAIL scene")
		quit(1)
		return
	for _i in 8:
		await process_frame
	var roam = current_scene
	if roam == null or roam.pawn == null:
		print("CAPTURE_FAIL roam")
		quit(1)
		return
	for _i in 40:
		await physics_frame
		if roam.pawn.is_on_floor():
			break
	for _i in 4:
		await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.get_width() < 8:
		print("CAPTURE_FAIL image")
		quit(1)
		return
	var path := "/tmp/frontier_rift_roam.png"
	image.save_png(path)
	var stats := _stats(image)
	print("CAPTURE ", path, " ", image.get_width(), "x", image.get_height(), " std=", stats.std, " greens=", stats.green, " blues=", stats.blue, " rocks=", stats.rock, " sit=", roam.pawn.visual_sit)
	if roam.pawn.toggle_sit():
		for _i in 20:
			await process_frame
		var seated := root.get_texture().get_image()
		seated.save_png("/tmp/frontier_rift_sit.png")
		print("CAPTURE sit=", roam.pawn.visual_sit)
	if float(stats.std) < 8.0:
		print("CAPTURE_FAIL flat image")
		quit(1)
		return
	quit(0)


func _stats(image: Image) -> Dictionary:
	var step := 4
	var n := 0
	var sum := 0.0
	var sum2 := 0.0
	var green := 0
	var blue := 0
	var rock := 0
	for y in range(0, image.get_height(), step):
		for x in range(0, image.get_width(), step):
			var c := image.get_pixel(x, y)
			var l := (c.r + c.g + c.b) / 3.0
			sum += l
			sum2 += l * l
			n += 1
			if c.g > c.r + 0.04 and c.g > c.b:
				green += 1
			if c.b > c.r and c.b > 0.35:
				blue += 1
			if absf(c.r - c.g) < 0.06 and absf(c.g - c.b) < 0.06 and c.r > 0.25:
				rock += 1
	var mean := sum / float(maxi(n, 1))
	var variance := sum2 / float(maxi(n, 1)) - mean * mean
	return {"std": sqrt(maxf(variance, 0.0)) * 255.0, "green": green, "blue": blue, "rock": rock}
