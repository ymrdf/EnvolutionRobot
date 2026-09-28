extends "res://scenes/training_scene/energy_scene.gd"

var training_initial_hp: float = 6.0

func _enter_tree():
	super._enter_tree()
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--initial_hp="):
			training_initial_hp = float(arg.get_slice("=", 1))
	assert(training_initial_hp > 0.0)
	get_tree().node_added.connect(_configure_robot)

func _configure_robot(node: Node):
	# Set before Robot._ready() performs its first reset; subsequent resets reuse it.
	if node is Robot:
		node.hp_initial = training_initial_hp
		node.hp = training_initial_hp

func _ready():
	super._ready()
	for robot in $PlayingArea._robots:
		assert(is_equal_approx(robot.hp_initial, training_initial_hp))
		assert(is_equal_approx(robot.hp, training_initial_hp))
	print("ENERGY_DENSITY: initial_hp=", training_initial_hp, "; original HP costs")
