extends RefCounted

var serial: int = 0
var session: GameSession
var catalog: ContentCatalog
var policy: WorldController
var technical: bool

func commit(kind: String, payload: Dictionary = {}) -> Dictionary:
	serial += 1
	payload["id"] = "campaign:"+str(serial)
	return session.commit_result(kind,payload)

func travel(to: String) -> bool:
	while session.state.room_id != to:
		var current: int = int(session.state.room_id.substr(1))
		var target: int = int(to.substr(1))
		policy.enter_room("R%02d" % (current+1 if current < target else current-1),"entry")
		if not policy.last_error.is_empty(): return false
	return true

func prepare(destination: String) -> bool:
	if not travel("R01"): return false
	while session.state.player.attribute_points > 0:
		var attribute := "VIT" if int(session.state.player.attribute_points)%4 == 0 else "INT" if technical else "STR"
		if not commit("allocate_attribute",{"attribute":attribute}).ok: return false
	var priorities: Array = [["S04",5],["S09",2],["S11",2],["S20",1],["S08",1],["S06",1],["S14",2],["S15",2],["S21",1],["S22",1],["S04",10]] if technical else [["S01",5],["S09",2],["S11",2],["S02",2],["S03",1],["S05",1],["S13",3],["S01",10],["S09",5]]
	for entry in priorities:
		while session.state.player.skill_points > 0 and int(session.state.player.skill_ranks.get(entry[0],0)) < entry[1]:
			if not commit("learn_skill",{"skill_id":entry[0]}).ok: break
	# Visit only already unlocked shops and use earned currency.
	for shop in ["R02","R05","R07","R09","R11"]:
		if int(shop.substr(1)) > int(destination.substr(1)): continue
		if not travel(shop): return false
		for slot in ["weapon","shield","head","suit"]:
			var chosen: Dictionary = {}
			var best := -1.0
			for item in catalog.data.items:
				if item.slot != slot or item.required_level > session.state.player.level: continue
				if item.source != "shop:"+shop and not item.id in session.state.player.items: continue
				var b: Dictionary = item.bonuses
				var score: float = b.get("tech" if technical else "attack",0)*3+b.get("barrier",0)*0.5+b.get("max_hp",0)*0.4+b.get("armor",0)+b.get("resist",0)+b.get("max_fp",0)*0.5
				var equipped: Dictionary = catalog.get_entry("items",session.state.player.equipment[slot])
				var eb: Dictionary = equipped.bonuses
				var old: float = eb.get("tech" if technical else "attack",0)*3+eb.get("barrier",0)*0.5+eb.get("max_hp",0)*0.4+eb.get("armor",0)+eb.get("resist",0)+eb.get("max_fp",0)*0.5
				if score > maxf(best,old) and (item.id in session.state.player.items or session.state.player.currency >= item.price):
					chosen = item
					best = score
			if not chosen.is_empty():
				if not chosen.id in session.state.player.items:
					if not commit("inventory",{"request":{"kind":"buy","item_id":chosen.id}}).ok: return false
				if not commit("inventory",{"request":{"kind":"equip","index":session.state.player.items.find(chosen.id)}}).ok: return false
		for potion in ["life","focus"]:
			while session.state.player.potions[potion] < (15 if potion == "life" else 10) and session.state.player.currency >= 20:
				if not commit("inventory",{"request":{"kind":"potion_buy","potion":potion}}).ok: return false
	if not travel("R01"): return false
	if not commit("rest").ok: return false
	return travel(destination)

func choose_action(c: CombatController) -> Dictionary:
	var hero: Dictionary = c._actor("hero")
	var enemy: Dictionary = {}
	for other in c.state.actors:
		if other.side == "enemy" and other.hp > 0:
			enemy = other
			if other.id == "root": break
	var kind := "attack"
	var skill := ""
	var dangerous := false
	for other in c.state.actors:
		if other.side != "enemy" or other.hp <= 0: continue
		var intent: Dictionary = other.intent
		var effect: Dictionary = intent.get("skill",{}).get("effects",{})
		if intent.get("power",0) >= 1.5 or effect.get("hits",1) >= 2 or (other.get("boss",false) and effect.get("power",0) >= 1.1):
			dangerous = true
	var healing: int = c.resolver.skill_preview(hero,catalog.get_entry("skills","S09"),int(c.learned.get("S09",1))).heal
	if dangerous and c.learned.has("S11") and hero.fp >= 10 and hero.barrier <= 0 and hero.pressure <= 90 and not enemy.intent.get("skill",{}).get("effects",{}).get("hits",1) > 1:
		kind = "skill"; skill = "S11"
	elif hero.hp < hero.max_hp*0.58 and hero.potions.life > 0 and (not c.learned.has("S09") or healing < hero.max_hp*0.35):
		kind = "life_potion"
	elif hero.hp < hero.max_hp*0.58 and c.learned.has("S09") and hero.fp >= 8 and not hero.statuses.has("Sealed"):
		kind = "skill"; skill = "S09"
	elif hero.hp < hero.max_hp*0.45 and hero.potions.life > 0:
		kind = "life_potion"
	elif dangerous:
		kind = "guard"
	elif hero.pressure > 75:
		kind = "vent"
	elif hero.fp < 10 and hero.potions.focus > 0:
		kind = "focus_potion"
	else:
		skill = "S04" if technical else "S01"
		if not technical and enemy.barrier > 0 and c.learned.has("S02"): skill = "S02"
		if technical and enemy.get("boss",false) and not enemy.statuses.has("Wet") and c.learned.has("S20"): skill = "S20"
		var definition := catalog.get_entry("skills",skill)
		if c.learned.has(skill) and hero.fp >= c.resolver.skill_preview(hero,definition,c.learned[skill]).fp_cost:
			kind = "skill"
		else: skill = ""
	return c.submit_player(kind,skill,enemy.id)

func run(t) -> bool:
	catalog = ContentCatalog.new()
	catalog.load_all("res://data")
	for profession in catalog.data.classes:
		var total_rounds := 0
		session = GameSession.new(catalog.data)
		session.new_game(profession.id)
		policy = WorldController.new(catalog.data,session)
		technical = profession.id in ["C03","C04","C05"]
		for encounter in catalog.data.encounters:
			if profession.id == "C03" and encounter.id == "E15": continue
			if not prepare(encounter.room):
				t.check(false,"earned preparation/travel: "+profession.id+" "+encounter.id)
				return true
			for valve_id in WorldController.ENVIRONMENT:
				if WorldController.ENVIRONMENT[valve_id].room == encounter.room:
					commit("environment",{"object_id":valve_id})
			for quest in catalog.data.story.quests:
				if quest.room != encounter.room or session.state.quest_states[quest.id].state == "turned_in": continue
				var node: String = "D"+quest.id.substr(1)
				commit("quest_event",{"event":{"type":"interact","payload":{"object_id":quest.object_id}}})
				commit("dialogue_choice",{"node_id":node,"choice_id":"accept"})
				var choice := "pragmatic" if profession.id == "C01" and quest.id == "Q04" else "help"
				commit("dialogue_choice",{"node_id":node,"choice_id":choice})
				if choice == "pragmatic": commit("dialogue_choice",{"node_id":node,"choice_id":"confirm_harvest"})
			var c := CombatController.new(catalog.data)
			var start := c.start(encounter.id,session.snapshot(),123)
			if not start.ok:
				t.check(false,"campaign start: "+profession.id+" "+encounter.id+" "+start.reason)
				return true
			for step in range(1800):
				if c.is_finished(): break
				var result := choose_action(c) if c.is_player_turn() else c.advance()
				if OS.get_cmdline_user_args().has("--trace") and encounter.id == "E31" and step < 50:
					print("TRACE ",c.state.round," ",c._actor("hero").hp," ",c._actor("hero").pressure," ",result.events)
				if not result.ok:
					t.check(false,"campaign legal action: "+profession.id+" "+encounter.id+" "+result.reason)
					return true
			t.check(c.state.get("outcome","") == "victory","earned no-repeat campaign: "+profession.id+" "+encounter.id)
			if c.state.get("outcome","") != "victory":
				print("Campaign diagnostic ",profession.id," ",encounter.id," level",session.state.player.level," stats",session.progression.derive(session.state.player,catalog.data)," actors",c.state.actors)
				return true
			total_rounds += int(c.state.round)
			if not session.commit_result("battle_won",c.result_payload()).ok: return false
		print("Campaign complete: ",profession.id," level",session.state.player.level," currency",session.state.player.currency," total_rounds",total_rounds)
		t.check(session.state.first_clears.has("B06") and session.state.quest_states.Q08.state == "turned_in","all bosses and archive quest reachable: "+profession.id)
		if OS.get_cmdline_user_args().has("--release-fixtures"):
			var fixtures := SaveService.new(catalog.data,"user://test-release-fixtures-owned")
			var saved := fixtures.save_slot("manual"+profession.id.substr(1),session.snapshot()) if profession.id in ["C01","C02","C03"] else {"ok":true}
			t.check(saved.ok,"earned release fixture validates: "+profession.id)
		var ending: String = {"C01":"Seize","C02":"Shutdown"}.get(profession.id,"Cure")
		t.check(commit("choose_ending",{"ending":ending}).ok,"earned ending "+profession.id+" "+ending)
		t.check(not commit("choose_ending",{"ending":"Cure"}).ok if profession.id == "C01" else true,"harvest remains irreversible after full campaign")
	return true
