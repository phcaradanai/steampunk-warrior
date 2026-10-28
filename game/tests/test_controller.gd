extends RefCounted

func run(t) -> bool:
	if not FileAccess.file_exists("res://combat/combat_controller.gd"):
		t.check(false,"CombatController must run a complete encounter through real resolver")
		return true
	var catalog = load("res://core/content_catalog.gd").new()
	catalog.load_all("res://data")
	var session = load("res://core/game_session.gd").new(catalog.data)
	session.new_game("C01")
	session.state.room_id = "R03"
	var controller = load("res://combat/combat_controller.gd").new(catalog.data)
	var result: Dictionary = controller.start("E01",session.snapshot(),42)
	t.check(result.ok and not controller.is_finished(),"real first encounter initializes")
	result = controller.submit_player("attack","","enemy0")
	t.check(result.ok,"player can issue first attack")
	var after: Dictionary = controller.state.duplicate(true)
	var duplicate: Dictionary = controller.submit_player("attack","","enemy0")
	t.check(not duplicate.ok and controller.state == after,"animation lock rejects click repeats")
	for _step in range(60):
		if controller.is_finished():
			break
		if controller.is_player_turn():
			controller.submit_player("attack","","enemy0")
		else:
			controller.advance()
	t.check(controller.is_finished() and controller.state.outcome == "victory","first encounter completes with real actions and enemy responses")
	result = session.commit_result("battle_won",controller.result_payload())
	t.check(result.ok and result.state.first_clears.has("E01"),"controller victory connects to canonical reward transaction")
	session.state.room_id = "R01"
	result = controller.start_training("T01",session.snapshot(),42)
	t.check(result.ok,"training initializes real controllable battle")
	for kind in ["attack","guard","vent"]:
		for _step in range(10):
			if controller.is_player_turn():
				break
			controller.advance()
		controller.submit_player(kind,"","enemy0")
	var completed: Array = controller.completed.duplicate()
	t.check(completed.has("attack") and completed.has("guard") and completed.has("vent"),"basic training detects actual actions rather than UI reward clicks")

	for _step in range(10):
		if controller.is_player_turn():
			break
		controller.advance()
	controller.end_training()
	result = session.commit_result("training_settle",controller.result_payload())
	t.check(result.ok and result.state.player.xp == 44 and result.state.player.current_hp == 104,"training settles earnedXP without leaking practice HP or loaner FP")
	var settled: Dictionary = session.snapshot()
	result = session.commit_result("training_settle",controller.result_payload())
	t.check(not result.ok and session.snapshot() == settled,"training run cannot settle twice")

	return true
