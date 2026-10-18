extends SceneTree
## Exercises the actual Godot UI. Run with a graphics renderer to save screenshots.
var app: Control
var failures: Array[String] = []
var output := "/private/tmp/long-way-home-qa"
var save_path := "user://long_way_home_save.json"
var old_save := ""
var had_save := false
var old_settings := ""
var had_settings := false
var settings_path := "user://settings.cfg"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1440,900)
	had_save = FileAccess.file_exists(save_path)
	if had_save:
		old_save = FileAccess.get_file_as_string(save_path)
	had_settings = FileAccess.file_exists(settings_path)
	if had_settings:
		old_settings = FileAccess.get_file_as_string(settings_path)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await settle()
	app.reduced_motion = true
	app._show("select")
	await settle()
	check(app.species_list.size()==5,"Five species are selectable")
	check(find_button(app,"START MIGRATION")!=null,"Start button exists")
	check(find_button(app,"START MIGRATION").get_global_rect().end.y <= app.size.y,"Start remains visible")
	await capture("01-select")
	var timeline: Control = app.find_child("EraTimeline", true, false)
	timeline.value = 1700
	await settle()
	var early_alpha: float = app.flock_art.modulate.a
	check(app.selected_era == 1700,"Timeline selects historical era")
	check(app.threat_row.get_child_count() == 3,"Historical threat preview updates")
	check(app.remaining_label.text == "100.0%", "1700 is the 100% baseline")
	check(is_equal_approx(early_alpha, 1.0), "Baseline shows the complete flock artwork")
	var cards: Control = app.find_child("SpeciesCards",true,false)
	check(cards.get_global_rect().end.y <= find_button(app,"START MIGRATION").global_position.y,"Species cards fit above start controls")
	await capture("07-era-1700")
	timeline.grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	root.push_input(key)
	key = InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = false
	root.push_input(key)
	await settle()
	check(is_equal_approx(timeline.value, 1701.0),"Timeline arrows move continuously by year")
	# Drag the ruler through an intermediate year: no century snapping.
	timeline.value = 1800.0
	await settle()
	var start_point: Vector2 = timeline.global_position + Vector2(timeline.size.x * 0.5, 44)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = start_point
	root.push_input(click, true)
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.position = start_point - Vector2(timeline.pixels_per_year() * 37.5, 0)
	drag.relative = drag.position - start_point
	root.push_input(drag, true)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = drag.position
	release.pressed = false
	root.push_input(release, true)
	await settle()
	check(absf(timeline.value - 1837.5) < 0.1,"Actual drag moves ruler without snapping")
	var intermediate: float = app.flock_art.modulate.a
	timeline.value = 1838.0
	await settle()
	check(app.flock_art.modulate.a < intermediate and intermediate - app.flock_art.modulate.a < 0.05,"Whale opacity changes smoothly within a century")
	check("humpback-flock-v1.png" in app.flock_art.texture.resource_path,"Flock uses its composed species artwork")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_RIGHT
	wheel.pressed = true
	wheel.factor = 1.0
	wheel.position = start_point
	root.push_input(wheel, true)
	wheel = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_RIGHT
	wheel.pressed = false
	wheel.position = start_point
	root.push_input(wheel, true)
	await create_timer(0.25).timeout
	check(timeline.value > 1838.0,"Horizontal scroll moves the timeline")
	await capture("09-continuous-timeline")
	timeline.value = 2100
	await settle()
	check(app.flock_art.modulate.a < early_alpha,"Whale silhouettes fade toward future")
	check("scenario" in app.era_title.text.to_lower(),"Future era explicitly says scenario")
	check(app.remaining_label.text == "20.0%" and is_equal_approx(app.flock_art.modulate.a, 0.2), "Future percentage and fade match the illustrative curve")
	timeline.value = 1750
	await settle()
	check(app.remaining_label.text == "90.0%" and is_equal_approx(app.flock_art.modulate.a, 0.9), "Scrolling backward restores the matching percentage and artwork")
	timeline.value = 2100
	await settle()
	await capture("08-era-2100")
	press("SETTINGS")
	await settle()
	var motion := find_button(app, "Reduce motion") as CheckButton
	check(motion != null,"Settings opens working motion control")
	motion.button_pressed = false
	await settle()
	check(not app.reduced_motion and FileAccess.file_exists(settings_path),"Motion setting applies and persists")
	motion.button_pressed = true
	var dialog: AcceptDialog = motion.get_parent().get_parent()
	dialog.hide()
	dialog.confirmed.emit()
	await settle()
	app.find_child("EraTimeline",true,false).value = 1837.5
	await settle()
	press("Blue Whale")
	await settle()
	check(app.selected_id=="blue","Species button changes selection")
	check(app.selected_era==1800 and is_equal_approx(app.timeline_year,1837.5),"Species selection preserves exact timeline position")
	check("blue-flock-v2.png" in app.flock_art.texture.resource_path,"Group artwork follows selected species")
	press("FIELD GUIDE")
	await settle()
	check(app.screen=="guide","Field guide opens")
	await capture("02-guide")
	press("BACK")
	await settle()
	check(app.screen=="select","Guide returns to selection")
	press("Humpback Whale")
	await settle()
	press("START MIGRATION")
	await settle()
	check(app.screen=="play","Start opens expedition")
	check(app.state.species_id=="humpback","Correct species started")
	check(app.state.era==1800,"Start carries selected era into simulation")
	await capture("03-expedition")
	# Play using the UI's own callback path; decisions are tested in engine tests.
	var steps := 0
	while app.state.status=="active" and steps<35:
		var ev: Dictionary = app.Sim.current_event(app.state)
		var upgrade: String = app.Sim.THREAT_UPGRADE[ev.threat]
		if app.Sim.can_buy(app.state,upgrade):
			app._buy(upgrade)
			await settle()
		var mode := "forage" if float(app.state.energy)<22 and app.Sim.can_forage(app.state) else "travel"
		press("FORAGE" if mode=="forage" else "ADVANCE")
		await settle()
		steps+=1
	check(app.state.status!="active","Journey reaches an ending")
	check(app.screen=="debrief","Ending displays debrief")
	await capture("04-debrief")
	press("REPLAY")
	await settle()
	check(app.state.turn==0 and app.screen=="play" and app.state.era==1800,"Replay preserves era and starts clean expedition")
	# Save/restore through the UI's actual helper.
	app._advance("travel")
	await settle()
	var loaded: Dictionary = app._read_save()
	check(loaded.get("turn",-1)==app.state.turn,"Save reload preserves progress")
	press("HOME")
	await settle()
	check(app.screen=="select" and not app._read_save().is_empty(),"Home preserves active save")
	app.find_child("EraTimeline",true,false).value = 2100
	await settle()
	press("CONTINUE")
	await settle()
	check(app.screen=="play" and app.state.turn==loaded.turn and app.selected_era==1800,"Continue restores saved expedition and era")
	root.size = Vector2i(960,720)
	await settle()
	await capture("05-compact")
	app._show("select")
	await settle()
	await capture("06-compact-select")
	if had_settings:
		var settings_file := FileAccess.open(settings_path,FileAccess.WRITE)
		settings_file.store_string(old_settings)
	elif FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	if had_save:
		var file := FileAccess.open(save_path,FileAccess.WRITE)
		file.store_string(old_save)
	elif FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	print("UI_TEST_RESULT ",JSON.stringify({"failures":failures,"steps":steps,"screenshots":output}))
	quit(0 if failures.is_empty() else 1)

func settle() -> void:
	for i in range(5):
		await process_frame

func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless":
		return
	# The side preview may cover this window on macOS; request a frame explicitly.
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute(output)
	root.get_texture().get_image().save_png(output.path_join(name+".png"))

func check(passed: bool, message: String) -> void:
	print("PASS " if passed else "FAIL ",message)
	if not passed:
		failures.append(message)

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.is_visible_in_tree() and text in node.text:
		return node
	for child in node.get_children():
		var button := find_button(child,text)
		if button:
			return button
	return null

func press(text: String) -> void:
	var button := find_button(app,text)
	if button==null or button.disabled:
		check(false,"Button available: "+text)
		return
	button.pressed.emit()
