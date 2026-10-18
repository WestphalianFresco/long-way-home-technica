extends SubViewportContainer
## Original procedural whale study, rendered as a live 3D hologram.
var reduced_motion := false
var species_id := "humpback"
var rig: Node3D
var camera: Camera3D
var elapsed := 0.0
var dragging := false
var rotation_offset := Vector2.ZERO
var view: SubViewport

func _ready() -> void:
	stretch = true
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	view = SubViewport.new()
	view.size = Vector2i(540, 400)
	view.transparent_bg = true
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.msaa_3d = Viewport.MSAA_4X
	add_child(view)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.035, 0.055, 0)
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.02
	world.environment = env
	view.add_child(world)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.4
	camera.position = Vector3(-0.4, 3.8, 7)
	view.add_child(camera)
	camera.look_at(Vector3.ZERO)
	rig = Node3D.new()
	rig.rotation = Vector3(-0.12,-0.3,-0.08)
	view.add_child(rig)
	_build_whale()
	var ring := PackedVector3Array()
	for i in range(120):
		var a := float(i) / 120 * TAU
		var b := float(i + 1) / 120 * TAU
		ring.append(Vector3(cos(a)*2.65, -0.85, sin(a)*1.0))
		ring.append(Vector3(cos(b)*2.65, -0.85, sin(b)*1.0))
	_add_lines(ring, Color(0.16,0.44,0.59), view)

func _body(u: float, a: float) -> Vector3:
	var x := lerpf(-2.0, 2.05, u)
	var r := pow(maxf(0.0, sin(PI * pow(u, 0.66))), 0.72) * lerpf(0.68, 0.25, u)
	var y := r * cos(a) * 0.85 + sin(u*PI)*0.13
	var z := r * sin(a)
	if species_id == "sperm":
		r = pow(maxf(0.0, sin(PI*pow(u,0.36))),0.35)*lerpf(0.7,0.1,u)
		y = r*cos(a)*0.9 + 0.12
		z = r*sin(a)
	return Vector3(x,y,z)

func _build_whale() -> void:
	var lines := PackedVector3Array()
	var dots := PackedVector3Array()
	for i in range(76):
		var u := float(i)/75.0
		for j in range(24):
			var a := float(j)/24.0*TAU
			var p := _body(u,a)
			dots.append(p)
			if i < 75:
				lines.append(p)
				lines.append(_body(float(i+1)/75.0,a))
			if i%4==0:
				lines.append(p)
				lines.append(_body(u,float(j+1)/24.0*TAU))
	# Long pectoral fins; swept flukes and dorsal ridge.
	for side in [-1.0,1.0]:
		var fin_length := 1.65 if species_id == "humpback" else 1.0
		_fin(lines, Vector3(-0.65,-0.12,0.38*side), Vector3(0.15,-0.72,fin_length*side), Vector3(-0.22,-0.22,0.4*side), 16)
		_fin(lines, Vector3(1.7,0.0,0), Vector3(2.32,0.12,1.05*side), Vector3(2.04,-0.02,0), 17)
	_fin(lines,Vector3(0.3,0.36,0),Vector3(0.76,0.59,0),Vector3(1.08,0.24,0),12)
	_add_lines(lines,Color(0.10,0.32,0.47),rig)
	_add_points(dots)
	# Ventral pleats, a curved jaw and two bright eyes add recognizable anatomy.
	var detail := PackedVector3Array()
	for j in range(8):
		var a := PI*0.62 + float(j)/7.0*PI*0.76
		for i in range(23):
			detail.append(_body(0.08+i*0.017,a)*1.006)
			detail.append(_body(0.08+(i+1)*0.017,a)*1.006)
	for side in [-1.0,1.0]:
		for i in range(28):
			var u := 0.025+i*0.013
			var a := _body(u,PI*0.52*side)
			var b := _body(u+0.013,PI*0.52*side)
			a.y -= 0.07; b.y -= 0.07
			detail.append(a*1.01); detail.append(b*1.01)
	_add_lines(detail,Color(0.38,0.68,0.89),rig)
	for side in [-1.0,1.0]:
		var eye := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.025
		sphere.height = 0.05
		eye.mesh = sphere
		eye.position = _body(0.17,PI*0.43*side)
		eye.material_override = _material(Color(0.8,0.95,1)*3.0)
		rig.add_child(eye)

func _fin(lines: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, count: int) -> void:
	for i in range(count):
		var t := float(i)/count
		var next := float(i+1)/count
		var left := a.lerp(b,t)
		var right := c.lerp(b,pow(t,0.6))
		var left_next := a.lerp(b,next)
		var right_next := c.lerp(b,pow(next,0.6))
		lines.append(left); lines.append(right)
		for j in range(5):
			lines.append(left.lerp(right,j/4.0))
			lines.append(left_next.lerp(right_next,j/4.0))

func _add_points(points: PackedVector3Array) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.009
	sphere.height = 0.018
	sphere.radial_segments = 4
	sphere.rings = 2
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = sphere
	multi.instance_count = points.size()
	for i in range(points.size()):
		multi.set_instance_transform(i,Transform3D(Basis(),points[i]))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.material_override = _material(Color(0.40,0.78,1.0)*1.3)
	rig.add_child(instance)

func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.no_depth_test = false
	return m

func _add_lines(points: PackedVector3Array, color: Color, parent: Node) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES,arrays)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material(color)
	parent.add_child(node)

func _process(delta: float) -> void:
	if not is_instance_valid(rig): return
	if not reduced_motion and not dragging:
		elapsed += delta
		rig.rotation.y = sin(elapsed*0.23)*0.18 - 0.3 + rotation_offset.x
		rig.rotation.z = sin(elapsed*0.35)*0.035 - 0.08 + rotation_offset.y
		rig.position.y = sin(elapsed*0.6)*0.055

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		accept_event()
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		rotation_offset.x += event.relative.x*0.012
		rotation_offset.y = clampf(rotation_offset.y+event.relative.y*0.005,-0.4,0.4)
		rig.rotation.y += event.relative.x*0.012
		rig.rotation.z = clampf(rig.rotation.z+event.relative.y*0.005,-0.5,0.5)
		accept_event()
