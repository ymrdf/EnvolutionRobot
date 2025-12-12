extends Area3D
class_name Block

@export var playing_area_size: float = 30.0

func _ready():
	reset()

func _on_body_entered(body):
	if body is Robot:
		body.heal(10)
		queue_free()

func reset():
	position.y = 0.5
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
	var half_size := playing_area_size / 2.0
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
