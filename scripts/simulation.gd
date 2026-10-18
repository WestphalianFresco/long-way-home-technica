extends RefCounted
class_name Simulation

# Simplified, deterministic game rules. Scores are illustrative, not biological estimates.

const SpeciesDataScript = preload("res://scripts/species_data.gd")

const EraData = preload("res://scripts/era_data.gd")
const VERSION := 2
const START_POINTS := 4
const POINTS_PER_LEG := 2
const MAX_LEVEL := 2
const MITIGATION_PER_LEVEL := 0.3
const PLASTIC_MITIGATION_PER_LEVEL := 0.1
const BASE_DAMAGE := {"noise": 3.0, "strike": 4.0, "gear": 4.0, "warming": 3.0, "plastic": 2.5, "sailing": 3.0, "harpoon": 4.0, "industrial": 4.0, "wreck": 3.0}
const WARMING_ENERGY := 5.0
const FORAGE_GAIN := 30.0
const FORAGE_REFUGE_BONUS := 5.0
const FORAGE_EXPOSURE := 1.4
const FORAGE_LIMIT := 70.0
const STARVATION_DAMAGE := 12.0
# Saves longer than this are rejected before replay; forage is self-limiting well below it.
const MAX_HISTORY_PER_LEG := 6

const UPGRADES := [
	{"id": "speed", "name": "Vessel Slow Zones", "description": "Ships slow down where whales travel, cutting ship-strike harm.", "cost": 3, "max_level": MAX_LEVEL, "effect": "-30% ship-strike harm per level"},
	{"id": "quiet", "name": "Quiet Ocean Rules", "description": "Limits on loud shipping and surveys reduce noise stress.", "cost": 2, "max_level": MAX_LEVEL, "effect": "-30% noise harm per level"},
	{"id": "gear", "name": "Ropeless Fishing Gear", "description": "Fewer vertical lines in the water mean fewer entanglements.", "cost": 3, "max_level": MAX_LEVEL, "effect": "-30% entanglement harm per level"},
	{"id": "refuge", "name": "Feeding Refuges", "description": "Protected feeding areas help whales cope with heat and food shifts. Offers only a little help with plastic.", "cost": 2, "max_level": MAX_LEVEL, "effect": "-30% warming harm, -10% plastic harm, +5 forage energy per level"},
]
const THREAT_UPGRADE := {"noise": "quiet", "strike": "speed", "gear": "gear", "warming": "refuge", "plastic": "refuge", "sailing": "speed", "harpoon": "quiet", "industrial": "quiet", "wreck": "gear"}

const EVENT_TEXT := {
 "sailing": ["Sailing Whalers", "A sailing whaling fleet searches the waters near %s."],
 "harpoon": ["Harpoon Cannon", "Mechanized whalers near %s put the pod in danger. In the 1800s, this represents the late century."],
 "industrial": ["Industrial Whaling", "Factory fleets hunt whales near %s at an industrial scale."],
 "wreck": ["Wreck Debris", "Abandoned rigging and debris near %s threaten to snag the pod."],
	"noise": ["Underwater Noise", "Engines and surveys around %s drown out the calls whales use to find each other."],
	"strike": ["Busy Shipping Lane", "Large ships cross the route near %s. Whales at the surface risk being hit."],
	"gear": ["Fishing Lines Ahead", "Ropes from traps and nets crowd the water near %s."],
	"warming": ["Warm Water, Less Food", "A marine heatwave near %s has pushed prey away from the usual feeding spots."],
	"plastic": ["Floating Debris", "Plastic and lost gear collect near %s. No upgrade can clean it up; the pod can only steer around it."],
}
const SEVERITY_LABEL := ["", "Moderate", "Severe", "Extreme"]


static func upgrades(state: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u in UPGRADES:
		var item: Dictionary = u.duplicate(true)
		if int(state.get("era", 2000)) < 2000:
			var historical := {
			 "speed": ["Protected Passage", "Keep sailing whalers and commercial vessels away from the route."],
			 "quiet": ["Whaling Sanctuary", "Restrict hunting and disruptive activity along the route."],
			 "gear": ["Clear Lines & Rigging", "Remove fishing lines and abandoned wreck rigging."],
			 "refuge": ["Feeding Refuges", "Protect feeding opportunities to restore energy."]}
			item.name = historical[u.id][0]
			item.description = historical[u.id][1] + " A counterfactual game choice, not a claim about historical policy."
			item.effect = "+5 forage energy per level" if u.id == "refuge" else "-30% matching threat harm per level"
		out.append(item)
	return out


static func new_game(species_id: String, era: int = 2000) -> Dictionary:
	var species: Dictionary = SpeciesDataScript.get_species(species_id)
	if species.is_empty() or EraData.get_era(era).is_empty():
		return {}
	return {
		"version": VERSION,
		"era": era,
		"species_id": species_id,
		"turn": 0,
		"total_turns": int(species.legs),
		"condition": float(species.condition_start),
		"energy": float(species.energy_start),
		"points": START_POINTS,
		"status": "active",
		"upgrades": {"speed": 0, "quiet": 0, "gear": 0, "refuge": 0},
		"purchased_this_turn": false,
		"history": [],
		"last_result": "The migration begins.",
	}


static func current_event(state: Dictionary) -> Dictionary:
	if state.get("status") != "active":
		return {}
	var species: Dictionary = SpeciesDataScript.get_species(state.species_id)
	var leg: int = state.turn
	var threat: String = species.events[leg][0]
	var severity: int = species.events[leg][1]
	var era: int = state.get("era", 2000)
	if era != 2000:
		var threats: Array = EraData.get_era(era).threats
		threat = threats[leg % threats.size()]
	var text: Array = EVENT_TEXT[threat]
	return {
		"era": era,
		"title": text[0],
		"description": text[1] % species.places[leg],
		"threat": threat,
		"label": "Leg %d of %d - %s" % [leg + 1, state.total_turns, species.places[leg]],
		"severity": severity,
		"severity_label": SEVERITY_LABEL[severity],
	}


static func upgrade_cost(id: String) -> int:
	for u in UPGRADES:
		if u.id == id:
			return u.cost
	return -1


static func can_buy(state: Dictionary, id: String) -> bool:
	var cost := upgrade_cost(id)
	return state.get("status") == "active" and cost >= 0 and not state.purchased_this_turn \
		and int(state.upgrades[id]) < MAX_LEVEL and int(state.points) >= cost


static func buy_upgrade(state: Dictionary, id: String) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if not can_buy(state, id):
		return next
	next.points = int(state.points) - upgrade_cost(id)
	next.upgrades[id] = int(state.upgrades[id]) + 1
	next.purchased_this_turn = true
	next.last_result = "%s upgraded to level %d." % [_upgrade_name(id, state), next.upgrades[id]]
	return next


static func can_forage(state: Dictionary) -> bool:
	return state.get("status") == "active" and float(state.energy) < FORAGE_LIMIT


# Damage this leg's event deals for a mode, after upgrades. Shared by previews and advance().
static func preview(state: Dictionary, mode: String) -> Dictionary:
	var species: Dictionary = SpeciesDataScript.get_species(state.species_id)
	var event := current_event(state)
	var threat: String = event.threat
	var level: int = state.upgrades[THREAT_UPGRADE[threat]]
	var per_level := PLASTIC_MITIGATION_PER_LEVEL if threat == "plastic" else MITIGATION_PER_LEVEL
	var mitigation := 1.0 - per_level * level
	var vulnerability_key: String = {"sailing":"strike", "harpoon":"gear", "industrial":"strike", "wreck":"gear"}.get(threat, threat)
	var harm: float = BASE_DAMAGE[threat] * event.severity * species.vulnerability[vulnerability_key] * mitigation * EraData.get_era(int(state.get("era", 2000))).damage_scale
	var energy_delta := 0.0
	if threat == "warming":
		energy_delta -= WARMING_ENERGY * event.severity * species.vulnerability.warming * mitigation
	if mode == "forage":
		harm = harm * FORAGE_EXPOSURE + 1.0
		energy_delta += FORAGE_GAIN + FORAGE_REFUGE_BONUS * int(state.upgrades.refuge)
	else:
		energy_delta -= float(species.travel_cost)
	var energy := clampf(float(state.energy) + energy_delta, 0.0, 100.0)
	if energy <= 0.0:
		harm += STARVATION_DAMAGE
	var condition := clampf(float(state.condition) - harm, 0.0, 100.0)
	return {
		"condition_delta": snappedf(condition - float(state.condition), 0.1),
		"energy_delta": snappedf(energy - float(state.energy), 0.1),
	}


static func advance(state: Dictionary, mode: String = "travel") -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if state.get("status") != "active" or not (mode == "travel" or mode == "forage"):
		return next
	if mode == "forage" and not can_forage(state):
		return next
	var event := current_event(state)
	var species: Dictionary = SpeciesDataScript.get_species(state.species_id)
	var change := preview(state, mode)
	next.condition = clampf(snappedf(float(state.condition) + change.condition_delta, 0.1), 0.0, 100.0)
	next.energy = clampf(snappedf(float(state.energy) + change.energy_delta, 0.1), 0.0, 100.0)
	next.purchased_this_turn = false
	if mode == "travel":
		next.turn = int(state.turn) + 1
		next.points = int(state.points) + POINTS_PER_LEG
	var narrative := _narrative(event, mode, int(state.upgrades[THREAT_UPGRADE[event.threat]]), next.energy <= 0.0)
	if next.condition <= 0.0:
		next.status = "lost"
		narrative += " The %s did not survive this stretch of the journey." % species.name.to_lower()
	elif next.turn >= int(state.total_turns):
		next.status = "arrived"
		narrative += " The %s has reached its destination." % species.name.to_lower()
	next.history.append({
		"turn": int(state.turn) + 1,
		"title": event.title,
		"threat": event.threat,
		"mode": mode,
		"upgrade": _bought_before(state),
		"condition_delta": change.condition_delta,
		"energy_delta": change.energy_delta,
		"condition_after": next.condition,
		"energy_after": next.energy,
		"narrative": narrative,
	})
	next.last_result = narrative
	return next


static func summary(state: Dictionary) -> Dictionary:
	var species: Dictionary = SpeciesDataScript.get_species(str(state.get("species_id", "")))
	var name: String = species.get("name", "The whale")
	var condition := float(state.get("condition", 0.0))
	var bought := 0
	for level in state.get("upgrades", {}).values():
		bought += int(level)
	var lesson := "Protections work best when they match the threat ahead. This game is a simplified illustration, not a scientific model."
	match state.get("status"):
		"arrived":
			var grade := "A" if condition >= 75.0 else "B" if condition >= 55.0 else "C" if condition >= 35.0 else "D"
			return {"title": "Arrived", "body": "%s finished the journey at %d%% condition with %d upgrade levels in place." % [name, roundi(condition), bought], "grade": grade, "lesson": lesson}
		"lost":
			var history: Array = state.get("history", [])
			var leg: int = int(history[-1].turn) if not history.is_empty() else int(state.get("turn", 0)) + 1
			return {"title": "Lost at Sea", "body": "%s was lost on leg %d of %d." % [name, leg, int(state.total_turns)], "grade": "F", "lesson": lesson}
	return {"title": "Journey in Progress", "body": "%s has completed %d of %d legs." % [name, int(state.get("turn", 0)), int(state.get("total_turns", 0))], "grade": "-", "lesson": lesson}


# Rebuilds the game by replaying saved choices, so tampered numbers cannot be restored.
static func restore(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var saved: Dictionary = value
	if not _is_integer(saved.get("version")) or int(saved.version) not in [1, VERSION]:
		return {}
	if typeof(saved.get("species_id")) != TYPE_STRING or typeof(saved.get("history")) != TYPE_ARRAY:
		return {}
	if typeof(saved.get("upgrades")) != TYPE_DICTIONARY:
		return {}
	if typeof(saved.get("last_result")) != TYPE_STRING or typeof(saved.get("purchased_this_turn")) != TYPE_BOOL:
		return {}
	for key in ["turn", "total_turns", "condition", "energy", "points"]:
		if not _is_number(saved.get(key)) or not is_finite(float(saved[key])):
			return {}
	var era := 2000
	if int(saved.version) == VERSION:
		if not _is_integer(saved.get("era")):
			return {}
		era = int(saved.era)
	elif saved.has("era") and saved.era != 2000:
		return {}
	for key in ["turn", "total_turns", "points"]:
		if not _is_integer(saved.get(key)):
			return {}
	for value_level in saved.upgrades.values():
		if not _is_integer(value_level):
			return {}
	var state := new_game(saved.species_id, era)
	if state.is_empty() or saved.history.size() > MAX_HISTORY_PER_LEG * int(state.total_turns):
		return {}
	for entry in saved.history:
		if typeof(entry) != TYPE_DICTIONARY or state.status != "active":
			return {}
		var bought: Variant = entry.get("upgrade", "")
		if typeof(bought) != TYPE_STRING:
			return {}
		if bought != "":
			if not can_buy(state, bought):
				return {}
			state = buy_upgrade(state, bought)
		var mode: Variant = entry.get("mode")
		if typeof(mode) != TYPE_STRING or (mode != "travel" and mode != "forage"):
			return {}
		if mode == "forage" and not can_forage(state):
			return {}
		state = advance(state, mode)
		var replayed: Dictionary = state.history[-1]
		for key in replayed:
			if not _same(entry.get(key), replayed[key]):
				return {}
	# One upgrade may have been bought after the last move.
	if saved.get("purchased_this_turn") == true:
		var pending := ""
		for id in state.upgrades:
			if _is_number(saved.upgrades.get(id)) and int(saved.upgrades[id]) == int(state.upgrades[id]) + 1:
				pending = id
		if pending == "" or not can_buy(state, pending):
			return {}
		state = buy_upgrade(state, pending)

	for key in ["turn", "total_turns", "condition", "energy", "points", "status", "upgrades", "purchased_this_turn"]:
		if not _same(saved.get(key), state[key]):
			return {}
	if int(saved.version) == VERSION and saved.last_result != state.last_result:
		return {}
	return state


static func _is_integer(v: Variant) -> bool:
	return _is_number(v) and float(v) == floor(float(v))


static func _same(a: Variant, b: Variant) -> bool:
	# Integer fields (turn, points, levels, history turn) must match exactly.
	if typeof(b) == TYPE_INT:
		return _is_integer(a) and int(a) == b
	if _is_number(a) and _is_number(b):
		return is_equal_approx(float(a), float(b))
	if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
		if a.size() != b.size():
			return false
		for k in b:
			if not a.has(k) or not _same(a[k], b[k]):
				return false
		return true
	return typeof(a) == typeof(b) and a == b


static func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or (typeof(v) == TYPE_FLOAT and is_finite(v))


static func _bought_before(state: Dictionary) -> String:
	# The upgrade bought since the last move is the one level not yet recorded in history.
	if not state.purchased_this_turn:
		return ""
	var recorded := {}
	for entry in state.history:
		if entry.upgrade != "":
			recorded[entry.upgrade] = recorded.get(entry.upgrade, 0) + 1
	for id in state.upgrades:
		if int(state.upgrades[id]) > recorded.get(id, 0):
			return id
	return ""


static func _upgrade_name(id: String, state: Dictionary = {}) -> String:
	for u in upgrades(state):
		if u.id == id:
			return u.name
	return id


static func _narrative(event: Dictionary, mode: String, level: int, starving: bool) -> String:
	var text := ""
	if mode == "forage":
		text = "The pod stops to feed and regains energy, but lingers in the danger zone."
	else:
		text = "The pod pushes on through the %s." % event.title.to_lower()
	if event.threat == "plastic":
		text += " Debris is swallowed or snagged along the way; there is no quick fix for plastic."
	elif level > 0:
		text += " %s (level %d) blunted the harm." % [_upgrade_name(THREAT_UPGRADE[event.threat], {"era": event.get("era", 2000)}), level]
	else:
		text += " Nothing was in place to soften this threat."
	if starving:
		text += " Out of energy, the whale burns its reserves."
	return text
