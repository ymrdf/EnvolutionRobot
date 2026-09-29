extends Node3D

func _enter_tree():
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--env_seed="):
			seed(int(arg.get_slice("=", 1)))
