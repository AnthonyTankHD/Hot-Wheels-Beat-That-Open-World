extends Node3D
# Hot Wheels Beat That — a real map from the original 2007 game.
# Loads a zone .glb converted from the original ArcBank data
# (see tools/arcbank-v5/zone_to_gltf.py), gives it trimesh collision
# so the M.A.V.S. car can drive on the real room/track geometry,
# and adds border walls + a fall respawn so the player can't leave
# the world. HUD and pause menu mirror the city (city.gd).
#
# Per-zone settings come from the scene as exported vars:
#   zone_glb  — res:// path to the zone .glb (converted original map)
#   zone_name — display name for the HUD
#   spawn     — where the car starts (on the room floor)
#   wall_min / wall_max — XZ bounds of the invisible border walls
#   floor_y   — respawn if the car falls below floor_y - 60

@export var zone_glb: String = "res://models/zones/zone1000.bin"
@export var zone_name: String = "Attic"
@export var spawn: Vector3 = Vector3(0, 1, 0)
@export var spawn_yaw: float = 0.0 # degrees; car faces +Z at 0, +X at 90
@export var cam_distance: float = 0.0 # 0 = M.A.V.S. default (8 + body len); else chase-cam spring length
@export var cam_height: float = 2.0 # chase-cam holder height above car origin (2.0 = M.A.V.S. default)
@export var cam_pitch: float = 0.0 # chase-cam pitch in degrees; negative = look down; 0 = level
@export var wall_min: Vector2 = Vector2(-700, -500)
@export var wall_max: Vector2 = Vector2(750, 300)
@export var floor_y: float = -300.0

var _car: MVehicle3D
var _name_label: Label
var _speed_label: Label
var _boost_label: Label
var _pause_menu: PauseMenu
var _stuck_time := 0.0

func _ready() -> void:
	GameSettings.load_settings()
	_car = $Car
	var car_data: Dictionary = CarData.selected()
	_car.apply_car(car_data)
	# After the model loads (so nothing in the load can clobber the
	# facing): put the car on the spawn point, facing the spawn
	# direction, camera already behind it.
	_place_at_spawn()
	_build_zone()
	_build_lane_patch()
	_build_north_floor_patch()
	_build_walls()
	_build_hud(car_data)
	_build_pause_menu()
	_car.apply_settings()
	_apply_zone_cam()

# Put the car on the spawn point, facing the spawn direction, with
# the chase camera already behind it (so the first frame is framed
# right instead of the camera swinging around from yaw 0).
func _place_at_spawn() -> void:
	_car.position = spawn
	_car.rotation = Vector3(0, deg_to_rad(spawn_yaw), 0)
	_car.linear_velocity = Vector3.ZERO
	_car.angular_velocity = Vector3.ZERO
	var anchor: Node3D = _car.get_node_or_null("Camera_Anchor")
	if anchor != null:
		anchor.rotation.y = deg_to_rad(spawn_yaw)

# Per-zone chase-cam distance. Runs after apply_settings() (which
# resets the spring length from the body length), and again after a
# pause-menu car swap for the same reason. 0 = leave the default.
func _apply_cam_distance() -> void:
	if cam_distance <= 0.0:
		return
	var arm: SpringArm3D = _car.get_node_or_null("Camera_Anchor/Cam_Holder/Cam_Pose/Springarm_Positioner")
	if arm != null:
		arm.spring_length = cam_distance

# Per-zone chase camera: height + pitch + distance, applied after
# apply_settings() (which resets the spring length from the body
# length) and again after a pause-menu car swap. Bowling's lane sits
# in a sunken channel with the room floor 31-42 units above it, so
# the low default chase cam made the furniture read as hanging from
# the ceiling; the camera is raised above the room floor (height 38,
# distance 28, pitch -26) so the floor reads as a floor and the
# furniture sits on it (with the north-floor patch filling the
# missing north floor). The other zones keep the defaults (height 2,
# pitch 0) — they already read level. The base values are stored on
# the cam holder so a camera switch keeps the zone's setup instead
# of resetting to the 8.0 / level defaults. Known trade-off: the
# hanging score TVs (y ~195-232) sit in the camera's line of sight,
# so the car ducks behind one briefly (~1 s) when passing each TV;
# that is original geometry, and raising the TVs is a separate call.
func _apply_zone_cam() -> void:
	_apply_cam_distance()
	var holder: Node = _car.get_node_or_null("Camera_Anchor/Cam_Holder")
	if holder == null:
		return
	holder.position = Vector3(0, cam_height, 0)
	holder.set("base_pitch_deg", cam_pitch)
	var arm: SpringArm3D = holder.get("cam_arm")
	if arm != null:
		holder.set("base_spring_length", arm.spring_length)
	var cam: Camera3D = holder.get("camera")
	if cam != null:
		cam.rotation_degrees.x = cam_pitch

func _build_pause_menu() -> void:
	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("change_car"):
		if _pause_menu != null and not _pause_menu.is_open():
			_pause_menu.open(_car, _apply_selected_car)
			get_viewport().set_input_as_handled()

# Swap in the car picked from the pause menu (or anywhere else):
# reload the model + drivetrain in place, refresh the camera distance
# for the new car's length, and update the HUD name.
func _apply_selected_car() -> void:
	var car_data: Dictionary = CarData.selected()
	_car.apply_car(car_data)
	_car.apply_settings()
	_apply_zone_cam()
	if _name_label != null:
		_name_label.text = "%s — %s" % [zone_name, car_data["name"]]

func _process(_delta: float) -> void:
	if _speed_label != null and _car != null:
		_speed_label.text = "SPEED %d" % int(absf(_car.speed) * 4.0)
		if _car.boost_timer > 0.0:
			_boost_label.text = "BOOST!"
			_boost_label.visible = true
		else:
			_boost_label.visible = false
		# Fell out of the world (through a gap in the room shell, or
		# off the edge of the table/bed/lane): put the car back at
		# the spawn, facing the spawn direction, instead of falling
		# forever. floor_y sits ~60 below the play level per zone,
		# so a fall of ~120 triggers the respawn promptly.
		if _car.global_position.y < floor_y - 60.0:
			_place_at_spawn()
			_stuck_time = 0.0
		# Wedged against a wall/toy with the gas floored and going
		# nowhere: respawn instead of sitting stuck. Only when the
		# player is actually holding gas, so a parked car never
		# resets out from under them.
		elif Input.is_action_pressed("gas") and absf(_car.speed) < 0.5:
			_stuck_time += _delta
			if _stuck_time > 3.0:
				_place_at_spawn()
				_stuck_time = 0.0
		else:
			_stuck_time = 0.0

# ------------------------------------------------------------------ zone

func _build_zone() -> void:
	# Load the zone .glb at RUNTIME via GLTFDocument, not via the
	# editor import (load()). The editor import of these big zone
	# files takes 10+ minutes per zone in this VM (it hangs in mesh
	# processing), while GLTFDocument parses the same .glb in ~3s.
	# The .glb files are real converted original geometry (see
	# tools/arcbank-v5/zone_to_gltf.py) with smooth normals
	# synthesized for the VBs that lack them, so every surface has
	# vertices and builds a valid trimesh.
	# The zone file is a .bin (raw .glb bytes) so Godot does NOT try
	# to editor-import it (the editor import of these big zone files
	# hangs for 10+ min per zone). A .bin is exported as raw data in
	# the .pck, and we parse it here at runtime via GLTFDocument.
	var file := FileAccess.open(zone_glb, FileAccess.READ)
	if file == null:
		push_error("[Zone] could not open " + zone_glb)
		return
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err: Error = doc.append_from_buffer(bytes, "", state)
	if err != OK:
		push_error("[Zone] could not parse " + zone_glb + " err=" + str(err))
		return
	var zone: Node = doc.generate_scene(state)
	if zone == null:
		push_error("[Zone] could not generate scene for " + zone_glb)
		return
	var body := StaticBody3D.new()
	body.name = "ZoneBody"
	add_child(body)
	body.add_child(zone)
	# Trimesh collision on every mesh in the real geometry, so the
	# car drives on the actual room floor, track, and furniture.
	# The CollisionShape3D MUST be a direct child of the StaticBody
	# (ZoneBody) — Godot only registers shapes that are direct
	# children of a physics body, so a shape nested under a
	# MeshInstance3D never collides (that's why the car fell through
	# even though 238 shapes existed). We add each shape to the
	# body and copy the mesh's global transform onto it.
	var count := 0
	var stack: Array[Node] = [zone]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh != null:
				var shape: Shape3D = mi.mesh.create_trimesh_shape()
				if shape != null:
					var col := CollisionShape3D.new()
					col.shape = shape
					body.add_child(col)
					col.global_transform = mi.global_transform
					count += 1
		for child in n.get_children():
			stack.append(child)
	print("[Zone] ", zone_name, ": trimesh collision on ", count, " meshes")

# Bowling Alley lane patch (2026-11-16): the converted zone3000
# geometry is MISSING the lane surface east of x≈-221 — no lane
# triangles and no collision there (verified by raycast grid and by
# the mesh data: lane-band verts stop at x=-220). The car drives
# east off the end of the real lane, falls through the hole, and
# flips onto its side against the north blue/cosmic wall (reproduced
# in the VM and on Anthony's Deck, video frame 15). The spawn move
# alone could not fix it — the hole is 36 units east of the spawn.
# Patch it with a red lane strip at the real lane level (top
# y=184.35, 0.05 above the real lane so it renders cleanly over the
# 4-unit overlap) running the full lane to the pins (x=330, where
# the real lane resumes at y≈185). Visual + collision together, so
# the car visibly drives on red, not on air over the pit.
func _build_lane_patch() -> void:
	if zone_name != "Bowling Alley":
		return
	var body := StaticBody3D.new()
	body.name = "LanePatch"
	body.position = Vector3(52.5, 183.35, -132)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(555, 2, 40)
	mesh.mesh = box
	mesh.material_override = _mat(Color(0.85, 0.20, 0.08))
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(555, 2, 40)
	col.shape = shape
	body.add_child(col)
	add_child(body)
	print("[Zone] Bowling Alley: lane patch added (x -225..330, top y=184.35)")

# North-floor patch (Bowling Alley only). Same loss class as the
# lane hole, found 2026-11-16 round 2: north of the lane the room
# has NO floor at all in the converted geometry. Godot raycast
# (the car drives on this collision) finds void from z=-110 to the
# north wall (z=+64) for almost every x east of -200, and a
# triangle-area count over the converted zone3000.bin finds only
# ~1,068 sq units of horizontal surface in the whole north band
# (scattered furniture tops) vs ~16,753 in the south band (a real
# floor) and ~11,267 in the lane band. The GLB holds all 145 meshes
# the original .ARC has, so the floor was never in the source data
# — the ball-return consoles, score-TV poles, snack table and
# seating were authored standing on legs over an open pit, and the
# original game's high camera never showed it. From the low chase
# cam the furniture reads as hanging from the ceiling (Anthony's
# annotation, 2026-11-16): the sightline to a console base passes
# through the sunken channel's wall (top y=215) so the base is
# occluded and the furniture floats against the sky. Patch it with
# a floor slab at the south floor's level (top y=215) spanning the
# void band, so the furniture stands ON a visible floor. Visual +
# collision together; the car can never reach it (29 units above
# the lane, no ramp), and the furniture legs sink into it exactly
# the way legs meet a floor.
func _build_north_floor_patch() -> void:
	if zone_name != "Bowling Alley":
		return
	var body := StaticBody3D.new()
	body.name = "NorthFloorPatch"
	body.position = Vector3(62.5, 214.0, -23)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(575, 2, 174)
	mesh.mesh = box
	mesh.material_override = _mat(Color(0.15, 0.17, 0.26))
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(575, 2, 174)
	col.shape = shape
	body.add_child(col)
	add_child(body)
	print("[Zone] Bowling Alley: north floor patch added (x -225..350, z -110..64, top y=215)")

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m

func _add_wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(Color(0.1, 0.15, 0.4))
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)

func _build_walls() -> void:
	# Invisible border walls around the room's plan bounds, tall
	# enough that the car can't jump over them.
	var cx := (wall_min.x + wall_max.x) * 0.5
	var cz := (wall_min.y + wall_max.y) * 0.5
	var wx := wall_max.x - wall_min.x
	var wz := wall_max.y - wall_min.y
	var mid_y := floor_y + 100.0
	_add_wall(Vector3(cx, mid_y, wall_min.y), Vector3(wx, 200, 2))
	_add_wall(Vector3(cx, mid_y, wall_max.y), Vector3(wx, 200, 2))
	_add_wall(Vector3(wall_min.x, mid_y, cz), Vector3(2, 200, wz))
	_add_wall(Vector3(wall_max.x, mid_y, cz), Vector3(2, 200, wz))

# ------------------------------------------------------------------ HUD

func _build_hud(car_data: Dictionary) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var name_label := Label.new()
	name_label.text = "%s — %s" % [zone_name, car_data["name"]]
	name_label.position = Vector2(16, 12)
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	name_label.add_theme_constant_override("shadow_offset_x", 2)
	name_label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(name_label)
	_name_label = name_label
	_speed_label = Label.new()
	_speed_label.text = "SPEED 0"
	_speed_label.position = Vector2(16, 52)
	_speed_label.add_theme_font_size_override("font_size", 24)
	_speed_label.add_theme_color_override("font_color", Color.WHITE)
	_speed_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	_speed_label.add_theme_constant_override("shadow_offset_x", 2)
	_speed_label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(_speed_label)
	_boost_label = Label.new()
	_boost_label.text = "BOOST!"
	_boost_label.position = Vector2(16, 88)
	_boost_label.add_theme_font_size_override("font_size", 28)
	_boost_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.0))
	_boost_label.visible = false
	layer.add_child(_boost_label)
	var hint := Label.new()
	hint.text = "W/S gas & brake  |  A/D or left stick steer  |  Right stick camera  |  Space handbrake  |  Esc / Back: pause"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -40
	hint.offset_bottom = -8
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	hint.add_theme_constant_override("shadow_offset_x", 1)
	hint.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(hint)
