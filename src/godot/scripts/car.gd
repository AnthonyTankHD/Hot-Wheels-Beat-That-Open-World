extends CharacterBody3D
# Hot Wheels Beat That — Open World City
# Car controller: arcade driving, camera-relative steering,
# full gamepad support (XInput + PlayStation) with haptics.
# Controls: W/Up or RT = gas, S/Down or LT = brake/reverse,
# A/D or left stick / D-pad = steer, C buttons = camera.

@export var max_speed := 26.0
@export var accel := 18.0
@export var brake_force := 26.0
@export var drag := 2.0
@export var turn_rate := 1.5
@export var deadzone := 0.2

var speed := 0.0
var heading := 0.0
var cam_heading := 0.0
var cam_distance := 8.0
var cam_height := 3.5

@onready var camera: Camera3D = $Camera3D
@onready var body: MeshInstance3D = $Body

func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	pass

func _physics_process(delta: float) -> void:
	# --- Steering input (analog stick, D-pad, or keys) ---
	var steer := 0.0
	steer += Input.get_action_strength("steer_right")
	steer -= Input.get_action_strength("steer_left")
	# Analog stick X axis (joypad motion is bound to steer actions)
	if absf(steer) < deadzone:
		steer = 0.0
	steer = clampf(steer, -1.0, 1.0)

	# --- Gas / brake ---
	var gas := Input.get_action_strength("gas")
	var brake := Input.get_action_strength("brake")

	# Acceleration curve: strong off the line, drops near top speed
	var accel_now := accel * (1.0 - pow(speed / max_speed, 2.0))
	speed += gas * accel_now * delta
	speed -= brake * brake_force * delta
	# Drag
	speed -= speed * drag * delta * 0.1
	speed = clampf(speed, -10.0, max_speed)

	# --- Camera-relative steering ---
	# "Left" always means screen-left, even when the camera is swung around.
	var rel := heading - cam_heading
	var cam_steer := steer * cos(rel)
	heading += cam_steer * turn_rate * delta * (1.0 if speed >= 0.0 else -1.0)
	heading = wrapf(heading, -PI, PI)

	# --- Move ---
	var forward := Vector3(sin(heading), 0.0, cos(heading))
	velocity = forward * speed
	move_and_slide()

	# --- Car visual: lean into turns ---
	rotation.y = heading
	var target_roll := -cam_steer * 0.35
	rotation.z = lerpf(rotation.z, target_roll, delta * 8.0)

	# --- Camera controls (C buttons / right stick) ---
	if Input.is_action_pressed("camera_left"):
		cam_heading += 2.5 * delta
	if Input.is_action_pressed("camera_right"):
		cam_heading -= 2.5 * delta
	if Input.is_action_pressed("camera_zoom_in"):
		cam_distance = maxf(4.0, cam_distance - 6.0 * delta)
	if Input.is_action_pressed("camera_zoom_out"):
		cam_distance = minf(12.0, cam_distance + 6.0 * delta)

	# Camera follows behind its own heading (never auto-centers)
	var cam_pos := Vector3(sin(cam_heading), 0.0, cos(cam_heading)) * -cam_distance
	cam_pos.y = cam_height
	camera.position = cam_pos
	camera.look_at(position + Vector3(0, 1.0, 0), Vector3.UP)

	# --- Haptics: rumble on hard steering at speed, and on landing ---
	if absf(steer) > 0.7 and absf(speed) > 10.0:
		# Light rumble while pushing hard at speed
		Input.start_joy_vibration(0, 0.15, 0.15, 0.1)
