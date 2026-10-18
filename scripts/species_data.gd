extends RefCounted
class_name SpeciesData

# Routes are schematic longitude/latitude anchors for one named population each,
# simplified into game legs. They are not tracks of real animals.

const _SPECIES := [
	{
		"id": "humpback",
		"name": "Humpback Whale",
		"scientific_name": "Megaptera novaeangliae",
		"tagline": "The singer of the North Pacific.",
		"difficulty": "Easy",
		"description": "Humpbacks that winter around Hawaii travel north each spring to feed in the cold, rich waters off Alaska.",
		"route_label": "Hawaii to Southeast Alaska",
		"route_note": "Schematic route for the Hawaii population. Humpbacks elsewhere follow different routes.",
		"fact": "Male humpbacks sing long, complex songs on their breeding grounds.",
		"source_url": "https://www.fisheries.noaa.gov/species/humpback-whale",
		"threats": ["Vessel noise", "Ship strikes", "Fishing gear entanglement"],
		"color": Color(0.45, 0.85, 0.95),
		"route": [Vector2(-156.5, 20.8), Vector2(-152.0, 28.0), Vector2(-147.0, 36.0), Vector2(-143.0, 45.0), Vector2(-139.0, 52.0), Vector2(-136.5, 56.0), Vector2(-134.5, 58.0)],
		"legs": 6,
		"condition_start": 90.0,
		"energy_start": 80.0,
		"travel_cost": 13.0,
		"vulnerability": {"noise": 1.2, "strike": 0.8, "gear": 0.9, "warming": 0.8, "plastic": 0.6},
		"events": [["noise", 1], ["warming", 1], ["strike", 1], ["gear", 2], ["noise", 2], ["strike", 1]],
		"places": ["Maui Nui waters", "Open North Pacific", "Subtropical front", "Gulf of Alaska", "Alaska shelf edge", "Inside Passage"],
	},
	{
		"id": "gray",
		"name": "Gray Whale",
		"scientific_name": "Eschrichtius robustus",
		"tagline": "A coastal traveler on one of the longest mammal migrations.",
		"difficulty": "Medium",
		"description": "Eastern North Pacific gray whales leave the lagoons of Baja California and follow the coast north to Arctic feeding grounds.",
		"route_label": "Baja California to the Bering and Chukchi Seas",
		"route_note": "Schematic coastal route for the Eastern North Pacific population. The Western North Pacific population is separate.",
		"fact": "Gray whales feed by sucking sediment from the seafloor and filtering out small animals.",
		"source_url": "https://www.fisheries.noaa.gov/species/gray-whale",
		"threats": ["Ship strikes", "Fishing gear entanglement", "Changing Arctic food supply"],
		"color": Color(0.75, 0.82, 0.88),
		"route": [Vector2(-114.0, 27.7), Vector2(-117.5, 32.5), Vector2(-121.5, 36.0), Vector2(-124.5, 41.0), Vector2(-125.0, 48.0), Vector2(-136.0, 57.5), Vector2(-152.0, 57.0), Vector2(-165.0, 60.5), Vector2(-168.5, 67.0)],
		"legs": 8,
		"condition_start": 85.0,
		"energy_start": 75.0,
		"travel_cost": 11.0,
		"vulnerability": {"noise": 0.9, "strike": 1.0, "gear": 1.0, "warming": 1.1, "plastic": 0.8},
		"events": [["noise", 1], ["strike", 2], ["gear", 1], ["strike", 1], ["gear", 2], ["plastic", 1], ["warming", 1], ["warming", 2]],
		"places": ["Baja lagoons", "Southern California Bight", "Central California coast", "Oregon coast", "Washington coast", "Gulf of Alaska", "Alaska Peninsula", "Bering Strait"],
	},
	{
		"id": "right",
		"name": "North Atlantic Right Whale",
		"scientific_name": "Eubalaena glacialis",
		"tagline": "A critically endangered whale in a busy ocean.",
		"difficulty": "Hard",
		"description": "Mothers and calves leave the calving grounds off Florida and Georgia and travel north toward New England and Canadian feeding areas.",
		"route_label": "Southeast U.S. calving grounds to the Gulf of St. Lawrence",
		"route_note": "Schematic route. Right whale movements vary year to year, and not every whale makes this full trip.",
		"fact": "Right whales feed close to the surface and spend much of their time in coastal waters, which brings them near ships and fishing gear.",
		"source_url": "https://www.fisheries.noaa.gov/species/north-atlantic-right-whale",
		"threats": ["Ship strikes", "Fishing gear entanglement", "Shifting food supply"],
		"color": Color(0.95, 0.72, 0.42),
		"route": [Vector2(-81.0, 30.5), Vector2(-78.5, 33.0), Vector2(-75.0, 36.5), Vector2(-73.5, 40.0), Vector2(-70.0, 41.8), Vector2(-66.5, 43.5), Vector2(-63.0, 47.5)],
		"legs": 6,
		"condition_start": 75.0,
		"energy_start": 70.0,
		"travel_cost": 13.0,
		"vulnerability": {"noise": 1.0, "strike": 1.6, "gear": 1.6, "warming": 1.0, "plastic": 0.7},
		"events": [["strike", 2], ["gear", 1], ["strike", 2], ["gear", 2], ["warming", 1], ["gear", 2]],
		"places": ["Georgia calving grounds", "Carolina coast", "Mid-Atlantic shipping lanes", "New York Bight", "Cape Cod Bay", "Gulf of Maine"],
	},
	{
		"id": "blue",
		"name": "Blue Whale",
		"scientific_name": "Balaenoptera musculus",
		"tagline": "The largest animal known to have lived, chasing krill.",
		"difficulty": "Medium",
		"description": "Eastern North Pacific blue whales move between warm waters off Mexico and Central America and summer feeding areas off the U.S. West Coast.",
		"route_label": "Costa Rica Dome to the California Current",
		"route_note": "Schematic route for the Eastern North Pacific population. Other blue whale populations range widely elsewhere.",
		"fact": "Blue whales eat mostly krill, gulping huge mouthfuls of water and filtering it through baleen.",
		"source_url": "https://www.fisheries.noaa.gov/species/blue-whale",
		"threats": ["Ship strikes", "Ocean noise", "Shifting krill"],
		"color": Color(0.35, 0.6, 1.0),
		"route": [Vector2(-89.0, 9.0), Vector2(-98.0, 14.0), Vector2(-106.0, 20.0), Vector2(-113.0, 26.0), Vector2(-118.5, 32.5), Vector2(-120.5, 34.2), Vector2(-123.0, 37.5)],
		"legs": 6,
		"condition_start": 85.0,
		"energy_start": 70.0,
		"travel_cost": 16.0,
		"vulnerability": {"noise": 1.0, "strike": 1.4, "gear": 0.6, "warming": 1.2, "plastic": 0.5},
		"events": [["warming", 1], ["noise", 1], ["strike", 2], ["strike", 2], ["warming", 2], ["noise", 1]],
		"places": ["Costa Rica Dome", "Gulf of Tehuantepec", "Mexican Pacific", "Baja Pacific coast", "Santa Barbara Channel", "Gulf of the Farallones"],
	},
	{
		"id": "sperm",
		"name": "Sperm Whale",
		"scientific_name": "Physeter macrocephalus",
		"tagline": "A deep diver following squid, not a fixed calendar.",
		"difficulty": "Medium-Hard",
		"description": "Females and young stay mostly in warmer waters. Adult males range farther, toward higher latitudes, to forage.",
		"route_label": "Adult male foraging journey, western North Atlantic",
		"route_note": "Sperm whale movements depend on sex and age and are less predictable than a seasonal migration. This shows one schematic adult-male journey.",
		"fact": "Sperm whales dive deep to hunt squid and find prey with echolocation clicks.",
		"source_url": "https://www.fisheries.noaa.gov/species/sperm-whale",
		"threats": ["Ocean noise", "Swallowed marine debris", "Fishing gear entanglement"],
		"color": Color(0.72, 0.62, 0.95),
		"route": [Vector2(-64.0, 17.0), Vector2(-66.0, 24.0), Vector2(-68.0, 31.0), Vector2(-68.0, 37.5), Vector2(-62.0, 41.0), Vector2(-56.0, 44.0), Vector2(-52.0, 50.0), Vector2(-54.0, 56.0)],
		"legs": 7,
		"condition_start": 82.0,
		"energy_start": 85.0,
		"travel_cost": 11.0,
		"vulnerability": {"noise": 1.4, "strike": 0.7, "gear": 1.0, "warming": 0.6, "plastic": 1.4},
		"events": [["noise", 2], ["plastic", 1], ["noise", 1], ["gear", 1], ["plastic", 2], ["noise", 2], ["warming", 1]],
		"places": ["Caribbean deep water", "Sargasso Sea", "Bermuda Rise", "Gulf Stream edge", "Continental slope", "Grand Banks", "Labrador Sea"],
	},
]


static func all_species() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for record in _SPECIES:
		out.append(_copy(record))
	return out


static func get_species(id: String) -> Dictionary:
	for record in _SPECIES:
		if record.id == id:
			return _copy(record)
	return {}


static func _copy(record: Dictionary) -> Dictionary:
	var out: Dictionary = record.duplicate(true)
	var route: Array[Vector2] = []
	for point in record.route:
		route.append(point)
	out.route = route
	var threats: Array[String] = []
	for threat in record.threats:
		threats.append(threat)
	out.threats = threats
	return out
