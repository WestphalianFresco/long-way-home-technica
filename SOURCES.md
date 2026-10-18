# Scientific sources and modeling boundaries

Checked October 17, 2026 against the NOAA Fisheries species pages below. These
sources inform the educational text. Numerical game penalties, upgrade costs,
condition scores, region timing, and difficulty are authored game rules.

- Humpback: https://www.fisheries.noaa.gov/species/humpback-whale — the Hawaii
  population breeds around Hawaii and feeds in northern Pacific areas including
  Alaska. The game follows a schematic northbound example, not all humpbacks.
- Gray: https://www.fisheries.noaa.gov/species/gray-whale — eastern North Pacific
  whales use Baja California wintering areas and northern Bering/Chukchi feeding
  areas. Some individuals feed elsewhere; not all follow one identical path.
- North Atlantic right: https://www.fisheries.noaa.gov/species/north-atlantic-right-whale
  — seasonal use of southeastern US calving waters and northeastern US/Canadian
  feeding waters, with variation and year-round occurrence in some areas. Ship
  strikes and gear entanglement are major threats. We avoid an undated count:
  the current page summarizes approximately 380 and separately gives 384 (+10/-9)
  for the start of 2024 in an October 2025 estimate. These are not a 2026 census.
- Blue: https://www.fisheries.noaa.gov/species/blue-whale — eastern North Pacific
  whales are believed to winter off Mexico/Central America and feed off the US
  West Coast in summer. Movement knowledge is incomplete and food-dependent.
- Sperm: https://www.fisheries.noaa.gov/species/sperm-whale — migration is less
  predictable than baleen-whale migration. Females/young tend to remain tropical;
  adult males can travel to temperate/higher-latitude feeding waters. The game
  depicts one illustrative adult-male foraging journey, not a tracked universal route.

## Simplifications shown to players

Routes are coarse illustrated corridors, not telemetry, safe-navigation advice, or
predictions. Turns compress time; they are not years. An expedition group is a game
abstraction: real social organization differs, and blue whales are often solitary
or in pairs. A condition score is not population abundance or a modeled survival
probability. We do not simulate births during a short journey or imply that real
reproduction can restore a population in a few turns. Recovery differences can be
explained in the guide without a fabricated biological forecast.

Protection upgrades represent coordinated policy and conservation effort. They
reduce simplified risk, do not instantly remove warming or plastic, and are not
validated estimates of intervention efficacy. No claims of real whales saved.

## Technical sources

Godot web export documentation: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html
Official matching release: https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable
The UI and procedural ocean relief are original prototype artwork. Coastlines in assets/land.geojson come from Natural Earth,
1:110m physical land (public domain):
https://www.naturalearthdata.com/about/terms-of-use/
https://github.com/nvkelso/natural-earth-vector/blob/master/geojson/ne_110m_land.geojson

The relief is generated noise, not measured bathymetry. The five static whale portraits are
AI-assisted illustrations, not anatomically validated species models. They were
created with the built-in image_gen tool from the project's Obsidian concept
artwork. Full prompts, source output paths, and project asset paths are recorded
in assets/whale-image-prompts.json. The PNGs preserve native transparency.
The desktop visual study uses Godot Forward+ through Metal on macOS. Web export
would require the Compatibility renderer and separate visual/performance QA.

## Era selection and historical boundaries

- IWC history and purpose: https://iwc.int/commission/history-and-purpose
- Modern harpoon development and late-19th-century adoption: IWC journal historical review, https://journal.iwc.int/index.php/jcrm/article/download/623/348/4324
- Modern right-whale pressures: NOAA, https://www.fisheries.noaa.gov/species/north-atlantic-right-whale/protected
- Recovery differs between humpback populations: NOAA, https://www.fisheries.noaa.gov/species/humpback-whale

Timeline ticks are broad centuries, so the 1800s cannon represents the late century.
1700s events exclude engine noise, plastic and mechanized whaling. The 1900s era
includes industrial whaling. No event sequence, damage multiplier, silhouette
fraction or era difficulty is a historical statistic or a calibrated ecological
model. The 2100 selection is a hypothetical future scenario, not observed data or
a quantitative projection. The declining silhouette row is illustrative; it must
not be read as a shared monotonic population trajectory for all five species.
Historical protections are counterfactual game choices, and modern schematic
routes are not verified historical migration tracks. Wreck debris is a provisional
interpretation of the sketch, specifically abandoned rigging/debris rather than
all shipwrecks. The nine transparent SVG obstacle icons are original vector art.
