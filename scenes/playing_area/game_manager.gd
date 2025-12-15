extends Node3D
class_name GameManager

@export var robot_scene: PackedScene
@export var block_scene:PackedScene
@export var number_of_robots_to_spawn: int = 1
@export var number_of_green_blocks_to_spawn: int = 100
@export var number_of_red_blocks_to_spawn: int = 50

var _robots: Array[Robot]
#var block_scene: PackedScene = preload("res://scenes/block/block.tscn")


func _ready():
	spawn_robots()
	spawn_blocks()


func spawn_blocks():
	# 先生成100个绿色block
	for i in number_of_green_blocks_to_spawn:
		var block = block_scene.instantiate()
		block.set_block_type(Block.BlockType.GREEN)
		add_child(block)
	
	# 再生成50个红色block
	for i in number_of_red_blocks_to_spawn:
		var block = block_scene.instantiate()
		block.set_block_type(Block.BlockType.RED)
		add_child(block)


func spawn_robots():
	for i in number_of_robots_to_spawn:
		var robot = robot_scene.instantiate()

		add_child(robot)
		robot.set_color(Color.from_hsv(i / float(number_of_robots_to_spawn), 0.9, 0.8))
		_robots.append(robot)
		robot.ai_controller.game_manager = self
