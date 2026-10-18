extends SceneTree
## Native rendered preview and input smoke test. Preserves the user's saved game.
var failures: Array[String] = []
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1440,900)
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	for i in range(45): await process_frame
	var atlas = app.content.find_child("AtlasStage",true,false).get_child(0)
	var original_zoom: float = atlas.zoom
	var scroll := InputEventMouseButton.new()
	scroll.position = Vector2(700,450)
	scroll.button_index = MOUSE_BUTTON_WHEEL_UP
	scroll.pressed = true
	root.push_input(scroll,true)
	for i in range(3): await process_frame
	check(atlas.zoom < original_zoom,"Mouse wheel zooms the rendered map")
	scroll.pressed = false
	root.push_input(scroll.duplicate(),true)
	await process_frame
	var press := InputEventMouseButton.new()
	press.position = Vector2(700,450)
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press.duplicate(),true)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(740,460)
	motion.relative = Vector2(40,10)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion.duplicate(),true)
	for i in range(3): await process_frame
	check(atlas.pan.length() > 0.0,"Dragging pans the rendered map")
	press.pressed = false
	press.position = Vector2(740,460)
	root.push_input(press.duplicate(),true)
	await process_frame
	atlas.reset_view()
	check(atlas.pan == Vector3.ZERO and is_equal_approx(atlas.zoom,13.5),"Reset restores the initial composition")
	var whale = app.content.find_child("WhalePortrait",true,false)
	check(whale is TextureRect and whale.texture != null,"Species portrait is a static texture")
	check(not whale.is_processing(),"Whale portrait has no animation loop")
	var portrait_rect: Rect2 = whale.get_global_rect()
	press.position = portrait_rect.get_center()
	press.global_position = press.position
	press.pressed = true
	root.push_input(press.duplicate(),true)
	await process_frame
	motion.position = press.position+Vector2(40,0)
	motion.global_position = motion.position
	motion.relative = Vector2(40,0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion.duplicate(),true)
	await process_frame
	press.position = motion.position
	press.pressed = false
	root.push_input(press.duplicate(),true)
	await process_frame
	check(whale.get_global_rect() == portrait_rect and atlas.pan == Vector3.ZERO,"Dragging the portrait leaves both whale and map stationary")
	var start := Time.get_ticks_msec()
	for i in range(90): await process_frame
	var elapsed := Time.get_ticks_msec()-start
	print("NATIVE_PREVIEW ",JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"viewport":str(root.size),"engine_static_memory_mib":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,"render_memory_mib":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,"average_fps_90_frames":90000.0/elapsed,"failures":failures}))
	DirAccess.make_dir_recursive_absolute("res://previews")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://previews/static-whale-atlas.png")
	var paths: Array[String] = []
	for species: Dictionary in app.species_list:
		app.selected_id = species.id
		app._show("select")
		for i in range(20): await process_frame
		whale = app.content.find_child("WhalePortrait",true,false)
		var expected := "res://assets/whales/%s-v1.png" % species.id
		check(whale.texture.resource_path == expected,"Correct portrait for " + species.id)
		check(not paths.has(expected),"Distinct artwork for " + species.id)
		var profile: Rect2 = app.content.find_child("ProfilePanel",true,false).get_global_rect()
		var stage: Rect2 = app.content.find_child("AtlasStage",true,false).get_global_rect()
		check(profile.end.x <= stage.end.x+1 and profile.end.y <= stage.end.y+1,"Profile stays inside the atlas for " + species.id)
		paths.append(expected)
		var original: Image = whale.texture.get_image()
		if original.is_compressed(): original.decompress()
		check(original.detect_alpha() != Image.ALPHA_NONE,"Transparent image for " + species.id)
		check(original.get_pixel(0,0).a < 0.1,"Transparent corner for " + species.id)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://previews/static-%s.png" % species.id)
	app.selected_id = "humpback"
	app._show("select")
	app._open_guide()
	for i in range(25): await process_frame
	check(app.content.find_child("WhalePortrait",true,false) != null,"Field guide displays the large static portrait")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://previews/static-whale-guide.png")
	app.reduced_motion = true
	app._show("select")
	for i in range(15): await process_frame
	whale = app.content.find_child("WhalePortrait",true,false)
	check(whale is TextureRect and not whale.is_processing(),"Portrait remains static with reduced motion")
	print("STATIC_ART_RESULT ",JSON.stringify({"failures":failures,"species":paths.size()}))
	quit(0 if failures.is_empty() else 1)
func check(passed: bool, message: String) -> void:
	print("PASS " if passed else "FAIL ",message)
	if not passed: failures.append(message)
