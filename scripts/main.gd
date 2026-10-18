extends Control
## Long Way Home: screens, controls and save/continue. Engine and map are loaded
## at runtime so this script parses even before their files exist.

const UI := preload("res://scripts/ui_theme.gd")
const Eras = preload("res://scripts/era_data.gd")
const SETTINGS_PATH := "user://settings.cfg"
const SAVE_PATH := "user://long_way_home_save.json"
const NARROW_WIDTH := 1000.0
const FLOCK_VERSIONS := {"humpback": 1, "blue": 2, "gray": 2, "right": 1, "sperm": 1}

var Sim: Script
var Data: Script
var MapScript: Script

var species_list: Array = []
var selected_id := ""
var selected_era := 1700
var timeline_year := 1700.0
var era_title: Label
var era_description: Label
var era_difficulty: Label
var threat_row: HFlowContainer
var flock_art: TextureRect
var remaining_label: Label
var state: Dictionary = {}
var screen := "select"
var return_screen := "select"
var reduced_motion := false
var saved_state: Dictionary = {}

var content: Control
var body_boxes: Array[BoxContainer] = []
var heading: Font
var mono: Font


func _ready() -> void:
	DisplayServer.window_set_title("Long Way Home - A Whale Migration Strategy Game")
	Sim = _load_script("res://scripts/simulation.gd")
	Data = _load_script("res://scripts/species_data.gd")
	MapScript = _load_script("res://scripts/atlas_3d.gd")
	theme = UI.build()
	heading = UI.heading_font()
	mono = UI.mono_font()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := Backdrop.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	content = MarginContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(content)
	resized.connect(_apply_responsive)

	if Data == null or Sim == null:
		_show_missing()
		return
	species_list = []
	for id in ["humpback", "blue", "gray", "right", "sperm"]:
		species_list.append(Data.get_species(id))
	if not species_list.is_empty():
		selected_id = species_list[0].id
	_load_settings()
	saved_state = _read_save()
	_show("select")


func _load_script(path: String) -> Script:
	return load(path) if ResourceLoader.exists(path) else null


# ---------------------------------------------------------------- screens

func _show(next: String) -> void:
	screen = next
	for c in content.get_children():
		c.queue_free()
	body_boxes.clear()
	var margin := 40 if size.x >= NARROW_WIDTH else 16
	for side in ["left", "right", "top", "bottom"]:
		content.add_theme_constant_override("margin_" + side, margin if side != "top" else 24)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	content.add_child(root)
	root.add_child(_top_bar())
	match next:
		"select": _build_select(root)
		"play": _build_play(root)
		"guide": _build_guide(root)
		"debrief": _build_debrief(root)
	_apply_responsive()
	if not reduced_motion:
		root.modulate.a = 0.0
		create_tween().tween_property(root, "modulate:a", 1.0, 0.25)
	_focus_first.call_deferred(root)


func _focus_first(root: Control) -> void:
	var primary := root.find_child("Primary", true, false)
	if primary is Control and (primary as Control).is_visible_in_tree():
		(primary as Control).grab_focus()


func _top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	var brand := _label("L O N G   W A Y   H O M E", 13, UI.CYAN, mono)
	brand.add_theme_constant_override("outline_size", 0)
	bar.add_child(brand)
	bar.add_child(_label("/  " + screen.to_upper(), 13, UI.MUTED, mono))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	if screen != "guide":
		bar.add_child(_button("FIELD GUIDE", _open_guide))
	var settings := _button("⚙  SETTINGS", _open_settings)
	settings.tooltip_text = "Motion and display settings"
	bar.add_child(settings)
	bar.add_child(_button("⌂  HOME", _home))
	return bar


func _build_select(root: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	scroll.add_child(col)
	var ocean := _bracket_panel()
	var ocean_col := ocean.get_child(0) as VBoxContainer
	ocean_col.add_child(_label("01 / CHOOSE AN ERA", 12, UI.MUTED, mono))
	var pod := Control.new()
	pod.name = "HolographicPod"
	pod.custom_minimum_size.y = 330
	pod.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flock_art = TextureRect.new()
	flock_art.name = "FlockArtwork"
	flock_art.texture = load("res://assets/whales/flocks/%s-flock-v%d.png" % [selected_id, FLOCK_VERSIONS[selected_id]])
	flock_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flock_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flock_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	flock_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flock_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pod.add_child(flock_art)
	var readout := VBoxContainer.new()
	readout.position = Vector2(12, 42)
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	readout.add_theme_constant_override("separation", 5)
	readout.add_child(_label("Long Way Home", 28, UI.TEXT, heading))
	readout.add_child(_label("Pick your setting", 18, UI.CYAN, heading))
	var breathing_room := Control.new()
	breathing_room.custom_minimum_size.y = 26
	readout.add_child(breathing_room)
	readout.add_child(_label("ILLUSTRATIVE POPULATION", 11, UI.MUTED, mono))
	remaining_label = _label("", 30, UI.CYAN, mono)
	remaining_label.name = "RemainingPercentage"
	readout.add_child(remaining_label)
	readout.add_child(_label("REMAINING / 1700 = 100%", 11, UI.MUTED, mono))
	pod.add_child(readout)
	ocean_col.add_child(pod)
	var timeline: Control = preload("res://scripts/era_timeline.gd").new()
	timeline.name = "EraTimeline"
	timeline.value = timeline_year
	ocean_col.add_child(timeline)
	var info := VBoxContainer.new()
	info.custom_minimum_size.x = 244
	info.add_theme_constant_override("separation", 10)
	pod.add_child(info)
	pod.resized.connect(func() -> void:
		info.position = Vector2(pod.size.x - 256, 42)
		info.size.x = 244)
	era_title = _label("", 20, UI.TEXT, heading)
	era_title.name = "EraTitle"
	era_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(era_title)
	era_difficulty = _label("", 11, UI.AMBER, mono)
	info.add_child(era_difficulty)
	era_description = _para("", 15, UI.MUTED)
	era_description.visible = false
	info.add_child(era_description)
	threat_row = HFlowContainer.new()
	threat_row.name = "EraThreats"
	threat_row.add_theme_constant_override("h_separation", 22)
	threat_row.add_theme_constant_override("v_separation", 5)
	info.add_child(threat_row)
	ocean_col.add_child(_para("Illustrative game curve, not historical population data. Real populations can recover. 2100 is a projection scenario.", 12, UI.MUTED))
	col.add_child(ocean)
	timeline.value_changed.connect(func(value: float) -> void:
		timeline_year = value
		# The ruler is continuous; gameplay uses the century containing that year.
		var era := mini(2100, 1700 + int((value - 1700.0) / 100.0) * 100)
		_refresh_whale_fade()
		if era != selected_era:
			selected_era = era
			_refresh_era())
	_refresh_era()
	col.add_child(_label("02 / SELECT TYPE", 12, UI.MUTED, mono))
	var cards := HBoxContainer.new()
	cards.name = "SpeciesCards"
	cards.add_theme_constant_override("separation", 12)
	for entry in species_list:
		var card := Button.new()
		card.text = entry.name
		card.name = "Species_" + entry.id
		card.toggle_mode = true
		card.button_pressed = entry.id == selected_id
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 138)
		card.clip_text = true
		card.tooltip_text = entry.name + " · " + entry.tagline
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			card.add_theme_color_override(key, Color.TRANSPARENT)
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 10)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(box)
		var art: Control = load("res://scripts/static_whale.gd").new()
		art.species_id = entry.id
		art.custom_minimum_size.y = 64
		box.add_child(art)
		var name_label := _label(entry.name, 17, UI.TEXT, heading)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(name_label)
		var selected := _label("SELECTED" if entry.id == selected_id else "SELECT", 10, UI.CYAN if entry.id == selected_id else UI.MUTED, mono)
		selected.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		selected.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(selected)
		card.add_child(margin)
		var id: String = entry.id
		card.pressed.connect(func() -> void:
			selected_id = id
			_show("select")
			_refocus_species.call_deferred(id))
		cards.add_child(card)
	col.add_child(cards)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	var route := _para(_species().route_label + " · " + str(_species().legs) + " legs" + ("\nStarting a new migration replaces the saved expedition." if not saved_state.is_empty() else ""), 14, UI.MUTED)
	route.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(route)
	if not saved_state.is_empty():
		actions.add_child(_button("CONTINUE EXPEDITION", func() -> void: _begin(saved_state)))
	var start := _button("START MIGRATION  →", _start_new)
	start.tooltip_text = "Start a new journey. This replaces the saved expedition." if not saved_state.is_empty() else "Begin with the selected species and era."
	start.name = "Primary"
	start.custom_minimum_size = Vector2(240, 52)
	start.add_theme_color_override("font_color", UI.AMBER)
	actions.add_child(start)
	root.add_child(actions)


func _refocus_species(id: String) -> void:
	var card := content.find_child("Species_" + id, true, false) as Button
	if card:
		card.grab_focus()


func _refresh_era() -> void:
	var era := Eras.get_era(selected_era)
	era_title.text = era.title
	era_description.text = era.description
	era_title.tooltip_text = era.description
	era_difficulty.text = ("SCENARIO  /  " if era.scenario else "ERA PRESSURE / ") + era.difficulty.to_upper()
	_refresh_whale_fade()
	for child in threat_row.get_children():
		threat_row.remove_child(child)
		child.queue_free()
	for threat in era.threats:
		var item := HBoxContainer.new()
		item.add_child(_threat_icon(threat, 28))
		item.add_child(_label(Eras.THREAT_NAMES[threat], 12, UI.CYAN))
		threat_row.add_child(item)


func _remaining_fraction() -> float:
	var position := clampf((timeline_year - 1700.0) / 100.0, 0.0, 4.0)
	var lower := mini(int(position), 3)
	return lerpf(float(Eras.RECORDS[lower].silhouette_fraction), float(Eras.RECORDS[lower + 1].silhouette_fraction), position - lower)


func _refresh_whale_fade() -> void:
	var fraction := _remaining_fraction()
	# One composed artwork retains its individual poses and scale relationships.
	# Opacity and the readout share the same continuous, illustrative baseline.
	flock_art.modulate.a = fraction
	remaining_label.text = "%0.1f%%" % (fraction * 100.0)


func _threat_icon(id: String, extent: int = 40) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load("res://assets/threats/%s.svg" % id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(extent, extent)
	icon.tooltip_text = Eras.THREAT_NAMES.get(id, id)
	return icon


func _home() -> void:
	if not state.is_empty() and state.get("status") == "active":
		_write_save()
	_show("select")


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		reduced_motion = bool(config.get_value("display", "reduced_motion", false))
		if bool(config.get_value("display", "fullscreen", false)):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "reduced_motion", reduced_motion)
	config.set_value("display", "fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	config.save(SETTINGS_PATH)


func _open_settings() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Settings"
	dialog.min_size = Vector2i(380, 180)
	var box := VBoxContainer.new()
	var motion := CheckButton.new()
	motion.text = "Reduce motion"
	motion.button_pressed = reduced_motion
	motion.toggled.connect(func(on: bool) -> void:
		reduced_motion = on
		_save_settings()
		_show(screen))
	box.add_child(motion)
	var fullscreen := CheckButton.new()
	fullscreen.text = "Fullscreen"
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(func(on: bool) -> void:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
		_save_settings())
	box.add_child(fullscreen)
	dialog.add_child(box)
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()


func _build_play(root: VBoxContainer) -> void:
	var sp := _species()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 28)
	var name_box := VBoxContainer.new()
	name_box.add_child(_label("LEG %02d / %02d" % [mini(state.turn + 1, state.total_turns), state.total_turns], 13, UI.AMBER, mono))
	name_box.add_child(_label(sp.get("name", ""), 40, UI.TEXT, heading))
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_child(_label(Eras.get_era(selected_era).title, 14, UI.CYAN, mono))
	head.add_child(name_box)
	head.add_child(_meter("CONDITION", state.condition))
	head.add_child(_meter("ENERGY", state.energy))
	head.add_child(_stat("POINTS", str(state.points)))
	root.add_child(head)
	root.add_child(_progress_rule(float(state.turn) / max(1.0, float(state.total_turns))))

	var body := _body_box(root)
	var map := _map(sp, state)
	map.size_flags_stretch_ratio = 2.0
	body.add_child(map)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(380, 320)
	var console := VBoxContainer.new()
	console.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	console.add_theme_constant_override("separation", 14)
	scroll.add_child(console)
	body.add_child(scroll)

	var ev: Dictionary = Sim.current_event(state)
	var brief := _bracket_panel()
	var bv := brief.get_child(0) as VBoxContainer
	bv.add_child(_threat_icon(ev.threat))
	var sev := int(ev.get("severity", 0))
	bv.add_child(_label("%s  ·  %s" % [String(ev.get("label", "Briefing")).to_upper(), String(ev.get("threat", "")).to_upper()],
		13, UI.AMBER if sev >= 2 else UI.CYAN, mono))
	bv.add_child(_para(ev.get("title", "Open water"), 24, UI.TEXT, heading))
	bv.add_child(_para(ev.get("description", ""), 16, UI.TEXT))
	if String(ev.get("severity_label", "")) != "":
		bv.add_child(_label("Severity: " + String(ev.severity_label), 14, UI.AMBER if sev >= 2 else UI.MUTED))
	console.add_child(brief)

	console.add_child(_section("MOVE"))
	var moves := HBoxContainer.new()
	moves.add_theme_constant_override("separation", 10)
	var pt: Dictionary = Sim.preview(state, "travel")
	var pf: Dictionary = Sim.preview(state, "forage")
	var adv := _button("ADVANCE\n%s" % _delta_text(pt), func() -> void: _advance("travel"))
	adv.name = "Primary"
	adv.tooltip_text = "Travel the next leg."
	var forage := _button("FORAGE\n%s" % _delta_text(pf), func() -> void: _advance("forage"))
	forage.tooltip_text = "Restore energy, but stay exposed longer."
	forage.disabled = not Sim.can_forage(state)
	for b in [adv, forage]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 64
		moves.add_child(b)
	console.add_child(moves)
	console.add_child(_para("Advance travels the next leg and earns points. Forage stays on this leg to restore energy, but this leg's threat hits harder." +
		("" if Sim.can_forage(state) else " Energy is high enough that foraging is not needed."), 14, UI.MUTED))

	console.add_child(_section("UPGRADES  ·  ONE PER MOVE"))
	for up in Sim.upgrades({"era": selected_era}):
		var level: int = int(state.upgrades.get(up.id, 0))
		var maxed := level >= int(up.max_level)
		var b := _button("%s   Lv %d/%d   %s" % [up.name, level, up.max_level, "MAX" if maxed else "%d pts" % up.cost],
			func() -> void: _buy(up.id))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = String(up.description)
		b.disabled = not Sim.can_buy(state, up.id)
		console.add_child(b)
		console.add_child(_para(up.description, 14, UI.MUTED))
	if state.purchased_this_turn:
		console.add_child(_label("Upgrade bought. You can buy another after your next move (Advance or Forage).", 14, UI.AMBER))

	if String(state.get("last_result", "")) != "":
		console.add_child(_section("LAST RESULT"))
		console.add_child(_para(state.last_result, 16, UI.TEXT))
	if not state.history.is_empty():
		console.add_child(_section("LOG"))
		var hist: Array = state.history
		for i in range(hist.size() - 1, maxi(-1, hist.size() - 5), -1):
			console.add_child(_history_row(hist[i]))

	console.add_child(_spacer(8))
	console.add_child(_button("ABANDON & CHOOSE SPECIES", func() -> void:
		_clear_save()
		state = {}
		_show("select")))


func _build_debrief(root: VBoxContainer) -> void:
	var sp := _species()
	var s: Dictionary = Sim.summary(state)
	var arrived: bool = state.status == "arrived"
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 16)
	scroll.add_child(col)
	root.add_child(scroll)

	col.add_child(_label(("ARRIVED" if arrived else "MIGRATION LOST") + "  ·  " + String(sp.get("name", "")).to_upper(),
		14, UI.CYAN if arrived else UI.DANGER, mono))
	col.add_child(_label(Eras.get_era(selected_era).title, 18, UI.CYAN, heading))
	col.add_child(_para(s.get("title", ""), 64, UI.TEXT, heading))
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 48)
	stats.add_child(_stat("GRADE", str(s.get("grade", "—")), 56))
	stats.add_child(_stat("CONDITION", "%d" % roundi(state.condition), 56))
	stats.add_child(_stat("ENERGY", "%d" % roundi(state.energy), 56))
	stats.add_child(_stat("LEGS", "%d/%d" % [state.turn, state.total_turns], 56))
	col.add_child(stats)
	col.add_child(_para(s.get("body", ""), 17, UI.TEXT))
	col.add_child(_para("Lesson: " + String(s.get("lesson", "")), 17, UI.AMBER))
	col.add_child(_para("Scores are illustrative game values, not biological estimates.", 14, UI.MUTED))

	col.add_child(_section("UPGRADES"))
	var ups := PackedStringArray()
	for up in Sim.upgrades({"era": selected_era}):
		ups.append("%s Lv %d" % [up.name, int(state.upgrades.get(up.id, 0))])
	col.add_child(_para("  ·  ".join(ups), 16, UI.TEXT))
	col.add_child(_section("ROUTE LOG"))
	for h in state.history:
		col.add_child(_history_row(h))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var again := _button("REPLAY " + String(sp.get("name", "")).to_upper(), _start_new)
	again.name = "Primary"
	row.add_child(again)
	row.add_child(_button("CHANGE SPECIES", func() -> void:
		state = {}
		_show("select")))
	col.add_child(row)


func _build_guide(root: VBoxContainer) -> void:
	var sp := _species()
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 14)
	scroll.add_child(col)
	root.add_child(scroll)

	var back := _button("←  BACK", func() -> void: _show(return_screen))
	back.name = "Primary"
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(back)
	col.add_child(_label("FIELD GUIDE   /   SPECIES PORTRAIT", 12, UI.AMBER, mono))
	var hero := BoxContainer.new()
	hero.name = "GuideHero"
	hero.add_theme_constant_override("separation", 32)
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_boxes.append(hero)
	col.add_child(hero)
	var art := _bracket_panel()
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.size_flags_stretch_ratio = 1.65
	var art_col := art.get_child(0) as VBoxContainer
	art_col.add_child(_label("%02d / OCEAN OBSERVATORY" % (species_list.find(sp)+1), 11, UI.MUTED, mono))
	var portrait: Control = load("res://scripts/static_whale.gd").new()
	portrait.species_id = selected_id
	portrait.custom_minimum_size = Vector2(300,390)
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art_col.add_child(portrait)
	art_col.add_child(_label("HOLOGRAPHIC SPECIES STUDY", 10, UI.MUTED, mono))
	hero.add_child(art)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 14)
	hero.add_child(details)
	details.add_child(_para(sp.get("name", ""), 42, UI.TEXT, heading))
	details.add_child(_label(sp.get("scientific_name", ""), 16, UI.MUTED))
	details.add_child(_rule())
	details.add_child(_para(sp.get("description", ""), 17, UI.TEXT))
	details.add_child(_section("ROUTE"))
	details.add_child(_para(String(sp.get("route_label", "")) + ". " + String(sp.get("route_note", "")), 16, UI.TEXT))
	details.add_child(_section("FIELD NOTE"))
	details.add_child(_para(sp.get("fact", ""), 16, UI.TEXT))
	var url := String(sp.get("source_url", ""))
	if url != "":
		var link := LinkButton.new()
		link.text = "Source: " + url
		link.pressed.connect(func() -> void: OS.shell_open(url))
		col.add_child(link)

	col.add_child(_section("SELECTED ERA / " + Eras.get_era(selected_era).title.to_upper()))
	col.add_child(_para(Eras.get_era(selected_era).description + " Routes are schematic, not verified historical tracks. Historical protections are counterfactual game choices. Era difficulty and silhouette fading are authored illustrations, not measured population estimates. The 2100 scenario is not a scientific forecast.", 16, UI.MUTED))
	col.add_child(_section("HOW TO PLAY"))
	col.add_child(_para("Each turn, choose ADVANCE to travel the next leg, or FORAGE to recover energy at the cost of more exposure. You can buy one upgrade before each move with conservation points; upgrades last for the whole journey. Arrive with the pod's condition intact.", 16, UI.TEXT))
	for up in Sim.upgrades({"era": selected_era}):
		col.add_child(_kv(String(up.name).to_upper(), "%s  (%d pts, max Lv %d)" % [up.description, up.cost, up.max_level]))
	col.add_child(_section("ABOUT THIS MODEL"))
	col.add_child(_para("Routes are schematic simplifications of specific populations, not universal species routes. Real journeys vary by population, sex and year. Threats and scores are illustrative game values, not biological estimates. Plastic pollution cannot be cleaned up within a single journey here, and in reality it cannot be either. The travelling group is a game abstraction: real social structure differs, and some species, such as blue whales, often travel alone or in pairs. Condition is not population size or a survival probability, and reproduction is not simulated during a journey.", 16, UI.MUTED))


func _show_missing() -> void:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_label("Long Way Home", 72, UI.TEXT, heading))
	col.add_child(_para("Game data is not available yet (scripts/simulation.gd or scripts/species_data.gd is missing).", 16, UI.AMBER))
	content.add_child(col)


# ---------------------------------------------------------------- actions

func _start_new() -> void:
	_begin(Sim.new_game(selected_id, selected_era))


func _begin(s: Dictionary) -> void:
	if s.is_empty():
		return
	state = s
	selected_id = state.species_id
	selected_era = int(state.get("era", 2000))
	timeline_year = float(selected_era)
	_commit()


func _advance(mode: String) -> void:
	state = Sim.advance(state, mode)
	_commit()


func _buy(id: String) -> void:
	state = Sim.buy_upgrade(state, id)
	_commit()


func _commit() -> void:
	if state.status == "active":
		_write_save()
		_show("play")
	else:
		_clear_save()
		_show("debrief")


func _open_guide() -> void:
	if screen != "guide":
		return_screen = screen
	_show("guide")


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and screen == "guide":
		_show(return_screen)
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- save

func _read_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	if text.is_empty():
		return {}
	var restored: Dictionary = Sim.restore(JSON.parse_string(text))
	return restored if restored.get("status", "") == "active" else {}


func _write_save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(state))
	saved_state = state


func _clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	saved_state = {}


# ---------------------------------------------------------------- layout

func _apply_responsive() -> void:
	var narrow := size.x < NARROW_WIDTH
	for b in body_boxes:
		if is_instance_valid(b):
			b.vertical = narrow
	var title := content.find_child("Title", true, false)
	if title is Label:
		(title as Label).add_theme_font_size_override("font_size", 56 if narrow else 96)


func _body_box(root: VBoxContainer) -> BoxContainer:
	var box := BoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 28)
	root.add_child(box)
	body_boxes.append(box)
	return box


func _species() -> Dictionary:
	return Data.get_species(selected_id)


func _map(sp: Dictionary, s: Dictionary) -> Control:
	var frame := Bracket.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size = Vector2(320, 300)
	if MapScript:
		var m: Control = MapScript.new()
		m.clip_contents = true
		m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		m.set_view(sp, s, reduced_motion)
		frame.add_child(m)
	else:
		var l := _label("Map loading…", 14, UI.MUTED, mono)
		l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		frame.add_child(l)
	return frame


# ---------------------------------------------------------------- widgets

func _label(text: Variant, font_size: int, color: Color, font: Font = null, italic := false) -> Label:
	var l := Label.new()
	l.text = str(text)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	if italic:
		var f := SystemFont.new()
		f.font_italic = true
		l.add_theme_font_override("font", f)
	if font == mono:
		l.add_theme_constant_override("line_spacing", 2)
	return l


func _para(text: Variant, font_size: int, color: Color, font: Font = null) -> Label:
	var l := _label(text, font_size, color, font)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 200
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(cb)
	return b


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _rule() -> Control:
	var r := ColorRect.new()
	r.color = UI.LINE
	r.custom_minimum_size.y = 1
	return r


func _progress_rule(frac: float) -> Control:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 3
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = frac
	return bar


func _section(text: String) -> Control:
	var box := VBoxContainer.new()
	box.add_child(_spacer(6))
	box.add_child(_label(text, 12, UI.MUTED, mono))
	box.add_child(_rule())
	return box


func _kv(key: String, value: String) -> Control:
	var v := VBoxContainer.new()
	v.add_child(_label(key, 12, UI.MUTED, mono))
	v.add_child(_para(value, 16, UI.TEXT))
	return v


func _stat(key: String, value: String, value_size := 32) -> Control:
	var v := VBoxContainer.new()
	v.add_child(_label(key, 12, UI.MUTED, mono))
	v.add_child(_label(value, value_size, UI.TEXT, heading))
	return v


func _meter(key: String, value: float) -> Control:
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = 150
	var low := value < 35.0
	v.add_child(_label(key + ("  ·  LOW" if low else ""), 12, UI.AMBER if low else UI.MUTED, mono))
	v.add_child(_label("%d" % roundi(value), 32, UI.AMBER if low else UI.TEXT, heading))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 3
	bar.value = value
	if low:
		bar.add_theme_stylebox_override("fill", UI.box(UI.AMBER, Color(0, 0, 0, 0), 0, 0))
	v.add_child(bar)
	return v


func _delta_text(p: Dictionary) -> String:
	return "Condition %+d   Energy %+d" % [roundi(float(p.condition_delta)), roundi(float(p.energy_delta))]


func _history_row(h: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var n := _label("%02d" % int(h.get("turn", 0)), 14, UI.CYAN, mono)
	n.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(n)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_para("%s — %s" % [h.get("title", ""), String(h.get("mode", "")).to_upper()], 15, UI.TEXT))
	v.add_child(_para(h.get("narrative", ""), 14, UI.MUTED))
	var cd := float(h.get("condition_delta", 0))
	v.add_child(_label("Condition %+d → %d   ·   Energy %+d → %d" % [roundi(cd), roundi(float(h.get("condition_after", 0))),
		roundi(float(h.get("energy_delta", 0))), roundi(float(h.get("energy_after", 0)))], 13, UI.AMBER if cd < 0 else UI.CYAN, mono))
	row.add_child(v)
	return row


func _bracket_panel() -> Bracket:
	var p := Bracket.new()
	p.fill = true
	var m := VBoxContainer.new()
	m.add_theme_constant_override("separation", 8)
	p.add_child(m)
	return p


## Hairline frame with open corner brackets; children get an inner margin.
class Bracket extends MarginContainer:
	var fill := false

	func _init() -> void:
		for side in ["left", "right", "top", "bottom"]:
			add_theme_constant_override("margin_" + side, 18)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if fill:
			draw_rect(r, UI.PANEL)
		draw_rect(r, Color(UI.LINE, 0.18), false, 1.0)
		var k := 14.0
		var c := Color(UI.CYAN, 0.85)
		for p in [r.position, Vector2(r.end.x, 0), Vector2(0, r.end.y), r.end]:
			var sx := 1.0 if p.x == 0 else -1.0
			var sy := 1.0 if p.y == 0 else -1.0
			draw_line(p, p + Vector2(k * sx, 0), c, 1.0)
			draw_line(p, p + Vector2(0, k * sy), c, 1.0)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()


## Faint survey grid behind everything.
class Backdrop extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UI.BG)
		var step := 64.0
		var c := Color(UI.CYAN, 0.015)
		var x := 0.0
		while x < size.x:
			draw_line(Vector2(x, 0), Vector2(x, size.y), c, 1.0)
			x += step
		var y := 0.0
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), c, 1.0)
			y += step

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()
