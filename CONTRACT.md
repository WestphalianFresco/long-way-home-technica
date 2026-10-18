# Long Way Home — implementation contract v1

Godot 4.7.2 installed at /Users/WilliamFan/Downloads/Godot.app/Contents/MacOS/Godot.
Run headless checks with that executable. No dependencies need installing.

## Product

Long Way Home / A Whale Migration Strategy Game. Five playable species. A calm,
cinematic, oceanic strategy terminal: black-navy, cyan-white glow, fine topographic
lines, amber danger, readable typography. Original vector artwork; no copied game
assets. Start species selector -> complete expedition -> debrief/replay.
Use a North-up stylized GLOBAL map, real coarse route anchors simplified into game
legs. Data grounded in specific NOAA populations, not universal species routes.

## Data and engine contract (technica2 owns)

scripts/species_data.gd: extends RefCounted; class_name SpeciesData.
static func all_species() -> Array[Dictionary], static func get_species(id: String) -> Dictionary.
Records fields: id ('humpback','gray','right','blue','sperm'), name, scientific_name,
tagline, difficulty (String), description, route_label, route_note, fact, source_url,
threats (Array[String]), color (Color), route (Array[Vector2] LONGITUDE,LATITUDE),
legs (int), condition_start (float), energy_start (float), vulnerability (Dictionary
with keys noise,strike,gear,warming,plastic, numeric multipliers).
Codex will supply SOURCES.md; avoid exact population counts or km claims until verified.
Suggested population routes: humpback Hawaii/Alaska; gray Baja/Arctic via coast;
right Florida/Georgia to Canada; blue eastern North Pacific; sperm adult male
northward foraging journey, not a universal fixed migration. Disclose schematic
routes, sex/population differences, and simplified grouping in field guide.

scripts/simulation.gd: extends RefCounted; class_name Simulation.
static func new_game(species_id: String) -> Dictionary
static func upgrades() -> Array[Dictionary] # id,name,description,cost (int),max_level (2),effect
static func current_event(state: Dictionary) -> Dictionary # title,description,threat,label,severity
static func buy_upgrade(state: Dictionary,id: String) -> Dictionary # immutable; invalid returns same values
static func advance(state: Dictionary,mode: String = 'travel') -> Dictionary # immutable
static func summary(state: Dictionary) -> Dictionary # title,body,grade,lesson
static func restore(value: Variant) -> Dictionary # empty dict if invalid

State fields version:1, species_id:String, turn:int COMPLETED LEGS (0 initially),
total_turns:int, condition:float 0..100, energy:float 0..100, points:int,
status:String ('active','arrived','lost'), upgrades:Dictionary four ids->level,
purchased_this_turn:bool, history:Array[Dictionary], last_result:String.
History entries: turn, title, threat, mode, condition_delta, energy_delta,
condition_after, energy_after, narrative. Buy at most one upgrade per turn;
upgrades persist. The choices: speed (ship strikes), quiet (noise), gear
(entanglement), refuge (food/heat/energy). Show plastic as event with limited
mitigation, no magic cleanup. Earn some conservation points as legs progress.
Advance either 'travel' or 'forage'; forage restores energy but increases exposure.
Different species have meaningful danger/energy changes. Some can lose before
arrival. Ensure a sensible affordable path can arrive with each species and
inaction can perform worse. Game scores are illustrative, not biological estimates.
Action history must allow trustworthy restore, or validate all schema/ranges.
Test with extends SceneTree script, no external test addon. No reference to main.gd.

## UI contract (technica1 owns)

scripts/main.gd extends Control; main.tscn root attaches it. scripts/ui_theme.gd
optional helper. Programmatic responsive UI at 1440x900 default; stretch canvas.
Species selector with five selectable species, prominent title, field guide/info,
route map, clear START MIGRATION button. Active expedition: turn/route progress,
condition/energy/points, event briefing, persistent upgrades with cost/level,
ADVANCE / FORAGE actions, recent result, field guide and abandon/restart controls.
Debrief: condition, upgrades/choices, outcome, replay/change species. Game fully
playable with keyboard and mouse. No fake buttons or sponsor claims.
Save/continue with ConfigFile or JSON user://; safely catch bad/missing files via
Simulation.restore. Optional reduced motion toggle. Empty save must be harmless.
Map is scripted Control with clip_contents; instantiate preload('res://scripts/ocean_map.gd').new().
Map API: set_view(species: Dictionary,state: Dictionary = {},reduced_motion: bool = false).
Codex implements map, no dummy stub file in its path. It sizes to own rect.
Engine may arrive while UI is written; follow this API exactly. Avoid class_name
load ordering problems with explicit preloads. Default font available; Codex adds
assets/Heading.ttf and assets/Mono.ttf if available. Code should work without them.
Audio absent is fine; do not display dead sound controls. Game should work offline.

## Validation

Codex runs Godot imports, engine tests, full headless scene run, native launch,
web export and browser smoke tests when templates available. Workers may run tests
for their own files; don't launch duplicate editor windows. Report actual checks.


# Era selection contract v2 — October 18, 2026

This section supersedes conflicting v1 details. The user explicitly requests the
IMG_3543 start screen: title Long Way Home, Pick Your Setting, settings/home,
fading whale silhouettes, era slider 1700/1800/1900/2000/2100, five species cards,
and era-specific obstacles. Keep the approved static holographic whale portraits.

## Ownership for this change
- Codex: main.gd, era_timeline.gd, settings UI, UI tests, integration, docs.
- technica2: simulation.gd, NEW era_data.gd, simulation tests; species_data.gd only
  if needed. Do not edit Codex UI or assets.
- technica1: NEW assets/threats/*.svg and assets/threats/README.md only. Do not
  edit main.gd, the simulation, or static whale art.

## Shared API (freeze these names)
- era_data.gd extends RefCounted (explicit preload; class_name optional).
- static all_eras() -> Array[Dictionary]
- static get_era(year: int) -> Dictionary (empty for unknown year)
- Each era record: year:int, title:String, description:String, difficulty:String,
  scenario:bool, silhouette_fraction:float 0..1, threats:Array[String].
- Years exactly 1700,1800,1900,2000,2100. Earlier ticks mean broad century eras,
  not a claim that all their technologies existed in the tick's first year.
- silhouette_fraction is authored illustrative decline: 1.0,0.8,0.55,0.35,0.2.
  UI must state that this is not a measured population series; recovery varies.
- new_game(species_id:String, era:int=2000) -> Dictionary, v2 state includes era.
- upgrades(state:Dictionary={}) -> Array[Dictionary]; no-arg retains modern names.
  Four existing upgrade IDs/costs remain; early-era wording must not claim modern
  ropeless fishing or engine-noise policies existed in 1700. Interventions in
  past eras are counterfactual game choices, not historical records.
- current_event fields unchanged, plus event.era optional. Existing modern threat
  IDs remain noise,strike,gear,warming,plastic; add sailing,harpoon,industrial,wreck.
- THREAT_UPGRADE must map all threats to an existing upgrade ID.
- Restore v1 saves by validating/replaying modern 2000 rules, then migrate to v2.
  Never silently discard or erase a legacy save. Validate era, finite/integral
  schema fields and replay history; reject invalid/tampered v2 states.
- Historical event sets are meaningfully different; 1700 must not show plastic,
  engine noise, industrial factory ships or explosive harpoon cannon. 1800s may
  include late-century cannon technology. 1900s include industrial whaling.
  2000 preserves existing modern gameplay; 2100 is a possible future scenario.
- Era affects difficulty/damage, with a viable sensible path for all 25 choices.
  Do bounded policy tests across eras; do not multiply the existing exhaustive
  search by five. Preserve existing modern regression tests.
- Wreck means debris/abandoned rigging in this prototype, not a claim that all
  wrecks pose a whale hazard. Slot 10 stays unassigned; do not invent an obstacle.

## Icon paths and labels
assets/threats/sailing.svg — Sailing ship
assets/threats/harpoon.svg — Harpoon cannon
assets/threats/industrial.svg — Industrial whaling
assets/threats/wreck.svg — Wreck debris
assets/threats/plastic.svg — Pollution
assets/threats/warming.svg — Warming ocean
assets/threats/gear.svg — Fishing nets
assets/threats/noise.svg — Underwater noise
assets/threats/strike.svg — Commercial shipping

## UI behavior
Slider snaps to the five eras and supports keyboard input. Changing era updates
silhouette opacity, era title/description/difficulty, scenario badge and threat
preview without resetting chosen species. Starting passes both selections;
continue, replay, guide and debrief preserve/display the chosen era. Settings
opens real controls for reduced motion and fullscreen, persisted independently
of saves. Home returns to setup and preserves any saved active expedition.
Species cards retain the generated static images. All copy remains English.

## Evidence boundaries
Era events and pressure levels are educational scenarios, not reconstructed
historical population series or forecasts. Modern route anchors are schematic
and are not claimed to be verified tracks for each historical century. 2100 must
always visibly say SCENARIO. NOAA notes recovery varies between populations.

Ownership update: both worker dispatches were denied before delivery. Codex owns
all v2 implementation files for this pass; the two undelivered requests are cancelled.

Current ownership after connection restored: technica2 owns era_data.gd, simulation.gd and simulation/era tests for final review. Codex owns UI/assets/integration/docs. technica1 completed a read-only UI/icon review; no project write ownership.

## Continuous timeline revision (user confirmed)
The opening time ruler scrolls continuously left/right beneath a fixed central marker. No five-position snapping or year buttons. Pointer drag, wheel/trackpad, arrows and Home/End supported. Whale group uses existing static holographic species PNGs; alpha interpolates smoothly within centuries and fully fades out. Art stays stationary. Setup keeps its exact continuous position across species/guide changes. Simulation continues using the century containing the selected year, with 2100 as a scenario. This supersedes the earlier slider snapping requirement.

Whale group clarification: use a loose scattered pod at different vertical positions, with varied adult/small sizes; never a uniform lineup. Reuse the selected species portrait, with no translation/rotation animation.
