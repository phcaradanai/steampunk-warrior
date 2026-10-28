extends RefCounted

func battle(catalog: Dictionary, id: String, flags: Dictionary = {}) -> CombatController:
	var session := GameSession.new(catalog)
	session.new_game("C05")
	for encounter in catalog.encounters:
		session.state.first_clears[encounter.id] = true
		session.state.first_clears.erase(id)
		session.state.room_id = encounter.room if encounter.id == id else session.state.room_id
	session.state.world_flags.merge(flags,true)
	var controller := CombatController.new(catalog)
	controller.start(id,session.snapshot(),19)
	return controller

func run(t) -> bool:
	var loader := ContentCatalog.new()
	loader.load_all("res://data")
	var c := battle(loader.data,"E20")
	t.check(c.state.actors.size() == 3,"glass stag occupies two enemy slots with one root helper")
	if c.state.actors.size() != 3: return true
	var boss: Dictionary = c._actor("enemy0")
	var root: Dictionary = c._actor("root")
	t.check(root.definition_id == "root" and root.intent.target_id == "enemy0","root advertises healing its own boss")
	boss.hp = boss.max_hp-100
	c.state.acted_ids = ["hero","enemy0"]
	var before: int = boss.hp
	var result := c.advance()
	t.check(result.ok and c._actor("enemy0").hp > before,"root performs actual ally healing through resolver")
	c._actor("enemy0").statuses.Sealed = {"turns":3}
	c.state.acted_ids = ["hero","enemy0"]
	before = c._actor("enemy0").hp
	result = c.advance()
	t.check(result.ok and c._actor("enemy0").hp == before,"Sealed blocks root healing without changing advertised action")
	c = battle(loader.data,"E31",{"objective:original_order":true})
	var sequence: Array[String] = []
	for _step in range(3):
		sequence.append(c._actor("enemy0").intent.label)
		c.state.actors[0].hp = 10000
		c.state.actors[0].max_hp = 10000
		c.state.acted_ids = ["hero"]
		c.advance()
	t.check(sequence[0] != sequence[1] and sequence[1] != sequence[2] and c._actor("enemy0").intent.label == sequence[0],"archivist repeats an honest three-action pattern")
	t.check(c._actor("enemy0").intent.has("following_label"),"original order evidence reveals the following memory action")
	c = battle(loader.data,"E36")
	var shown: Dictionary = c._actor("enemy0").intent.duplicate(true)
	c._actor("enemy0").hp = int(c._actor("enemy0").max_hp*0.3)
	t.check(c._actor("enemy0").intent == shown,"crossing final boss thresholds preserves advertised action")
	c.state.acted_ids = ["hero"]
	c.advance()
	t.check(c._actor("enemy0").phase == 2 and c._actor("enemy0").get("core_exposed",false),"final boss skips directly to exposed core after its frozen action")
	var signatures: Dictionary = {}
	for item in loader.data.items:
		var key: String = item.slot+":"+str(item.bonuses)
		t.check(not signatures.has(key),"every gear definition changes a build: " + item.id)
		signatures[key] = item.id
	return true
