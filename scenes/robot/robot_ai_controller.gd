extends AIController3D
class_name RobotAIController

const RGB_SENSOR_SCENE = preload("res://addons/godot_rl_agents/sensors/sensors_3d/RGBCameraSensor3D.tscn")

@export var playing_area_size: float = 30

## Reference set by game manager
var game_manager: GameManager

var right_eye_sensor: RGBCameraSensor3D
var left_eye_sensor: RGBCameraSensor3D

func init(player: Node3D):
	super.init(player)
	_setup_sensors()

func _setup_sensors():
	var eye_width = 320
	var eye_height = 300
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--eye_width="):
			eye_width = int(arg.get_slice("=", 1))
		if arg.begins_with("--eye_height="):
			eye_height = int(arg.get_slice("=", 1))
	assert(eye_width >= 36 and eye_height >= 36)
	var eye_resolution = Vector2(eye_width, eye_height)
	# Right Eye
	var right_cam = _player.get_node_or_null("RightEye")
	if right_cam:
		right_eye_sensor = RGB_SENSOR_SCENE.instantiate()
		right_eye_sensor.name = "RightEyeSensor"
		right_eye_sensor.render_image_resolution = eye_resolution
		right_eye_sensor.displayed_image_scale_factor = Vector2(0.5, 0.5)  # 调小预览显示
		_player.add_child(right_eye_sensor)
		right_eye_sensor.transform = right_cam.transform
		
	# Left Eye
	var left_cam = _player.get_node_or_null("LeftEye")
	if left_cam:
		left_eye_sensor = RGB_SENSOR_SCENE.instantiate()
		left_eye_sensor.name = "LeftEyeSensor"
		left_eye_sensor.render_image_resolution = eye_resolution
		left_eye_sensor.displayed_image_scale_factor = Vector2(0.5, 0.5)  # 调小预览显示
		_player.add_child(left_eye_sensor)
		left_eye_sensor.transform = left_cam.transform

func reset():
	n_steps = 0
	needs_reset = false
	if _player.hp <= 0:
		_player.reset()


func get_obs() -> Dictionary:
	var obs = {}
	if right_eye_sensor:
		obs["right_eye"] = right_eye_sensor.get_camera_pixel_encoding()
	if left_eye_sensor:
		obs["left_eye"] = left_eye_sensor.get_camera_pixel_encoding()
	
	# Return current hp
	if _player:
		obs["hp"] = [_player.hp]
	else:
		obs["hp"] = [0.0]
		
	obs["block_counts"] = [_player.green_blocks_collected, _player.red_blocks_collected]
	return obs

func _shape_to_int(shape: Array) -> Array:
	var int_shape: Array[int] = []
	for v in shape:
		int_shape.append(int(v))
	return int_shape

func get_obs_space() -> Dictionary:
	var spaces = {}
	if right_eye_sensor:
		spaces["right_eye"] = {"size": _shape_to_int(right_eye_sensor.get_camera_shape()), "space": "box"}
	if left_eye_sensor:
		spaces["left_eye"] = {"size": _shape_to_int(left_eye_sensor.get_camera_shape()), "space": "box"}
		
	spaces["hp"] = {"size": [1], "space": "box"}
	spaces["block_counts"] = {"size": [2], "space": "box"}
	return spaces

## Overriden method to exclude reset on timeout
func _physics_process(_delta):
	n_steps += 1
	#if n_steps > reset_after:
	#needs_reset = true


func get_reward() -> float:
	return reward


func get_action_space() -> Dictionary:
	return {
		"accelerate_forward": {"size": 3, "action_type": "discrete"},
		"accelerate_sideways": {"size": 3, "action_type": "discrete"},
		"turn": {"size": 3, "action_type": "discrete"},
		"shoot": {"size": 2, "action_type": "discrete"},
	}


func set_action(action: Dictionary) -> void:
	# Actions are recorded by the trainer; avoid per-agent per-frame console spam.
	_player.requested_acceleration_forward = action.accelerate_forward - 1
	_player.requested_acceleration_sideways = action.accelerate_sideways - 1
	_player.requested_turn = action.turn - 1
	_player.shoot_ball_requested = bool(action.shoot)


func get_obs_fast(include_rgb: bool = true) -> Dictionary:
	var obs = {"hp": [_player.hp], "block_counts": [_player.green_blocks_collected, _player.red_blocks_collected]}
	if include_rgb:
		obs["right_eye"] = right_eye_sensor.get_camera_bytes()
		obs["left_eye"] = left_eye_sensor.get_camera_bytes()
	return obs


func restart_competition_body() -> bool:
	_player.reset()
	n_steps = 0
	needs_reset = false
	done = false
	reward = 0.0
	return true
