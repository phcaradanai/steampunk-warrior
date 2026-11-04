extends RefCounted

func _json(path: String):
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func run(t) -> bool:
	for id in GameAudio.MUSIC:
		t.check(FileAccess.file_exists("res://audio/"+id+".wav"),"original music exists: "+id)
		var stream = load("res://audio/"+id+".wav")
		t.check(stream is AudioStreamWAV,"music loads as WAV: "+id)
		if stream is AudioStreamWAV:
			var frames := int(round(stream.get_length()*stream.mix_rate))
			# The importer may compress the data, so compare the loop end with the source PCM length (16-bit, 44-byte header).
			var bytes := FileAccess.get_file_as_bytes("res://audio/"+id+".wav").size() - 44
			t.check(frames > 0 and absi(frames - bytes / (4 if stream.stereo else 2)) <= 1,"loop end matches the whole clip: "+id)
			if id in ["hub","canal","rail","lab","foundry","archive","ending"]:
				t.check(stream.get_length() >= 60.0 and stream.get_length() <= 120.0,"area score is 60-120 s: "+id)
	for id in GameAudio.SFX:
		t.check(load("res://audio/"+id+".wav") is AudioStreamWAV,"original effect loads: "+id)
	var rooms = _json("res://data/rooms.json")
	var rooms_list: Array = rooms if rooms is Array else rooms.get("rooms",[])
	t.check(rooms_list.size() == 12,"twelve rooms are checked for music")
	for room in rooms_list:
		var track := GameAudio.room_track(room.id)
		t.check(track != "city" and track in GameAudio.MUSIC,"room maps to its own existing track: "+room.id)
	t.check(GameAudio.room_track("R01") == "hub" and GameAudio.room_track("R12") == "archive","first and last room use hub and archive scores")
	var types := ["physical","electric","thermal","chemical","Heated"]
	for skill in _json("res://data/skills.json"):
		if skill.get("effects") is Dictionary and skill.effects.has("damage_type"): t.check(skill.effects.damage_type in types,"skill damage type is covered: "+skill.id)
	for type in types:
		var id := GameAudio.sfx_for({"type":"damage","payload":{"type":type,"amount":3}})
		t.check(id in GameAudio.SFX,"damage type has an effect: "+type)
	t.check(GameAudio.sfx_for({"type":"damage","payload":{"type":"physical","amount":99}}) == "heavy","heavy blow has its own effect")
	t.check(GameAudio.sfx_for({"type":"damage","payload":{"type":"physical","amount":20}},60) == "heavy","hit of 25% max HP is heavy")
	t.check(GameAudio.sfx_for({"type":"damage","payload":{"type":"physical","amount":30}},400) == "metal","hit under 25% max HP is metal")
	t.check(GameAudio.sfx_for({"type":"damage","payload":{"type":"physical","amount":99,"shielded":true}}) == "shield","guarded blow uses shield")
	t.check(GameAudio.sfx_for({"type":"heal","payload":{}}) == "heal","heal has an effect")
	for kind in ["attack","guard","vent","retreat"]:
		t.check(GameAudio.sfx_for({"type":"action","payload":{"kind":kind,"skill_id":""}}) in GameAudio.SFX,"action has an effect: "+kind)
	for skill in _json("res://data/skills.json"):
		if skill.get("kind","") == "active":
			t.check(GameAudio.sfx_for({"type":"action","payload":{"kind":"skill","skill_id":skill.id}}) in GameAudio.SFX,"skill has an effect: "+skill.id)
	t.check(GameAudio.sfx_for({"type":"action","payload":{"kind":"skill","skill_id":"S04"}}) == "charge" and GameAudio.sfx_for({"type":"action","payload":{"kind":"skill","skill_id":"S03"}}) == "shot","cast and ranged shot differ")
	t.check(FileAccess.file_exists("res://audio/game_audio.gd"),"music must route through actual game audio service")
	return true
