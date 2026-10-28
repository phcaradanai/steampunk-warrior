extends RefCounted

func run(t) -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	var s := GameSession.new(catalog.data)
	s.new_game("C01")
	var result := s.commit_result("environment",{"id":"remote-valve","object_id":"furnace_coolant"})
	t.check(not result.ok,"remote valves cannot change an unvisited room")
	s.state.room_id = "R10"
	result = s.commit_result("environment",{"id":"cool","object_id":"furnace_coolant"})
	t.check(result.ok and s.state.world_flags.get("environment:furnace_coolant",false),"local cooling valve persists an actual environment change")
	s.state.first_clears.E26 = true
	var c := CombatController.new(catalog.data)
	c.start("E27",s.snapshot(),17)
	var cooled: int = c._actor("enemy0").tech
	s.state.world_flags.erase("environment:furnace_coolant")
	c.start("E27",s.snapshot(),17)
	t.check(cooled < c._actor("enemy0").tech and c._actor("hero").statuses.has("Heated"),"coolant changes furnace power and removes the starting heat hazard")
	s.state.quest_states.Q04.state = "objectives_complete"
	var d := DialogueService.new(catalog.data)
	t.check(not d.choose("D04","help",s.snapshot()).ok,"rescue route requires solving intake and exhaust valves")
	s.state.room_id = "R07"
	for id in ["specimen_intake","specimen_exhaust"]:
		t.check(s.commit_result("environment",{"id":id,"object_id":id}).ok,"specimen pressure valve works: "+id)
	t.check(d.choose("D04","help",s.snapshot()).ok,"safe valve configuration allows rescue")
	return true
