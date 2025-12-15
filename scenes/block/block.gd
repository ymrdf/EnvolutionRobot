extends Area3D
class_name Block

@export var playing_area_size: float = 30.0

enum BlockType { GREEN, RED }
var block_type: BlockType = BlockType.GREEN

func _ready():
	reset()

func _on_body_entered(body):
	if body is Robot:
		if block_type == BlockType.GREEN:
			body.heal(5)
		else:  # RED block
			body.take_damage(5)
		queue_free()

func set_block_type(type: BlockType):
	block_type = type
	var mesh_instance = $MeshInstance3D
	if mesh_instance:
		var material = mesh_instance.mesh.material as StandardMaterial3D
		if material:
			# 需要复制材质以避免所有block共享同一个材质
			material = material.duplicate()
			mesh_instance.mesh = mesh_instance.mesh.duplicate()
			mesh_instance.mesh.material = material
			if type == BlockType.GREEN:
				material.albedo_color = Color(0, 1, 0, 1)  # 绿色
			else:
				material.albedo_color = Color(1, 0, 0, 1)  # 红色

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
