extends RefCounted

func run(t) -> bool:
	# Missing validation must fail before malformed content can enter a game.
	if not FileAccess.file_exists("res://core/content_catalog.gd"):
		t.check(false, "ContentCatalog must load and reject invalid content")
		return true
	var catalog = load("res://core/content_catalog.gd").new()
	catalog.load_all("res://data")
	t.check(catalog.validate_all().is_empty(), "complete content references validate: " + str(catalog.validate_all()))
	for pair in [["classes", 5], ["skills", 22], ["items", 62], ["rooms", 12], ["training", 4], ["encounters", 36]]:
		t.check(catalog.data.get(pair[0], []).size() == pair[1], "%s content count" % pair[0])
	t.check(catalog.data.get("enemies", []).size() == 32, "26 enemy archetypes plus six bosses")
	t.check(catalog.get_entry("skills", "S22").get("pressure_delta") == -40, "phase vent definition available to real consumers")
	t.check(catalog.get_entry("items", "W26").get("source") == "boss:B06", "extra weapon has deterministic source")
	# Late fights (R10-R12) must not recycle the chapter 1-2 mutants N01-N09; every foe needs a figure.
	var early := ["N01","N02","N03","N04","N05","N06","N07","N08","N09"]
	# Building figures headless spams dummy-renderer material errors; capture_roster.gd builds them for real.
	for enemy in catalog.data.enemies:
		t.check(Roster3D.has(enemy.id), "enemy %s has a Roster3D figure" % enemy.id)
	for encounter in catalog.data.encounters:
		for enemy_id in encounter.enemies:
			t.check(catalog.get_entry("enemies", enemy_id).has("id"), "%s references existing enemy %s" % [encounter.id, enemy_id])
			if encounter.room in ["R10","R11","R12"]:
				t.check(not early.has(enemy_id), "%s in %s does not reuse early foe %s" % [encounter.id, encounter.room, enemy_id])
	var original: Dictionary = catalog.data.duplicate(true)
	catalog.data.skills.append(catalog.data.skills[0].duplicate(true))
	t.check(not catalog.validate_all().is_empty(), "duplicate IDs rejected")
	catalog.data = original.duplicate(true)
	catalog.data.skills[0].parents = ["S22"]
	catalog.data.skills[21].parents = ["S01"]
	t.check(not catalog.validate_all().is_empty(), "cyclic prerequisites rejected")
	catalog.data = original.duplicate(true)
	catalog.data.rooms[0].exits[0].to = "missing_room"
	t.check(not catalog.validate_all().is_empty(), "missing room exit rejected")
	catalog.data = original.duplicate(true)
	catalog.data.rooms[1].exits[1].requires = "B06"
	t.check(not catalog.validate_all().is_empty(), "boss behind its own gate rejected")
	catalog.data = original.duplicate(true)
	catalog.data.items[0].source = "quest:missing"
	t.check(not catalog.validate_all().is_empty(), "missing gear acquisition quest rejected")
	catalog.data = original.duplicate(true)
	catalog.data.skills[0].fp_cost = -10
	t.check(not catalog.validate_all().is_empty(), "invalid resource costs rejected at data boundary")

	catalog.data = original.duplicate(true)
	catalog.data.story.dialogue[0].speaker = "missing_npc"
	t.check(not catalog.validate_all().is_empty(), "unknown dialogue speaker rejected")
	catalog.data = original.duplicate(true)
	catalog.data.story.quests[0].item = "missing_item"
	t.check(not catalog.validate_all().is_empty(), "unknown quest reward gear rejected")
	# Class traits are shown to players, so design shorthand ("barrier20", "Wet", "1turn") must not leak through.
	var shorthand := RegEx.create_from_string("(?i)[A-Za-z]+\\d|\\d[A-Za-z]|barrier|FP ?cost|turn|Marked|Wet|Corroded")
	for profession in catalog.data.classes:
		t.check(not profession.trait.is_empty() and shorthand.search(profession.trait) == null, "class %s trait reads as plain Thai: %s" % [profession.id, profession.trait])
	# Room purposes are the entry banner subtitle, so no designer ids like "บอสB04".
	for room in catalog.data.rooms:
		t.check(RegEx.create_from_string("[A-Za-z]").search(room.purpose) == null, "room %s banner has no design ids: %s" % [room.id, room.purpose])
	return true
