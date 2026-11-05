extends RefCounted

func run(t) -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	var progression := Progression.new(catalog.data)
	# P3-1 pacing: the first E01 clear gives at most one level; each level adds fixed HP/FP.
	for id in ["C01","C02","C03","C04","C05"]:
		var fresh := GameSession.new(catalog.data)
		fresh.new_game(id)
		var won := fresh.commit_result("battle_won",{"id":"battle:pace","encounter_id":"E01"})
		t.check(won.ok and won.state.player.level <= 2,"first E01 clear gains at most one level: "+id)
	var player := progression.new_player("C01")
	var low := progression.derive(player,catalog.data)
	var grown := player.duplicate(true)
	grown.level = 2
	var high := progression.derive(grown,catalog.data)
	t.check(high.max_hp - low.max_hp == Progression.LEVEL_HP and high.max_fp - low.max_fp == Progression.LEVEL_FP,"a level adds fixed HP and FP without touching VIT/INT")
	var leveled := progression.gain_xp(player,40)
	t.check(progression.derive(leveled.state,catalog.data).max_hp - low.max_hp == Progression.LEVEL_HP + 6 and progression.derive(leveled.state,catalog.data).max_fp - low.max_fp == Progression.LEVEL_FP,"level-up screen sees HP (fixed + VIT) and FP lines")
	# P3-2 upgrades.
	var service := InventoryService.new()
	var shop := "R05"
	var weapon := catalog.get_entry("items","W07")
	t.check(InventoryService.upgrade_cost(weapon,0) < InventoryService.upgrade_cost(weapon,1) and InventoryService.upgrade_cost(weapon,1) < InventoryService.upgrade_cost(weapon,2) and InventoryService.upgrade_cost(weapon,3) == -1,"cost rises per level and stops at +3")
	t.check(InventoryService.upgrade_cost(catalog.get_entry("items","W22"),0) > InventoryService.upgrade_cost(weapon,0),"cost rises with tier")
	player = progression.new_player("C01")
	player.items = ["W07"]
	player.equipment.weapon = "W07"
	player.currency = 100000
	var base_attack: int = progression.derive(player,catalog.data).attack
	var spent := 0
	for level in range(3):
		var cost := InventoryService.upgrade_cost(weapon,level)
		var result := service.transact(player,{"kind":"upgrade","item_id":"W07","room_id":shop},catalog.data)
		t.check(result.ok and result.state.upgrades.W07 == level + 1 and result.state.currency == player.currency - cost,"upgrade +%d charges exact cost" % (level + 1))
		player = result.state
		spent += cost
	var up_gain: int = int(roundf(float(weapon.bonuses.attack) * Progression.UPGRADE_RATE * 3.0))
	t.check(progression.derive(player,catalog.data).attack == base_attack + up_gain and base_attack + up_gain == progression.derive(player,catalog.data).attack,"+3 adds the percentage of base bonus to derived attack")
	var capped := service.transact(player,{"kind":"upgrade","item_id":"W07","room_id":shop},catalog.data)
	t.check(not capped.ok and capped.state == player,"+3 is the cap")
	t.check(not service.transact(player,{"kind":"upgrade","item_id":"W07","room_id":"R03"},catalog.data).ok,"upgrade only at a shop room")
	t.check(not service.transact(player,{"kind":"upgrade","item_id":"W08","room_id":shop},catalog.data).ok,"unowned gear cannot be upgraded")
	var poor := progression.new_player("C01")
	poor.equipment.weapon = "W07"
	poor.currency = InventoryService.upgrade_cost(weapon,0) - 1
	var rejected := service.transact(poor,{"kind":"upgrade","item_id":"W07","room_id":shop},catalog.data)
	t.check(not rejected.ok and rejected.state == poor,"insufficient funds rejected without change")
	t.check(UIBuilder.item_description(Progression.upgraded_item(weapon,2)) != UIBuilder.item_description(weapon) and Progression.upgraded_item(weapon,2).name.ends_with("+2"),"upgraded copy shows +N and bigger numbers")
	var sold := player.duplicate(true)
	sold.items = ["W07"]
	sold.equipment.erase("weapon")
	var after_sale := service.transact(sold,{"kind":"sell","index":0},catalog.data)
	t.check(after_sale.ok and not after_sale.state.upgrades.has("W07"),"selling the last copy drops its upgrade")
	# Idempotent through GameSession.commit_result.
	var session := GameSession.new(catalog.data)
	session.new_game("C01")
	session.state.player.equipment.weapon = "W07"
	session.state.player.level = 6
	session.state.player.currency = 1000
	session.state.room_id = shop
	var first := session.commit_result("inventory",{"id":"up:1","request":{"kind":"upgrade","item_id":"W07"}})
	var money: int = session.state.player.currency
	var again := session.commit_result("inventory",{"id":"up:1","request":{"kind":"upgrade","item_id":"W07"}})
	t.check(first.ok and not again.ok and session.state.player.currency == money and session.state.player.upgrades.W07 == 1,"same request id upgrades only once")
	# Save round trip, bad data, and a save from before upgrades existed.
	var saves := SaveService.new(catalog.data,"user://test-upgrade-saves-"+str(Time.get_ticks_usec()))
	var snapshot := session.snapshot()
	t.check(saves.save_slot("manual01",snapshot).ok and saves.load_slot("manual01").state == snapshot,"upgrade levels roundtrip through save")
	var old_save := snapshot.duplicate(true)
	old_save.player.erase("upgrades")
	t.check(saves.save_slot("manual02",old_save).ok and saves.load_slot("manual02").ok,"save without the upgrades field still loads (no upgrades)")
	t.check(progression.derive(old_save.player,catalog.data).attack == progression.derive(snapshot.player,catalog.data).attack - 2,"old save derives without upgrades")
	for bad in [{"W07":4},{"W07":0},{"W07":1.5},{"W08":1},{"nope":1},{"W07":"2"}]:
		var invalid := snapshot.duplicate(true)
		invalid.player.upgrades = bad
		t.check(not saves.save_slot("manual03",invalid).ok,"invalid upgrades rejected: "+str(bad))
	var broken := snapshot.duplicate(true)
	broken.player.upgrades = []
	t.check(not saves.save_slot("manual03",broken).ok,"non-dictionary upgrades rejected")
	# Potion price climbs by chapter.
	t.check(InventoryService.potion_price("R02") < InventoryService.potion_price("R07") and InventoryService.potion_price("R07") < InventoryService.potion_price("R11"),"potion price rises by chapter")
	return true
