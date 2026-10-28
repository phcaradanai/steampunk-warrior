extends RefCounted

func actor(id: String, side: String, initiative: int = 30) -> Dictionary:
	return {"id":id,"side":side,"hp":100,"max_hp":100,"fp":100,"max_fp":100,"attack":100,"tech":100,"armor":0,"resist":0,"initiative":initiative,"barrier":0,"pressure":0,"statuses":{},"cooldowns":{},"potions":{"life":5,"focus":5}}

func fixture() -> Dictionary:
	return {"actors":[actor("hero","player"),actor("enemy","enemy",10)],"round":1,"acted_ids":[],"action_ids":[],"drone":{}}

func command(id: String = "a1", kind: String = "attack") -> Dictionary:
	return {"commit_id":id,"actor_id":"hero","kind":kind,"target_id":"enemy"}

func run(t) -> bool:
	if not FileAccess.file_exists("res://combat/combat_resolver.gd"):
		t.check(false,"CombatResolver must resolve original state safely")
		return true
	var resolver = load("res://combat/combat_resolver.gd").new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var state := fixture()
	state.actors[1].barrier = 1
	var before: Dictionary = state.duplicate(true)
	var result: Dictionary = resolver.apply_action(state,command(),rng)
	t.check(result.ok and result.state.actors[1].barrier == 0 and result.state.actors[1].hp == 100,"breaking shield does not spill to body")
	t.check(state == before,"resolver does not mutate caller state")
	var duplicate: Dictionary = resolver.apply_action(result.state,command(),rng)
	t.check(not duplicate.ok and duplicate.state == result.state,"duplicate commit cannot apply twice")
	var catalog = load("res://core/content_catalog.gd").new()
	catalog.load_all("res://data")
	state = fixture()
	state.actors[1].barrier = 1
	var action := command()
	action.kind = "skill"
	action.skill = catalog.get_entry("skills","S02")
	action.rank = 1
	result = resolver.apply_action(state,action,rng)
	t.check(result.ok and result.state.actors[1].hp < 100,"second hit reaches body after first hit breaks shield")
	t.check(result.state.actors[0].fp == 92 and result.state.actors[0].pressure == 12,"multihit commits cost once")
	state = fixture()
	state.actors[0].pressure = 99
	action.skill = catalog.get_entry("skills","S01")
	result = resolver.apply_action(state,action,rng)
	t.check(not result.ok and result.state == state,"pressure overflow rejects without resource loss")
	state.actors[0].pressure = 100
	result = resolver.apply_action(state,command("vent","vent"),rng)
	t.check(result.ok and result.state.actors[0].pressure == 65,"vent remains usable at pressure100")
	state = fixture()
	state.actors[0].pressure = 4
	result = resolver.apply_action(state,command("vent","vent"),rng)
	t.check(result.state.actors[0].pressure == 0,"vent clamps at zero")
	state = fixture()
	state.actors[1].hp = 0
	result = resolver.apply_action(state,action,rng)
	t.check(not result.ok and result.state == state,"dead target rejects before FP cost")
	state = fixture()
	state.actors[0].fp = 0
	result = resolver.apply_action(state,action,rng)
	t.check(not result.ok and result.state == state,"insufficient FP does not mutate state")
	state = fixture()
	state.actors[1].armor = 100
	result = resolver.apply_action(state,command(),rng)
	var damage: int = 100 - int(result.state.actors[1].hp)
	t.check(damage >= 47 and damage <= 52,"armor100 reduces physical damage by half before variance")
	state = fixture()
	state.actors[0].tech = 20
	state.actors[1].statuses = {"Heated":{"turns":2}}
	action.skill = catalog.get_entry("skills","S20")
	result = resolver.apply_action(state,action,rng)
	t.check(result.ok and result.state.actors[1].statuses.has("Wet") and not result.state.actors[1].statuses.has("Heated"),"Wet replaces Heated")
	state = fixture()
	state.actors[1].hp = 500
	state.actors[1].max_hp = 500
	state.actors[1].statuses = {"Wet":{"turns":2}}
	action.skill = catalog.get_entry("skills","S04")
	result = resolver.apply_action(state,action,rng)
	damage = 500 - int(result.state.actors[1].hp)
	t.check(damage >= 148 and damage <= 164,"Wet multiplies electric damage by1.25")
	state = fixture()
	state.actors[0].statuses = {"Sealed":{"turns":2}}
	state.actors[0].hp = 10
	action.skill = catalog.get_entry("skills","S09")
	result = resolver.apply_action(state,action,rng)
	t.check(result.ok and result.state.actors[0].hp == 10,"Sealed blocks healing")
	state = fixture()
	action.skill = catalog.get_entry("skills","S10")
	result = resolver.apply_action(state,action,rng)
	t.check(result.state.actors[0].statuses.Haste.turns == 2,"new self buff does not tick during its casting action")
	var actors: Array[Dictionary] = [actor("b","enemy",20),actor("a","player",20),actor("c","enemy",35)]
	actors[2].statuses = {"Staggered":{"turns":1}}
	var none_acted: Array[String] = []
	var hero_acted: Array[String] = ["a"]
	t.check(resolver.get_turn_order(actors,none_acted) == ["a","b","c"],"initiative updates unacted actors with deterministic tie order")
	t.check(resolver.get_turn_order(actors,hero_acted) == ["b","c"],"haste cannot grant a second action in one round")
	state = fixture()
	action.skill = catalog.get_entry("skills","S12")
	result = resolver.apply_action(state,action,rng)
	t.check(result.ok and result.state.actors.size() == 2 and not result.state.drone.is_empty(),"drone is owner linked effect not another initiative actor")
	state = fixture()
	state.actors[1].boss = true
	state.actors[1].phase = 0
	state.actors[1].phase_thresholds = [0.75,0.4]
	state.actors[1].hp = 45
	state.actors[0].attack = 1
	state.actors[1].intent = {"kind":"attack","power":1.0,"label":"locked attack"}
	result = resolver.apply_action(state,command(),rng)
	t.check(result.state.actors[1].phase == 0 and result.state.actors[1].intent.label == "locked attack","boss advertised intent survives threshold crossing until its action resolves")
	var boss_action := {"commit_id":"b1","actor_id":"enemy","kind":"attack","target_id":"hero"}
	result = resolver.apply_action(result.state,boss_action,rng)
	t.check(result.ok and result.state.actors[1].phase == 1,"boss phase updates after advertised action")
	state = fixture()
	rng.seed = 883
	var first: Dictionary = resolver.apply_action(state,command(),rng)
	rng.seed = 883
	var second: Dictionary = resolver.apply_action(state,command(),rng)
	t.check(first == second,"same seed and actions replay identical combat state/events")


	state = fixture()
	state.actors[0].pressure = 92
	action.skill = catalog.get_entry("skills","S01")
	result = resolver.apply_action(state,action,rng)
	t.check(result.ok and result.state.actors[0].pressure == 100,"pressure exactly100 is permitted")
	state = fixture()
	state.actors[0].class_id = "C03"
	action.skill = catalog.get_entry("skills","S01")
	result = resolver.apply_action(state,action,rng)
	t.check(result.state.actors[0].fp == 96,"engineer reduces positive FP costs by one")
	state = fixture()
	state.actors[0].hp = 1
	state.actors[0].max_hp = 500
	action.skill = catalog.get_entry("skills","S09")
	action.rank = 10
	result = resolver.apply_action(state,action,rng)
	t.check(result.state.actors[0].hp == 202,"rank10 heal uses1.54 scale without multiplying duration")
	action.rank = 1
	for definition in catalog.data.skills:
		if definition.kind != "active":
			continue
		state = fixture()
		state.actors[1].hp = 2000
		state.actors[1].max_hp = 2000
		action.skill = definition
		result = resolver.apply_action(state,action,rng)
		t.check(result.ok and result.state.actors[0].fp == 100 - int(definition.fp_cost),"active skill cost/effect resolves: " + definition.id)
	state = fixture()
	state.actors[0].tech = 10
	state.actors[1].hp = 2000
	state.actors[1].max_hp = 2000
	action.skill = catalog.get_entry("skills","S12")
	result = resolver.apply_action(state,action,rng)
	for i in range(2):
		var enemy_guard := {"commit_id":"eg"+str(i),"actor_id":"enemy","kind":"guard"}
		result = resolver.apply_action(result.state,enemy_guard,rng)
		result = resolver.apply_action(result.state,command("hv"+str(i),"vent"),rng)
	t.check(result.ok and result.state.drone.is_empty(),"drone expires after exactly three owner actions including summon")
	state = fixture()
	action.skill = catalog.get_entry("skills","S22")
	result = resolver.apply_action(state,action,rng)
	result = resolver.apply_action(result.state,{"commit_id":"eg3","actor_id":"enemy","kind":"guard"},rng)
	action.commit_id = "s22again"
	var rejected: Dictionary = resolver.apply_action(result.state,action,rng)
	t.check(not rejected.ok and rejected.state == result.state,"cooldown rejects repeated phase vent without spending resources")


	if not resolver.has_method("skill_preview"):
		t.check(false,"skill tooltip preview must use same cost and rank math as resolver")
		return true
	var preview_actor := actor("preview","player")
	preview_actor.class_id = "C03"
	var preview: Dictionary = resolver.skill_preview(preview_actor,catalog.get_entry("skills","S01"),10)
	t.check(preview.fp_cost == 4 and preview.damage_min == 182 and preview.damage_max == 202,"engineer rank10 preview uses actual cost and base damage range")
	preview_actor.class_id = "C04"
	preview = resolver.skill_preview(preview_actor,catalog.get_entry("skills","S09"),10)
	t.check(preview.heal == 242,"healer preview includes class multiplier and actual rounding")
	preview = resolver.skill_preview(preview_actor,catalog.get_entry("skills","S22"),10)
	t.check(preview.pressure_delta == -40 and preview.barrier == 77 and preview.cooldown == 2,"phasevent preview describes real barrier and cooldown")
	preview_actor.class_id = "C05"
	preview = resolver.skill_preview(preview_actor,catalog.get_entry("skills","S20"),1)
	t.check(preview.duration == 3,"biomechanist preview includes extended Wet duration")

	return true
