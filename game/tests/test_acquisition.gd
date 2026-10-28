extends RefCounted

func run(t) -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	for item in catalog.data.items:
		var s := GameSession.new(catalog.data)
		s.new_game("C01")
		# Acquisition contract fixture, separate from the earned full-campaign test.
		s.state.player = s.progression.gain_xp(s.state.player,1000000).state
		s.state.player.currency = 10000
		var result: Dictionary = {}
		var source: String = item.source
		if source.begins_with("shop:"):
			s.state.room_id = source.trim_prefix("shop:")
			result = s.commit_result("inventory",{"id":item.id,"request":{"kind":"buy","item_id":item.id}})
		elif source.begins_with("boss:"):
			for encounter in catalog.data.encounters:
				if encounter.boss_id == source.trim_prefix("boss:"):
					result = s.commit_result("battle_won",{"id":item.id,"encounter_id":encounter.id})
		else:
			var quest: String = source.trim_prefix("quest:")
			s.state.quest_states[quest].state = "objectives_complete"
			result = s.commit_result("dialogue_choice",{"id":item.id,"node_id":"D"+quest.substr(1),"choice_id":"help"})
		t.check(result.get("ok",false) and item.id in s.state.player.items,"actual acquisition transaction: "+item.id)
		var equipped := s.commit_result("inventory",{"id":"equip:"+item.id,"request":{"kind":"equip","index":s.state.player.items.find(item.id)}})
		t.check(equipped.ok and s.state.player.equipment[item.slot] == item.id,"obtainable gear is usable: "+item.id)
		t.check(not UIBuilder.item_description(item).is_empty() and UIBuilder.item_icon(item) != null,"gear has visible stats and icon: "+item.id)
	for tier in ["T02","T03","T04"]:
		var s := GameSession.new(catalog.data)
		s.new_game("C01")
		for id in ["B01","B02","B04"]: s.state.first_clears[id] = true
		var c := CombatController.new(catalog.data)
		c.start_training(tier,s.snapshot(),8)
		var commands: Array = {"T02":["S01","S01","S03","attack","S09"],"T03":["S20","S04","S21","S22"],"T04":["S22","attack","guard","S12"]}[tier]
		for command in commands:
			for _step in range(10):
				if c.is_player_turn(): break
				c.advance()
			var result := c.submit_player(command if command in ["attack","guard"] else "skill","" if command in ["attack","guard"] else command,"enemy0")
			t.check(result.ok,"training loan action legal: "+tier+" "+command)
		for objective in TrainingService.OBJECTIVES[tier]: t.check(objective in c.completed,"training objective achieved by real actions: "+tier+" "+objective)
	return true
