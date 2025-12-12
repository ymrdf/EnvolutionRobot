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
	# Right Eye
	var right_cam = _player.get_node_or_null("RightEye")
	if right_cam:
		right_eye_sensor = RGB_SENSOR_SCENE.instantiate()
		right_eye_sensor.name = "RightEyeSensor"
		right_eye_sensor.render_image_resolution = Vector2(320, 300)
		right_eye_sensor.displayed_image_scale_factor = Vector2(0.5, 0.5)  # 调小预览显示
		_player.add_child(right_eye_sensor)
		right_eye_sensor.transform = right_cam.transform
		
	# Left Eye
	var left_cam = _player.get_node_or_null("LeftEye")
	if left_cam:
		left_eye_sensor = RGB_SENSOR_SCENE.instantiate()
		left_eye_sensor.name = "LeftEyeSensor"
		left_eye_sensor.render_image_resolution = Vector2(320, 300)
		left_eye_sensor.displayed_image_scale_factor = Vector2(0.5, 0.5)  # 调小预览显示
		_player.add_child(left_eye_sensor)
		left_eye_sensor.transform = left_cam.transform

func reset():
	n_steps = 0
	needs_reset = false

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
	_player.requested_acceleration_forward = action.accelerate_forward - 1
	_player.requested_acceleration_sideways = action.accelerate_sideways - 1
	_player.requested_turn = action.turn - 1
	_player.shoot_ball_requested = bool(action.shoot)
