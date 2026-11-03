extends RefCounted

func run(t) -> bool:
	if not FileAccess.file_exists("res://world/world_controller.gd"):
		t.check(false,"WorldController must enforce gates without trapping return paths")
		return true
	var catalog = load("res://core/content_catalog.gd").new()
	catalog.load_all("res://data")
	var session = load("res://core/game_session.gd").new(catalog.data)
	session.new_game("C01")
	var world = load("res://world/world_controller.gd").new(catalog.data,session)
	t.check(world.can_travel("R01","R02",session.snapshot()),"initial market exit reachable")
	t.check(not world.can_travel("R04","R05",session.snapshot()),"next chapter blocked before boss")
	session.state.first_clears.B01 = true
	t.check(world.can_travel("R04","R05",session.snapshot()),"boss key opens next chapter")
	session.state.room_id = "R03"
	session.state.player.energy = 0
	t.check(not world.can_start_encounter("E01",session.snapshot()).ok,"energy zero blocks new encounter")
	t.check(world.can_travel("R03","R02",session.snapshot()) and world.can_travel("R02","R01",session.snapshot()),"zero resources still allow free return to rest")
	session.state.player.energy = 100
	t.check(world.can_start_encounter("E01",session.snapshot()).ok,"first encounter allowed in correct room")
	t.check(not world.can_start_encounter("E02",session.snapshot()).ok,"encounter sequence cannot skip uncleared requirement")
	session.state.first_clears.E01 = true
	t.check(world.can_start_encounter("E01",session.snapshot()).ok,"cleared normal encounter only replays by explicit start request")
	session.state.room_id = "R04"
	session.state.first_clears.E05 = true
	session.state.first_clears.E06 = true
	t.check(not world.can_start_encounter("E06",session.snapshot()).ok,"cleared boss cannot replay before postgame")
	session.state.world_flags.postgame = true
	t.check(world.can_start_encounter("E06",session.snapshot()).ok,"boss replay becomes available in postgame")
	session.state.room_id = "R05"
	session.state.world_flags["visited:R05"] = true
	t.check(world.can_travel("R05","R01",session.snapshot()),"unlocked station fast travel returns home free")
	world.enter_room("R01","entry")
	t.check(session.snapshot().room_id == "R01" and session.snapshot().checkpoint.room_id == "R01","travel updates canonical room and checkpoint together")
	_pipes(t,catalog)
	return true

func _pipes(t, catalog) -> void:
	var session = load("res://core/game_session.gd").new(catalog.data)
	session.new_game("C01")
	var world = load("res://world/world_controller.gd").new(catalog.data,session)
	var drain: Dictionary = world.pipe("P01")
	var rail: Dictionary = world.pipe("P02")
	t.check(drain.room == "R01" and rail.room == "R01","both pipe lines start from the hub")
	t.check(world.pipe_next(drain,session.snapshot()) == "E01" and world.can_start_encounter("E01",session.snapshot(),"P01").ok,"drain pipe leads to its first fight from the hub")
	t.check(not world.can_start_encounter("E02",session.snapshot(),"P01").ok,"pipe cannot skip to a later fight")
	t.check(not world.can_start_encounter("E07",session.snapshot(),"P02").ok,"second line stays closed until its gate fight")
	for id in ["E01","E02","E03","E04","E05"]: session.state.first_clears[id] = true
	t.check(world.can_start_encounter("E07",session.snapshot(),"P02").ok,"second line opens before the first boss is beaten")
	t.check(world.pipe_next(drain,session.snapshot()) == "E06","stuck line keeps its boss as next fight")
	session.state.first_clears.E07 = true
	t.check(world.pipe_next(drain,session.snapshot()) == "E06" and world.pipe_next(rail,session.snapshot()) == "E08","each line keeps its own progress when switching")
	session.state.first_clears.E06 = true
	t.check(world.pipe_next(drain,session.snapshot()) == "E05","cleared line farms its last normal fight")
	session.state.room_id = "R02"
	t.check(not world.can_start_encounter("E08",session.snapshot(),"P02").ok,"pipe launch requires standing in the hub")
	var won: Dictionary = session.commit_result("battle_won",{"id":"pipe:drop","encounter_id":"E08"})
	var event: Dictionary = won.events.filter(func(e): return e.type == "battle_won")[0]
	t.check(event.payload.drop in catalog.get_entry("encounters","E08").drops,"victory reports one of the encounter's drop candidates")
	var replay: Dictionary = session.commit_result("battle_won",{"id":"pipe:replay","encounter_id":"E08"})
	t.check(replay.events.filter(func(e): return e.type == "battle_won")[0].payload.drop == "","replayed stage drops nothing, like the reference's one-way gateway")
	_pipe_round_trip(t,catalog)

# Acceptance: stuck on one line, farm the other from the hub, and both lines survive save/load and defeat.
func _pipe_round_trip(t, catalog) -> void:
	var session = load("res://core/game_session.gd").new(catalog.data)
	session.new_game("C01")
	for id in ["E01","E02","E03","E04","E05"]: session.state.first_clears[id] = true
	var combat := CombatController.new(catalog.data)
	t.check(combat.start("E07",session.snapshot(),5,"P02").ok and combat.pipe_id == "P02","combat starts through the rail pipe from the hub")
	t.check(session.commit_result("battle_won",combat.result_payload()).ok,"pipe victory settles from the hub")
	var saves := SaveService.new(catalog.data,"user://test-pipe-"+str(Time.get_ticks_usec()))
	t.check(saves.save_slot("manual01",session.snapshot()).ok,"pipe progress saves")
	var loaded: Dictionary = saves.load_slot("manual01").get("state",{})
	var world := WorldController.new(catalog.data)
	t.check(world.pipe_next(world.pipe("P01"),loaded) == "E06" and world.pipe_next(world.pipe("P02"),loaded) == "E08","both lines keep their own progress after save and load")
	combat = CombatController.new(catalog.data)
	combat.start("E06",session.snapshot(),5,"P01")
	t.check(session.commit_result("battle_lost",combat.result_payload()).ok,"pipe defeat settles")
	t.check(session.state.room_id == "R01" and world.pipe_next(world.pipe("P01"),session.state) == "E06" and world.pipe_next(world.pipe("P02"),session.state) == "E08","defeat returns to the hub with both lines intact")
	for filename in DirAccess.get_files_at(saves.directory): DirAccess.remove_absolute(saves.directory.path_join(filename))
