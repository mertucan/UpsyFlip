extends "res://tests/test_case.gd"
## Integration smoke test: runs the real game scene and plays the first jump,
## exercising HUD, effects, audio and scoring code paths together.

const SETTLE_TIMEOUT: float = 4.0


func test_first_jump_sticks_and_scores() -> void:
	var save: Node = tree.root.get_node("SaveService")
	var original_path: String = save.get("save_path")
	save.set("save_path", "user://test_scene_save.json")
	save.call("load_from_disk")
	tree.root.get_node("Economy").call("reload")
	tree.root.get_node("PlayerProgress").call("reload")

	var game: Node = (load("res://core/game.tscn") as PackedScene).instantiate()
	tree.root.add_child(game)
	await tree.process_frame
	assert_eq(game.get("_flow"), 0, "game opens on the main menu")
	game.call("_start_play")
	var sim: FlightSim = game.get("_sim")
	assert_eq(sim.state, FlightSim.State.STUCK, "run starts stuck in the floor")
	assert_true(sim.launch(1), "first launch is accepted")

	var waited: float = 0.0
	while sim.state != FlightSim.State.STUCK and sim.state != FlightSim.State.DEAD and waited < SETTLE_TIMEOUT:
		await tree.process_frame
		waited += tree.root.get_process_delta_time()
	assert_eq(sim.state, FlightSim.State.STUCK, "first jump lands on the first platform")
	var score: ScoreKeeper = game.get("_score")
	assert_true(score.total() >= 1, "landing scores height")

	# Fall off the world and make sure death and restart work.
	sim.surfaces.clear()
	sim.launch(1)
	waited = 0.0
	while sim.state != FlightSim.State.DEAD and waited < SETTLE_TIMEOUT * 2.0:
		await tree.process_frame
		waited += tree.root.get_process_delta_time()
	assert_eq(sim.state, FlightSim.State.DEAD, "falling below the screen ends the run")
	assert_eq(game.get("_flow"), 2, "death shows the results screen")

	# A rewarded-ad continue puts the object back and resumes the same run.
	game.call("_on_rewarded_completed", &"continue")
	assert_eq(game.get("_flow"), 1, "continue resumes play")
	assert_eq((game.get("_sim") as FlightSim).state, FlightSim.State.STUCK, "object is stuck again after continuing")
	assert_true(game.get("_continue_used"), "continue can only be used once per run")

	game.call("_reset_run")
	await tree.process_frame
	assert_eq((game.get("_sim") as FlightSim).state, FlightSim.State.STUCK, "restart gives a fresh run")

	game.queue_free()
	await tree.process_frame
	for suffix: String in ["", ".bak"]:
		var path: String = ProjectSettings.globalize_path("user://test_scene_save.json" + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	save.set("save_path", original_path)
	save.call("load_from_disk")
	tree.root.get_node("Economy").call("reload")
	tree.root.get_node("PlayerProgress").call("reload")
