extends RefCounted
## Authored game eras, not reconstructed population data or predictive models.
const YEARS := [1700, 1800, 1900, 2000, 2100]
const THREAT_NAMES := {"sailing":"Sailing ships", "harpoon":"Harpoon cannon", "industrial":"Industrial whaling", "wreck":"Wreck debris", "plastic":"Pollution", "warming":"Warming ocean", "gear":"Fishing nets", "noise":"Underwater noise", "strike":"Commercial shipping"}
const RECORDS := [
 {"year":1700,"title":"1700s · Age of sail","description":"Sailing whalers, fishing lines and abandoned rigging cross the journey.","difficulty":"Gentler","scenario":false,"silhouette_fraction":1.0,"threats":["sailing","gear","wreck"],"damage_scale":0.75},
 {"year":1800,"title":"1800s · Whaling expands","description":"Sailing fleets give way to late-century harpoon cannon. A century compressed into one journey.","difficulty":"Challenging","scenario":false,"silhouette_fraction":0.8,"threats":["sailing","harpoon","wreck","gear"],"damage_scale":0.9},
 {"year":1900,"title":"1900s · Industrial whaling","description":"Factory fleets and mechanized hunting overlap with growing shipping and fishing pressure.","difficulty":"Hard","scenario":false,"silhouette_fraction":0.55,"threats":["industrial","harpoon","strike","gear","noise","wreck"],"damage_scale":1.15},
 {"year":2000,"title":"2000s · A crowded ocean","description":"Shipping, entanglement, pollution and warming shape the modern migration.","difficulty":"Challenging","scenario":false,"silhouette_fraction":0.35,"threats":["noise","strike","gear","warming","plastic"],"damage_scale":1.0},
 {"year":2100,"title":"2100 · Future scenario","description":"An imagined high-pressure ocean. A projection scenario, not observed data or a forecast.","difficulty":"Hard","scenario":true,"silhouette_fraction":0.2,"threats":["warming","strike","gear","noise","plastic"],"damage_scale":1.3},
]
static func all_eras() -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 for record in RECORDS:
  result.append(record.duplicate(true))
 return result
static func get_era(year: int) -> Dictionary:
 for record in RECORDS:
  if record.year == year:
   return record.duplicate(true)
 return {}
