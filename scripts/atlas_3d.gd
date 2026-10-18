extends SubViewportContainer
## Live 3D schematic ocean atlas. Natural Earth coastlines; synthetic seabed relief.
var species: Dictionary = {}
var state: Dictionary = {}
var reduced_motion := false
var view: SubViewport
var camera: Camera3D
var world: Node3D
var markers: Node3D
var center_lon := -135.0
var center_lat := 28.0
var elapsed := 0.0
var noise: FastNoiseLite
var coast_rings: Array[PackedVector2Array] = []
var route_world := PackedVector3Array()
var beacon: MeshInstance3D
var labels: Array[Dictionary] = []
var font: Font
static var cached_contour := PackedVector3Array()
static var cached_bright := PackedVector3Array()
var zoom := 13.5
var pan := Vector3.ZERO

func set_view(sp: Dictionary, s: Dictionary = {}, reduce: bool = false) -> void:
	species = sp
	state = s
	reduced_motion = reduce

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	font = load("res://assets/Mono.ttf")
	center_lon = -48.0 if species.get("id","") in ["right","sperm"] else -138.0
	center_lat = 30.0
	view = SubViewport.new()
	view.size = Vector2i(1280,800)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("030a12")
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.13
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	view.add_child(we)
	world = Node3D.new()
	view.add_child(world)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = zoom
	view.add_child(camera)
	_camera_update()
	noise = FastNoiseLite.new()
	noise.seed = 718
	noise.frequency = 0.065
	noise.fractal_octaves = 3
	_load_coasts()
	_build_seabed()
	_build_grid()
	_build_coasts()
	_build_route()
	# Labels are a separate overlay, so they remain crisp above bloom.
	var overlay := AtlasLabels.new()
	overlay.atlas = self
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

func _camera_update() -> void:
	camera.size = zoom
	camera.position = Vector3(0,17,12)+pan
	camera.look_at(pan)

func geo(lon: float, lat: float) -> Vector3:
	var x := wrapf(lon-center_lon,-180.0,180.0)/10.0
	return Vector3(x,0.1,(center_lat-lat)/10.0)

func height_at(x: float, z: float) -> float:
	var ridge := exp(-pow((x+2.0+sin(z*0.65)*2.8)/1.8,2.0))*0.8
	return noise.get_noise_2d(x*2.4,z*2.4)*0.5+ridge

func _load_coasts() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/land.geojson"))
	for feature: Dictionary in data.get("features",[]):
		var geometry: Dictionary = feature.geometry
		var polys: Array = [geometry.coordinates] if geometry.type == "Polygon" else geometry.coordinates
		for polygon: Array in polys:
			var ring := PackedVector2Array()
			for point: Array in polygon[0]:
				var p := geo(point[0],point[1])
				ring.append(Vector2(p.x,p.z))
			coast_rings.append(ring)

func _build_grid() -> void:
	var lines := PackedVector3Array()
	for x in range(-18,19,2):
		lines.append(Vector3(x,-0.12,-10))
		lines.append(Vector3(x,-0.12,10))
	for z in range(-10,11,2):
		lines.append(Vector3(-18,-0.12,z))
		lines.append(Vector3(18,-0.12,z))
	_lines(lines,Color(0.055,0.15,0.22))

func _build_seabed() -> void:
	if not cached_contour.is_empty():
		_lines(cached_contour,Color(0.018,0.065,0.11))
		_lines(cached_bright,Color(0.035,0.12,0.19))
		return
	# Marching squares on deterministic relief; not measured bathymetry.
	var n_x := 200
	var n_z := 112
	var step := 0.18
	var values := PackedFloat32Array()
	for z in range(n_z+1):
		for x in range(n_x+1):
			values.append(height_at(x*step-18,z*step-10))
	var contour := PackedVector3Array()
	var bright := PackedVector3Array()
	for level_i in range(-7,22):
		var level := level_i*0.05
		for z in range(n_z):
			for x in range(n_x):
				var idx := z*(n_x+1)+x
				var h := [values[idx],values[idx+1],values[idx+n_x+2],values[idx+n_x+1]]
				var p := [Vector2(x*step-18,z*step-10),Vector2((x+1)*step-18,z*step-10),Vector2((x+1)*step-18,(z+1)*step-10),Vector2(x*step-18,(z+1)*step-10)]
				var crosses: Array[Vector3] = []
				for edge in range(4):
					var next := (edge+1)%4
					if (h[edge]<level) != (h[next]<level):
						var pt: Vector2 = p[edge].lerp(p[next],(level-h[edge])/(h[next]-h[edge]))
						crosses.append(Vector3(pt.x,level*0.65-0.42,pt.y))
				for i in range(0,crosses.size()-1,2):
					if level_i%4==0:
						bright.append(crosses[i]); bright.append(crosses[i+1])
					else:
						contour.append(crosses[i]); contour.append(crosses[i+1])
	cached_contour = contour
	cached_bright = bright
	_lines(contour,Color(0.018,0.065,0.11))
	_lines(bright,Color(0.035,0.12,0.19))

func _build_coasts() -> void:
	var lines := PackedVector3Array()
	var dots := PackedVector3Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 117
	for ring in coast_rings:
		for i in range(ring.size()-1):
			var a := ring[i]
			var b := ring[i+1]
			if a.distance_to(b)>8: continue
			lines.append(Vector3(a.x,0.18,a.y))
			lines.append(Vector3(b.x,0.18,b.y))
			if i%2==0:
				var q := a+Vector2(rng.randf_range(-0.03,0.03),rng.randf_range(-0.03,0.03))
				dots.append(Vector3(q.x,0.22,q.y))
				dots.append(Vector3(q.x+0.024,0.22,q.y))
		# Low-opacity land fill behind the coastal outline.
		var clean := ring.duplicate()
		if clean.size()>2 and clean[0].is_equal_approx(clean[-1]): clean.remove_at(clean.size()-1)
		var crosses_seam := false
		for i in range(clean.size()-1):
			if clean[i].distance_to(clean[i+1])>8: crosses_seam = true
		if crosses_seam: continue
		var indices := Geometry2D.triangulate_polygon(clean)
		if indices.is_empty(): continue
		var vertices := PackedVector3Array()
		for p in clean: vertices.append(Vector3(p.x,0.08,p.y))
		var arr := []; arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = vertices
		arr[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
		var inst := MeshInstance3D.new()
		inst.mesh = mesh
		inst.material_override = _mat(Color(0.012,0.028,0.04))
		world.add_child(inst)
	_lines(lines,Color(0.12,0.36,0.55)*1.2)
	_lines(dots,Color(0.35,0.64,0.85)*1.4)
	labels.append({"pos":geo(-150,25),"text":"N O R T H   P A C I F I C"})
	labels.append({"pos":geo(-110,49),"text":"N O R T H   A M E R I C A"})
	labels.append({"pos":geo(-42,30),"text":"N O R T H   A T L A N T I C"})

func _build_route() -> void:
	var route: Array = species.get("route",[])
	if route.size()<2: return
	for p: Vector2 in route:
		var q := geo(p.x,p.y)
		q.y = 0.28
		route_world.append(q)
	var curve := Curve3D.new()
	for i in range(route_world.size()):
		var prev := route_world[maxi(0,i-1)]
		var next := route_world[mini(route_world.size()-1,i+1)]
		var tangent := (next-prev)*0.12
		curve.add_point(route_world[i],-tangent,tangent)
	var baked := curve.get_baked_points()
	var lines := PackedVector3Array()
	for i in range(baked.size()-1):
		lines.append(baked[i]); lines.append(baked[i+1])
	_lines(lines,Color(0.52,0.86,1)*3.3)
	for i in range(route_world.size()):
		var point := route_world[i]
		_sphere(point,0.055,Color(0.69,0.91,1)*3.0)
		_ring(point,0.14,Color(0.28,0.6,0.76))
	var progress := float(state.get("turn",0))/maxf(1.0,float(state.get("total_turns",species.get("legs",8))))
	var current := curve.sample_baked(progress*curve.get_baked_length())
	beacon = _sphere(current,0.085,Color(1.0,0.66,0.23)*2.8)
	for radius in [0.32,0.62,1.0]: _ring(current,radius,Color(0.38,0.28,0.12))
	labels.append({"pos":route_world[0]+Vector3(0.2,0,-0.28),"text":"DEPARTURE","gold":true})
	labels.append({"pos":route_world[-1]+Vector3(0.2,0,-0.28),"text":"FEEDING GROUNDS","gold":true})

func _ring(center: Vector3, radius: float, color: Color) -> void:
	var points := PackedVector3Array()
	for i in range(90):
		var a := i/90.0*TAU
		var b := (i+1)/90.0*TAU
		points.append(center+Vector3(cos(a)*radius,0.01,sin(a)*radius))
		points.append(center+Vector3(cos(b)*radius,0.01,sin(b)*radius))
	_lines(points,color)

func _sphere(pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius*2
	node.mesh = mesh
	node.position = pos
	node.material_override = _mat(color)
	world.add_child(node)
	return node

func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _lines(points: PackedVector3Array, color: Color) -> void:
	if points.is_empty(): return
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = points
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES,arr)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = _mat(color)
	world.add_child(inst)

func _process(delta: float) -> void:
	if not reduced_motion:
		elapsed += delta
		if is_instance_valid(beacon): beacon.scale = Vector3.ONE*(1.0+sin(elapsed*2)*0.12)
	if get_child_count()>1: get_child(1).queue_redraw()

func change_zoom(amount: float) -> void:
	zoom = clampf(zoom+amount,8.0,24.0)
	_camera_update()

func reset_view() -> void:
	zoom = 13.5
	pan = Vector3.ZERO
	_camera_update()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: change_zoom(-1.0); accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: change_zoom(1.0); accept_event()
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		pan.x = clampf(pan.x-event.relative.x*zoom/maxf(size.y,1),-12,12)
		pan.z = clampf(pan.z-event.relative.y*zoom/maxf(size.y,1),-6,6)
		_camera_update()
		accept_event()

class AtlasLabels extends Control:
	var atlas: Control
	func _draw() -> void:
		if not is_instance_valid(atlas.camera): return
		for label: Dictionary in atlas.labels:
			if atlas.camera.is_position_behind(label.pos): continue
			var at: Vector2 = atlas.camera.unproject_position(label.pos)
			if Rect2(Vector2(10,20),size-Vector2(170,45)).has_point(at):
				draw_string(atlas.font,at,label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("d5b980") if label.get("gold",false) else Color("6695ad"))
