extends SceneTree

# Run: Godot --headless --path . --script res://tests/test_eras.gd

const Sim = preload("res://scripts/simulation.gd")
const Eras = preload("res://scripts/era_data.gd")
const Species = preload("res://scripts/species_data.gd")
const IDS := ["humpback", "gray", "right", "blue", "sperm"]
const YEARS := [1700, 1800, 1900, 2000, 2100]

var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)


func _init() -> void:
	test_era_records()
	test_threat_tables()
	test_upgrade_wording()
	test_all_pairs()
	test_restore_v2()
	test_legacy_v1()
	test_strict_and_parity()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_era_records() -> void:
	var eras := Eras.all_eras()
	check(eras.size() == 5, "five eras")
	var fractions := [1.0, 0.8, 0.55, 0.35, 0.2]
	for i in eras.size():
		var e: Dictionary = eras[i]
		check(e.year == YEARS[i], "era year %d" % YEARS[i])
		for key in ["title", "description", "difficulty", "scenario", "silhouette_fraction", "threats"]:
			check(e.has(key), "%d has %s" % [e.year, key])
		check(is_equal_approx(e.silhouette_fraction, fractions[i]), "%d silhouette fraction" % e.year)
		check(e.scenario == (e.year == 2100), "%d scenario flag" % e.year)
		check(not e.threats.is_empty(), "%d has threats" % e.year)
	check(Eras.get_era(2100).description.to_lower().contains("scenario"), "2100 says scenario")
	check(Eras.get_era(1950).is_empty() and Eras.get_era(0).is_empty(), "unknown era is empty")
	var copy := Eras.get_era(1700)
	copy.threats.append("plastic")
	check(not Eras.get_era(1700).threats.has("plastic"), "get_era returns a copy")
	# Anachronism guards from CONTRACT v2.
	var t1700: Array = Eras.get_era(1700).threats
	for banned in ["plastic", "noise", "industrial", "harpoon", "strike"]:
		check(not t1700.has(banned), "1700 excludes " + banned)
	check(Eras.get_era(1800).threats.has("harpoon"), "1800 includes late-century harpoon cannon")
	check(Eras.get_era(1900).threats.has("industrial"), "1900 includes industrial whaling")
	check(not Eras.get_era(1800).threats.has("plastic"), "1800 excludes plastic")
	check(Sim.new_game("humpback", 1950).is_empty(), "new_game rejects unknown era")
	check(Sim.new_game("humpback").era == 2000, "default era is 2000")


func test_threat_tables() -> void:
	var upgrade_ids := Sim.UPGRADES.map(func(u): return u.id)
	for e in Eras.all_eras():
		for t in e.threats:
			check(Sim.THREAT_UPGRADE.has(t) and upgrade_ids.has(Sim.THREAT_UPGRADE[t]), "%s maps to an upgrade" % t)
			check(Sim.BASE_DAMAGE.has(t) and Sim.EVENT_TEXT.has(t), "%s has damage and text" % t)
	# Events in a game only use that era's threats.
	for year in YEARS:
		var allowed: Array = Eras.get_era(year).threats
		for id in IDS:
			var s := Sim.new_game(id, year)
			while s.status == "active":
				var ev := Sim.current_event(s)
				check(allowed.has(ev.threat), "%s %d leg %d threat %s belongs to era" % [id, year, s.turn, ev.threat])
				check(ev.era == year, "event carries era")
				s = Sim.advance(s, "travel")


func test_upgrade_wording() -> void:
	var modern := Sim.upgrades()
	check(modern.size() == 4 and modern[2].name == "Ropeless Fishing Gear", "no-arg upgrades keep modern names")
	for year in [1700, 1800, 1900]:
		var list := Sim.upgrades({"era": year})
		check(list.size() == 4, "%d four upgrades" % year)
		for u in list:
			var text: String = (u.name + " " + u.description).to_lower()
			check(not text.contains("ropeless") and not text.contains("engine"), "%d %s avoids modern tech wording" % [year, u.id])
			check(text.contains("counterfactual"), "%d %s marked counterfactual" % [year, u.id])
		for i in 4:
			check(list[i].id == modern[i].id and list[i].cost == modern[i].cost, "%d keeps ids and costs" % year)


# Sensible policy: buy the counter for the current threat, forage when energy < 30.
func sensible(id: String, year: int, use_upgrades: bool = true) -> Dictionary:
	var s := Sim.new_game(id, year)
	var guard := 0
	while s.status == "active" and guard < 100:
		guard += 1
		if use_upgrades:
			s = Sim.buy_upgrade(s, Sim.THREAT_UPGRADE[Sim.current_event(s).threat])
		s = Sim.advance(s, "forage" if Sim.can_forage(s) and s.energy < 30.0 else "travel")
		check(s.points >= 0 and s.condition >= 0.0 and s.condition <= 100.0 and s.energy >= 0.0 and s.energy <= 100.0, "%s %d bounds" % [id, year])
	return s


func test_all_pairs() -> void:
	var totals := {}
	var line := "species   " + "  ".join(YEARS.map(func(y): return "%9d" % y))
	print(line)
	for id in IDS:
		var row := "%-9s" % id
		for year in YEARS:
			var smart := sensible(id, year)
			var plain := sensible(id, year, false)
			check(smart.status == "arrived", "%s %d arrives with sensible policy" % [id, year])
			check(plain.status != "arrived" or smart.condition > plain.condition, "%s %d upgrades beat no-upgrade baseline" % [id, year])
			totals[year] = totals.get(year, 0.0) + smart.condition
			row += "  %4.1f/%-4s" % [smart.condition, "lost" if plain.status == "lost" else "%.0f" % plain.condition]
		print(row)
	print("(sensible condition / no-upgrade condition)")
	# Era matters: the gentlest era is clearly easier than the future scenario.
	check(totals[1700] > totals[2100] + 10.0, "1700 easier than 2100 overall")
	check(totals[2000] > totals[2100], "2100 scenario harder than 2000")
	check(totals[1900] < totals[2000], "1900 labelled Hard is not easier than 2000")


func json(state: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(state))


func test_restore_v2() -> void:
	for year in YEARS:
		var s := Sim.new_game("gray", year)
		s = Sim.advance(Sim.buy_upgrade(s, "speed"), "travel")
		s = Sim.advance(s, "travel")
		s = Sim.buy_upgrade(s, "gear")
		var r := Sim.restore(json(s))
		check(not r.is_empty() and r.era == year and Sim._same(r, s), "%d save with pending upgrade round-trips" % year)
	var base := json(Sim.advance(Sim.new_game("right", 1800), "travel"))
	var bad := base.duplicate(true)
	bad.era = 2000
	check(Sim.restore(bad).is_empty(), "rejects era swapped after play")
	for v in [1950, "1800", 1800.5, null, NAN]:
		bad = base.duplicate(true)
		bad.era = v
		check(Sim.restore(bad).is_empty(), "rejects era value " + str(v))
	bad = base.duplicate(true)
	bad.erase("era")
	check(Sim.restore(bad).is_empty(), "rejects v2 save without era")
	bad = base.duplicate(true)
	bad.history[0].threat = "plastic"
	check(Sim.restore(bad).is_empty(), "rejects edited history threat")
	bad = base.duplicate(true)
	bad.version = 3
	check(Sim.restore(bad).is_empty(), "rejects unknown version")


# Legacy v1 saves (no era field) replay under modern rules and migrate to v2.
func test_legacy_v1() -> void:
	var s := Sim.new_game("humpback")
	s = Sim.advance(Sim.buy_upgrade(s, "quiet"), "travel")
	s = Sim.advance(s, "travel")
	s = Sim.buy_upgrade(s, "refuge")
	var legacy := json(s)
	legacy.version = 1
	legacy.erase("era")
	var r := Sim.restore(legacy)
	check(not r.is_empty(), "v1 save with pending upgrade restores")
	check(r.version == 2 and r.era == 2000, "v1 migrates to v2 era 2000")
	check(r.turn == s.turn and is_equal_approx(r.condition, s.condition) and r.points == s.points and r.upgrades.refuge == 1, "v1 values preserved")
	var tampered := legacy.duplicate(true)
	tampered.condition = 99.0
	check(Sim.restore(tampered).is_empty(), "tampered v1 rejected")
	var wrong_era := legacy.duplicate(true)
	wrong_era.era = 1700
	check(Sim.restore(wrong_era).is_empty(), "v1 claiming a non-2000 era rejected")


# Strict integer fields and parity with the frozen pre-era (v1) fixture.
func test_strict_and_parity() -> void:
	var s := Sim.advance(Sim.advance(Sim.new_game("blue", 1900), "travel"), "travel")
	var cases := {"version": 2.5, "turn": 2.0001, "points": 8.5, "total_turns": 6.5}
	for key in cases:
		var bad := json(s)
		bad[key] = cases[key]
		check(Sim.restore(bad).is_empty(), "rejects fractional " + key)
	var bad_turn := json(s)
	bad_turn.history[0].turn = 1.000001
	check(Sim.restore(bad_turn).is_empty(), "rejects fractional history.turn")
	var bad_level := json(Sim.buy_upgrade(s, "quiet"))
	bad_level.upgrades.quiet = 1.0001
	check(Sim.restore(bad_level).is_empty(), "rejects fractional upgrade level")
	check(not Sim.restore(json(s)).is_empty(), "integral floats from JSON still accepted")

	var src: String = FileAccess.get_file_as_string("res://tests/fixtures/legacy_simulation_v1.txt")
	check(not src.is_empty(), "backup simulation found")
	var Old := GDScript.new()
	Old.source_code = src.replace("class_name Simulation", "")
	check(Old.reload() == OK, "backup simulation compiles")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var games := 0
	for id in IDS:
		for g in 40:
			var old: Dictionary = Old.new_game(id)
			var cur := Sim.new_game(id, 2000)
			while old.status == "active":
				var u: Dictionary = Sim.UPGRADES[rng.randi_range(0, 3)]
				if rng.randf() < 0.5:
					old = Old.buy_upgrade(old, u.id)
					cur = Sim.buy_upgrade(cur, u.id)
				var mode := "forage" if rng.randf() < 0.25 else "travel"
				old = Old.advance(old, mode)
				cur = Sim.advance(cur, mode)
				# Compare every v1 field except version.
				var same := true
				for key in old:
					if key != "version" and not Sim._same(cur[key], old[key]):
						same = false
				check(same, "%s game %d matches v1 rules at turn %d" % [id, g, old.turn])
				if not same:
					break
				# A real v1 save restores and migrates to the same v2 state.
				var restored := Sim.restore(json(old))
				check(not restored.is_empty() and restored.version == 2 and restored.era == 2000 and Sim._same(restored.history, cur.history), "%s real v1 save migrates" % id)
			games += 1
	print("legacy parity: %d seeded games compared with the frozen v1 fixture" % games)
