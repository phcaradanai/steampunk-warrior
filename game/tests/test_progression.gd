extends RefCounted

func run(t) -> bool:
	if not FileAccess.file_exists("res://rpg/progression.gd"):
		t.check(false,"Progression must create and grow a playable character")
		return true
	var catalog = load("res://core/content_catalog.gd").new()
	catalog.load_all("res://data")
	var progression = load("res://rpg/progression.gd").new(catalog.data)
	for id in ["C01","C02","C03","C04","C05"]:
		var p: Dictionary = progression.new_player(id)
		var c: Dictionary = catalog.get_entry("classes",id)
		t.check(p.class_id == id and p.skill_ranks.get(c.starter_skill) == 1,"class starter: " + id)
		t.check(p.base_attributes.VIT + p.base_attributes.STR + p.base_attributes.INT + p.base_attributes.AGI == 30,"equal class attribute budget: " + id)
		t.check(p.current_hp == progression.derive(p,catalog.data).max_hp and p.current_fp == progression.derive(p,catalog.data).max_fp,"class starts with full derived resources: " + id)
	t.check(progression.new_player("missing").is_empty(),"unknown class rejected")
	var player: Dictionary = progression.new_player("C01")
	player.equipment = {}
	var stats: Dictionary = progression.derive(player,catalog.data)
	t.check(stats.max_hp == 92 and stats.attack == 21 and stats.tech == 15 and stats.initiative == 15,"base derived stats follow hand computed class formula")
	player.equipment = {"weapon":"W01","suit":"A01"}
	stats = progression.derive(player,catalog.data)
	t.check(stats.attack == 28 and stats.tech == 16 and stats.max_hp == 104,"gear applies derived modifiers without changing base")
	var before: Dictionary = player.duplicate(true)
	progression.derive(player,catalog.data)
	t.check(player == before,"recomputing does not mutate canonical player")
	player.skill_ranks.S17 = 10
	stats = progression.derive(player,catalog.data)
	t.check(stats.max_hp == 124,"passive max HP uses floor of104x1.20")
	player = progression.new_player("C01")
	var result: Dictionary = progression.gain_xp(player,100)
	t.check(result.ok and result.state.level == 3 and result.state.xp == 4,"XP100 crosses thresholds40and56 and retains4")
	t.check(result.state.skill_points == 2 and result.state.attribute_points == 4 and result.state.base_attributes.VIT == 14,"two level gains award exact points and VIT")
	result = progression.gain_xp(player,-1)
	t.check(not result.ok and result.state == player,"negative XP rejected")
	result = progression.gain_xp(player,10000000)
	t.check(result.state.level == 30 and result.state.skill_points == 29,"huge XP stops at level30 and grants29skillpoints")
	result = progression.allocate_attribute(result.state,"STR")
	t.check(result.ok and result.state.base_attributes.STR == 9 and result.state.attribute_points == 57,"attribute spend changes only selected attribute")
	var rejected: Dictionary = progression.allocate_attribute(result.state,"money")
	t.check(not rejected.ok and rejected.state == result.state,"unknown attribute cannot alter state")
	player = progression.new_player("C01")
	player.skill_points = 10
	result = progression.learn_skill(player,"S07")
	t.check(not result.ok and result.state.skill_points == 10,"level and parent gates reject skill purchase without spending")
	player.level = 30
	player.skill_ranks.S02 = 1
	result = progression.learn_skill(player,"S07")
	t.check(result.ok and result.state.skill_ranks.S07 == 1 and result.state.skill_points == 9,"both parents permit a shared tree skill")
	player = result.state
	player.skill_ranks.S01 = 10
	result = progression.learn_skill(player,"S01")
	t.check(not result.ok and result.state.skill_points == 9,"rank10 rejects overspending")
	player = progression.new_player("C05")
	player.skill_ranks.S20 = 4
	player.skill_ranks.S09 = 2
	player.skill_points = 7
	result = progression.respec(player)
	t.check(result.ok and result.state.skill_ranks == {"S20":1} and result.state.skill_points == 12,"respec refunds five purchased ranks and retains starter1")
	var second: Dictionary = progression.respec(result.state)
	t.check(second.state.skill_points == 12,"repeated respec cannot duplicate points")
	player = progression.new_player("C01")
	result = progression.allocate_attribute(player,"VIT")
	t.check(not result.ok and result.state == player,"no attribute point means no free allocation")

	# Isolate every node's spending/rank policy with an explicit high-level fixture.
	for definition in catalog.data.skills:
		var fixture_class := "C01" if definition.id == "S20" else "C05"
		player = progression.new_player(fixture_class)
		player.level = 30
		player.skill_points = 20
		for parent_definition in catalog.data.skills:
			if parent_definition.id != definition.id:
				player.skill_ranks[parent_definition.id] = 1
		for rank in range(1,11):
			result = progression.learn_skill(player,definition.id)
			t.check(result.ok and result.state.skill_ranks.get(definition.id,0) == rank and result.state.skill_points == 20-rank,"rank purchase " + definition.id + ":" + str(rank))
			player = result.state
		result = progression.learn_skill(player,definition.id)
		t.check(not result.ok and result.state == player,"rank cap preserves points for " + definition.id)

	return true
