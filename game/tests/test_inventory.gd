extends RefCounted

func run(t) -> bool:
	if not FileAccess.file_exists("res://rpg/inventory_service.gd"):
		t.check(false,"InventoryService must transact without partial changes")
		return true
	var catalog = load("res://core/content_catalog.gd").new()
	catalog.load_all("res://data")
	var progression = load("res://rpg/progression.gd").new(catalog.data)
	var service = load("res://rpg/inventory_service.gd").new()
	var player: Dictionary = progression.new_player("C01")
	player.currency = 30
	var result: Dictionary = service.transact(player,{"kind":"buy","item_id":"W02","room_id":"R02"},catalog.data)
	t.check(result.ok and result.state.currency == 0 and result.state.items == ["W02"],"purchase charges exact price and inserts gear")
	var rejected: Dictionary = service.transact(result.state,{"kind":"buy","item_id":"W02","room_id":"R02"},catalog.data)
	t.check(not rejected.ok and rejected.state == result.state,"insufficient currency leaves inventory unchanged")
	rejected = service.transact(player,{"kind":"buy","item_id":"W26","room_id":"R02"},catalog.data)
	t.check(not rejected.ok and rejected.state == player,"boss gear cannot be forged into a shop purchase")
	player = result.state
	var original_base: Dictionary = player.base_attributes.duplicate(true)
	result = service.transact(player,{"kind":"equip","index":0},catalog.data)
	t.check(result.ok and result.state.equipment.weapon == "W02" and result.state.items == ["W01"],"equip swaps selected item and old weapon atomically")
	player = result.state
	for _i in range(100):
		result = service.transact(player,{"kind":"equip","index":0},catalog.data)
		player = result.state
	t.check(player.base_attributes == original_base and progression.derive(player,catalog.data).attack == 22,"100equipment swaps do not drift base or derived stats")
	result = service.transact(player,{"kind":"sell","index":0},catalog.data)
	t.check(result.ok and result.state.currency == 10,"sale rounds down30x0.35 to10")
	player.items = ["W26"]
	rejected = service.transact(player,{"kind":"equip","index":0},catalog.data)
	t.check(not rejected.ok and rejected.state == player,"level requirement prevents equip without losing held gear")
	player.items = []
	for _i in range(24):
		player.items.append("W01")
	result = service.transact(player,{"kind":"reward","items":["W26"]},catalog.data)
	t.check(result.ok and result.state.items.size() == 24 and result.state.stash == ["W26"] and not result.events.is_empty(),"full bag sends reward to stash with notification")
	rejected = service.transact(player,{"kind":"reward","items":["W26","missing"]},catalog.data)
	t.check(not rejected.ok and rejected.state == player,"invalid item rejects entire reward transaction")
	rejected = service.transact(player,{"kind":"unequip","slot":"weapon"},catalog.data)
	t.check(not rejected.ok and rejected.state == player,"unequip into full bag does not discard equipment")
	player.items = []
	result = service.transact(player,{"kind":"unequip","slot":"weapon"},catalog.data)
	t.check(result.ok and not result.state.equipment.has("weapon") and result.state.items == ["W02"],"unequip preserves exact gear identity")
	return true
