extends RefCounted

func run(t) -> bool:
	if not FileAccess.file_exists("res://training/training_service.gd"):
		t.check(false,"TrainingService must preserve per-objective first rewards")
		return true
	var catalog = load("res://core/content_catalog.gd").new()
	catalog.load_all("res://data")
	var session = load("res://core/game_session.gd").new(catalog.data)
	session.new_game("C01")
	var service = load("res://training/training_service.gd").new(catalog.data)
	t.check(service.start("T01",session.snapshot()).ok,"first training is open initially")
	t.check(not service.start("T04",session.snapshot()).ok,"fourth training requires B04")
	session.state.first_clears.B04 = true
	t.check(service.start("T04",session.snapshot()).ok,"fourth training unlocks after B04")
	var first: Dictionary = service.settle("T01",["attack","guard","vent"],session.snapshot())
	t.check(first.ok and first.state.player.level == 2 and first.state.player.xp == 0,"all basic objectives grant firstXP40")
	var repeat: Dictionary = service.settle("T01",["attack","guard","vent"],first.state)
	t.check(repeat.ok and repeat.state.player.xp == 10,"all repeated basic objectives grant XP10")
	var partial: Dictionary = service.settle("T01",["attack","attack"],session.snapshot())
	t.check(partial.ok and partial.state.player.level == 1 and partial.state.player.xp == 14,"duplicate objectives in one attempt do not duplicate partialfirstXP14")
	var rest: Dictionary = service.settle("T01",["guard","vent"],partial.state)
	t.check(rest.state.player.level == 2 and rest.state.player.xp == 0,"remaining first objectives settle totalXP40 across attempts")
	var bad: Dictionary = service.settle("T01",["made_up"],session.snapshot())
	t.check(not bad.ok and bad.state == session.snapshot(),"unknown objective cannot mint trainingXP")
	return true
