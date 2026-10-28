extends SceneTree

func _initialize() -> void:
	var catalog := ContentCatalog.new()
	catalog.load_all("res://data")
	var session := GameSession.new(catalog.data)
	session.new_game("C05")
	var original := session.snapshot()
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(original))
	for key in original:
		if original[key] != decoded[key]:
			print("DIFF ",key," original=",original[key]," decoded=",decoded[key])
	print("leaf equal=",original.player.level == decoded.player.level," leaf types=",typeof(original.player.level),"/",typeof(decoded.player.level)," full equal=",original == decoded)
	quit()
