extends RefCounted

func run(t) -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	var session := GameSession.new(catalog.data)
	session.new_game("C01")
	var policy := WorldController.new(catalog.data,session)
	for destination in ["R02","R03"]:
		policy.enter_room(destination,"entry")
	for index in range(1,7):
		var encounter_id := "E%02d" % index
		var encounter := catalog.get_entry("encounters",encounter_id)
		if session.state.room_id != encounter.room:
			policy.enter_room(encounter.room,"entry")
		var controller := CombatController.new(catalog.data)
		var start := controller.start(encounter_id,session.snapshot(),123)
		t.check(start.ok,"earned progression allows encounter " + encounter_id)
		if not start.ok:
			return true
		for _step in range(400):
			if controller.is_finished():
				break
			if not controller.is_player_turn():
				controller.advance()
				continue
			var hero: Dictionary = controller.state.actors[0]
			var enemy: Dictionary = {}
			for candidate in controller.state.actors:
				if candidate.side == "enemy" and candidate.hp > 0:
					enemy = candidate
					break
			var kind := "attack"
			var skill := ""
			if float(enemy.intent.get("power",0)) >= 1.8:
				kind = "guard"
			elif hero.hp < hero.max_hp * 0.45 and hero.potions.life > 0:
				kind = "life_potion"
			elif hero.pressure > 90:
				kind = "vent"
			elif hero.fp >= 5:
				kind = "skill"
				skill = "S01"
			elif hero.potions.focus > 0:
				kind = "focus_potion"
			var action := controller.submit_player(kind,skill,enemy.id)
			if not action.ok:
				t.check(false,"legal slice action rejected: " + action.reason)
				return true
		t.check(controller.state.get("outcome", "") == "victory","attainable build wins " + encounter_id)
		if controller.state.get("outcome", "") != "victory":
			return true
		var reward := session.commit_result("battle_won",controller.result_payload())
		t.check(reward.ok,"earned reward commits " + encounter_id)
		while session.state.player.attribute_points > 0:
			session.commit_result("allocate_attribute",{"id":"stat:"+str(index)+":"+str(session.state.player.attribute_points),"attribute":"STR"})
		while session.state.player.skill_points > 0 and session.state.player.skill_ranks.S01 < 10:
			session.commit_result("learn_skill",{"id":"skill:"+str(index)+":"+str(session.state.player.skill_points),"skill_id":"S01"})
		# Return over cleared paths; free rest never relies on money or enemy drops.
		if index < 6:
			var original_room: String = session.state.room_id
			if original_room == "R04":
				policy.enter_room("R03","entry")
			policy.enter_room("R02","entry")
			policy.enter_room("R01","entry")
			session.commit_result("rest",{"id":"rest:"+str(index)})
			policy.enter_room("R02","entry")
			policy.enter_room("R03","entry")
			if original_room == "R04":
				policy.enter_room("R04","entry")
	t.check(session.state.first_clears.has("B01") and policy.can_travel("R04","R05",session.state),"first boss opens next chapter with earned stats and no repeats")
	return true
