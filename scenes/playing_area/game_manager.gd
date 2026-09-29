extends Node3D
class_name GameManager

@export var policy_labels: Array[String] = []
@export var robot_scene: PackedScene
@export var block_scene:PackedScene
@export var number_of_robots_to_spawn: int = 1
@export var number_of_green_blocks_to_spawn: int = 60
@export var number_of_red_blocks_to_spawn: int = 200
@export var min_green_blocks: int = 50  # 绿色方块最少数量
@export var min_red_blocks: int = 200  # 红色方块最少数量
@export var block_check_interval: float = 5.0  # 检查间隔（秒）

var _robots: Array[Robot]
var _block_check_timer: Timer
#var block_scene: PackedScene = preload("res://scenes/block/block.tscn")


func _ready():
	spawn_robots()
	spawn_blocks()
	_setup_block_check_timer()


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
		if i < policy_labels.size():
			robot.ai_controller.policy_name = policy_labels[i]


func _setup_block_check_timer():
	_block_check_timer = Timer.new()
	_block_check_timer.wait_time = block_check_interval
	_block_check_timer.autostart = true
	_block_check_timer.timeout.connect(_on_block_check_timer_timeout)
	add_child(_block_check_timer)


func _on_block_check_timer_timeout():
	# 检查并补充绿色方块
	var green_block_count = _count_blocks(Block.BlockType.GREEN)
	if green_block_count < min_green_blocks:
		var blocks_to_spawn = min_green_blocks - green_block_count
		_spawn_blocks(Block.BlockType.GREEN, blocks_to_spawn)
		print("补充了 %d 个绿色方块，当前总数: %d" % [blocks_to_spawn, min_green_blocks])
	
	# 检查并补充红色方块
	var red_block_count = _count_blocks(Block.BlockType.RED)
	if red_block_count < min_red_blocks:
		var blocks_to_spawn = min_red_blocks - red_block_count
		_spawn_blocks(Block.BlockType.RED, blocks_to_spawn)
		print("补充了 %d 个红色方块，当前总数: %d" % [blocks_to_spawn, min_red_blocks])


func _count_blocks(block_type: Block.BlockType) -> int:
	var count = 0
	for child in get_children():
		if child is Block and child.block_type == block_type:
			count += 1
	return count


func _spawn_blocks(block_type: Block.BlockType, amount: int):
	for i in amount:
		var block = block_scene.instantiate()
		block.set_block_type(block_type)
		add_child(block)
