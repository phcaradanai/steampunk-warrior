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
	return true
