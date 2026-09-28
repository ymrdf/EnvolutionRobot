extends Node3D

# Seed before child managers create robots. This scene contains no HP blocks.
func _enter_tree():
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--env_seed="):
			seed(int(arg.get_slice("=", 1)))

func _ready():
	var area = $PlayingArea
	assert(area.number_of_green_blocks_to_spawn == 0)
	assert(area.number_of_red_blocks_to_spawn == 0)
	assert(area.min_green_blocks == 0 and area.min_red_blocks == 0)
	for child in area.get_children():
		assert(not child is Block)
	print("ENERGY_SCENE: zero blocks; replenishment disabled; original HP costs")
