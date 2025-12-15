extends RigidBody3D
class_name Robot

@export var ball_scene: PackedScene
@export var launcher: Node3D

@onready var ai_controller: RobotAIController = $AIController3D
@onready var animation_player: AnimationPlayer = $robot/AnimationPlayer

var acceleration: float = 70
var torque_multiplier: float = 7

var requested_acceleration_forward: float
var requested_acceleration_sideways: float

var requested_turn: float
var shoot_ball_requested: float

var shoot_ball_timer_duration := 0.45
var shoot_ball_timer := shoot_ball_timer_duration

var spawn_protection_timer_duration := 2.0
var spawn_protection_timer := spawn_protection_timer_duration

var hp_initial := 6
var hp_max := 100
var hp := hp_initial:
	set(value):
		hp = value
		update_health_bar()

var health_bar: Sprite3D
var health_bar_bg: Sprite3D
const HEALTH_BAR_WIDTH := 1
const HEALTH_BAR_HEIGHT := 0.15

var passive_hp_loss_timer: float = 0.0
var movement_hp_loss_timer: float = 0.0


func _ready():
	ai_controller.init(self)
	setup_health_bar()
	reset()


## Sets the color of the robot
var robot_color: Color


func set_color(color: Color):
	var material := $robot/Robot/Arm.get_active_material(0) as StandardMaterial3D
	material.albedo_color = color
	robot_color = color


## Resets the robot to a new random position
func reset():
	spawn_protection_timer = spawn_protection_timer_duration
	shoot_ball_timer = shoot_ball_timer_duration
	hp = hp_initial
	passive_hp_loss_timer = 0.0
	movement_hp_loss_timer = 0.0

	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	position.y = 0.4
	var random_free_position: Vector2 = get_random_free_position()
	global_position.x = random_free_position.x
	global_position.z = random_free_position.y


## Returns shape cast parameters set to a random map position
func get_free_position_check_params() -> PhysicsShapeQueryParameters3D:
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = $CollisionShape3D.shape
	params.transform.basis = $CollisionShape3D.global_basis
	params.transform.origin = get_parent().global_transform.origin
	var margin := 2.0
	var half_size := ai_controller.playing_area_size / 2.0
	params.transform.origin.x += randf_range(-half_size + margin, half_size - margin)
	params.transform.origin.z += randf_range(-half_size + margin, half_size - margin)
	params.transform.origin.y = global_position.y + $CollisionShape3D.position.y
	return params


## Returns a free position on the map for placing the Robot in global coords (x and z)
func get_random_free_position() -> Vector2:
	var params = get_free_position_check_params()
	var state := get_world_3d().direct_space_state
	var results := state.intersect_shape(params)
	while results.size() > 0:
		params = get_free_position_check_params()
		results = state.intersect_shape(params)
	return Vector2(params.transform.origin.x, params.transform.origin.z)


func _physics_process(delta):
	reset_if_needed()

	handle_human_controls()

	# Slows down backward movement
	requested_acceleration_forward = clampf(requested_acceleration_forward, -0.5, 1.0)

	var combined_force = (
		global_basis * Vector3(requested_acceleration_sideways, 0, -requested_acceleration_forward)
	)
	combined_force = combined_force.limit_length(1.0) * acceleration

	var torque: Vector3 = requested_turn * torque_multiplier * Vector3.UP

	apply_central_force(combined_force)
	apply_torque(torque)
	handle_shooting(delta)
	handle_animation(linear_velocity)
	handle_hp_loss(delta)


func handle_human_controls():
	if ai_controller.heuristic == "human":
		requested_acceleration_forward = (
			Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
		)
		requested_acceleration_sideways = (
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		)
		requested_turn = (
			Input.get_action_strength("turn_left") - Input.get_action_strength("turn_right")
		)
		shoot_ball_requested = Input.is_action_pressed("shoot")


func handle_shooting(delta: float):
	shoot_ball_timer -= delta
	spawn_protection_timer -= delta
	if shoot_ball_requested and shoot_ball_timer < 0 and spawn_protection_timer < 0.0:
		spawn_ball()
		shoot_ball_timer = shoot_ball_timer_duration


## Instantiates a ball with forward initial velocity
func spawn_ball():
	var ball_instance = ball_scene.instantiate()
	get_parent().add_child(ball_instance)
	ball_instance = ball_instance as RigidBody3D
	ball_instance.global_transform = launcher.global_transform
	ball_instance.global_position = (launcher.global_position - launcher.global_basis.z)
	ball_instance.linear_velocity = -ball_instance.basis.z * 60
	ball_instance.spawned_by_robot = self
	ball_instance.add_collision_exception_with(self)
	ball_instance.set_color(robot_color)


## Handles the robot animation
func handle_animation(velocity: Vector3):
	if velocity.length() > 0.05:
		animation_player.play("walking", -1, 1.75)
	else:
		animation_player.play("idle")


## Resets the robot if needed
func reset_if_needed():
	if ai_controller.needs_reset:
		reset()
		ai_controller.reset()

	if hp <= 0:
		game_over(0)


## Ends the game episode for the robot, and resets the robot
func game_over(reward: float = 0):
	ai_controller.reward += reward
	ai_controller.needs_reset = true
	ai_controller.done = true


func just_hit_by_ball(_ball: Ball):
	hp -= 1


func just_hit_another_robot():
	ai_controller.reward += 1


func heal(amount: int):
	hp += amount
	if hp > hp_max:
		hp = hp_max


func take_damage(amount: int):
	hp -= amount


func handle_hp_loss(delta: float):
	passive_hp_loss_timer += delta
	if passive_hp_loss_timer >= 60.0:
		hp -= 1
		passive_hp_loss_timer -= 60.0
	
	if linear_velocity.length() > 0.05:
		movement_hp_loss_timer += delta
		if movement_hp_loss_timer >= 30.0:
			hp -= 1
			movement_hp_loss_timer -= 30.0


func setup_health_bar():
	# Create small white texture we can tint
	var image = Image.create(128, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture = ImageTexture.create_from_image(image)
	
	# Background (Red)
	health_bar_bg = Sprite3D.new()
	health_bar_bg.texture = texture
	health_bar_bg.modulate = Color.RED
	health_bar_bg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_bar_bg.pixel_size = 0.01
	health_bar_bg.scale = Vector3(HEALTH_BAR_WIDTH + 0.05, HEALTH_BAR_HEIGHT + 0.02, 1.0)
	health_bar_bg.position = Vector3(0, 1.2, 0)
	health_bar_bg.render_priority = 0
	add_child(health_bar_bg)
	
	# Foreground (Green)
	health_bar = Sprite3D.new()
	health_bar.texture = texture
	health_bar.modulate = Color.GREEN
	health_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_bar.pixel_size = 0.01
	health_bar.scale = Vector3(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT, 1.0)
	health_bar.position = Vector3(0, 1.2, 0)
	health_bar.render_priority = 1
	add_child(health_bar)
	update_health_bar()


func update_health_bar():
	if not health_bar:
		return
	
	var pct = float(hp) / float(hp_initial)
	pct = clamp(pct, 0.0, 1.0)
	health_bar.scale.x = HEALTH_BAR_WIDTH * pct
