class_name InventoryService
extends RefCounted

func _item(content: Dictionary, id: String) -> Dictionary:
	for item in content.get("items", []):
		if item.id == id:
			return item
	return {}

const UPGRADE_COST := [0.5, 0.9, 1.5]
const POTION_PRICE := {"R01":20,"R02":20,"R03":20,"R04":20,"R05":30,"R06":30,"R07":45,"R08":45,"R09":65,"R10":65,"R11":90,"R12":90}

# Potion price climbs by chapter so late-game supplies stay a real expense.
static func potion_price(room_id: String) -> int:
	return int(POTION_PRICE.get(room_id, 20))

# Cost to raise an item from `level` to `level + 1`; -1 at the cap.
static func upgrade_cost(item: Dictionary, level: int) -> int:
	if level < 0 or level >= Progression.MAX_UPGRADE:
		return -1
	return int(round(float(item.get("price", 0)) * UPGRADE_COST[level] / 5.0)) * 5

static func owns(player: Dictionary, id: String) -> bool:
	return id in player.get("items", []) or id in player.get("stash", []) or id in player.get("equipment", {}).values()

func _reject(player: Dictionary, reason: String) -> Dictionary:
	return {"ok":false,"reason":reason,"state":player.duplicate(true),"events":[]}

func transact(player: Dictionary, request: Dictionary, catalog: Dictionary) -> Dictionary:
	var next: Dictionary = player.duplicate(true)
	var kind: String = str(request.get("kind", ""))
	var events: Array = []
	if kind == "buy":
		var item := _item(catalog, str(request.get("item_id", "")))
		if item.is_empty() or item.source != "shop:" + str(request.get("room_id", "")):
			return _reject(player, "ร้านนี้ไม่มีอุปกรณ์ชิ้นนี้")
		if next.currency < int(item.price):
			return _reject(player, "เงินไม่พอ")
		if next.items.size() >= 24:
			return _reject(player, "กระเป๋าเต็ม ฝากของก่อนซื้อ")
		next.currency -= int(item.price)
		next.items.append(item.id)
	elif kind in ["equip", "sell"]:
		var index: int = int(request.get("index", -1))
		if index < 0 or index >= next.items.size():
			return _reject(player, "เลือกอุปกรณ์ในกระเป๋า")
		var item := _item(catalog, str(next.items[index]))
		if item.is_empty():
			return _reject(player, "ข้อมูลอุปกรณ์ไม่ถูกต้อง")
		if kind == "sell":
			next.currency += int(floor(float(item.price) * 0.35))
			next.items.remove_at(index)
			if not owns(next, item.id) and next.get("upgrades", {}).has(item.id):
				next.upgrades.erase(item.id)
		else:
			if int(next.level) < int(item.required_level):
				return _reject(player, "เลเวลยังไม่ถึง")
			var previous: String = next.equipment.get(item.slot, "")
			next.items.remove_at(index)
			next.equipment[item.slot] = item.id
			if not previous.is_empty():
				next.items.append(previous)
	elif kind == "unequip":
		var slot: String = str(request.get("slot", ""))
		if not next.equipment.has(slot):
			return _reject(player, "ไม่มีอุปกรณ์ในช่องนี้")
		if next.items.size() >= 24:
			return _reject(player, "กระเป๋าเต็ม")
		next.items.append(next.equipment[slot])
		next.equipment.erase(slot)
	elif kind == "reward":
		var items = request.get("items", [])
		if not items is Array or items.size() > 100:
			return _reject(player, "รายการรางวัลไม่ถูกต้อง")
		for id in items:
			if not id is String or _item(catalog, id).is_empty():
				return _reject(player, "อุปกรณ์รางวัลไม่ถูกต้อง")
		for id in items:
			if next.items.size() < 24:
				next.items.append(id)
			else:
				next.stash.append(id)
				events.append({"id":"overflow:" + str(events.size()),"type":"stash_overflow","payload":{"item_id":id}})
	elif kind == "stash_take":
		var index: int = int(request.get("index", -1))
		if index < 0 or index >= next.stash.size() or next.items.size() >= 24:
			return _reject(player, "เลือกของในคลังและเว้นช่องกระเป๋า")
		next.items.append(next.stash[index])
		next.stash.remove_at(index)
	elif kind == "stash_put":
		var index: int = int(request.get("index", -1))
		if index < 0 or index >= next.items.size():
			return _reject(player, "เลือกอุปกรณ์ในกระเป๋า")
		next.stash.append(next.items[index])
		next.items.remove_at(index)
	elif kind == "upgrade":
		var item := _item(catalog, str(request.get("item_id", "")))
		if item.is_empty() or not item.slot in ["weapon", "shield", "head", "suit"] or not owns(next, item.id):
			return _reject(player, "ไม่มีอุปกรณ์ชิ้นนี้ให้อัปเกรด")
		if not catalog.get("items", []).any(func(entry): return entry.source == "shop:" + str(request.get("room_id", ""))):
			return _reject(player, "อัปเกรดได้ที่ร้านอุปกรณ์เท่านั้น")
		if not next.has("upgrades"):
			next["upgrades"] = {}
		var level: int = int(next.upgrades.get(item.id, 0))
		var cost := upgrade_cost(item, level)
		if cost < 0:
			return _reject(player, "อัปเกรดเต็ม +%d แล้ว" % Progression.MAX_UPGRADE)
		if next.currency < cost:
			return _reject(player, "เงินไม่พอ")
		next.currency -= cost
		next.upgrades[item.id] = level + 1
	elif kind == "potion_buy":
		var potion: String = str(request.get("potion", ""))
		var potion_cost := potion_price(str(request.get("room_id", "")))
		if not potion in ["life", "focus"] or next.potions.get(potion, 0) >= 99 or next.currency < potion_cost:
			return _reject(player, "ซื้อยาไม่ได้ เงินไม่พอหรือเก็บครบ99แล้ว")
		next.currency -= potion_cost
		next.potions[potion] = int(next.potions.get(potion, 0)) + 1
	elif kind == "food":
		if next.currency < 30:
			return _reject(player, "เงินไม่พอ กลับโรงซ่อมพักฟรีได้")
		next.currency -= 30
		next.energy = mini(100, int(next.energy) + 50)
	else:
		return _reject(player, "ไม่รู้จักรายการอุปกรณ์")
	var progression := Progression.new(catalog)
	var stats := progression.derive(next, catalog)
	next.current_hp = mini(int(next.current_hp), int(stats.max_hp))
	next.current_fp = mini(int(next.current_fp), int(stats.max_fp))
	return {"ok":true,"reason":"","state":next,"events":events}
