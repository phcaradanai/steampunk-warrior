extends RefCounted

func run(t) -> bool:
	if not FileAccess.file_exists("res://core/game_session.gd"):
		t.check(false,"GameSession must commit rewards exactly once")
		return true
	var catalog = load("res://core/content_catalog.gd").new()
	catalog.load_all("res://data")
	var session = load("res://core/game_session.gd").new(catalog.data)
	session.new_game("C01")
	var before: Dictionary = session.snapshot()
	var result: Dictionary = session.commit_result("battle_won",{"id":"battle:1","encounter_id":"E01"})
	t.check(result.ok and result.state.player.currency == 115 and result.state.first_clears.has("E01"),"first victory commits40gold and progression together")
	t.check(result.state.player.energy == 92 and result.state.player.level == 3 and result.state.player.xp == 4,"victory grants XP100 once and energy cost8")
	var won: Dictionary = session.snapshot()
	result = session.commit_result("battle_won",{"id":"battle:1","encounter_id":"E01"})
	t.check(not result.ok and session.snapshot() == won,"same battle event cannot grant a second reward")
	result = session.commit_result("battle_won",{"id":"battle:2","encounter_id":"E01"})
	t.check(result.ok and result.state.player.xp == 29,"new repeat victory grants25percent XP without replaying first clear")
	var detached: Dictionary = session.snapshot()
	detached.player.currency = 99999
	t.check(session.snapshot().player.currency == 155,"snapshot cannot mutate live canonical state")
	won = session.snapshot()
	result = session.commit_result("battle_won",{"id":"bad","encounter_id":"missing"})
	t.check(not result.ok and session.snapshot() == won,"unknown encounter cannot partially grant rewards")
	session.state.room_id = "R01"
	session.state.player.currency = 0
	session.state.player.energy = 0
	session.state.player.current_hp = 1
	result = session.commit_result("rest",{"id":"rest1"})
	t.check(result.ok and result.state.player.energy == 100 and result.state.player.current_hp > 1 and result.state.player.currency == 0,"free hubrest recovers even at zero money and energy")
	t.check(before.first_clears.is_empty(),"new game does not preclear content")
	var encounters: Array = catalog.data.encounters
	var seen_pairs := {}
	var boss_drops := {}
	var normal_drops := {}
	var drops_ok := true
	var starters_ok := true
	for enc in encounters:
		var pair: Array = enc.drops.duplicate()
		pair.sort()
		seen_pairs[",".join(pair)] = seen_pairs.get(",".join(pair), 0) + 1
		for drop in enc.drops:
			drops_ok = drops_ok and not catalog.get_entry("items", drop).is_empty()
			starters_ok = starters_ok and drop not in ["W01","D01","H01","A01"]
			(boss_drops if not enc.boss_id.is_empty() else normal_drops)[drop] = true
	t.check(drops_ok,"every drop id exists in items")
	t.check(starters_ok,"starter gear is never a drop")
	t.check(seen_pairs.size() == encounters.size(),"no two encounters share an identical drop pair")
	t.check(boss_drops.keys().all(func(d): return not normal_drops.has(d)),"boss drops never appear in normal encounters")
	return true
