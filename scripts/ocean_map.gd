extends Control
## Original, schematic ocean chart. Coastline and contours are illustrative.

var species: Dictionary = {}
var state: Dictionary = {}
var reduced_motion: bool = false
var phase: float = 0.0
var clock_accum: float = 0.0
var bounds: Rect2 = Rect2(-180, -5, 150, 85)
var accent: Color = Color("91e6ef")
var font: Font
var whale_texture: Texture2D

const LAND := [
	[Vector2(-168,72),Vector2(-148,70),Vector2(-130,70),Vector2(-112,74),Vector2(-90,75),Vector2(-70,69),Vector2(-60,55),Vector2(-64,49),Vector2(-60,47),Vector2(-66,44),Vector2(-70,43),Vector2(-71,41),Vector2(-74,40),Vector2(-76,35),Vector2(-80,32),Vector2(-81,25),Vector2(-82,27),Vector2(-84,30),Vector2(-90,29),Vector2(-97,26),Vector2(-98,22),Vector2(-92,18),Vector2(-87,21),Vector2(-87,17),Vector2(-83,10),Vector2(-79,9),Vector2(-81,8),Vector2(-90,14),Vector2(-104,19),Vector2(-110,23),Vector2(-114,29),Vector2(-117,32),Vector2(-123,39),Vector2(-125,48),Vector2(-133,55),Vector2(-140,59),Vector2(-150,60),Vector2(-160,55),Vector2(-170,52),Vector2(-164,60),Vector2(-168,65)],
	[Vector2(-81,12),Vector2(-72,12),Vector2(-62,10),Vector2(-51,3),Vector2(-35,-7),Vector2(-40,-22),Vector2(-52,-33),Vector2(-64,-55),Vector2(-72,-51),Vector2(-75,-30),Vector2(-81,-4)],
	[Vector2(-17,35),Vector2(-8,36),Vector2(4,37),Vector2(14,33),Vector2(33,31),Vector2(44,12),Vector2(51,11),Vector2(41,-12),Vector2(33,-26),Vector2(20,-35),Vector2(12,-18),Vector2(8,4),Vector2(-5,5),Vector2(-16,13)],
	[Vector2(-10,36),Vector2(-9,43),Vector2(-2,44),Vector2(-5,49),Vector2(3,51),Vector2(8,57),Vector2(5,61),Vector2(17,70),Vector2(30,71),Vector2(50,69),Vector2(80,76),Vector2(140,71),Vector2(179,66),Vector2(160,55),Vector2(141,47),Vector2(130,35),Vector2(110,20),Vector2(102,5),Vector2(90,22),Vector2(80,8),Vector2(68,24),Vector2(51,25),Vector2(42,13),Vector2(35,30),Vector2(28,40),Vector2(20,40),Vector2(15,37),Vector2(12,45),Vector2(3,43)],
	[Vector2(-52,59),Vector2(-43,60),Vector2(-21,72),Vector2(-25,82),Vector2(-48,84),Vector2(-65,76)],
	[Vector2(-8,50),Vector2(-3,50),Vector2(0,53),Vector2(-3,59),Vector2(-6,58)],
	[Vector2(-24,64),Vector2(-14,64),Vector2(-14,66),Vector2(-22,67)],
	[Vector2(-159.8,22),Vector2(-159.3,21.7),Vector2(-159.5,22.3)],
	[Vector2(-156,20.5),Vector2(-154.8,19.5),Vector2(-155.7,18.9),Vector2(-156.2,19.8)],
	[Vector2(-84,23),Vector2(-78,22),Vector2(-74,20),Vector2(-79,20),Vector2(-83,22)]
]

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = load("res://assets/Mono.ttf") if ResourceLoader.exists("res://assets/Mono.ttf") else ThemeDB.fallback_font
	if ResourceLoader.exists("res://assets/whale.svg"):
		whale_texture = load("res://assets/whale.svg")
	resized.connect(queue_redraw)
	queue_redraw()

func set_view(next_species: Dictionary, next_state: Dictionary = {}, reduce: bool = false) -> void:
	species = next_species
	state = next_state
	reduced_motion = reduce
	accent = species.get("color", Color("91e6ef"))
	var route: Array = species.get("route", [])
	if not route.is_empty():
		var low := Vector2(180,90)
		var high := Vector2(-180,-90)
		for point: Vector2 in route:
			low = low.min(point)
			high = high.max(point)
		var center := (low + high) * 0.5
		var span := (high - low + Vector2(34,24)).max(Vector2(65,55))
		bounds = Rect2(center - span * 0.5, span)
	queue_redraw()

func _process(delta: float) -> void:
	if reduced_motion or not is_visible_in_tree():
		return
	phase += delta
	clock_accum += delta
	if clock_accum > 0.05:
		clock_accum = 0.0
		queue_redraw()

func project(point: Vector2) -> Vector2:
	var pad := Vector2(35,50)
	var area := (size - pad * 2.0).max(Vector2(1,1))
	return pad + Vector2((point.x - bounds.position.x) / bounds.size.x, 1.0 - (point.y - bounds.position.y) / bounds.size.y) * area

func _draw() -> void:
	if size.x < 2 or size.y < 2 or font == null:
		return
	draw_rect(Rect2(Vector2.ZERO,size),Color("06121d"))
	_draw_contours()
	_draw_grid()
	_draw_land()
	_draw_route()
	_draw_instruments()

func _draw_grid() -> void:
	for longitude: int in range(-180,181,10):
		var x := project(Vector2(longitude,bounds.position.y)).x
		if x < 20 or x > size.x-20:
			continue
		draw_line(Vector2(x,38),Vector2(x,size.y-36),Color(0.35,0.65,0.73,0.09),1.0)
		for y: int in range(58,int(size.y)-38,44):
			draw_circle(Vector2(x,y),1,Color(0.5,0.8,0.9,0.18))
		_label(Vector2(x-15,size.y-18),str(absi(longitude))+"°"+("W" if longitude<0 else "E"),10,Color("56818c"))
	for latitude: int in range(-80,91,10):
		var y := project(Vector2(bounds.position.x,latitude)).y
		if y<45 or y>size.y-42:
			continue
		draw_line(Vector2(24,y),Vector2(size.x-24,y),Color(0.35,0.65,0.73,0.09),1.0)
		_label(Vector2(7,y-5),str(absi(latitude))+"°",10,Color("56818c"))

func _draw_contours() -> void:
	# Synthetic visual contours are never labeled as measured bathymetry.
	var centers := [Vector2(0.15,0.55),Vector2(0.66,0.75),Vector2(0.83,0.20)]
	for center: Vector2 in centers:
		for ring: int in range(1,17):
			var line := PackedVector2Array()
			for j: int in range(97):
				var angle := float(j) / 96.0 * TAU
				var radius := float(ring) * 16.0 + sin(angle*3.0+center.x*11.0)*10.0 + sin(angle*5.0+ring*0.17)*7.0
				line.append(center*size + Vector2(cos(angle)*radius*1.35,sin(angle)*radius*0.8))
			draw_polyline(line,Color(0.24,0.58,0.68,0.07 if ring%4 != 0 else 0.14),1.0,true)

func _draw_land() -> void:
	for continent: Array in LAND:
		var polygon := PackedVector2Array()
		for point: Vector2 in continent:
			polygon.append(project(point))
		draw_colored_polygon(polygon,Color("0d212a"))
		polygon.append(polygon[0])
		draw_polyline(polygon,Color(0.4,0.72,0.75,0.25),1.2,true)
	var region_labels := [[Vector2(-110,45),"N O R T H  A M E R I C A"],[Vector2(-42,73),"G R E E N L A N D"],[Vector2(-140,25),"N O R T H  P A C I F I C"],[Vector2(-49,28),"N O R T H  A T L A N T I C"]]
	for entry: Array in region_labels:
		var pos := project(entry[0])
		if Rect2(Vector2(40,60),size-Vector2(220,130)).has_point(pos):
			_label(pos,entry[1],10,Color("567c84"))

func _draw_route() -> void:
	var route: Array = species.get("route",[])
	if route.size() < 2:
		return
	var points := PackedVector2Array()
	for point: Vector2 in route:
		points.append(project(point))
	var progress := float(state.get("turn",0)) / float(maxi(1,int(state.get("total_turns",species.get("legs",8)))))
	var position_index := progress * float(points.size()-1)
	var lower := mini(int(position_index),points.size()-2)
	var position := points[lower].lerp(points[lower+1],position_index-float(lower))
	for index: int in range(points.size()-1):
		draw_dashed_line(points[index],points[index+1],Color(accent,0.30),1.0,5.0,true)
	var completed := PackedVector2Array()
	completed.append(points[0])
	for index: int in range(1,lower+1):
		completed.append(points[index])
	completed.append(position)
	if progress>0:
		draw_polyline(completed,Color(accent,0.06),14,true)
		draw_polyline(completed,Color(accent,0.13),6,true)
		draw_polyline(completed,Color(accent,0.95),1.8,true)
	for index: int in range(points.size()):
		var done := float(index)<=position_index
		draw_circle(points[index],3,Color(accent,0.9 if done else 0.35))
		draw_arc(points[index],7,0,TAU,24,Color(accent,0.3),1,true)
	# A moving carrier marker and a gentle sonar ring.
	var pulse := 23.0 + (0.5 if reduced_motion else fmod(phase*0.22,1.0))*36.0
	draw_arc(position,pulse,0,TAU,60,Color(accent,0.14),1,true)
	draw_arc(position,24,0,TAU,48,Color(accent,0.4),1,true)
	draw_circle(position,17,Color("102f3b"))
	draw_circle(position,4,accent)
	if whale_texture:
		draw_texture_rect(whale_texture,Rect2(position-Vector2(24,12),Vector2(48,24)),false,accent)
	var label_pos := position + Vector2(32,-26)
	label_pos.x = clampf(label_pos.x,12,maxf(12,size.x-190))
	label_pos.y = clampf(label_pos.y,70,maxf(70,size.y-90))
	draw_line(position+Vector2(16,-12),label_pos-Vector2(4,-4),Color(accent,0.6),1,true)
	_label(label_pos,str(species.get("name","WHALE")).to_upper(),12,accent)
	_label(label_pos+Vector2(0,17),"EXPEDITION SIGNAL  /  %02d" % (int(state.get("turn",0))+1),9,Color("86a4b0"))
	_label(points[0]+Vector2(-8,26),"DEPARTURE",10,Color("9bb8bc"))
	var end_label := points[points.size()-1]+Vector2(12,-10)
	end_label.x=clampf(end_label.x,15,maxf(15,size.x-120))
	_label(end_label,"FEEDING GROUNDS",10,Color("e6c88d"))
	if not state.is_empty() and state.get("status","active")=="active":
		var risk_position := position.lerp(points[mini(lower+1,points.size()-1)],0.6)+Vector2(23,30)
		draw_arc(risk_position,34,0,TAU,48,Color(0.92,0.61,0.28,0.3),1,true)
		draw_arc(risk_position,30,0,TAU,48,Color(0.92,0.61,0.28,0.13),5,true)
		_label(risk_position+Vector2(-4,5),"!",15,Color("e9b56c"))

func _draw_instruments() -> void:
	var line := Color(0.5,0.8,0.88,0.38)
	for origin: Vector2 in [Vector2(1,1),Vector2(size.x-1,1),Vector2(1,size.y-1),size-Vector2.ONE]:
		var direction := Vector2(1 if origin.x<10 else -1,1 if origin.y<10 else -1)
		draw_line(origin,origin+Vector2(20*direction.x,0),line,1.0)
		draw_line(origin,origin+Vector2(0,20*direction.y),line,1.0)
	_label(Vector2(20,25),"MIGRATION ATLAS  /  SCHEMATIC",10,Color("82a9b3"))
	var north := Vector2(size.x-35,65)
	draw_line(north+Vector2(0,19),north-Vector2(0,12),Color("9bcbd2"),1.0)
	draw_line(north-Vector2(0,12),north+Vector2(-4,-4),Color("9bcbd2"),1.0)
	_label(north-Vector2(4,18),"N",10,Color("9bcbd2"))
	_label(Vector2(20,size.y-42),"ILLUSTRATIVE ROUTE  ·  NOT LIVE TRACKING",9,Color("688994"))

func _label(at: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
