extends SceneTree

# Run: Godot --headless --path . --script res://tests/test_simulation.gd

const Sim = preload("res://scripts/simulation.gd")
const Species = preload("res://scripts/species_data.gd")
const IDS := ["humpback", "gray", "right", "blue", "sperm"]
const MAX_FORAGES := 2

var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)


func _init() -> void:
	test_species_data()
	test_new_game_and_bounds()
	test_upgrades()
	test_immutability()
	test_forage()
	test_endgame()
	test_restore()
	test_routes_per_species()
	test_sensible_policy()
	test_review_fixes()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_species_data() -> void:
	var all := Species.all_species()
	check(all.size() == 5, "five species")
	var difficulties := {}
	for s in all:
		check(IDS.has(s.id), "known id " + s.id)
		check(s.route.size() == s.legs + 1, s.id + " route has one anchor per leg boundary")
		check(s.events.size() == s.legs and s.places.size() == s.legs, s.id + " one event per leg")
		for p in s.route:
			check(p.x >= -180.0 and p.x <= 180.0 and p.y >= -90.0 and p.y <= 90.0, s.id + " lon/lat in range")
		for k in ["noise", "strike", "gear", "warming", "plastic"]:
			check(s.vulnerability.has(k), s.id + " vulnerability " + k)
		check(not s.route_note.is_empty() and s.source_url.begins_with("https://www.fisheries.noaa.gov/"), s.id + " note and NOAA source")
		difficulties[s.difficulty] = true
	check(difficulties.size() >= 3, "species span several difficulty labels")
	check(Species.get_species("narwhal").is_empty(), "unknown species is empty")
	var copy := Species.get_species("gray")
	copy.legs = 99
	check(Species.get_species("gray").legs == 8, "get_species returns a copy")


func test_new_game_and_bounds() -> void:
	check(Sim.new_game("narwhal").is_empty(), "unknown species gives empty game")
	var s := Sim.new_game("humpback")
	check(s.turn == 0 and s.status == "active" and s.points == Sim.START_POINTS, "fresh game")
	check(s.upgrades.keys().size() == 4, "four upgrade types")
	check(Sim.upgrades().size() == 4, "four upgrade definitions")
	for u in Sim.upgrades():
		check(u.max_level == 2 and u.cost > 0, "upgrade " + u.id + " cost and max level")
	var e := Sim.current_event(s)
	check(e.has("title") and e.has("description") and e.has("threat") and e.has("label") and e.has("severity"), "event fields")


func test_upgrades() -> void:
	var s := Sim.new_game("humpback")
	var bought := Sim.buy_upgrade(s, "quiet")
	check(bought.points == s.points - 2 and bought.upgrades.quiet == 1 and bought.purchased_this_turn, "buy quiet")
	var twice := Sim.buy_upgrade(bought, "speed")
	check(twice.points == bought.points and twice.upgrades.speed == 0, "one purchase per turn")
	var bogus := Sim.buy_upgrade(s, "laser")
	check(bogus == s, "unknown upgrade returns same values")
	# Upgrades persist and cap at max level.
	var st := s
	for i in 4:
		st = Sim.advance(Sim.buy_upgrade(st, "quiet"), "travel")
	check(st.upgrades.quiet == 2, "quiet capped at level 2 and persists")
	# Upgrade lowers the matching harm.
	var plain := Sim.preview(s, "travel")
	var quiet := Sim.preview(bought, "travel")
	check(quiet.condition_delta > plain.condition_delta, "quiet reduces noise harm")
	var broke := s.duplicate(true)
	broke.points = 1
	check(Sim.buy_upgrade(broke, "gear").points == 1, "cannot buy without points")


func test_immutability() -> void:
	var s := Sim.new_game("right")
	var snapshot := s.duplicate(true)
	Sim.advance(s, "travel")
	Sim.advance(s, "forage")
	Sim.buy_upgrade(s, "speed")
	check(s == snapshot, "transitions do not mutate input")
	var next := Sim.advance(s, "travel")
	check(next.history.size() == 1 and s.history.size() == 0, "history copied, not shared")
	check(Sim.advance(s, "teleport") == s, "invalid mode returns same values")


func test_forage() -> void:
	var s := Sim.new_game("blue")
	check(not Sim.can_forage(s), "cannot forage with high energy")
	check(Sim.advance(s, "forage") == s, "forage refused above the limit")
	s = Sim.advance(s, "travel")
	s = Sim.advance(s, "travel")
	check(Sim.can_forage(s), "can forage when hungry")
	var fed := Sim.advance(s, "forage")
	check(fed.energy > s.energy and fed.turn == s.turn and fed.condition < s.condition, "forage restores energy, keeps leg, costs condition")
	check(Sim.preview(s, "forage").condition_delta < Sim.preview(s, "travel").condition_delta, "forage is more exposed")
	check(fed.points == s.points, "forage earns no points")


func test_endgame() -> void:
	var s := Sim.new_game("humpback")
	while s.status == "active":
		s = Sim.advance(s, "travel")
	check(s.status == "arrived" and s.turn == s.total_turns, "humpback travel-only arrives")
	check(Sim.current_event(s).is_empty(), "no event after the end")
	check(Sim.advance(s, "travel") == s, "finished game cannot advance")
	check(Sim.buy_upgrade(s, "speed") == s, "finished game cannot buy")
	var sm := Sim.summary(s)
	check(sm.title == "Arrived" and sm.grade != "-" and sm.lesson.contains("simplified"), "arrival summary")
	var starving := Sim.new_game("right")
	starving.condition = 5.0
	starving.energy = 1.0
	var lost := Sim.advance(starving, "travel")
	check(lost.status == "lost" and lost.condition == 0.0, "low condition loses")
	check(Sim.summary(lost).grade == "F", "lost summary")


func test_restore() -> void:
	var s := Sim.new_game("gray")
	s = Sim.advance(Sim.buy_upgrade(s, "speed"), "travel")
	s = Sim.advance(s, "travel")
	s = Sim.buy_upgrade(s, "quiet")
	var json: Variant = JSON.parse_string(JSON.stringify(s))
	var restored := Sim.restore(json)
	check(not restored.is_empty() and Sim._same(restored, s), "valid save round-trips through JSON")
	check(Sim.advance(restored, "travel").turn == 3, "restored game is playable")
	check(not Sim.restore(Sim.new_game("sperm")).is_empty(), "fresh save restores")
	for bad in [null, 42, "save", [], {}, {"version": 2}, {"version": 1, "species_id": "narwhal", "history": [], "upgrades": {}}]:
		check(Sim.restore(bad).is_empty(), "rejects malformed " + str(bad))
	var tampered: Dictionary = JSON.parse_string(JSON.stringify(s))
	tampered.condition = 100.0
	check(Sim.restore(tampered).is_empty(), "rejects edited condition")
	tampered = JSON.parse_string(JSON.stringify(s))
	tampered.points = 50
	check(Sim.restore(tampered).is_empty(), "rejects edited points")
	tampered = JSON.parse_string(JSON.stringify(s))
	tampered.history[0].condition_after = 99.0
	check(Sim.restore(tampered).is_empty(), "rejects edited history")
	tampered = JSON.parse_string(JSON.stringify(s))
	tampered.history[1].mode = "fly"
	check(Sim.restore(tampered).is_empty(), "rejects invalid mode")
	tampered = JSON.parse_string(JSON.stringify(s))
	tampered.upgrades.gear = 2
	check(Sim.restore(tampered).is_empty(), "rejects free upgrades")
	tampered = JSON.parse_string(JSON.stringify(s))
	tampered.history[0].upgrade = "gear"
	check(Sim.restore(tampered).is_empty(), "rejects swapped upgrade")


# Bounded exhaustive search: every purchase choice and mode on every leg, with
# at most MAX_FORAGES forage stops per game. Memoized on the full state.
func explore(state: Dictionary, forages: int, memo: Dictionary, stats: Dictionary) -> void:
	var key := str([state.turn, state.condition, state.energy, state.points, state.upgrades, state.purchased_this_turn, forages])
	if memo.has(key):
		return
	memo[key] = true
	check(state.points >= 0, "points never negative")
	check(state.condition >= 0.0 and state.condition <= 100.0 and state.energy >= 0.0 and state.energy <= 100.0, "stats bounded")
	if state.status != "active":
		stats.endings += 1
		if state.status == "arrived":
			stats.arrived += 1
			stats.best = maxf(stats.best, state.condition)
		else:
			stats.lost += 1
		return
	if not state.purchased_this_turn:
		for u in Sim.UPGRADES:
			if Sim.can_buy(state, u.id):
				explore(Sim.buy_upgrade(state, u.id), forages, memo, stats)
	explore(Sim.advance(state, "travel"), forages, memo, stats)
	if forages < MAX_FORAGES and Sim.can_forage(state):
		explore(Sim.advance(state, "forage"), forages + 1, memo, stats)


# Sensible policy (also the suggested UI test script): each action, buy the upgrade
# that counters the current event if affordable; forage when energy < 30; else travel.
func sensible(id: String, use_upgrades: bool = true) -> Dictionary:
	var s := Sim.new_game(id)
	while s.status == "active":
		if use_upgrades:
			s = Sim.buy_upgrade(s, Sim.THREAT_UPGRADE[Sim.current_event(s).threat])
		s = Sim.advance(s, "forage" if Sim.can_forage(s) and s.energy < 30.0 else "travel")
	return s


func test_sensible_policy() -> void:
	for id in IDS:
		var smart := sensible(id)
		var plain := sensible(id, false)
		print("%-9s sensible=%s %.1f  no-upgrades=%s %.1f" % [id, smart.status, smart.condition, plain.status, plain.condition])
		check(smart.status == "arrived", id + " arrives with the sensible policy")
		check(plain.status != "arrived" or smart.condition > plain.condition, id + " upgrades beat the no-upgrade baseline")


func test_review_fixes() -> void:
	# One upgrade per action: forage also resets the purchase flag.
	var s := Sim.new_game("blue")
	s = Sim.advance(Sim.advance(s, "travel"), "travel")
	var after_buy := Sim.buy_upgrade(s, "quiet")
	var after_forage := Sim.advance(after_buy, "forage")
	check(not after_forage.purchased_this_turn and Sim.can_buy(after_forage, "refuge"), "forage allows a new purchase")
	# Lost summary names the leg where the whale was lost.
	var doomed := Sim.new_game("right")
	doomed = Sim.advance(doomed, "travel")
	doomed.condition = 1.0
	var lost := Sim.advance(doomed, "travel")
	check(lost.status == "lost" and Sim.summary(lost).body.contains("leg 2 of 6"), "lost summary uses the last leg")
	# Malformed save guards.
	var base: Dictionary = JSON.parse_string(JSON.stringify(Sim.advance(Sim.new_game("gray"), "travel")))
	var huge := base.duplicate(true)
	for i in 1000:
		huge.history.append(base.history[0])
	check(Sim.restore(huge).is_empty(), "rejects huge history")
	var bad_text := base.duplicate(true)
	bad_text.last_result = 7
	check(Sim.restore(bad_text).is_empty(), "rejects non-string last_result")
	for key in ["condition", "energy", "points", "turn"]:
		for v in [NAN, INF]:
			var bad := base.duplicate(true)
			bad[key] = v
			check(Sim.restore(bad).is_empty(), "rejects nonfinite " + key)
	var bad_hist := base.duplicate(true)
	bad_hist.history[0].condition_after = NAN
	check(Sim.restore(bad_hist).is_empty(), "rejects nonfinite history value")


func travel_only(id: String) -> Dictionary:
	var s := Sim.new_game(id)
	while s.status == "active":
		s = Sim.advance(s, "travel")
	return s


func test_routes_per_species() -> void:
	var bests := {}
	for id in IDS:
		var stats := {"endings": 0, "arrived": 0, "lost": 0, "best": 0.0}
		explore(Sim.new_game(id), 0, {}, stats)
		var idle := travel_only(id)
		var idle_score: float = idle.condition if idle.status == "arrived" else -1.0
		print("%-9s endings=%d arrived=%d lost=%d best=%.1f travel-only=%s %.1f" % [id, stats.endings, stats.arrived, stats.lost, stats.best, idle.status, idle.condition])
		check(stats.arrived > 0, id + " has a successful affordable route")
		check(stats.best > idle_score + 5.0, id + " planning beats doing nothing")
		bests[id] = stats.best
	check(bests.right < bests.humpback, "right whale is harder than humpback")
	check(travel_only("right").status == "lost", "right whale is lost without protection")
