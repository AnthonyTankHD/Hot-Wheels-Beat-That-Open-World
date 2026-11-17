extends MVehicle3D
# Hot Wheels Beat That car — M.A.V.S. physics (VehicleBody3D) with the
# REAL Beat That car models (converted from the game's .ARC files).
#
# Controls (Steam Deck): LEFT thumbstick steers, RIGHT thumbstick runs
# the camera (M.A.V.S. Cam_Holder), RT gas, LT brake.
# Keyboard: W/S gas & brake, A/D steer, Space handbrake, R reset,
# V switches camera, Esc / Back opens the pause menu.
#
# Interface kept from the old arcade car so city.gd does not change:
#   apply_car(car_data), boost(), speed (units/sec), boost_timer.
# New: apply_settings() applies camera/volume settings to this car.
#
# The real models carry their own textures, so the M.A.V.S. colour
# tint stays disabled (allow_color_change = false) — the per-car colour
# is only used on the car select screen now. Each model is auto-fitted
# at load: physics wheel radius/position, collision box, lights, hood
# camera and smoke all follow the model's own geometry, so every one
# of the 30 cars sits right without per-car constants.

var speed := 0.0 # units/sec, for the HUD (veh_speed is km/h)
var boost_timer := 0.0

const BASE_DIFFERENTIAL: Array = [0.0, 33.0, 25.0, 24.0, 22.0, 20.0]
const BASE_GEAR_RATIO: Array = [0.0, 7.0, 6.0, 5.8, 5.5, 4.0]
# M.A.V.S. force numbers are tuned for a ~1 kg car; ours is 1000 kg,
# so the drivetrain force is scaled up to keep the arcade feel
# (0 to top speed in ~4 s). Body engine_force/brake are native
# VehicleBody3D properties applied to the wheels at the physics step.
const FORCE_SCALE := 20.0
const BOOST_FORCE := 2000.0 # +4 u/s^2 while a boost pad is active
const BRAKE_FORCE := 150.0 # stops from top speed in ~2.5 s (Jolt brake
# is far stronger per unit than a plain force; 800 stopped the car
# in 0.5 s and left the wheels spinning at 300 RPM while stopped)
const HANDBRAKE_FORCE := 300.0 # locks the wheels, slides the rear
# Tyre contact patch height, car-local. The model is placed so its
# lowest tyre bottom sits here, and every physics wheel is built so
# its contact patch lands here too.
const CONTACT_Y := -0.45
const STATIC_SAG := 0.041 # how far the suspension compresses under the
# car's own weight at rest (measured headless: Bone Shaker front
# 0.0406, rear 0.0415; same mass/stiffness for all 30 cars so one
# constant covers them). The physics engine writes the SIMULATED wheel
# centre into each VehicleWheel3D node every step — the node's
# position is NOT a fixed attach point. So the visual wheel must be
# centred ON the node (spinner at 0,0,0), and the attach point is set
# so the simulated centre lands on the model's own wheel centre:
# attach = model centre + rest length - sag. The old code hung the
# visual 0.2 below the node (WHEEL_REST) on top of the physics already
# moving the node ~0.26, so the visual wheels sat 0.256 below the
# axle with the tyres sunk 0.23 into the ground.
const SUSP_REST_LENGTH := 0.30

var _top_speed := 28.0 # units/sec, set per car by apply_car()
var _loaded_key := ""
var _model_root: Node = null
var _body_len := 5.8
var _collision_shape: CollisionShape3D
# Wheel order everywhere: [FL, FR, RL, RR].
var _wheel_nodes: Array = []
var _wheel_visuals: Array = [] # fallback cylinder per wheel
var _wheel_spinners: Array = [] # Node3D per wheel, holds the real mesh
var _cam_holder: Node = null # M.A.V.S. Cam_Holder (after super._ready)

func _ready() -> void:
	# --- Wire the project's input actions into M.A.V.S. ---
	key_accelerate = "gas"
	key_brake = "brake"
	key_turn_left = "steer_left"
	key_turn_right = "steer_right"
	key_handbrake = "Hand Brake"
	key_shift_up = "Shift Up"
	key_shift_down = "Shift Down"
	key_lights = "Lights"
	key_camera = "Camera Change"
	key_reset = "Reset"
	key_nitro = "Nitro"
	# Automatic gearbox, no NOS tank (boost pads do the boosting),
	# no energy/fuel drain.
	gearbox_transmission = transmission.automatic
	nos_tier = nos_level.Empty
	use_energy = false
	debug_hud = false
	is_current_veh = true
	# Real models carry their own textures — never tint them.
	allow_color_change = false
	# Keep launches grippy: the default burnout slip (0.5) would make
	# the rear tires spin under our scaled-up launch force.
	burnout_slip = 2.0
	# Tame the default steering a little: full lock at speed was
	# swinging the car ~80 deg/s, too twitchy for an arcade feel.
	turn_angle = 0.45
	# The addon's example cars are tuned for this mass; keep the
	# vehicle planted with a low center of mass.
	mass = 1000.0
	center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.3, 0)
	collision_layer = 3
	collision_mask = 3

	_build_collision()
	_build_wheels()
	_build_lights()
	_build_sounds()
	_build_particles()
	_build_markers()
	_load_model(CarData.selected_key)

	# Runs M.A.V.S. assign_vehicle(): minimap + chase camera, wheel
	# grip, rims. Needs every reference above set.
	super._ready()

	_find_cam_holder()
	_build_cam_fill_light()
	apply_settings()

func _build_cam_fill_light() -> void:
	# Soft spotlight riding on the chase camera, shining forward at
	# the car. The chase cam shows the car's rear, which faces away
	# from the sun in every zone, so without this the car reads as a
	# flat black blob. This lifts the rear paint just enough to show
	# its shape and gloss. Raised 0.7 -> 1.5 (playtest fix): black
	# metallic paint was still reading as a dark blob from behind on
	# every map, and 0.7 barely dented it. It rides the camera, so it
	# works in the city and every zone, whatever way the car is
	# facing; the narrow 55-degree cone and 20-unit range keep it on
	# the car instead of washing out the scene.
	if _cam_holder == null:
		return
	var cam: Camera3D = _cam_holder.get("camera") as Camera3D
	if cam == null:
		return
	var fill := SpotLight3D.new()
	fill.name = "Cam_Fill_Light"
	fill.spot_range = 20.0
	fill.spot_angle = 55.0
	fill.light_energy = 1.5
	fill.light_color = Color(1.0, 0.95, 0.85)
	fill.shadow_enabled = false
	cam.add_child(fill)

# ------------------------------------------------------------------ setup

func _build_collision() -> void:
	# Placeholder box; _fit_model resizes it to the real shell.
	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "CarCollision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 0.6, 4.0)
	_collision_shape.shape = shape
	add_child(_collision_shape)

func _make_wheel(pos: Vector3, steering: bool, traction: bool) -> VehicleWheel3D:
	var wheel := VehicleWheel3D.new()
	wheel.position = pos
	wheel.use_as_steering = steering
	wheel.use_as_traction = traction
	wheel.wheel_radius = 0.42
	wheel.wheel_rest_length = SUSP_REST_LENGTH
	wheel.suspension_stiffness = 60.0
	wheel.wheel_friction_slip = wheel_grip # M.A.V.S. default grip
	# (the addon also re-applies it to all_wheels every frame).
	# Fallback visual: dark cylinder, axle along X. The real wheel
	# mesh from the .glb goes in the spinner (child 1) when available
	# and this cylinder hides.
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.08, 0.12)
	var vis := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.42
	cyl.height = 0.35
	vis.mesh = cyl
	vis.rotation.z = PI * 0.5
	vis.material_override = dark
	wheel.add_child(vis)
	_wheel_visuals.append(vis)
	# Spinner: centred exactly on the wheel node. The physics engine
	# overwrites the VehicleWheel3D node's position every step with
	# the simulated wheel centre, so the real wheel mesh must hang
	# right on the node — any offset here drops the visual wheel
	# below the axle (the old -0.2 offset was the wheel bug).
	# Steering rotates the VehicleWheel3D node itself, which the
	# spinner inherits; the physics spin rotates it too.
	var spinner := Node3D.new()
	spinner.position = Vector3.ZERO
	wheel.add_child(spinner)
	_wheel_spinners.append(spinner)
	# NOT added to the tree here: _fit_model adds the wheels after
	# it sets the fitted positions, so the physics first sees each
	# wheel at the model's own wheel position.
	return wheel

func _build_wheels() -> void:
	# Front axle steers (+Z is the car's nose in M.A.V.S. layout).
	# Positions are defaults; _fit_model moves them to the model's
	# own wheel positions and adds the wheels to the tree.
	var fl := _make_wheel(Vector3(0.95, 0.1, 1.3), true, false)
	var fr := _make_wheel(Vector3(-0.95, 0.1, 1.3), true, false)
	var rl := _make_wheel(Vector3(0.95, 0.1, -1.3), false, true)
	var rr := _make_wheel(Vector3(-0.95, 0.1, -1.3), false, true)
	fl.name = "WheelFL"
	fr.name = "WheelFR"
	rl.name = "WheelRL"
	rr.name = "WheelRR"
	# M.A.V.S. applies handbrake/burnout to `wheels` (rear pair) and
	# grip to `all_wheels`; rpm is read from a traction wheel.
	wheels = [rl, rr]
	all_wheels = [fl, fr, rl, rr]
	_wheel_nodes = [fl, fr, rl, rr]
	rpm_wheel = rl

func _build_lights() -> void:
	# Headlights (toggled by the Lights action). Lamps sit at local
	# z = 0; _fit_model moves the whole container to the nose.
	var front := Node3D.new()
	front.name = "Front_Lights"
	for lx in [-0.7, 0.7]:
		var lamp := MeshInstance3D.new()
		var lamp_box := BoxMesh.new()
		lamp_box.size = Vector3(0.3, 0.15, 0.1)
		lamp.mesh = lamp_box
		lamp.position = Vector3(lx, 0.15, 0)
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color(1.0, 0.95, 0.8)
		glow.emission_enabled = true
		glow.emission = Color(1.0, 0.95, 0.7)
		glow.emission_energy_multiplier = 2.0
		lamp.material_override = glow
		front.add_child(lamp)
		var spot := SpotLight3D.new()
		spot.position = Vector3(lx, 0.15, 0)
		spot.rotation.x = -PI * 0.5
		spot.spot_range = 18.0
		spot.spot_angle = 35.0
		spot.light_energy = 2.0
		front.add_child(spot)
	front.visible = false
	add_child(front)
	front_light = front

func _build_sounds() -> void:
	# Engine + tyre audio. Streams are generated loopable tones
	# (res://sounds/); silent if the files are missing.
	var eng := AudioStreamPlayer3D.new()
	eng.name = "Engine Sound"
	var eng_stream: AudioStream = load("res://sounds/engine_hum.wav")
	if eng_stream != null:
		eng.stream = eng_stream
	add_child(eng)
	engine_sound = eng
	var tyre := AudioStreamPlayer3D.new()
	tyre.name = "Tire Sound"
	var tyre_stream: AudioStream = load("res://sounds/tyre_skid.wav")
	if tyre_stream != null:
		tyre.stream = tyre_stream
	add_child(tyre)
	tyre_sound = tyre

func _build_particles() -> void:
	# Tyre smoke puffs for the two rear wheels (M.A.V.S. toggles
	# emission while drifting / handbraking). _fit_model moves them
	# to the model's rear wheels.
	smoke_particles = []
	for sx in [-0.95, 0.95]:
		var p := GPUParticles3D.new()
		p.position = Vector3(sx, 0.1, -1.3)
		p.amount = 16
		p.lifetime = 0.7
		p.emitting = false
		var mat := ParticleProcessMaterial.new()
		mat.direction = Vector3(0, 1, 0)
		mat.spread = 35.0
		mat.initial_velocity_min = 1.0
		mat.initial_velocity_max = 2.5
		mat.gravity = Vector3(0, 0.5, 0)
		mat.scale_min = 0.3
		mat.scale_max = 0.7
		mat.color = Color(0.75, 0.75, 0.75, 0.6)
		p.process_material = mat
		var quad := QuadMesh.new()
		quad.size = Vector2(0.5, 0.5)
		p.draw_pass_1 = quad
		add_child(p)
		smoke_particles.append(p)
	# Skid marks: not used (M.A.V.S. guards on array size).
	skidmarks_particle = []

func _build_markers() -> void:
	# Hood camera marker (M.A.V.S. camera switch) + remote transform
	# that makes the chase camera follow the car. _fit_model moves
	# the hood marker just above the model's roof.
	var hood := Marker3D.new()
	hood.name = "Hood_Camera"
	hood.position = Vector3(0, 0.85, 1.5)
	add_child(hood)
	hood_cam = hood
	var rt := RemoteTransform3D.new()
	rt.name = "RemoteTransform3D"
	add_child(rt)
	remote_transformer = rt

# ------------------------------------------------------------------ real models

func _find_body_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.name.to_lower() == "body":
		return node
	for child in node.get_children():
		var found := _find_body_mesh(child)
		if found != null:
			return found
	return null

func _find_wheel_meshes(body_mesh: MeshInstance3D) -> Array:
	var found: Array = []
	for child in body_mesh.get_children():
		if child is MeshInstance3D and child.name.to_lower().begins_with("wheel"):
			found.append(child)
	return found

func _load_model(key: String, p_swap := false) -> void:
	if key == _loaded_key and _model_root != null:
		return
	if p_swap:
		# Fresh wheel nodes for the new car. Jolt never reliably
		# re-registers a wheel that is removed and re-added: stale
		# registrations pile up and the car sinks a little further
		# with every swap (measured: settled height fell 0.93 ->
		# 0.25 over 30 swaps, same-frame and 2-frame-gap re-adds
		# alike). Brand-new nodes are registered exactly once, at
		# the fitted positions, so there is no stale state to carry.
		# Freeing a wheel also frees its spinner and the old real
		# wheel mesh hanging off it.
		for wheel in _wheel_nodes:
			wheel.free()
		_wheel_nodes = []
		_wheel_visuals = []
		_wheel_spinners = []
		_build_wheels()
	if _model_root != null:
		_model_root.free()
		_model_root = null
	var path := "res://models/%s.glb" % key.to_lower()
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("[mavs_car] could not load model: " + path)
		return
	var inst: Node = packed.instantiate()
	inst.name = "RealModel"
	add_child(inst)
	_model_root = inst
	var body_mesh := _find_body_mesh(inst)
	if body_mesh == null:
		push_error("[mavs_car] no Body mesh found in " + path)
		return
	veh_mesh = body_mesh
	_fit_model(body_mesh, _find_wheel_meshes(body_mesh))
	# Metallic glossy die-cast finish on the body paint (not the
	# tyres, glass, or chrome — see gloss_body_paint).
	var glossed := gloss_body_paint(body_mesh)
	print("[mavs_car] glossed ", glossed, " paint surfaces (", key, ")")
	# Phantom Racer only: its "Screen FR" glass renders white/opaque
	# and vanishes against the car's white body, so tint it green.
	if key == "PHANTOMRACER":
		var tinted := tint_glass_green_tree(_model_root)
		print("[mavs_car] tinted ", tinted, " glass surfaces green (Phantom Racer)")
	# M.A.V.S. cached the old rpm wheel's radius for its puncture
	# logic; point it at the new car.
	wheel_def_radius = rpm_wheel.wheel_radius
	_loaded_key = key
	print("[mavs_car] loaded real model: ", key, " (", path, ")")

func _fit_model(body_mesh: MeshInstance3D, wheel_meshes: Array) -> void:
	# All measurements are in the Body's local space (the model's own
	# frame): X = width, Y = up, Z = length, nose at +Z. The model
	# root is counter-rotated below, so these map 1:1 to car space.
	var body_aabb: AABB = body_mesh.get_aabb()
	_body_len = body_aabb.size.z
	var body_center: Vector3 = body_aabb.get_center()

	# Match each real wheel mesh to a corner by its position, and
	# measure its radius/width. Defaults cover a missing corner.
	var corner_mesh := {"fl": null, "fr": null, "rl": null, "rr": null}
	var corner_pos := {
		"fl": Vector3(0.95, 0, 1.3), "fr": Vector3(-0.95, 0, 1.3),
		"rl": Vector3(0.95, 0, -1.3), "rr": Vector3(-0.95, 0, -1.3),
	}
	var corner_radius := {"fl": 0.42, "fr": 0.42, "rl": 0.42, "rr": 0.42}
	var corner_width := {"fl": 0.35, "fr": 0.35, "rl": 0.35, "rr": 0.35}
	var ground := 1e9
	for w in wheel_meshes:
		var wa: AABB = w.transform * w.get_aabb()
		var wp: Vector3 = w.position
		var radius := maxf(wa.size.y, wa.size.z) * 0.5
		radius = clampf(radius, 0.3, 0.9)
		ground = minf(ground, wa.position.y)
		var corner := ""
		if wp.z >= 0.0:
			corner = "fl" if wp.x >= 0.0 else "fr"
		else:
			corner = "rl" if wp.x >= 0.0 else "rr"
		corner_mesh[corner] = w
		corner_pos[corner] = wp
		corner_radius[corner] = radius
		corner_width[corner] = wa.size.x
	if ground > 1e8:
		push_error("[mavs_car] no wheel meshes found in model; using defaults")
		ground = -1.0

	# Place the model so the lowest tyre bottom sits on the contact patch.
	var y_offset := CONTACT_Y - ground
	# Counter-rotate the converter's -90deg X rotation on the Body
	# node (the .glb node matrix carries R while the vertices are
	# already Y-up). Without this the car renders standing on its nose.
	_model_root.rotation.x = PI * 0.5
	_model_root.position = Vector3(0, y_offset, 0)

	# Loop 1 — physics wheels: radius + attach height per corner so
	# the simulated wheel centres match the model's own wheel centres
	# (the visual meshes hang on the nodes, so this IS the axle).
	var order := ["fl", "fr", "rl", "rr"]
	for i in range(4):
		var corner: String = order[i]
		var radius: float = corner_radius[corner]
		var wp: Vector3 = corner_pos[corner]
		var wheel: VehicleWheel3D = _wheel_nodes[i]
		wheel.wheel_radius = radius
		# Attach point: the physics writes the simulated wheel centre
		# into the node (attach - rest length + sag under load), so
		# set the attach so the simulated centre lands exactly on
		# the model's own wheel centre (wp.y + y_offset).
		var model_center_y: float = wp.y + y_offset
		wheel.position = Vector3(wp.x, model_center_y + SUSP_REST_LENGTH - STATIC_SAG, wp.z)
		# Fallback cylinder visual matches the real wheel size.
		var vis: MeshInstance3D = _wheel_visuals[i]
		var cyl := vis.mesh as CylinderMesh
		if cyl != null:
			cyl.top_radius = radius
			cyl.bottom_radius = radius
			cyl.height = float(corner_width[corner])
	# The wheels enter the tree here, AFTER positioning: the physics
	# first sees them at the fitted positions (whether it captures
	# at add time or at the next sync, the positions are fitted).
	# Never remove + re-add the same nodes — Jolt keeps the stale
	# registration and the car sinks a little more every swap.
	for wheel in _wheel_nodes:
		if wheel.get_parent() == null:
			add_child(wheel)
	# Loop 2 — real wheel meshes: now that the wheels are in the tree
	# the reparent's global-transform math is exact (the car's yaw
	# cancels instead of doubling). The mesh hangs centred on the
	# spinner so it spins around the axle. Otherwise the cylinder
	# stays visible.
	for i in range(4):
		var corner: String = order[i]
		var mesh: MeshInstance3D = corner_mesh[corner]
		var spinner: Node3D = _wheel_spinners[i]
		var vis2: MeshInstance3D = _wheel_visuals[i]
		if mesh != null:
			mesh.reparent(spinner, true)
			mesh.position = Vector3.ZERO
			# Chrome rims (metallic 0.9) render as a flat grey slab in
			# the Compatibility renderer — there is no sky or env map
			# for them to reflect. Tame the metal so the rims read as
			# bright silver with visible spokes and a dark tyre ring.
			tame_chrome(mesh)
			vis2.visible = false
		else:
			vis2.visible = true

	# Collision box follows the body shell, with a little ground
	# clearance at the bottom (the old box sat 0.22 above the patch).
	var col_size := Vector3(
		maxf(body_aabb.size.x - 0.1, 1.0),
		clampf(body_aabb.size.y - 0.4, 1.0, 2.2),
		maxf(body_aabb.size.z - 0.1, 1.0))
	var shape := _collision_shape.shape as BoxShape3D
	if shape != null:
		shape.size = col_size
	_collision_shape.position = Vector3(body_center.x, y_offset + body_center.y + 0.1, body_center.z)

	# Headlights / hood cam / smoke follow the shell.
	var front_z := body_center.z + body_aabb.size.z * 0.5 - 0.05
	front_light.position = Vector3(0, y_offset - 0.5, front_z)
	hood_cam.position = Vector3(0, y_offset + body_aabb.end.y + 0.08,
		body_center.z + body_aabb.size.z * 0.18)
	var rear_pos: Vector3 = corner_pos["rl"]
	smoke_particles[0].position = Vector3(rear_pos.x, 0.1, rear_pos.z)
	smoke_particles[1].position = Vector3(-rear_pos.x, 0.1, rear_pos.z)

func _find_cam_holder() -> void:
	if _cam_holder == null:
		_cam_holder = get_node_or_null("Camera_Anchor/Cam_Holder")

# Chrome (metallic ~0.9) has nothing to reflect in the Compatibility
# renderer, so it renders as a flat grey slab — that is why the wheels
# looked like grey discs. Tame every chrome surface on a mesh so the
# rims read as bright silver. Duplicated per mesh so the body's own
# chrome materials are untouched. Also used by the car-select preview.
static func tame_chrome(mesh_inst: MeshInstance3D) -> void:
	var mesh: Mesh = mesh_inst.mesh
	if mesh == null:
		return
	for s in range(mesh.get_surface_count()):
		var mat: Material = mesh.surface_get_material(s)
		if mat == null:
			mat = mesh_inst.get_surface_override_material(s)
		if mat is StandardMaterial3D and (mat as StandardMaterial3D).metallic > 0.5:
			var fixed := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			fixed.metallic = 0.45
			fixed.roughness = 0.35
			mesh_inst.set_surface_override_material(s, fixed)

static func tame_chrome_tree(root: Node) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			tame_chrome(child)
		tame_chrome_tree(child)

# Metallic glossy die-cast finish for the body paint. The real .glb
# textures stay — same paint colours and decals — only the material
# finish changes: metallic up, roughness down, so the paint reads
# shiny like real die-cast instead of matte. Body paint ONLY: glass,
# chrome, tyres, lights and plastic trim are all skipped, and it runs
# on the Body mesh alone (never the wheel meshes, so the tyres stay
# matte rubber and the wheel-chrome treatment is untouched). Same
# per-mesh duplicate pattern as tame_chrome: the shared imported
# materials are never mutated.
const GLOSS_METALLIC := 0.3
const GLOSS_ROUGHNESS := 0.15

static func gloss_body_paint(body_mesh: MeshInstance3D) -> int:
	var glossed := 0
	var mesh: Mesh = body_mesh.mesh
	if mesh == null:
		return 0
	for s in range(mesh.get_surface_count()):
		var mat: Material = mesh.surface_get_material(s)
		if mat == null:
			mat = body_mesh.get_surface_override_material(s)
		if mat is StandardMaterial3D:
			var sm := mat as StandardMaterial3D
			var mname := String(sm.resource_name).to_lower()
			if mname.contains("screen") or mname.contains("glass"):
				continue # glass — the Phantom green tint lives here
			if mname.contains("tyre") or mname.contains("tire"):
				continue # tyres stay matte rubber
			if mname.contains("chrome") or mname.contains("chorme"):
				continue # chrome keeps its own treatment
			if mname.contains("light") or mname.contains("glow"):
				continue # lamp lenses, not paint
			if mname.contains("plastic"):
				continue # trim, not paint
			if sm.metallic > 0.5:
				continue # already metallic (chrome etc.)
			var fixed := sm.duplicate() as StandardMaterial3D
			fixed.metallic = GLOSS_METALLIC
			fixed.roughness = GLOSS_ROUGHNESS
			body_mesh.set_surface_override_material(s, fixed)
			glossed += 1
	return glossed

# Phantom Racer window tint: the "Screen FR" glass renders white and
# opaque, so it disappears against the car's white body. Tint it
# green — same per-mesh duplicate pattern as tame_chrome, so no other
# car and no other material on this car is touched. Only the tint
# changes: the glass keeps whatever alpha/roughness/metallic it had.
const PHANTOM_GLASS_TINT := Color(0.12, 0.8, 0.3)

static func tint_glass_green(mesh_inst: MeshInstance3D) -> int:
	var tinted := 0
	var mesh: Mesh = mesh_inst.mesh
	if mesh == null:
		return 0
	for s in range(mesh.get_surface_count()):
		var mat: Material = mesh.surface_get_material(s)
		if mat == null:
			mat = mesh_inst.get_surface_override_material(s)
		if mat is StandardMaterial3D:
			var sm := mat as StandardMaterial3D
			var mname := String(sm.resource_name).to_lower()
			if mname.contains("screen") or mname.contains("glass"):
				var fixed := sm.duplicate() as StandardMaterial3D
				var old := sm.albedo_color
				fixed.albedo_color = Color(PHANTOM_GLASS_TINT.r, PHANTOM_GLASS_TINT.g, PHANTOM_GLASS_TINT.b, old.a)
				mesh_inst.set_surface_override_material(s, fixed)
				tinted += 1
	return tinted

static func tint_glass_green_tree(root: Node) -> int:
	var total := 0
	for child in root.get_children():
		if child is MeshInstance3D:
			total += tint_glass_green(child)
		total += tint_glass_green_tree(child)
	return total

func apply_settings() -> void:
	GameSettings.load_settings()
	if engine_sound != null:
		engine_sound.volume_db = linear_to_db(maxf(GameSettings.engine_volume, 0.001))
	_find_cam_holder()
	if _cam_holder != null:
		# set() keeps this working even though Cam_Holder has no
		# class_name for a static type.
		_cam_holder.set("orbit_speed", GameSettings.cam_sensitivity)
		_cam_holder.set("invert_cam_y", GameSettings.invert_cam_y)
		var arm = _cam_holder.get("cam_arm")
		if arm != null:
			# The camera was only ~4.6 units behind the car, so the
			# car filled the screen and you could not see the whole
			# car (or the wheels). Pull it back so the full car is
			# visible with room around it; longer cars sit a little
			# further back so the camera never clips the rear bumper.
			arm.spring_length = 8.0 + maxf(0.0, _body_len - 6.0) * 0.6

# ------------------------------------------------------------------ API

func apply_car(car_data: Dictionary) -> void:
	veh_name = String(car_data.get("name", "Hot Wheels"))
	# Real models carry their own textures — no colour tinting here.
	# Swaps rebuild the wheel nodes fresh (see _load_model): the
	# physics registers the new nodes once, at the fitted positions.
	_load_model(String(car_data.get("key", "BONESHAKER")), true)
	# Per-car performance: scale the M.A.V.S. defaults.
	# top_speed 24..32 u/s, accel 16..22 (CarData).
	var ts := float(car_data["top_speed"])
	var ac := float(car_data["accel"])
	_top_speed = ts
	# NOTE: torque = gear_ratio * differential, so the force scale is
	# applied to the differential ONLY — scaling both would square it.
	var diff_scale := (ts / 28.0) * FORCE_SCALE
	var gear_scale := ac / 19.0
	var new_diff: Array = []
	for v in BASE_DIFFERENTIAL:
		new_diff.append(float(v) * diff_scale)
	differential = new_diff
	var new_gear: Array = []
	for v in BASE_GEAR_RATIO:
		new_gear.append(float(v) * gear_scale)
	gear_ratio = new_gear

func boost() -> void:
	boost_timer = 2.0
	Input.start_joy_vibration(0, 0.4, 0.4, 0.25)

func _physics_process(delta: float) -> void:
	# M.A.V.S. drivetrain, gearbox, grip, lights, sounds, reset.
	super._physics_process(delta)
	# HUD speed in units/sec (M.A.V.S. veh_speed is km/h).
	speed = veh_speed / 3.6
	# Top-speed cap: M.A.V.S. has no cap of its own, so cut the drive
	# once the car is at its per-car top speed (boost still applies).
	if speed > _top_speed and acceleration > 0.0:
		engine_force = 0.0
	# Reverse is computed inside M.A.V.S. as reverse_ratio * 50 and is
	# not scaled with the drivetrain, so scale it up here to match.
	if gear == -1:
		engine_force *= 20.0
	# Boost pads: extra engine force for a couple of seconds.
	# (engine_force is the native VehicleBody3D property, applied to
	# the traction wheels at the physics step.)
	if boost_timer > 0.0:
		boost_timer -= delta
		engine_force += BOOST_FORCE
	# Strong braking: the addon's brake value (5.0) is tuned for a
	# ~1 kg car and barely slows a 1000 kg one. Only while rolling
	# forward in a forward gear, so reverse still engages.
	var brake_strength := Input.get_action_strength("brake")
	if brake_strength > 0.1 and veh_speed > 1.0 and gear >= 0:
		brake = BRAKE_FORCE * brake_strength
	if Input.is_action_pressed("Hand Brake"):
		brake = HANDBRAKE_FORCE
	# Rumble on hard steering at speed.
	var steer := Input.get_axis("steer_left", "steer_right")
	if absf(steer) > 0.7 and absf(speed) > 10.0:
		Input.start_joy_vibration(0, 0.15, 0.15, 0.1)
	# NOTE: do NOT rotate the wheel spinners here. The physics engine
	# already spins each VehicleWheel3D node around its axle as the car
	# drives, and the real wheel meshes (children of the spinners,
	# children of the wheels) inherit that spin. Rotating the spinners
	# on top of it CANCELLED the physics spin — the wheel node's basis
	# carries a mirror (determinant -1), so the two equal rotations
	# subtract instead of adding — and the wheels looked frozen even
	# though the spin code was running (verified by a basis probe:
	# wheel basis and spinner basis both rotated ~32 deg over 3 s,
	# mesh global basis did not move). The spinners stay as the
	# reparenting targets for the real wheel meshes; they just don't
	# rotate anymore.
